module Mongoid
  module Haystack
    module Util 
      def models
        [
          Mongoid::Haystack::Token,
          Mongoid::Haystack::Index,
          Mongoid::Haystack::Count,
          Mongoid::Haystack::Sequence
        ]
      end

      def reset!
        models.each do |model|
          begin
            model.collection.indexes.drop
          rescue Object => e
          end

          begin
            model.collection.drop
          rescue Object => e
          end

          begin
            model.create_indexes
          rescue Object => e
          end
        end
      end

      def destroy_all
        models.map{|model| model.destroy_all}
      end

      def stem(*args, &block)
        Stemming.stem(*args, &block)
      end

      def find_or_create(finder, creator)
        doc = finder.call()
        return doc if doc

        n, max = 0, 2

        begin
          creator.call()
        rescue Object => e
          n += 1
          raise if n > max
          sleep(rand(0.1))
          finder.call() or retry
        end
      end

      def connect!
        Mongoid.configure do |config|
          config.connect_to('mongoid-haystack')
        end
      end

      extend Util
    end

    extend Util
  end
end
