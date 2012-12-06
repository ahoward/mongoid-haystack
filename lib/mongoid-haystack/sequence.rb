module Mongoid
  module Haystack
    class Sequence
      include Mongoid::Document

      field(:name, :type => String)

      field(:value, :default => 0, :type => Integer)

      validates_presence_of(:name)
      validates_uniqueness_of(:name)

      validates_presence_of(:value)

      index({:name => 1}, {:unique => true})

      Cache = Hash.new

      class << self
        def for(name)
          name = name.to_s

          Cache[name] ||= (
            Haystack.find_or_create(
              ->{ where(:name => name).first },
              ->{ create!(:name => name) }
            )
          )
        end

        alias_method('[]', 'for')

        def sequence_name_for(klass, fieldname)
          "#{ klass.name.gsub(/::/, '.').downcase }-#{ fieldname }"
        end
      end

      after_destroy do |sequence|
        Cache.delete(sequence.name)
      end

      def next
        inc(:value, 1)
      end

      def current_value
        reload.value
      end

      def reset!
        update_attributes!(:value => 0)
      end
    end
  end
end
