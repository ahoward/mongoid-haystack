module Mongoid
  module Haystack
    class Count
      include Mongoid::Document

      field(:name, :type => String)
      field(:value, :type => Integer, :default => 0)

      index({:name => 1}, {:unique => true})
      index({:value => 1})

      def Count.for(name)
        Haystack.find_or_create(
          ->{ where(:name => name.to_s).first },
          ->{ create!(:name => name.to_s) }
        )
      end

      def Count.[](name)
        Count.for(name)
      end

      def inc(n = 1)
        super(:value, n)
      end
    end
  end
end
