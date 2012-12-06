# -*- encoding : utf-8 -*-

# this triggers mongoid to load rails...
# module Rails; end

require_relative 'testing'
require_relative '../lib/mongoid-haystack.rb'

Mongoid::Haystack.connect!

class A
  include Mongoid::Document
  field(:content, :type => String)
  def to_s; content; end
end

class B
  include Mongoid::Document
  field(:content, :type => String)
  def to_s; content; end
end

class C
  include Mongoid::Document
  field(:content, :type => String)
  def to_s; content; end
end

