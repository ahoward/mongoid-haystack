module Mongoid
  module Haystack
    def search(*args, &block)
    #
      options = Map.options_for!(args)
      search = args.join(' ')

      conditions = {}
      order = []

      op = :tokens.in

    #
      case
        when options[:all]
          op = :tokens.all
          search += Coerce.string(options[:all]) 

        when options[:any]
          op = :tokens.in
          search += Coerce.string(options[:any]) 

        when options[:in]
          op = :tokens.in
          search += Coerce.string(options[:in]) 
      end

    #
      tokens = search_tokens_for(search)
      token_ids = tokens.map{|token| token.id}

    #
      conditions[op] = token_ids

    #
      order.push(["score", :desc])

      tokens.each do |token|
        order.push(["keyword_scores.#{ token.id }", :desc])
      end

      tokens.each do |token|
        order.push(["fulltext_scores.#{ token.id }", :desc])
      end

    #
      if options[:facets]
        conditions[:facets] = {'$elemMatch' => options[:facets]}
      end

    #
      if options[:types]
        model_types = Array(options[:types]).map{|type| type.name}
        conditions[:model_type.in] = model_types
      end

    #
      Index.where(conditions).order_by(order).tap do |results|
        results.extend(Denormalize)
      end
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
          results = Haystack.search(*args, &block)
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

        has_one(:haystack_index, :as => :model, :class_name => '::Mongoid::Haystack::Index')
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

    module Denormalize
      def denormalize
        ::Mongoid::Haystack.denormalize(self)
        self
      end

      def models
        denormalize
        map(&:model)
      end
    end

    def Haystack.denormalize(results)
      queries = Hash.new{|h,k| h[k] = []}

      results = results.to_a.flatten.compact

      results.each do |result|
        model_type = result[:model_type]
        model_id = result[:model_id]
        model_class = model_type.constantize
        queries[model_class].push(model_id)
      end

      index = Hash.new{|h,k| h[k] = {}}

      queries.each do |model_class, model_ids|
        models = 
          begin
            model_class.find(model_ids)
          rescue Mongoid::Errors::DocumentNotFound
            model_ids.map do |model_id|
              begin
                model_class.find(model_id)
              rescue Mongoid::Errors::DocumentNotFound
                nil
              end
            end
          end

        models.each do |model|
          index[model.class.name] ||= Hash.new
          next unless model
          index[model.class.name][model.id.to_s] = model
        end
      end

      to_ignore = []

      results.each_with_index do |result, i|
        model = index[result['model_type']][result['model_id'].to_s]

        if model.nil?
          to_ignore.push(i)
          next
        else
          result.model = model
        end

        result.model.freeze
        result.freeze
      end

      to_ignore.reverse.each{|i| results.delete_at(i)}

      results.to_a
    end
  end
end
