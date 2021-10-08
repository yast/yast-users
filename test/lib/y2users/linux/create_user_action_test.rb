require_relative "../test_helper"

require "date"
require "y2users/user"
require "y2users/linux/create_user_action"
require "y2users/commit_config"

describe Y2Users::Linux::CreateUserAction do
  subject(:action) { described_class.new(user, commit_config) }
  let(:user) { Y2Users::User.new("test") }
  let(:commit_config) { nil }

  before do
    allow(Yast::Execute).to receive(:on_target!)
  end

  describe "#perform" do

    it "creates user with useradd" do
      expect(Yast::Execute).to receive(:on_target!) do |cmd, *_args|
        expect(cmd).to eq "/usr/sbin/useradd"
      end

      action.perform
    end

    it "passes --uid parameter" do
      user.uid = "1000"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--uid"
        expect(args).to include "1000"
      end

      action.perform
    end

    it "passes --gid parameter" do
      user.gid = "100"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--gid"
        expect(args).to include "100"
      end

      action.perform
    end

    it "passes --shell parameter" do
      user.shell = "bash"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--shell"
        expect(args).to include "bash"
      end

      action.perform
    end

    it "passes --home-dir parameter" do
      user.home.path = "/home/test5"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--home-dir"
        expect(args).to include "/home/test5"
      end

      action.perform
    end

    it "passes --comment parameter" do
      user.gecos = ["full name"]

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--comment"
        expect(args).to include "full name"
      end

      action.perform
    end

    it "passes --groups parameter" do
      allow(user).to receive(:secondary_groups_name).and_return(["test", "users"])

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--groups"
        expect(args).to include "test,users"
      end

      action.perform
    end

    it "passes --system parameter for system users" do
      user.system = true

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--system"
      end

      action.perform
    end

    it "passes --non-unique if uid is defined" do
      user.uid = "1000"

      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args).to include "--non-unique"
      end

      action.perform
    end

    it "passes user name as final parameter" do
      expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
        expect(args.last).to eq "test"
      end

      action.perform
    end

    context "non-system users" do
      it "passes --create-home parameter" do
        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include "--create-home"
        end

        action.perform
      end

      it "passes --btrfs-subvolume-home parameter if btrfs home configured" do
        user.home.btrfs_subvol = true

        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include "--btrfs-subvolume-home"
        end

        action.perform
      end

      it "overwrites home mode parameter if home permission specified" do
        user.home.permissions = "0533"

        expect(Yast::Execute).to receive(:on_target!) do |_cmd, *args|
          expect(args).to include "--key"
          expect(args).to include "HOME_MODE=0533"
        end

        action.perform
      end
    end

    context "home creation failed" do
      it "retry to create user if home.path is not specified" do
        expect(Yast::Execute).to receive(:on_target!).twice do |_cmd, *args|
          if !args.include?("--no-create-home")
            raise Cheetah::ExecutionFailed.new([], double(exitstatus: 12), "", "")
          end
        end

        action.perform
      end
    end

    it "returns result without success and with issues if cmd failed" do
      allow(Yast::Execute).to receive(:on_target!)
        .and_raise(Cheetah::ExecutionFailed.new(nil, double(exitstatus: 1), nil, nil))

      result = action.perform
      expect(result.success?).to eq false
      expect(result.issues).to_not be_empty
    end
  end
end
