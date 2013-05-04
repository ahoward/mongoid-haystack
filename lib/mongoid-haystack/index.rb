module Mongoid
  module Haystack
    def Haystack.index(*args, &block)
      Index.add(*args, &block)
    end

    def Haystack.unindex(*args, &block)
      Index.remove(*args, &block)
    end

    def Haystack.reindex!(*args, &block)
      Index.all.each do |index|
        model =
          begin
            index.model
          rescue Object => e
            index.destroy
            next
          end

        index(model)
      end
    end

    class Index
      include Mongoid::Document

      class << Index
        def add(*args)
        # we all one or more models to the index..
        #
          models_for(*args) do |model|
            config = nil

          # ask the model how it wants to be indexed.  if it does not know,
          # guess.
          #
            if model.respond_to?(:to_haystack)
              config = Map.for(model.to_haystack)
            else
              keywords = []
                %w( keywords title ).each do |attr|
                  if model.respond_to?(attr)
                    keywords.push(*model.send(attr))
                    break
                  end
                end

              fulltext = []
                %w( fulltext text content body description to_s ).each do |attr|
                  if model.respond_to?(attr)
                    fulltext.push(*model.send(attr))
                    break
                  end
                end

              config =
                Map.for(
                  :keywords => keywords,
                  :fulltext => fulltext
                )
            end

          # blow up if no sane config was produced
          #
            unless %w( keywords fulltext facets score ).detect{|key| config.has_key?(key)}
              raise ArgumentError, "you need to defined #{ model }#to_haystack"
            end

          # parse the config
          #
            keywords = Array(config[:keywords]).join(' ')
            fulltext = Array(config[:fulltext]).join(' ')
            facets   = Map.for(config[:facets] || {})
            score    = config[:score]

          # find or create an index item for this model
          #
            index =
              Haystack.find_or_create(
                ->{ where(:model => model).first },
                ->{ new(:model => model) },
              )

          # if we are updating an index we need to decrement old token counts
          # before updating it
          #
            if index.persisted?
              Index.subtract(index)
            end

          # add tokens for both keywords and fulltext.  increment counts for
          # both.
          #
            keyword_scores = Hash.new{|h,k| h[k] = 0}
            fulltext_scores = Hash.new{|h,k| h[k] = 0}
            token_ids = []

            values = Token.values_for(keywords)
            tokens = Token.add(values)
            token_index = tokens.inject({}){|hash, token| hash[token.value] = token; hash}
            values.each do |value|
              token = token_index.fetch(value)
              id = token.id
              token_ids.push(id)
              keyword_scores[id] += 1
            end

            values = Token.values_for(fulltext)
            tokens = Token.add(values)
            token_index = tokens.inject({}){|hash, token| hash[token.value] = token; hash}
            values.each do |value|
              token = token_index.fetch(value)
              id = token.id
              token_ids.push(id)
              fulltext_scores[id] += 1
            end

          # our index item is complete with list of tokens, counts of each
          # one, and a facet hash for this model
          #
            index.keyword_scores = keyword_scores
            index.fulltext_scores = fulltext_scores

            index.score = score if score
            index.facets = facets if facets

            index.token_ids = token_ids

            index.save!
          end
        end

        def remove(*args)
          models_for(*args) do |model|
            index = where(:model_type => model.class.name, :model_id => model.id).first
            index.destroy if index
          end
        end

        def subtract(index)
          tokens = index.tokens

          counts = {}

          tokens.each do |token|
            keyword_score = index.keyword_scores[token.id].to_i
            fulltext_score = index.fulltext_scores[token.id].to_i

            count = keyword_score + fulltext_score

            counts[count] ||= []
            counts[count].push(token.id)
          end

          counts.each do |count, token_ids|
            Token.where(:id.in => token_ids).inc(:count, -count)
          end

          tokens
        end

        def models_for(*args, &block)
          args.flatten.compact.each do |arg|
            if arg.respond_to?(:persisted?)
              model = arg
              block.call(model)
            else
              arg.all.each do |model|
                block.call(model)
              end
            end
          end
        end
      end

      before_destroy do |index|
        Index.subtract(index)
      end

      before_validation do |index|
        index.size = tokens.count
      end

      belongs_to(:model, :polymorphic => true)

      has_and_belongs_to_many(:tokens, :class_name => '::Mongoid::Haystack::Token', :inverse_of => nil)

      field(:size, :type => Integer, :default => nil)
      field(:score, :type => Integer, :default => 0)
      field(:keyword_scores, :type => Hash, :default => proc{ Hash.new{|h,k| h[k] = 0} })
      field(:fulltext_scores, :type => Hash, :default => proc{ Hash.new{|h,k| h[k] = 0} })
      field(:facets, :type => Hash, :default => {})

      %w( size score ).each do |f|
        validates_presence_of(f)
      end

      index({:model_type => 1, :model_id => 1}, :unique => true)

      index({:token_ids => 1})
      index({:score => 1})
      index({:size => 1})
      index({:keyword_scores => 1})
      index({:fulltext_scores => 1})
      index({:facets => 1})
    end
  end
end
