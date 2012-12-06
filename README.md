NAME
----

  mongoid-haystack.rb

DESCRIPTION
-----------

  mongoid-haystack provides a zero-config, POLS, pure mongo, fulltext search
  solution for your mongoid models.

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


  # haystack stems the search terms and does score based sorting all using a
  # fast b-tree 
  #
    a = Article.create!(:content => 'cats are awesome')
    b = Article.create!(:content => 'dogs eat cats')
    c = Article.create!(:content => 'dogs dogs dogs')

    results = Article.search('dogs cats').models
    results == [b, a, c] #=> true

    results = Article.search('awesome').models
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

    models = results.models
    models == [a1, a2, c]  #=> true. articles first beause we generally score them higher

    results = Mongoid::Haystack.search('hot')
    models = results.models
    models == [a1, a2]  #=> true. because keywords score highter that general fulltext

  # by default searching returns Mongoid::Haystack::Index objects. you'll want
  # to expand these results to the models they reference in your views, but
  # avoid doing an N+1 query.  to do this simply call #models on the result set
  # and the models will be eager loaded using only as many queries as their are
  # model types in your result set
  #

    @results = Mongoid::Haystack.search('needle').page(params[:page]).per(10)
    @models = @results.models


````

SEE ALSO
--------
  tests: <a href='https://github.com/ahoward/mongoid-haystack/blob/master/test/mongoid-haystack_test.rb'>./test/mongoid-haystack_test.rb<a/>
