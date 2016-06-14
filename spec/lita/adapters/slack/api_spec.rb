require "spec_helper"

describe Lita::Adapters::Slack::API do
  subject { described_class.new(config, stubs) }
  let(:api) { subject }
  # Stubs are empty by default. Override or call expect_post to add stubs.
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }

  let(:http_status) { 200 }
  let(:token) { 'abcd-1234567890-hWYd21AmMH2UHAkx29vb5c1Y' }
  let(:config) { Lita::Adapters::Slack.configuration_builder.build }

  before do
    config.token = token
  end

  describe "#call_api" do
    it "with no arguments sends a POST with just a token" do
      stubs.post("http://slack.com/api/x.y", token: token) do
        [200, {}, MultiJson.dump("ok" => true)]
      end
      expect(api.call_api("x.y")).to eq("ok" => true)
    end
    it "with arguments sends the arguments" do
      stubs.post("http://slack.com/api/x.y", token: token, a: 1, b: "hi", c: false, d: true) do
        [200, {}, MultiJson.dump("ok" => true)]
      end
      expect(api.call_api("x.y", a: 1, b: "hi", c: false, d: true)).to eq("ok" => true)
    end
    it "with nil arguments does not send the arguments" do
      stubs.post("http://slack.com/api/x.y", token: token, a: 1, c: false) do
        [200, {}, MultiJson.dump("ok" => true)]
      end
      expect(api.call_api("x.y", a: 1, b: nil, c: false)).to eq("ok" => true)
    end
    it "with hash arguments, JSON-encodes the arguments" do
      stubs.post("http://slack.com/api/x.y", token: token, a: %|{"x":1,"y":2}|) do
        [200, {}, MultiJson.dump("ok" => true)]
      end
      expect(api.call_api("x.y", a: {x: 1, y: 2})).to eq("ok" => true)
    end
    it "with array arguments, JSON-encodes the arguments" do
      stubs.post("http://slack.com/api/x.y", token: token, a: %|["x","y"]|) do
        [200, {}, MultiJson.dump("ok" => true)]
      end
      expect(api.call_api("x.y", a: ["x","y"])).to eq("ok" => true)
    end
    it "with an array of Attachments, JSON-encodes the attachments" do
      stubs.post("http://slack.com/api/x.y", token: token, a: %|[{"fallback":"foo","text":"foo"}]|) do
        [200, {}, MultiJson.dump("ok" => true)]
      end
      attachment = Lita::Adapters::Slack::Attachment.new("foo")
      expect(api.call_api("x.y", a: [attachment])).to eq("ok" => true)
    end
    it "when Slack responds with an error, a RuntimeError is thrown" do
      stubs.post("http://slack.com/api/x.y", token: token) do
        [200, {}, MultiJson.dump("ok" => false, "error" => "invalid_auth") ]
      end
      expect { api.call_api("x.y") }.to raise_error "Slack API call to x.y returned an error: invalid_auth."
    end
    it "when Slack responds with non-200, a RuntimeError is thrown" do
      stubs.post("http://slack.com/api/x.y", token: token) do
        [422, {}, "failed big time"]
      end
      expect { api.call_api("x.y") }.to raise_error "Slack API call to x.y failed with status code 422: 'failed big time'. Headers: {}"
    end
  end

  describe "#set_topic" do
    let(:channel) { 'C1234567890' }
    let(:topic) { 'Topic' }
    let(:stubs) do
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(
          'https://slack.com/api/channels.setTopic',
          token: token,
          channel: channel,
          topic: topic
        ) do
          [http_status, {}, http_response]
        end
      end
    end

    context "with a successful response" do
      let(:http_response) do
        MultiJson.dump({
          ok: true,
          topic: 'Topic'
        })
      end

      it "returns a response with the channel's topic" do
        response = subject.set_topic(channel, topic)

        expect(response['topic']).to eq(topic)
      end
    end

    context "with a Slack error" do
      let(:http_response) do
        MultiJson.dump({
          ok: false,
          error: 'invalid_auth'
        })
      end

      it "raises a RuntimeError" do
        expect { subject.set_topic(channel, topic) }.to raise_error(
          "Slack API call to channels.setTopic returned an error: invalid_auth."
        )
      end
    end

    context "with an HTTP error" do
      let(:http_status) { 422 }
      let(:http_response) { '' }

      it "raises a RuntimeError" do
        expect { subject.set_topic(channel, topic) }.to raise_error(
          "Slack API call to channels.setTopic failed with status code 422: ''. Headers: {}"
        )
      end
    end
  end

  describe "#rtm_start" do
    let(:http_status) { 200 }
    let(:stubs) do
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post('https://slack.com/api/rtm.start', token: token) do
          [http_status, {}, http_response]
        end
      end
    end

    describe "with a successful response" do
      let(:http_response) do
        MultiJson.dump({
          ok: true,
          url: 'wss://example.com/',
          users: [{ id: 'U023BECGF' }],
          ims: [{ id: 'D024BFF1M' }],
          self: { id: 'U12345678' },
          channels: [{ id: 'C1234567890' }],
          groups: [{ id: 'G0987654321' }],
        })
      end

      it "has data on the bot user" do
        response = subject.rtm_start

        expect(response.self.id).to eq('U12345678')
      end

      it "has an array of IMs" do
        response = subject.rtm_start

        expect(response.ims[0].id).to eq('D024BFF1M')
      end

      it "has an array of users" do
        response = subject.rtm_start

        expect(response.users[0].id).to eq('U023BECGF')
      end

      it "has a WebSocket URL" do
        response = subject.rtm_start

        expect(response.websocket_url).to eq('wss://example.com/')
      end
    end
  end
end
