module Mongoid
  module Haystack
    class Token
      include Mongoid::Document

      class << Token
        def values_for(*args)
          Haystack.stems_for(*args)
        end

        def add(value)
          values = Array(value)
          values.flatten!
          values.compact!

          existing = where(:value.in => values)
          missing = values - existing.map(&:value)

          docs = missing.map{|value| {:_id => Token.next_hex_id, :value => value}}
          collection.insert(docs, [:continue_on_error])

          tokens = where(:value.in => values)

          tokens.inc(:count, 1)

          value.is_a?(Array) ? tokens : tokens.first
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
