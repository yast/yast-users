#!/usr/bin/env rspec

require_relative "../../../test_helper"
require "yaml"
require "users/clients/auto"
require "y2users/autoinst/reader"
require "y2issues"

Yast.import "Report"

# defines exported users
require_relative "../../../fixtures/users_export"

describe Y2Users::Clients::Auto do
  let(:mode) { "autoinstallation" }
  let(:args) { [func] }

  before do
    allow(Yast).to receive(:import).and_call_original
    allow(Yast).to receive(:import).with("Ldap")
    allow(Yast).to receive(:import).with("LdapPopup")
    allow(Yast::Mode).to receive(:mode).and_return(mode)
    allow(Yast::Stage).to receive(:initial).and_return(true)
    allow(Yast::WFM).to receive(:Args).and_return(args)
  end

  describe "#run" do
    context "Import" do
      let(:func) { "Import" }
      let(:args) { [func, users] }

      context "when double users have been given in the profile" do
        let(:mode) { "normal" }
        let(:users) { YAML.load_file(FIXTURES_PATH.join("users_error.yml")) }

        it "report error" do
          allow(Yast::Stage).to receive(:initial).and_return(false)
          expect(Yast::Report).to receive(:Error)
            .with(_("Found users in profile with equal <username>."))
          expect(Yast::Report).to receive(:Error)
            .with(_("Found users in profile with equal <uid>."))
          expect(subject.run).to eq(true)
        end
      end

      context "when users without any UID are defined in the profile" do
        let(:users) { YAML.load_file(FIXTURES_PATH.join("users_no_error.yml")) }

        it "will not be checked for double UIDs" do
          expect(Yast::Report).not_to receive(:Error)
            .with(_("Found users in profile with equal <username>."))
          expect(Yast::Report).not_to receive(:Error)
            .with(_("Found users in profile with equal <uid>."))
          expect(subject.run).to eq(true)
        end
      end

      context "when root password linuxrc attribute is set" do
        before do
          allow(Yast::Linuxrc).to receive(:InstallInf).with("RootPassword").and_return("test")
        end

        context "when profile contain root password" do
          let(:users) { USERS_EXPORT }

          it "keeps root password from profile" do
            allow(Y2Issues).to receive(:report).and_return(true) # fixture contain dup uids
            expect(subject.run).to eq(true)

            config = Y2Users::ConfigManager.instance.target
            root_user = config.users.root
            expect(root_user.password.value.encrypted?).to eq true
            expect(root_user.password.value.content).to match(/^\$6\$AS/)
          end
        end

        context "when profile does not contain root password" do
          let(:users) { {} }

          it "sets root password to linuxrc value" do
            expect(subject.run).to eq(true)
            config = Y2Users::ConfigManager.instance.target
            root_user = config.users.root
            expect(root_user.password.value.encrypted?).to eq false
            expect(root_user.password.value.content).to eq "test"
          end
        end
      end

      context "when some issue is registered" do
        let(:users) { { "users" => [] } }
        let(:reader) { Y2Users::Autoinst::Reader.new(users) }
        let(:issues) { Y2Issues::List.new }
        let(:continue?) { true }

        let(:result) do
          Y2Users::ReadResult.new(Y2Users::Config.new, issues)
        end

        before do
          allow(Y2Users::Autoinst::Reader).to receive(:new).and_return(reader)
          allow(reader).to receive(:read).and_return(result)
          issues << Y2Issues::InvalidValue.new("dummy", location: nil)
          allow(Y2Issues).to receive(:report).and_return(continue?)
        end

        it "reports the issues" do
          expect(Y2Issues).to receive(:report).with(issues)
          subject.run
        end

        context "and the user wants to continue" do
          let(:continue?) { true }

          it "returns true" do
            expect(subject.run).to eq(true)
          end
        end

        context "and the user does not want to continue" do
          let(:continue?) { false }

          it "returns false" do
            expect(subject.run).to eq(false)
          end
        end
      end
    end

    context "Change" do
      let(:func) { "Change" }

      it "returns the 'summary' autosequence result" do
        expect(subject).to receive(:AutoSequence).and_return(:next)
        expect(subject.run).to eq(:next)
      end
    end

    context "Summary" do
      let(:func) { "Summary" }

      before do
        allow(Yast::Users).to receive(:Summary).and_return("summary")
      end

      it "returns the users summary" do
        expect(subject.run).to eq("summary")
      end
    end

    context "Export" do
      let(:func) { "Export" }
      let(:args) { [func] }

      let(:local_users) { double("local_users") }
      let(:all_users) { double("all_users") }

      before do
        allow(Yast::WFM).to receive(:Args).and_return(args)
        allow(Yast::Users).to receive(:Export).with("default")
          .and_return(all_users)
        allow(Yast::Users).to receive(:Export).with("compact")
          .and_return(local_users)
      end

      it "exports all users and groups" do
        expect(subject.run).to eq(all_users)
      end

      context "when 'compact' export is wanted" do
        let(:args) { [func, { "target" => "compact" }] }

        it "it exports only local users and groups" do
          expect(subject.run).to eq(local_users)
        end
      end
    end

    context "Modified" do
      let(:func) { "GetModified" }

      before do
        allow(Yast::Users).to receive(:Modified).and_return(true)
      end

      it "returns whether the data in Users module has been modified" do
        expect(subject.run).to eq(true)
      end
    end

    context "SetModified" do
      let(:func) { "SetModified" }

      it "sets the Users module as modified" do
        expect(Yast::Users).to receive(:SetModified).with(true)
        subject.run
      end
    end

    context "Reset" do
      let(:func) { "Reset" }

      it "removes the configuration object" do
        # reset is not called during installation
        allow(Yast::Stage).to receive(:initial).and_return(false)
        expect(Yast::Users).to receive(:Import).with({})

        subject.run
      end
    end

    context "Write" do
      let(:func) { "Write" }
      let(:reader) do
        instance_double(
          Y2Users::UsersModule::Reader, read: [Y2Users::Config.new, target_config]
        )
      end
      let(:writer) { instance_double(Y2Users::Linux::Writer, write: []) }
      let(:system_config) { Y2Users::Config.new }
      let(:target_config) do
        Y2Users::Config.new.tap do |config|
          config.attach(user)
          config.attach(root)
          config.attach(users_group)
          config.attach(others_group)
        end
      end
      let(:root) { Y2Users::User.new("root").tap { |u| u.uid = 0 } }
      let(:user) { Y2Users::User.new("foo") }
      let(:users_group) { Y2Users::Group.new("users") }
      let(:others_group) { Y2Users::Group.new("others") }

      before do
        allow(Y2Users::ConfigManager.instance).to receive(:system)
          .and_return(system_config)
        allow(Y2Users::Linux::Writer).to receive(:new).and_return(writer)
        allow(Y2Users::UsersModule::Reader).to receive(:new).and_return(reader)
        allow(Yast::Users).to receive(:GetUsers).with("uid", "local")
          .and_return("foo" => { "uid" => "foo", "modified" => true })
        allow(Yast::Users).to receive(:GetUsers).with("uid", "system")
          .and_return("root" => { "uid" => "root", "modified" => false })
        allow(Yast::Users).to receive(:GetGroups).with("cn", "local")
          .and_return("foo" => { "cn" => "users", "modified" => true })
        allow(Yast::Users).to receive(:GetGroups).with("cn", "system")
          .and_return("root" => { "cn" => "others", "modified" => false })
      end

      it "writes the users defined in the Users module" do
        expect(Y2Users::Linux::Writer).to receive(:new) do |new_config, _|
          names = new_config.users.map(&:name)
          expect(names).to include("foo")
          expect(names).to_not include("root")
          writer
        end
        subject.run
      end

      it "writes the groups defined in the Users module" do
        expect(Y2Users::Linux::Writer).to receive(:new) do |new_config, _|
          names = new_config.groups.map(&:name)
          expect(names).to include("users")
          expect(names).to_not include("others")
          writer
        end
        subject.run
      end

      context "when there are not issues" do
        it "returns true" do
          expect(subject.run).to eq(true)
        end
      end

      context "when any issue was found" do
        before do
          allow(writer).to receive(:write).and_return([double("issue")])
        end

        it "returns false" do
          expect(subject.run).to eq(false)
        end
      end
    end
  end
end
