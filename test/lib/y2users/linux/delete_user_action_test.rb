require_relative "../test_helper"

require "y2users/user"
require "y2users/linux/delete_user_action"
require "y2users/commit_config"

describe Y2Users::Linux::DeleteUserAction do
  subject(:action) { described_class.new(user, commit_config) }
  let(:user) { Y2Users::User.new("test") }
  let(:commit_config) { nil }

  before do
    allow(Yast::Execute).to receive(:on_target!)
  end

  describe "#perform" do
    it "deletes user with userdel" do
      expect(Yast::Execute).to receive(:on_target!) do |cmd, *_args|
        expect(cmd).to eq "/usr/sbin/userdel"
      end

      action.perform
    end

    it "passes user name as last parameter" do
      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args.last).to eq "test"
      end

      action.perform
    end

    context "commit config contain remove_home" do
      let(:commit_config) { Y2Users::CommitConfig.new.tap { |c| c.remove_home = true } }

      it "passes --remove parameter" do
        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include "--remove"
        end

        action.perform
      end
    end
  end
end
