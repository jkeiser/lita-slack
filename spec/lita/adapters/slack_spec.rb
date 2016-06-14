require "spec_helper"
require "support/expect_api_call"

describe Lita::Adapters::Slack, lita: true do
  include ExpectApiCall

  subject { adapter }

  let(:rtm_connection) { instance_double('Lita::Adapters::Slack::RTMConnection') }

  before do
    allow(
      described_class::RTMConnection
    ).to receive(:build).with(robot, subject.config).and_return(rtm_connection)
    allow(rtm_connection).to receive(:run)
  end

  include ExpectApiCall

  it "registers with Lita" do
    expect(Lita.adapters[:slack]).to eql(described_class)
  end

  describe "#chat_service" do
    it "returns an object with Slack-specific methods" do
      expect(subject.chat_service).to be_an_instance_of(described_class::ChatService)
    end
  end

  describe "#mention_format" do
    it "returns the name prefixed with an @" do
      expect(subject.mention_format("carl")).to eq("@carl")
    end
  end

  describe "#run" do
    it "starts the RTM connection" do
      expect(rtm_connection).to receive(:run)

      subject.run
    end

    it "does nothing if the RTM connection is already created" do
      expect(rtm_connection).to receive(:run).once

      subject.run
      subject.run
    end
  end

  describe "#roster" do
    describe "retrieving the roster for a channel" do
      let(:channel) { 'C024BE91L' }

      before do
        expect_api_call("channels.info", channel: channel,
          response: { "ok" => true, "channel" => { "members" => %w{U07KF7HTR U07KFHN64}}}
        )
      end

      it "returns UID(s) when passed a Lita::Room" do
        expect(subject.roster(Lita::Room.new(channel))).to eq(%w{U07KF7HTR U07KFHN64})
      end

      it "returns UID(s) when passed a Lita::Source" do
        expect(subject.roster(Lita::Source.new(room: channel))).to eq(%w{U07KF7HTR U07KFHN64})
      end

      it "returns UID(s) when passed a String" do
        expect_api_call("channel.info", channel: channel)
        expect(subject.roster(channel)).to eq(%w{U07KF7HTR U07KFHN64})
      end
    end

    describe "retrieving the roster for a group channel" do
      let(:channel) { 'G024BE91L' }

      before do
        expect_api_call("groups.list",
          response: {
            "ok" => true,
            "groups" => [{ "id" => channel, "members" => %w{U07KF7HTR U07KFHN64}}]
          }
        )
      end

      it "returns UID(s) when passed a Lita::Room" do
        expect(subject.roster(Lita::Room.new(channel))).to eq(%w{U07KF7HTR U07KFHN64})
      end

      it "returns UID(s) when passed a Lita::Source" do
        expect(subject.roster(Lita::Source.new(room: channel))).to eq(%w{U07KF7HTR U07KFHN64})
      end

      it "returns UID(s) when passed a String" do
        expect(subject.roster(channel)).to eq(%w{U07KF7HTR U07KFHN64})
      end
    end

    describe "retrieving the roster for a mpim channel" do
      let(:channel) { 'G024BE91L' }

      before do
        expect_api_call("groups.list",
          response: { "ok" => true, "groups" => [] }
        )
        expect_api_call("mpim.list",
          response: {
            "ok" => true,
            "groups" => [{ "id" => channel, "members" => %w{U07KF7HTR U07KFHN64}}]
          }
        )
      end

      it "returns UID(s) when passed a Lita::Room" do
        expect(subject.roster(Lita::Room.new(channel))).to eq(%w{U07KF7HTR U07KFHN64})
      end

      it "returns UID(s) when passed a Lita::Source" do
        expect(subject.roster(Lita::Source.new(room: channel))).to eq(%w{U07KF7HTR U07KFHN64})
      end

      it "returns UID(s) when passed a String" do
        expect(subject.roster(channel)).to eq(%w{U07KF7HTR U07KFHN64})
      end
    end

    # TODO shouldn't we just throw an exception?
    context "retrieving the roster for a non-existent group or mpim channel" do
      let(:channel) { 'G024BE91L' }

      before do
        expect_api_call("groups.list",
          response: { "ok" => true, "groups" => [] }
        )
        expect_api_call("mpim.list",
          response: { "ok" => true, "groups" => [] }
        )
      end

      it "returns empty list" do
        expect(subject.roster(channel)).to eq([])
      end
    end

    # TODO this should also return the current user in the list of
    # channel members, yes?
    describe "retrieving the roster for an im channel" do
      let(:channel) { 'D024BFF1M' }

      before do
        expect_api_call("im.list",
          response: {
            "ok" => true,
            "ims" => [{ "id" => channel, "user" => "U07KF7HTR"}]
          }
        )
      end

      it "returns UID(s) when passed a Lita::Room" do
        expect(subject.roster(Lita::Room.new(channel))).to eq(%w{U07KF7HTR})
      end

      it "returns UID(s) when passed a Lita::Source" do
        expect(subject.roster(Lita::Source.new(room: channel))).to eq(%w{U07KF7HTR})
      end

      it "returns UID(s) when passed a String" do
        expect(subject.roster(channel)).to eq(%w{U07KF7HTR})
      end
    end

    # TODO shouldn't this raise an error?
    describe "retrieving the roster for a non-existent im channel" do
      let(:channel) { 'D024BFF1M' }

      before do
        expect_api_call("im.list",
          response: {
            "ok" => true,
            "ims" => []
          }
        )
      end

      it "returns empty list" do
        expect(subject.roster(channel)).to eq([])
      end
    end
  end

  describe "#send_messages" do
    let(:room_source) { Lita::Source.new(room: 'C024BE91L') }
    let(:user) { Lita::User.new('U023BECGF') }
    let(:user_source) { Lita::Source.new(user: user) }
    let(:private_message_source) do
      Lita::Source.new(room: 'C024BE91L', user: user, private_message: true)
    end

    describe "via the Web API" do
      it "sends via the non-RTM API" do
        expect(rtm_connection).to_not receive(:send_messages)
        expect_api_call("chat.postMessage", channel: room_source.room, text: 'foo')

        subject.send_messages(room_source, ['foo'])
      end

      context "with parse, link_names, unfurl_media and unfurl_links configured" do
        before do
          registry.config.adapters.slack.parse = "none"
          registry.config.adapters.slack.link_names = true
          registry.config.adapters.slack.unfurl_media = true
          registry.config.adapters.slack.unfurl_links = true
        end

        it "sends those arguments alongside messages" do
          expect_api_call("chat.postMessage",
            channel: room_source.room,
            text: 'foo',
            parse: "none",
            link_names: 1,
            unfurl_media: true,
            unfurl_links: true
          )
          subject.send_messages(room_source, ['foo'])
        end
      end
    end
  end

  describe "#set_topic" do
    it "set_topic with a Lita::Room sets a new topic for the room" do
      expect_api_call("channels.setTopic", channel: 'C1234567890', topic: 'Topic')
      subject.set_topic(Lita::Room.new('C1234567890'), 'Topic')
    end

    it "set_topic with a Lita::Source sets a new topic for the room" do
      expect_api_call("channels.setTopic", channel: 'C1234567890', topic: 'Topic')
      subject.set_topic(Lita::Source.new(room: 'C1234567890'), 'Topic')
    end

    it "set_topic with a String sets a new topic for the channel" do
      expect_api_call("channels.setTopic", channel: 'C1234567890', topic: 'Topic')
      subject.set_topic('C1234567890', 'Topic')
    end
  end

  describe "#shut_down" do
    before { allow(rtm_connection).to receive(:shut_down) }

    it "shuts down the RTM connection" do
      expect(rtm_connection).to receive(:shut_down)

      subject.run
      subject.shut_down
    end

    it "triggers a :disconnected event" do
      expect(robot).to receive(:trigger).with(:disconnected)

      subject.run
      subject.shut_down
    end

    it "does nothing if the RTM connection hasn't been created yet" do
      expect(rtm_connection).not_to receive(:shut_down)

      subject.shut_down
    end
  end
end
