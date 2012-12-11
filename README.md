NAME
----

  mongoid-haystack.rb

DESCRIPTION
-----------

  mongoid-haystack provides a zero-config, POLS, pure mongo, fulltext search
  solution for your mongoid models.

INSTALL
-------

  rubygems: gem intstall 'mongoid-haystack'

  Gemfile: gem 'mongoid-haystack'

  rake db:mongoid:create_indexes  # important!!!!!!!!

````ruby

    # you might want this in lib/tasks/db.rake

    namespace :db do
      namespace :mongoid do
        task :create_indexes do
          Mongoid::Haystack.create_indexes
        end
      end
    end


````

SYNOPSIS
--------

````ruby

  # simple usage is simple
  #
    class Article
      include Mongoid::Document
      include Mongoid::Haystack

      field(:content, :type => String)
    end

    Article.create!(:content => 'teh cats')

    results = Article.search('cat')

    article = results.first.model

  # by default 'search' returns a Mongoid::Criteria object.  the result set will
  # be full of objects that refer to a model in your app via a polymorphic
  # relation out.  aka
  #
  #   Article.search('foobar').first.class       #=> Mongoid::Haystack::Index
  #   Article.search('foobar').first.model.class #=> Article
  #
  # in an index view you are not going to want to expand the search index
  # objects into full blown models one at the time (N+1) so you can use the
  # 'models' method on the collection to effciently expand the collection into
  # your application models with the fewest possible queries.  note that
  # 'models' is a terminal operator.  that is to say it returns an array and,
  # afterwards, no more fancy query language is gonna work.

    @results = Mongoid::Haystack.search('needle').models

  # pagination is supported out of the box.  note that you should chain it
  # *b4* any call to 'models'

    @results = 
      Mongoid::Haystack.search('needle').paginate(:page => 3, :size => 42).models


  # haystack stems the search terms and does score based sorting all using a
  # fast b-tree 
  #
    a = Article.create!(:content => 'cats are awesome')
    b = Article.create!(:content => 'dogs eat cats')
    c = Article.create!(:content => 'dogs dogs dogs')

    results = Article.search('dogs cats').map(&:model)
    results == [b, a, c] #=> true

    results = Article.search('awesome').map(&:model)
    results == [a] #=> true


  # cross models searching is supported out of the box, and models can
  # customise how they are indexed:
  #
  # - a global score lets some models appear hight in the global results
  # - keywords count more than fulltext 
  #
    class Article
      include Mongoid::Document
      include Mongoid::Haystack

      field(:title, :type => String)
      field(:content, :type => String)

      def to_haystack
        { :score => 11, :keywords => title, :fulltext => content }
      end
    end

    class Comment
      include Mongoid::Document
      include Mongoid::Haystack

      field(:content, :type => String)

      def to_haystack
        { :score => -11, :fulltext => content }
      end
    end

    a1 = Article.create!(:title => 'hot pants', :content => 'teh b 52s rock')
    a2 = Article.create!(:title => 'boring title', :content => 'but hot content that rocks')

    c = Comment.create!(:content => 'those guys rock')

    results = Mongoid::Haystack.search('rock')
    results.count #=> 3

    models = Mongoid::Haystack.models_for(results)
    models == [a1, a2, c]  #=> true. articles first beause we generally score them higher

    results = Mongoid::Haystack.search('hot')
    models = Mongoid::Haystack.models_for(results)
    models == [a1, a2]  #=> true. because keywords score highter than general fulltext


  # you can decorate your search items with arbirtrary meta data and filter
  # searches by it later.  this too uses a b-tree index.
  #
    class Article
      include Mongoid::Document
      include Mongoid::Haystack

      belongs_to :author, :class_name => '::User'

      field(:title, :type => String)
      field(:content, :type => String)

      def to_haystack
        { 
          :score    => author.popularity,
          :keywords => title,
          :fulltext => content,
          :facets   => {:author_id => author.id}
        }
      end
    end

    a = 
      author.articles.create!(
        :title => 'iggy and keith',
        :content => 'seen the needles and the damage done...'
      )

    author_articles = Article.search('needle', :facets => {:author_id => author.id})


````

DESCRIPTION
-----------

there two main pathways to understand in the code.  shit going into the
index, and shit coming out.

shit going in entails:

- stem and stopword the search terms.
- create or update a new token for each
- create an index item reference all the tokens with precomputed scores

for example the terms 'dog dogs cat' might result in these tokens

````javascript

  [
    {
      '_id'   : '0x1',
      'value' : 'dog',
      'count' : 2
    },


    {
      '_id'   : '0x2',
      'value' : 'cat',
      'count' : 1
    }
  ]

````

  and this index item


````javascript

    {
      '_id'        : '50c11759a04745961e000001'

      'model_type' : 'Article',
      'model_id'   : '50c11775a04745461f000001'

      'tokens'     : ['0x1', '0x2'],

      'score'      : 10,

      'keyword_scores' : {
        '0x1' : 2,
        '0x2' : 1
      },

      'fulltext_scores' : {
      }
    }


````

being built

in addition, some other information is tracked such and the total number of
search tokens every discovered in the corpus
  


a few things to notice:
  
- the tokens are counted and auto-id'd using hex notation and a sequence
  generator.  the reason for this is so that their ids are legit hash keys
  in the keyword and fulltext score hashes.

- the data structure above allows both filtering for index items that have
  certain tokens, but also ordering them based on global, keyword, and
  fulltext score without resorting to map-reduce: a b-tree index can be
  used.

- all tokens have their text/stem stored exactly once.  aka: we do not store
  'hugewords' all over the place but store it once and count occurances of
  it to keep the total index much smaller




pulling objects back out in a search involved these logical steps:

- filter the search terms through the same tokenizer as when indexed

- lookup tokens for each of the tokens in the search string

- using the count for each token, plus the global token count that has been
  tracked we can decide to order the results by relatively rare words first
  and, all else being equal (same rarity bin: 0.10, 0.20, 0.30, etc.), the
  order in which the user typed the words

- this approach is applies and is valid whether we are doing a union (or) or
  intersection (all) search and regardless of whether facets are included in
  the search.  facets, however, never affect the order unless done so by the
  user manually.  eg

````ruby

  results =
    Mongoid::Haystack.
      search('foo bar', :facets => {:hotness.gte => 11}).
        order_by('facets.hotness' => :desc)

````
  

SEE ALSO
--------
  tests: <a href='https://github.com/ahoward/mongoid-haystack/blob/master/test/mongoid-haystack_test.rb'>./test/mongoid-haystack_test.rb<a/>
