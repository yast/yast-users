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
        .to eq({"retval" => true, "chown_home" => false})
    end
    it "returns a one result when No is answered" do
      expect(Yast::UI).to receive(:UserInput).and_return :no
      expect(subject.ask_chown_home("/home/foo", true))
        .to eq({"retval" => false})
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

  context "public keys handling" do
    let(:user) do
      { "username" => "root", "authorized_keys" => authorized_keys }
    end

    describe "#handle_authorized_keys_input" do
      let(:key1) { instance_double(Y2Users::SSHPublicKey, to_s: "ssh-rsa 1...") }
      let(:key2) { instance_double(Y2Users::SSHPublicKey, to_s: "ssh-rsa 2...") }

      before do
        allow(subject).to receive(:read_public_key).and_return(key1)
      end

      context "when the user adds a public key" do
        let(:authorized_keys) { [] }

        it "adds the public key to the user" do
          subject.handle_authorized_keys_input(:add_authorized_key, user)
          expect(user["authorized_keys"]).to_not be_empty
        end

        context "and the public key was already selected" do
          let(:authorized_keys) { [key1.to_s] }

          it "displays an error" do
            expect(Yast2::Popup).to receive(:show)
              .with("The selected public key is already present in the list.", headline: :error)
            subject.handle_authorized_keys_input(:add_authorized_key, user)
          end
        end
      end

      context "when the user removes a public key" do
        let(:authorized_keys) { [key1.to_s, key2.to_s] }

        before do
          allow(Yast::UI).to receive(:QueryWidget).with(Id(:authorized_keys_table), :CurrentItem)
            .and_return(1)
          allow(Yast::UI).to receive(:QueryWidget).with(Id(:authorized_keys_table), :Items)
            .and_return([Item(Id(0), "fingerprint#1", "comment#1")])
        end

        it "removes the public key from the user" do
          subject.handle_authorized_keys_input(:remove_authorized_key, user)
          expect(user["authorized_keys"]).to eq([key1.to_s])
        end
      end
    end

    describe "#read_public_key" do
      let(:path) { FIXTURES_PATH.join("id_rsa.pub").to_s }

      before do
        allow(Yast::UI).to receive(:AskForExistingFile).and_return(path)
      end

      context "when the user selects a file" do
        it "returns the public key" do
          key = subject.read_public_key
          expect(key.comment).to eq("dummy1@example.net")
        end
      end

      context "when the user selects an invalid file" do
        let(:path) { FIXTURES_PATH.join("users.yml").to_s }

        it "displays an error" do
          expect(Yast2::Popup).to receive(:show)
            .with("The selected file does not contain a valid public key", headline: :error)
          subject.read_public_key
        end
      end

      context "when the user file that does not exist" do
        let(:path) { FIXTURES_PATH.join("non-existent").to_s }

        it "displays an error" do
          expect(Yast2::Popup).to receive(:show)
            .with("Could not read the file containing the public key", headline: :error)
          subject.read_public_key
        end
      end

      context "when the user cancels the dialog" do
        let(:path) { nil }

        it "returns nil" do
          expect(subject.read_public_key).to eq(nil)
        end
      end
    end

    describe "#display_authorized_keys_tab" do
      let(:user) do
        { "username" => "root", "authorized_keys" => authorized_keys }
      end

      before do
        allow(Yast::UI).to receive(:ChangeWidget)
            .with(Id(:remove_authorized_key), :Enabled, anything)
      end

      context "when a public keys is found" do
        let(:authorized_keys) { ["ssh-rsa ..."] }

        it "enables the 'remove' button" do
          expect(Yast::UI).to receive(:ChangeWidget)
            .with(Id(:remove_authorized_key), :Enabled, true)
          subject.display_authorized_keys_tab(user)
        end
      end

      context "when no public keys are found" do
        let(:authorized_keys) { [] }

        it "disables the 'remove' button" do
          expect(Yast::UI).to receive(:ChangeWidget)
            .with(Id(:remove_authorized_key), :Enabled, false)
          subject.display_authorized_keys_tab(user)
        end
      end

      context "when a row is selected" do
        let(:authorized_keys) { ["ssh-rsa ..."] }

        it "selects the corresponding row in the table" do
          expect(Yast::UI).to receive(:ChangeWidget)
            .with(Id(:authorized_keys_table), :CurrentItem, 0)
          subject.display_authorized_keys_tab(user, 0)
        end
      end
    end

    describe "#get_authorized_keys_term"
  end
end
