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
          models_for(*args) do |model|
            config = nil

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

            keywords = Array(config[:keywords]).join(' ')
            fulltext = Array(config[:fulltext]).join(' ')
            facets   = Map.for(config[:facets] || {})
            score    = config[:score]

            index =
              Haystack.find_or_create(
                ->{ where(:model => model).first },
                ->{ new(:model => model) },
              )

            if index.persisted?
              Index.subtract(index)
            end

            keyword_scores = Hash.new{|h,k| h[k] = 0}
            fulltext_scores = Hash.new{|h,k| h[k] = 0}
            token_ids = []

            Token.values_for(keywords).each do |value|
              token = Token.add(value)
              id = token.id

              token_ids.push(id)
              keyword_scores[id] += 1
            end

            Token.values_for(fulltext).each do |value|
              token = Token.add(value)
              id = token.id

              token_ids.push(id)
              fulltext_scores[id] += 1
            end

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

          n = 0

          tokens.each do |token|
            keyword_score = index.keyword_scores[token.id].to_i
            fulltext_score = index.fulltext_scores[token.id].to_i

            i = keyword_score + fulltext_score
            token.inc(:count, -i)

            n += i
          end

          Count[:tokens].inc(-n)
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

      before_destroy{|index| Index.subtract(index)}

      belongs_to(:model, :polymorphic => true)

      has_and_belongs_to_many(:tokens, :class_name => '::Mongoid::Haystack::Token', :inverse_of => nil)
      field(:score, :type => Integer, :default => 0)
      field(:keyword_scores, :type => Hash, :default => proc{ Hash.new{|h,k| h[k] = 0} })
      field(:fulltext_scores, :type => Hash, :default => proc{ Hash.new{|h,k| h[k] = 0} })
      field(:facets, :type => Hash, :default => {})

      index({:model_type => 1})
      index({:model_id => 1})

      index({:token_ids => 1})
      index({:score => 1})
      index({:keyword_scores => 1})
      index({:fulltext_scores => 1})
    end
  end
end
