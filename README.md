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
    class Book
      include Mongoid::Document
      include Mongoid::Haystack

      field(:content, :type => String)
    end

    Book.create!(:content => 'teh cats')

    results = Book.search('cat')

    book = results.first.model


````

SEE ALSO
--------
  tests: <a href='./test/mongoid-haystack_test.rb'>./test/mongoid-haystack_test.rb<a/>
