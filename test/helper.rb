# -*- encoding : utf-8 -*-

# this triggers mongoid to load rails...
# module Rails; end

require_relative 'testing'
require_relative '../lib/mongoid-haystack.rb'

Mongoid::Haystack.connect!
Mongoid::Haystack.reset!

class A
  include Mongoid::Document
  field(:content, :type => String)
  def to_s; content; end

  field(:a)
  field(:b)
  field(:c)
end

class B
  include Mongoid::Document
  field(:content, :type => String)
  def to_s; content; end

  field(:a)
  field(:b)
  field(:c)
end

class C
  include Mongoid::Document
  field(:content, :type => String)
  def to_s; content; end

  field(:a)
  field(:b)
  field(:c)
end

