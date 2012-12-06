module Mongoid
  module Haystack
    def search(*args, &block)
    #
      options = Map.options_for!(args)
      search = args.join(' ')

    #
      tokens = search_tokens_for(search)

    #
      conditions = {}
      conditions[:tokens.in] = tokens.map{|token| token.id}

    #
      order = []
      order.push(["score", :desc])

      tokens.each do |token|
        order.push(["keyword_scores.#{ token.id }", :desc])
      end

      tokens.each do |token|
        order.push(["fulltext_scores.#{ token.id }", :desc])
      end

    #
      if options[:facets]
        conditions[:facets] = options[:facets]
      end

    #
      if options[:types]
        model_types = Array(options[:types]).map{|type| type.name}
        conditions[:model_type.in] = model_types
      end

    #
      Index.where(conditions).order_by(order)
    end

    def search_tokens_for(search)
      values = Token.values_for(search.to_s)
      tokens = Token.where(:value.in => values).to_a

      positions = {}
      tokens.each_with_index{|token, index| positions[token] = index + 1}

      t = Count[:tokens].value.to_f

      tokens.sort! do |a,b|
        [b.rarity_bin(t), positions[b]] <=> [a.rarity_bin(t), positions[a]]
      end

      tokens
    end

    module Search
      ClassMethods = proc do
        def search(*args, &block)
          options = Map.options_for!(args)
          options[:types] = Array(options[:types]).flatten.compact
          options[:types].push(self)
          args.push(options)
          Haystack.search(*args, &block)
        end

        after_save do |doc|
          begin
            Mongoid::Haystack::Index.add(doc) if doc.persisted?
          rescue Object
            nil
          end
        end

        after_destroy do |doc|
          begin
            Mongoid::Haystack::Index.remove(doc)
          rescue Object
            nil
          end
        end
      end

      InstanceMethods = proc do
      end

      def Search.included(other)
        super
      ensure
        other.instance_eval(&ClassMethods)
        other.class_eval(&InstanceMethods)
      end
    end
  end
end
