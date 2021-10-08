require_relative "../test_helper"

require "date"
require "y2users/user"
require "y2users/linux/edit_user_action"
require "y2users/commit_config"

describe Y2Users::Linux::EditUserAction do
  subject(:action) { described_class.new(old_user, new_user, commit_config) }
  let(:old_user) { Y2Users::User.new("test") }
  let(:new_user) { Y2Users::User.new("test2").tap { |u| u.assign_internal_id(old_user.id) } }
  let(:commit_config) { nil }

  before do
    allow(Yast::Execute).to receive(:on_target!)
  end

  describe "#perform" do
    it "modifies user with usermod" do
      expect(Yast::Execute).to receive(:on_target!) do |cmd, *_args|
        expect(cmd).to eq "/usr/sbin/usermod"
      end

      action.perform
    end

    it "passes --login parameter" do
      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--login"
        expect(args).to include "test2"
      end

      action.perform
    end

    it "passes --uid parameter" do
      new_user.uid = "1000"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--uid"
        expect(args).to include "1000"
      end

      action.perform
    end

    it "passes --gid parameter" do
      new_user.gid = "100"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--gid"
        expect(args).to include "100"
      end

      action.perform
    end

    it "passes --shell parameter" do
      new_user.shell = "bash"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--shell"
        expect(args).to include "bash"
      end

      action.perform
    end

    it "passes --comment parameter" do
      new_user.gecos = ["full name"]

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--comment"
        expect(args).to include "full name"
      end

      action.perform
    end

    it "passes --groups parameter" do
      allow(new_user).to receive(:secondary_groups_name).and_return(["test", "users"])
      allow(new_user).to receive(:groups).and_return([
                                                       double(id: 1),
                                                       double(id: 2)
                                                     ])

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--groups"
        expect(args).to include "test,users"
      end

      action.perform
    end

    it "passes --home parameter" do
      new_user.home.path = "/home/test5"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--home"
        expect(args).to include "/home/test5"
      end

      action.perform
    end

    context "commit config contain move_home" do
      let(:commit_config) { Y2Users::CommitConfig.new.tap { |c| c.move_home = true } }

      it "passes --move-home parameter" do
        new_user.home.path = "/home/test5"

        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include "--move-home"
        end

        action.perform
      end
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
