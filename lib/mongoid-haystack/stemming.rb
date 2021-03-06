# encoding: utf-8

module Mongoid
  module Haystack
    module Stemming
      def stem(*args, &block)
        words = args.join(' ').strip.split(/\s+/)
        list = []

        words.each do |word|
          stem = word.stem.downcase
          next if Stopwords.stopword?(word)
          next if Stopwords.stopword?(stem)
          block ? block.call(stem) : list.push(stem)
        end

        block ? nil : list
      end

      alias_method('for', 'stem')

      module Stopwords
        dirname = __FILE__.sub(/\.rb\Z/, '')
        glob = File.join(dirname, 'stopwords', '*.txt')

        List = {}

        Dir.glob(glob).each do |wordlist|
          basename = File.basename(wordlist)
          name = basename.split(/\./).first

          open(wordlist) do |fd|
            lines = fd.readlines
            words = lines.map{|line| line.strip}
            words.delete_if{|word| word.empty?}
            words.push('')
            List[name] = words
          end
        end

      # TODO - this needs to be configurable...
      #
        unless defined?(All)
          All = []
          All.concat(List['english'])
          All.concat(List['full_english'])
          All.concat(List['extended_english'])
          #All.concat(List['full_french'])
          #All.concat(List['full_spanish'])
          #All.concat(List['full_portuguese'])
          #All.concat(List['full_italian'])
          #All.concat(List['full_german'])
          #All.concat(List['full_dutch'])
          #All.concat(List['full_norwegian'])
          #All.concat(List['full_danish'])
          #All.concat(List['full_russian'])
          #All.concat(List['full_russian_koi8_r'])
          #All.concat(List['full_finnish'])
          All.sort!
          All.uniq!
        end

        unless defined?(Index)
          Index = {}

          All.each do |word|
            Index[word] = word
          end
        end

        def stopword?(word)
          !!Index[word]
        end

        extend(Stopwords)
      end

      extend(Stemming)
    end
  end
end

if $0 == __FILE__
  p Stemming.stem("the foobars foo-bars foos bars cat and mountains")
end
