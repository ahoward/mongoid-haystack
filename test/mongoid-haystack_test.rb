require_relative 'helper'

Testing Mongoid::Haystack do
##
#
  Mongoid::Haystack.reset!

  setup do
    [A, B, C].map{|m| m.destroy_all}
    Mongoid::Haystack.destroy_all
  end

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
    assert{ Mongoid::Haystack.stem('dogs cats') == %w[ dog cat ] }
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
    assert{ Mongoid::Haystack::Count[:tokens].value == 3 }
  end

  testing 'that removing a model from the index decrements counts appropriately' do
  #
    a = A.create!(:content => 'dog')
    b = A.create!(:content => 'cat')
    c = A.create!(:content => 'cats dogs')

    assert{ Mongoid::Haystack.index(A) }

  #
    assert{ Mongoid::Haystack.search('cat').first }

    assert{ Mongoid::Haystack::Token.where(:value => 'cat').first.count == 2 }
    assert{ Mongoid::Haystack::Token.where(:value => 'dog').first.count == 2 }
    assert{ Mongoid::Haystack::Count[:tokens].value == 4 }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack.unindex(c) }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack::Count[:tokens].value == 2 }
    assert{ Mongoid::Haystack::Token.where(:value => 'cat').first.count == 1 }
    assert{ Mongoid::Haystack::Token.where(:value => 'dog').first.count == 1 }

    assert{ Mongoid::Haystack::Count[:tokens].value == 2 }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack.unindex(b) }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack::Count[:tokens].value == 1 }
    assert{ Mongoid::Haystack::Token.where(:value => 'cat').first.count == 0 }
    assert{ Mongoid::Haystack::Token.where(:value => 'dog').first.count == 1 }

    assert{ Mongoid::Haystack::Count[:tokens].value == 1 }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack.unindex(a) }
    assert{ Mongoid::Haystack::Token.all.map(&:value).sort == %w( cat dog ) }
    assert{ Mongoid::Haystack::Count[:tokens].value == 0 }
    assert{ Mongoid::Haystack::Token.where(:value => 'cat').first.count == 0 }
    assert{ Mongoid::Haystack::Token.where(:value => 'dog').first.count == 0 }
  end
end
