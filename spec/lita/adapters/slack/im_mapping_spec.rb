require "spec_helper"
require "support/expect_api_call"

describe Lita::Adapters::Slack::IMMapping, lita: true do
  subject { described_class.new(api, ims) }

  include ExpectApiCall

  let(:im) { Lita::Adapters::Slack::SlackIM.new('D1234567890', 'U023BECGF') }
  let(:api) { Lita::Adapters::Slack::API.new(adapter.config) }

  describe "#im_for" do
    context "when a mapping is already stored" do
      let(:ims) { [im] }

      it "returns the IM ID for the given user ID" do
        expect(subject.im_for('U023BECGF')).to eq('D1234567890')
      end
    end

    context "when a mapping is not yet stored" do
      before do
        expect_api_call("im.open", user: 'U023BECGF', response: { "ok" => true, "channel" => { "id" => 'D1234567890' }})
      end

      let(:ims) { [] }

      it "fetches the IM ID from the API and returns it" do
        expect(subject.im_for('U023BECGF')).to eq('D1234567890')
      end

      it "doesn't hit the API on subsequent look ups of the same user ID" do
        expect(subject.im_for('U023BECGF')).to eq(subject.im_for('U023BECGF'))
      end
    end
  end
end
