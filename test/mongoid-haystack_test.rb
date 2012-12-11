require_relative 'helper'

Testing Mongoid::Haystack do
##
#
  testing 'that models can, at minimum, be indexed and searched' do
    a = A.create!(:content => 'dog')
    b = B.create!(:content => 'cat')

    assert{ Mongoid::Haystack.index(a) }
    assert{ Mongoid::Haystack.index(b) }

    assert{ Mongoid::Haystack.search('dog').map(&:model) == [a] }
    assert{ Mongoid::Haystack.search('cat').map(&:model) == [b] }
  end

##
#
  testing 'that results are returned as chainable Mongoid::Criteria' do
     k = new_klass

     3.times{ k.create! :content => 'cats' }

     results = assert{ Mongoid::Haystack.search('cat') }
     assert{ results.is_a?(Mongoid::Criteria) }
  end

##
#
  testing 'that word occurance affects the sort' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dog dog')
    c = A.create!(:content => 'dog dog dog')
    
    assert{ Mongoid::Haystack.index(A) }
    assert{ Mongoid::Haystack.search('dog').map(&:model) == [c, b, a] }
  end

##
#
  testing 'that rare words float to the front of the results' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dog dog')
    c = A.create!(:content => 'dog dog dog')
    d = A.create!(:content => 'dog dog dog cat')
    
    assert{ Mongoid::Haystack.index(A) }
    assert{ Mongoid::Haystack.search('cat dog').map(&:model) == [d, c, b, a] }
  end

##
#
  testing 'that basic stemming can be performed' do
    assert{ Mongoid::Haystack.stems_for('dogs cats fishes') == %w[ dog cat fish ] }
  end

  testing 'that words are stemmed when they are indexed' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dogs')
    c = A.create!(:content => 'dogen')

    assert{ Mongoid::Haystack.index(A) }

    assert{
      results = Mongoid::Haystack.search('dog').map(&:model)
      results.include?(a) and results.include?(b) and !results.include?(c)
    }
  end

##
#
  testing 'that counts are kept regarding each seen token' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dogs')
    c = A.create!(:content => 'cat')

    assert{ Mongoid::Haystack.index(A) }

    assert{ Mongoid::Haystack::Token.count == 2 }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack::Token.total == 3 }
  end

  testing 'that removing a model from the index decrements counts appropriately' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'cat')
    c = A.create!(:content => 'cats dogs')

    assert{ Mongoid::Haystack.index(A) }

    assert{ Mongoid::Haystack.search('cat').first }

    assert{ Mongoid::Haystack::Token.where(:value => 'cat').first.count == 2 }
    assert{ Mongoid::Haystack::Token.where(:value => 'dog').first.count == 2 }
    assert{ Mongoid::Haystack::Token.total == 4 }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack.unindex(c) }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack::Token.total == 2 }
    assert{ Mongoid::Haystack::Token.where(:value => 'cat').first.count == 1 }
    assert{ Mongoid::Haystack::Token.where(:value => 'dog').first.count == 1 }

    assert{ Mongoid::Haystack::Token.total == 2 }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack.unindex(b) }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack::Token.total == 1 }
    assert{ Mongoid::Haystack::Token.where(:value => 'cat').first.count == 0 }
    assert{ Mongoid::Haystack::Token.where(:value => 'dog').first.count == 1 }

    assert{ Mongoid::Haystack::Token.total == 1 }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack.unindex(a) }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack::Token.total == 0 }
    assert{ Mongoid::Haystack::Token.where(:value => 'cat').first.count == 0 }
    assert{ Mongoid::Haystack::Token.where(:value => 'dog').first.count == 0 }
  end

##
#
  testing 'that search uses a b-tree index' do
    a = A.create!(:content => 'dog')

    assert{ Mongoid::Haystack.index(A) }
    assert{ Mongoid::Haystack.search('dog').explain['cursor'] =~ /BtreeCursor/i }
  end

##
#
  testing 'that classes can export a custom [score|keywords|fulltext] for the search index' do
    k = new_klass do 
      def to_haystack
        colors.push(color = colors.shift)

        {
          :score => score,

          :keywords => "cats #{ color }",

          :fulltext => 'now is the time for all good men...'
        }
      end

      def self.score
        @score ||= 0
      ensure
        @score += 1
      end

      def score
        self.class.score
      end

      def self.colors
        @colors ||= %w( black white )
      end

      def colors
        self.class.colors
      end
    end

    a = k.create!(:content => 'dog')
    b = k.create!(:content => 'dogs too')

    assert{ a.haystack_index.score == 0 }
    assert{ b.haystack_index.score == 1 }

    assert do
      a.haystack_index.tokens.map(&:value).sort ==
        ["black", "cat", "good", "men", "time"]
    end
    assert do
      b.haystack_index.tokens.map(&:value).sort ==
        ["cat", "good", "men", "time", "white"]
    end

    assert{ Mongoid::Haystack.search('cat').count == 2 }
    assert{ Mongoid::Haystack.search('black').count == 1 }
    assert{ Mongoid::Haystack.search('white').count == 1 }
    assert{ Mongoid::Haystack.search('good men').count == 2 }
  end

##
#
  testing 'that set intersection and union are supported via search' do
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'dog cat')
    c = A.create!(:content => 'dog cat fish')

    assert{ Mongoid::Haystack.index(A) }

    assert{ Mongoid::Haystack.search(:any => 'dog').count == 3 }
    assert{ Mongoid::Haystack.search(:any => 'dog cat').count == 3 }
    assert{ Mongoid::Haystack.search(:any => 'dog cat fish').count == 3 }

    assert{ Mongoid::Haystack.search(:all => 'dog').count == 3 }
    assert{ Mongoid::Haystack.search(:all => 'dog cat').count == 2 }
    assert{ Mongoid::Haystack.search(:all => 'dog cat fish').count == 1 }
  end

##
#
  testing 'that classes can export custom facets and then search them, again using a b-tree index' do
    k = new_klass do
      field(:to_haystack, :type => Hash, :default => proc{ Hash.new })
    end

    a = k.create!(:content => 'hello kitty', :to_haystack => { :keywords => 'cat', :facets => {:x => 42.0}})
    b = k.create!(:content => 'hello kitty', :to_haystack => { :keywords => 'cat', :facets => {:x => 4.20}})

    assert{ Mongoid::Haystack.search('cat').where(:facets => {'x' => 42.0}).first.model == a }
    assert{ Mongoid::Haystack.search('cat').where(:facets => {'x' => 4.20}).first.model == b }

    assert{ Mongoid::Haystack.search('cat').where('facets.x' => 42.0).first.model == a }
    assert{ Mongoid::Haystack.search('cat').where('facets.x' => 4.20).first.model == b }

    assert{ Mongoid::Haystack.search('cat').where('facets' => {'x' => 42.0}).explain['cursor'] =~ /BtreeCursor/ }
    assert{ Mongoid::Haystack.search('cat').where('facets' => {'x' => 4.20}).explain['cursor'] =~ /BtreeCursor/ }

    assert{ Mongoid::Haystack.search('cat').where('facets.x' => 42.0).explain['cursor'] =~ /BtreeCursor/ }
    assert{ Mongoid::Haystack.search('cat').where('facets.x' => 4.20).explain['cursor'] =~ /BtreeCursor/ }
  end

##
#
  testing 'that keywords are considered more highly than fulltext' do
    k = new_klass do
      field(:title)
      field(:body)

      def to_haystack
        { :keywords => title, :fulltext => body }
      end
    end

    a = k.create!(:title => 'the cats', :body => 'like to meow')
    b = k.create!(:title => 'the dogs', :body => 'do not like to meow, they bark at cats')

    assert{ Mongoid::Haystack.search('cat').count == 2 }
    assert{ Mongoid::Haystack.search('cat').first.model == a }

    assert{ Mongoid::Haystack.search('meow').count == 2 }
    assert{ Mongoid::Haystack.search('bark').count == 1 }
    assert{ Mongoid::Haystack.search('dog').first.model == b }
  end

##
#
  testing 'that re-indexing a class is idempotent' do
    k = new_klass do
      field(:title)
      field(:body)

      def to_haystack
        { :keywords => title, :fulltext => body }
      end
    end

    n = 10

    n.times do
      k.create!(:title => 'the cats and dogs', :body => 'now now is is the the time time for for all all good good men women')
    end

    n.times do
      k.create!(:title => 'a b c abc xyz abc xyz b', :body => 'pdq pdq pdq xyz teh ngr am')
    end

    assert{ Mongoid::Haystack.search('cat').count == n }
    assert{ Mongoid::Haystack.search('pdq').count == n }

    ca = Mongoid::Haystack::Token.all.inject({}){|hash, token| hash.update token.id => token.value}

    assert{ k.search_index_all! }

    cb = Mongoid::Haystack::Token.all.inject({}){|hash, token| hash.update token.id => token.value}

    assert{ ca.size == Mongoid::Haystack::Token.count }
    assert{ cb.size == Mongoid::Haystack::Token.count }
    assert{ ca == cb }
  end

##
#
   testing 'that not just any model can be indexed' do
     o = new_klass.create!
     assert{ begin; Mongoid::Haystack::Index.add(o); rescue Object => e; e.is_a?(ArgumentError); end }
   end

##
#
  testing 'that results can be expanded efficiently if need be' do
     k = new_klass
     3.times{ k.create! :content => 'cats' }

     results = assert{ Mongoid::Haystack.search('cat') }
     assert{ Mongoid::Haystack.models_for(results).map{|model| model.class} == [k, k, k] }
  end

##
#
  testing 'basic pagination' do
     k = new_klass
     11.times{|i| k.create! :content => "cats #{ i }" }

     assert{ k.search('cat').paginate(:page => 1, :size => 2).to_a.size == 2 }
     assert{ k.search('cat').paginate(:page => 2, :size => 5).to_a.size == 5 }

     accum = []

     n = 6
     size = 2
     (1..n).each do |page|
       list = assert{ k.search('cat').paginate(:page => page, :size => size) }
       accum.push(*list)
       assert{ list.num_pages == n }
       assert{ list.total_pages == n }
       assert{ list.current_page == page }
     end

     a = accum.map{|i| i.model}.sort_by{|m| m.content}
     b = k.all.sort_by{|m| m.content}

     assert{ a == b }
  end

##
#
  testing 'that pagination preserves the #model terminator' do
     k = new_klass
     11.times{|i| k.create! :content => "cats #{ i }" }

     list = assert{ k.search('cat').paginate(:page => 1, :size => 2) }
     assert{ list.is_a?(Mongoid::Criteria) }

     models = assert{ list.models }
     assert{ models.is_a?(Array) }
  end

protected

  def new_klass(&block)
    if Object.send(:const_defined?, :K)
      Object.const_get(:K).destroy_all
      Object.send(:remove_const, :K)
    end

    k = Class.new(A) do
      self.default_collection_name = :ks
      def self.name() 'K' end
    end

    Object.const_set(:K, k)

    k.class_eval do
      include ::Mongoid::Haystack::Search
      class_eval(&block) if block
    end

    k
  end

  H = Mongoid::Haystack
  T = Mongoid::Haystack::Token
  I = Mongoid::Haystack::Index

  setup do
    [A, B, C].map{|m| m.destroy_all}
    Mongoid::Haystack.destroy_all
  end

  at_exit{ K.destroy_all if defined?(K) }
end
