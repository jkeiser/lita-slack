module Lita
  module Adapters
    class Slack < Adapter
      # @api private
      class IMMapping
        def initialize(api, ims)
          @api = api
          @mapping = {}

          add_mappings(ims)
        end

        def add_mapping(im)
          mapping[im.user_id] = im.id
        end

        def add_mappings(ims)
          ims.each { |im| add_mapping(im) }
        end

        def im_for(user_id)
          mapping.fetch(user_id) do
            response = api.call_api("im.open", user: user_id)
            add_mapping(SlackIM.new(response["channel"]["id"], user_id))
          end
        end

        private

        attr_reader :api
        attr_reader :mapping
      end
    end
  end
end
