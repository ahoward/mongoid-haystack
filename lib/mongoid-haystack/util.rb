module Mongoid
  module Haystack
    module Util 
      def models
        [
          Mongoid::Haystack::Index,
          Mongoid::Haystack::Token,
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

      def create_indexes
        models.each{|model| model.create_indexes}
      end

      def destroy_all
        models.map{|model| model.destroy_all}
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

      def token_tree_for(*args, &block)
        tree = []

        phrases_for(*args) do |phrase|
          #next if stopword?(phrase)

          if block
            block.call(:phrase, phrase)
          else
            tree.push([phrase, words = []])
          end

          words_for(phrase) do |word|
            #next if phrase == word
            #next if stopword?(word)

            if block
              block.call(:word, word)
            else
              words.push([word, stems = []])
            end

            stems_for(word) do |stem|
              #next if word == stem

              if block
                block.call(:stem, stem)
              else
                stems.push(stem)
              end
            end
          end
        end

        block ? nil : tree
      end

      def tokens_for(*args, &block)
        list = []

        token_tree_for(*args).each do |phrase, words|
          next if stopword?(phrase)
          block ? block.call(phrase) : list.push(phrase) 

          words.each do |word, stems|
            next if stopword?(word)

            unless word == phrase
              block ? block.call(word) : list.push(word) 
            end

            stems.each do |stem|
              next if stopword?(stem)

              unless stem == phrase or stem == word
                block ? block.call(stem) : list.push(stem)
              end
            end
          end
        end

        block ? nil : list
      end

      def phrases_for(*args, &block)
        string = args.join(' ')
        string.strip!

        phrases = string.split(/\s+/)

        list = []

        phrases.each do |phrase|
          strip!(phrase)
          next if phrase.empty?
          block ? block.call(phrase) : list.push(phrase)
        end

        block ? nil : list
      end

      def words_for(*args, &block)
        string = args.join(' ')
        string.gsub!(/_+/, '-')
        string.gsub!(/[^\w]/, ' ')

        list = []

        UnicodeUtils.each_word(string) do |word|
          strip!(word)
          next if word.empty?
          block ? block.call(word) : list.push(word)
        end

        block ? nil : list
      end

      def stems_for(*args, &block)
        Stemming.stem(*args, &block)
      end

      def search_for(*args, &block)
        phrases_for(*args).map{|phrase| [phrase, stems_for(phrase)]}.flatten.compact.uniq
      end

      def stopword?(word)
        word = UnicodeUtils.nfkd(word.to_s.strip.downcase)
        word.empty? or Stemming::Stopwords.stopword?(word)
      end

      def strip!(word)
        word.replace(UnicodeUtils.nfkd(word.to_s.strip))
        word.gsub!(/\A(?:[^\w]|_|\s)+/, '')  # leading punctuation/spaces
        word.gsub!(/(?:[^\w]|_|\s+)+\Z/, '') # trailing punctuation/spaces
        word
      end

      extend Util
    end

    extend Util
  end
end
