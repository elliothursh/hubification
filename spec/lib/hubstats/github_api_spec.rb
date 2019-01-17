require 'spec_helper'

module Hubstats
  describe GithubAPI, :type => :model do
    context ".configure" do
      let(:access_token) { "access_token" }
      let(:user) { double }
      let(:client) { double(:user => user) }

      before do
        allow(client).to receive(:user).and_return( "user" )
      end

      after do
        puts Hubstats::GithubAPI.class_variable_set(:@@auth_info, nil)
      end

      context "with configuration file" do
        before do
          allow(ENV).to receive(:[]).and_return(nil)
        end

        it 'should initialize client with options param' do
          Hubstats::GithubAPI.configure({"access_token" => access_token})
          expect(Octokit::Client).to receive(:new).with(access_token: access_token).and_return(client)
          expect(Hubstats::GithubAPI.client).to eq(client)
        end
      end

      context "with environment variables" do
        before do
          allow(ENV).to receive(:[]).with("GITHUB_API_TOKEN").and_return("github_api_token")
        end

        it 'should initialize client with environment variables' do
          Hubstats::GithubAPI.configure({"access_token" => access_token})
          expect(Octokit::Client).to receive(:new).with(access_token: "github_api_token").and_return(client)
          expect(Hubstats::GithubAPI.client()).to eq(client)
        end
      end

      context "with application authentication" do
        before do
          allow(ENV).to receive(:[]).and_return(nil)
          allow(ENV).to receive(:[]).with("CLIENT_ID").and_return("client_id")
          allow(ENV).to receive(:[]).with("CLIENT_SECRET").and_return("client_secret")
        end

        it 'should intialize client with client-id environment variables' do
          Hubstats::GithubAPI.configure()
          expect(Octokit::Client).to receive(:new).with(client_id: "client_id", client_secret: "client_secret").and_return(client)
          expect(Hubstats::GithubAPI.client).to eq(client)
        end
      end

      context "with wrong credentials" do
        before do
          allow(client).to receive(:user).and_return( 'test' )
          allow(ENV).to receive(:[]).and_return('creds')
          allow(Octokit::Client).to receive(:new).with({:access_token=>"creds"}).and_raise(Octokit::Unauthorized)
        end

        it 'should fail to initialize at all' do
         Hubstats::GithubAPI.configure()
         expect{Hubstats::GithubAPI.client}.to raise_error Octokit::Unauthorized
        end
      end
    end

    context '.update_teams' do
      subject {Hubstats::GithubAPI}
      let(:org) {'sportngin'}
      let(:team1) {build(:team_hash, :name => "Team One", description: "hubstats")}
      let(:team2) {build(:team_hash, :name => "Team Four")}
      let(:team3) {build(:team_hash, :name => "Team Five")}
      let(:team4) {build(:team_hash, :name => "Team Six")}
      let(:team) {build(:team)}
      let(:user1) {build(:user_hash)}
      let(:user2) {build(:user_hash)}
      let(:user3) {build(:user_hash)}
      let(:finished_user) {build(:user, :created_at => Date.today, :updated_at => Date.today)}
      let(:hubstats_user) {build(:user)}
      let(:access_token) { "access_token" }
      let(:user) { double }
      let(:octokit_team) {double(:octokit_team, description: "Description for Hubstats")}
      let(:client) {double(:octokit_client, team: octokit_team, user: user)}

      it 'should successfully update all teams' do
        allow_message_expectations_on_nil
        allow(client).to receive(:organization_teams).with("sportngin").and_return([team1, team2, team3, team4])
        allow(client).to receive(:team_members).with(team1[:id]).and_return([user1, user2, user3])
        allow(client).to receive(:team).and_return(octokit_team)
        allow(Hubstats).to receive_message_chain(:config, :github_config, :[]).with("team_list") { ["Team One", "Team Two", "Team Three"] }
        allow(Hubstats).to receive_message_chain(:config, :github_config, :[]).with("org_name") {"sportngin"}
        allow(Hubstats::GithubAPI).to receive(:client).and_return(client)
        allow(client).to receive(:rate_limit)
        allow(Hubstats::Team).to receive_message_chain(:where, :name).with("Team One")
        allow(Hubstats::Team.where(name: "Team One")).to receive(:first).and_return(team)
        allow(client).to receive_message_chain(:rate_limit, :remaining).and_return(500)
        allow(Hubstats::User).to receive(:create_or_update).and_return(finished_user)
        expect(Hubstats::Team).to receive(:create_or_update).at_least(:once)
        subject.update_teams
      end
    end

    context '.deprecate_teams' do
      subject {Hubstats::GithubAPI}
      let(:team1) {create(:team, :name => "Team One")}
      let(:team2) {create(:team, :name => "Team Two")}
      let(:team3) {create(:team, :name => "Team Three")}
      let(:team4) {create(:team, :name => "Team Four")}
      let(:team5) {create(:team, :name => "Team Five")}
      let(:octokit_team) {double(:octokit_team, description: "Description for Hubstats")}
      let(:client) {double(:octokit_client, team: octokit_team)}

      it 'should update the teams in the database based on a given whitelist' do
        allow(Hubstats::Team).to receive(:all).and_return( [team1, team2, team3, team4, team5] )
        allow(client).to receive(:team).and_return(octokit_team)
        allow(subject).to receive(client).and_return(client)
        expect(team5).to receive(:update_column).with(:hubstats, false)
        subject.deprecate_teams
      end
    end

    context ".create_repo_hook" do
      subject {Hubstats::GithubAPI}
      let(:config) {double(:webhook_secret => 'a1b2c3d4', :webhook_endpoint => "hubstats.com")}
      let(:client) {double}
      let(:repo) {double(:full_name =>'hubstats') }
      before do
        allow(Hubstats).to receive(:config) {config}
        allow(subject).to receive(:client) {client}
      end

      it "should call octokit create_hook for repositories" do
        expect(client).to receive(:create_hook)
        subject.create_repo_hook(repo)
      end

      it "should rescue unprocessable entity from repo hook" do
        allow(client).to receive(:create_hook) { raise Octokit::UnprocessableEntity }
        subject.create_repo_hook(repo)
      end
    end

    context ".create_org_hook" do
      subject {Hubstats::GithubAPI}
      let(:config) {double(:webhook_secret => 'a1b2c3d4', :webhook_endpoint => "hubstats.com")}
      let(:client) {double}
      let(:org) {double(:full_name => 'sportngin') }
      before do
        allow(Hubstats).to receive(:config) {config}
        allow(subject).to receive(:client) {client}
      end

      it "should call octokit create_org_hook for organizations" do
        expect(client).to receive(:create_org_hook)
        subject.create_org_hook(org)
      end

      it "should rescue unprocessable entity from organization hook" do
        allow(client).to receive(:create_org_hook) { raise Octokit::UnprocessableEntity }
        subject.create_org_hook(org)
      end
    end

  end
end
