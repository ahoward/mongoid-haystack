module Mongoid
  module Haystack
    class Token
      include Mongoid::Document

      class << Token
        def values_for(*args, &block)
          string = args.join(' ')
          values = string.scan(/[^\s]+/)
          Stemming.stem(*values)
        end

        def add(value)
          token = nil
          created = nil

          Haystack.find_or_create(
            proc do
              token = where(:value => value).first
              created = false if token
              token
            end,

            proc do
              token = create!(:value => value)
              created = true if token
              token
            end
          )

          token.inc(:count, 1)

          Count[:tokens].inc(1) #if created

          token
        end

        def sequence
          Sequence.for(Token.name.scan(/[^:]+/).join('.').downcase)
        end

        def next_hex_id
          "0x#{ hex = sequence.next.to_s(16) }"
        end
      end

      field(:_id, :type => String, :default => proc{ Token.next_hex_id })
      field(:value, :type => String)
      field(:count, :type => Integer, :default => 0)

      index({:value => 1}, {:unique => true})
      index({:count => 1})

      def frequency(n_tokens = Count[:tokens].value.to_f)
        (count / n_tokens).round(2)
      end

      def frequency_bin(n_tokens = Count[:tokens].value.to_f)
        (frequency(n_tokens) * 10).truncate
      end

      def rarity(n_tokens = Count[:tokens].value.to_f)
        ((n_tokens - count) / n_tokens).round(2)
      end

      def rarity_bin(n_tokens = Count[:tokens].value.to_f)
        (rarity(n_tokens) * 10).truncate
      end
    end
  end
end
