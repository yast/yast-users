require_relative "../test_helper"

require "y2users/linux/set_home_ownership_action"
require "y2users/commit_config"
require "y2users/user"

describe Y2Users::Linux::SetHomeOwnershipAction do
  subject(:action) { described_class.new(user, commit_config) }
  let(:user) do
    Y2Users::User.new("test").tap do |u|
      u.gid = "100"
      u.home.path = "/tmp/home"
    end
  end
  let(:commit_config) { nil }

  describe "#perform" do
    it "calls chown on user home" do
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/chown", "-R", "test:100", "/tmp/home")

      subject.perform
    end

    it "returns result without success and with issues if cmd failed" do
      allow(Yast::Execute).to receive(:on_target!)
        .and_raise(Cheetah::ExecutionFailed.new(nil, nil, nil, nil))

      result = action.perform
      expect(result.success?).to eq false
      expect(result.issues).to_not be_empty
    end
  end
end
