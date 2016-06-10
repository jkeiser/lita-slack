require 'faraday'

require 'lita/adapters/slack/team_data'
require 'lita/adapters/slack/slack_im'
require 'lita/adapters/slack/slack_user'
require 'lita/adapters/slack/slack_channel'

module Lita
  module Adapters
    class Slack < Adapter
      # @api private
      class API
        def initialize(config, stubs = nil)
          @config = config
          @stubs = stubs
          @default_message_arguments = {}
          default_message_arguments[:parse] = config.parse unless config.parse.nil?
          default_message_arguments[:link_names] = config.link_names ? 1 : 0 unless config.link_names.nil?
          default_message_arguments[:unfurl_links] = config.unfurl_links unless config.unfurl_links.nil?
          default_message_arguments[:unfurl_media] = config.unfurl_media unless config.unfurl_media.nil?
          default_message_arguments.merge!(config.default_message_arguments)
        end

        def im_open(user_id)
          response_data = call_api("im.open", user: user_id)

          SlackIM.new(response_data["channel"]["id"], user_id)
        end

        def channels_info(channel_id)
          call_api("channels.info", channel: channel_id)
        end

        def channels_list
          call_api("channels.list")
        end

        def groups_list
          call_api("groups.list")
        end

        def mpim_list
          call_api("mpim.list")
        end

        def im_list
          call_api("im.list")
        end

        #
        # Post a message via the Slack `chat.postMessage` API.
        #
        # @param message_arguments Slack `chat.postMessage` arguments. These
        #   override the defaults in `config.default_message_arguments`. See the
        #   README for that config variable for details. You must pass channel
        #   and either text or attachments.
        #
        def post_message(channel:, **message_arguments)
          call_api("chat.postMessage",
            **default_message_arguments,
            channel: channel,
            **message_arguments
          )
        end

        def me_message(channel:, text:, **arguments)
          call_api("chat.meMessage", channel: channel, text: text, **arguments)
        end

        def chat_update(channel:, ts:, **arguments)
          call_api("chat.update",
            **default_message_arguments,
            channel: channel,
            ts: ts,
            **arguments
          )
        end

        def chat_delete(channel:, ts:, **arguments)
          # Copy only as_user from default_message_arguments
          if default_message_arguments.has_key?(:as_user) && !arguments.has_key?(:as_user)
            arguments[:as_user] = default_message_arguments[:as_user]
          end

          call_api("chat.delete", channel: channel, ts: ts, **arguments)
        end

        def set_topic(channel, topic)
          call_api("channels.setTopic", channel: channel, topic: topic)
        end

        def rtm_start
          response_data = call_api("rtm.start")

          TeamData.new(
            SlackIM.from_data_array(response_data["ims"]),
            SlackUser.from_data(response_data["self"]),
            SlackUser.from_data_array(response_data["users"]),
            SlackChannel.from_data_array(response_data["channels"]) +
              SlackChannel.from_data_array(response_data["groups"]),
            response_data["url"],
          )
        end

        private

        attr_reader :stubs
        attr_reader :config
        attr_reader :default_message_arguments

        def call_api(method, **arguments)
          # Array and Hash arguments must be JSON-encoded
          arguments.each do |key, value|
            case value
            when Array, Hash
              arguments[key] = MultiJson.dump(value)
            when Attachment
              arguments[key] = MultiJson.dump(value.to_hash)
            end
          end

          response = connection.post(
            "https://slack.com/api/#{method}",
            token: config.token,
            **arguments
          )

          data = parse_response(response, method)

          raise "Slack API call to #{method} returned an error: #{data["error"]}." if data["error"]

          data
        end

        def connection
          if stubs
            Faraday.new { |faraday| faraday.adapter(:test, stubs) }
          else
            options = {}
            unless config.proxy.nil?
              options = { proxy: config.proxy }
            end
            Faraday.new(options)
          end
        end

        def parse_response(response, method)
          unless response.success?
            raise "Slack API call to #{method} failed with status code #{response.status}: '#{response.body}'. Headers: #{response.headers}"
          end

          MultiJson.load(response.body)
        end
      end
    end
  end
end
