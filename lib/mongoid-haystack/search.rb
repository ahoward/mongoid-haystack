module Mongoid
  module Haystack
    module Search
      ClassMethods = proc do
        def mongoid_haystack_searchable?
          true
        end

        def search(*args, &block)
          options = Map.options_for!(args)
          options[:types] = Array(options[:types]).flatten.compact
          options[:types].push(self)
          args.push(options)
          results = Haystack.search(*args, &block)
        end

        def search_index_all!(*args, &block)
          options = Map.options_for!(args)
          models = args.shift
          
          unless models
            models = where(:haystack_index => nil)
          end

          threads = options[:threads] || 16

          models.all.each do |doc|
            Mongoid::Haystack::Index.remove(doc)
          end

          models.all.each do |doc|
            Mongoid::Haystack::Index.add(doc)
          end
        end

        after_save do |doc|
          begin
            doc.search_index! if doc.persisted?
          rescue Object
            nil
          end
        end

        after_destroy do |doc|
          begin
            doc.search_unindex! if doc.destroyed?
          rescue Object
            nil
          end
        end

        has_one(:haystack_index, :as => :model, :class_name => '::Mongoid::Haystack::Index')
      end

      InstanceMethods = proc do
        def search_index!
          doc = self
          Mongoid::Haystack::Index.remove(doc)
          Mongoid::Haystack::Index.add(doc)
        end

        def search_unindex!
          doc = self
          Mongoid::Haystack::Index.remove(doc)
        end
      end

      def Search.included(other)
        super
      ensure
        unless other.respond_to?(:mongoid_haystack_searchable?)
          other.instance_eval(&ClassMethods)
          other.class_eval(&InstanceMethods)
        end
      end
    end

    def search(*args, &block)
    #
      options = Map.options_for!(args)
      search = args.join(' ')

      conditions = {}
      order = []

      op = :token_ids.in

    #
      case
        when options[:all]
          op = :token_ids.all
          search += Coerce.string(options[:all])

        when options[:any]
          op = :token_ids.in
          search += Coerce.string(options[:any])

        when options[:in]
          op = :token_ids.in
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

      order.push(["size", :asc])

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
      query =
        Index.where(conditions)
          .order_by(order)
            .only(:_id, :model_type, :model_id)

      query.extend(Pagination)

      query.extend(Denormalization)

      query
    end

    module Pagination
      def paginate(*args, &block)
        list = self
        options = Map.options_for!(args)

        page = Integer(args.shift || options[:page] || 1)
        size = Integer(args.shift || options[:size] || 42)

        count =
          if list.is_a?(Array)
            list.size
          else
            list.count
          end

        limit = size
        skip = (page - 1 ) * size
        
        result =
          if list.is_a?(Array)
            list.slice(skip, limit)
          else
            list.skip(skip).limit(limit)
          end

        result._paginated.update(
          :total_pages  => (count / size.to_f).ceil,
          :num_pages    => (count / size.to_f).ceil,
          :current_page => page
        )

        result
      end

      def _paginated
        @_paginated ||= Map.new
      end

      def method_missing(method, *args, &block)
        if respond_to?(:_paginated) and _paginated.has_key?(method) and args.empty? and block.nil?
          _paginated[method]
        else
          super
        end
      end
    end

    module Denormalization
      def models
        Results.for(query = self)
      end

      def _denormalized
        @_denormalized ||= (is_a?(Mongoid::Criteria) ? ::Mongoid::Haystack.denormalize(self) : self)
      end

      class Results < ::Array
        include ::Mongoid::Haystack::Pagination

        attr_accessor :query

        def Results.for(query)
          Results.new.tap do |results|
            results.query = query
            results.replace(query._denormalized)
            results._paginated.replace(query._paginated) rescue nil
          end
        end

        def models
          self
        end
      end
    end

    def search_tokens_for(search)
      #values = Token.values_for(search.to_s)
      #values = Util.phrases_for(search).map{|phrase| Util.stems_for(phrase)}.flatten
      values = Util.search_for(search)
      tokens = []

      Token.where(:value.in => values).each do |token|
        index = values.index(token.value)
        tokens[index] = token
      end

      tokens.compact!

      total = Token.total.to_f

      rarity = {}
      tokens.map{|token| rarity[token] = token.rarity_bin(total)}

      position = {}
      tokens.each_with_index{|token, i| position[token] = i + 1}

      tokens.sort!{ |a, b| [rarity[b], position[a]] <=> [rarity[a], position[b]] }

      tokens
    end

    def Haystack.denormalize(results)
      queries = Hash.new{|h,k| h[k] = []}

      results.each do |result|
        model_type = result[:model_type]
        model_id = result[:model_id]
        model_class = eval(model_type) rescue next
        queries[model_class].push(model_id)
      end

=begin
      index = Hash.new{|h,k| h[k] = {}}
=end

      models =
        queries.map do |model_class, model_ids|
          model_class_models =
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

=begin
          model_class_models.each do |model|
            index[model.class.name] ||= Hash.new
            next unless model
            index[model.class.name][model.id.to_s] = model
          end
=end

          model_class_models
        end

      models.flatten!
      models.compact!
      models

=begin
      to_ignore = []

      results.each_with_index do |result, i|
        model = index[result['model_type']][result['model_id'].to_s]

        if model.nil?
          to_ignore.push(i)
          next
        else
          result.model = model
        end

        result.model
        result
      end

      to_ignore.reverse.each do |index|
        models.delete_at(index)
      end
=end

      models
    end

    def Haystack.expand(*args, &block)
      Haystack.denormalize(*args, &block)
    end

    def Haystack.models_for(*args, &block)
      Haystack.denormalize(*args, &block)
    end
  end
end
