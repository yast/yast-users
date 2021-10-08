require_relative "../test_helper"

require "y2users/linux/set_auth_keys_action"
require "y2users/commit_config"
require "y2users/user"

describe Y2Users::Linux::SetAuthKeysAction do
  subject(:action) { described_class.new(user, commit_config) }
  let(:user) { Y2Users::User.new("test").tap { |u| u.authorized_keys = ["test"] } }
  let(:commit_config) { nil }

  describe "#perform" do
    it "calls SSHAuthorizedKeyring#write_keys" do
      obj = double
      expect(obj).to receive(:write_keys)
      expect(Yast::Users::SSHAuthorizedKeyring).to receive(:new).with(user.home, ["test"])
        .and_return(obj)

      subject.perform
    end

    it "returns result without success and with issues if cmd failed" do
      obj = double
      expect(obj).to receive(:write_keys)
        .and_raise(Yast::Users::SSHAuthorizedKeyring::PathError, user.home)
      expect(Yast::Users::SSHAuthorizedKeyring).to receive(:new).with(user.home, ["test"])
        .and_return(obj)

      result = action.perform
      expect(result.success?).to eq false
      expect(result.issues).to_not be_empty
    end
  end
end
