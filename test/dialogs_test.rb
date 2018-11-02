require_relative "./test_helper"
Yast.import "UI"

class UsersDialogsDummy < Yast::Module
  def initialize
    Yast.include self, "users/dialogs.rb"
  end
end

describe "Yast::UsersDialogsInclude" do
  subject { UsersDialogsDummy.new }

  before do
    allow(Yast).to receive(:import).and_call_original
    allow(Yast).to receive(:import).with("Ldap")
    allow(Yast).to receive(:import).with("LdapPopup")
  end

  describe "#ask_chown_home" do
    before(:each) do
      expect(Yast::UI).to receive(:OpenDialog)
      expect(Yast::UI).to receive(:CloseDialog)
    end

    it "returns a two-key result when Yes is answered" do
      expect(Yast::UI).to receive(:UserInput).and_return :yes
      expect(Yast::UI).to receive(:QueryWidget)
        .with(Id(:chown_home), :Value).and_return(false)

      expect(subject.ask_chown_home("/home/foo", true))
        .to eq("retval" => true, "chown_home" => false)
    end
    it "returns a one result when No is answered" do
      expect(Yast::UI).to receive(:UserInput).and_return :no
      expect(subject.ask_chown_home("/home/foo", true))
        .to eq("retval" => false)
    end
  end

  describe "#get_password_term" do
    it "sets exp_date" do
      user = { "shadowExpire" => 30 } # days after 1970-01-01
      exp_date = ""

      subject.get_password_term(user, exp_date)
      expect(exp_date).to eq("1970-01-31")
    end
  end
end
