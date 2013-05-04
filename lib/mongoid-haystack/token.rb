module Mongoid
  module Haystack
    class Token
      include Mongoid::Document

      class << Token
        def values_for(*args)
          Haystack.tokens_for(*args)
        end

        def add(value)
        # handle a value or array of values - which may contain dups
        #
          values = Array(value)
          values.flatten!
          values.compact!

        # ensure that a token exists for each value seen
        #
          existing = where(:value.in => values)
          missing = values - existing.map(&:value)

          docs = missing.map{|value| {:_id => Token.next_hex_id, :value => value}}
          unless docs.empty?
            collection = mongo_session.with(:safe => false)[collection_name]
            collection.insert(docs, [:continue_on_error])
          end

        # new we should have one token per uniq value
        #
          tokens = where(:value.in => values)

        # batch update the counts on the tokens by the number of times each
        # value was seen in the list
        #
        #   'dog dog' #=> increment the 'dog' token's count by 2
        #
          counts = {}
          token_index = tokens.inject({}){|hash, token| hash[token.value] = token; hash}
          value_index = values.inject({}){|hash, value| hash[value] ||= []; hash[value].push(value); hash}

          values.each do |value|
            token = token_index[value]
            count = value_index[value].size
            counts[count] ||= []
            counts[count].push(token.id)
          end

          counts.each do |count, token_ids|
            Token.where(:id.in => token_ids).inc(:count, count)
          end

        # return an array or single token depending on whether a list or
        # single value was added
        #
          value.is_a?(Array) ? tokens : tokens.first
        end

        def subtract(tokens)
        end

        def sequence
          Sequence.for(Token.name.scan(/[^:]+/).join('.').downcase)
        end

        def next_hex_id
          "0x#{ hex = sequence.next.to_s(16) }"
        end

        def total
          sum(:count)
        end
      end

      field(:_id, :type => String, :default => proc{ Token.next_hex_id })
      field(:value, :type => String)
      field(:count, :type => Integer, :default => 0)

      index({:value => 1}, {:unique => true})
      index({:count => 1})

      def frequency(n_tokens = Token.total.value.to_f)
        (count / n_tokens).round(2)
      end

      def frequency_bin(n_tokens = Token.total.value.to_f)
        (frequency(n_tokens) * 10).truncate
      end

      def rarity(n_tokens = Token.total.value.to_f)
        ((n_tokens - count) / n_tokens).round(2)
      end

      def rarity_bin(n_tokens = Token.total.value.to_f)
        (rarity(n_tokens) * 10).truncate
      end
    end
  end
end
