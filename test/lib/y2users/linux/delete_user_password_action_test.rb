require_relative "../test_helper"

require "y2users/user"
require "y2users/linux/delete_user_password_action"
require "y2users/commit_config"

describe Y2Users::Linux::DeleteUserPasswordAction do
  subject(:action) { described_class.new(user, commit_config) }
  let(:user) { Y2Users::User.new("test") }
  let(:commit_config) { nil }

  before do
    allow(Yast::Execute).to receive(:on_target!)
  end

  describe "#perform" do

    it "removes password with passwd --delete" do
      expect(Yast::Execute).to receive(:on_target!) do |cmd, *args|
        expect(cmd).to eq "/usr/bin/passwd"
        expect(args).to include "--delete"
      end

      action.perform
    end

    it "passes user name as final parameter" do
      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args.last).to eq "test"
      end

      action.perform
    end
  end
end
