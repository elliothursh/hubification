require 'spec_helper'

module Hubstats
  describe TeamsController, :type => :controller do
    routes { Hubstats::Engine.routes }

    describe "#index" do
      it "should return all of the teams" do
        team1 = create(:team, :name => "Team One", :hubstats => true)
        team2 = create(:team, :name => "Team Two", :hubstats => false)
        team3 = create(:team, :name => "Team Three", :hubstats => true)
        team4 = create(:team, :name => "Team Four", :hubstats => true)
        team5 = create(:team, :name => "Team Five", :hubstats => false)
        expect(Hubstats::Team).to receive_message_chain("with_id.order_by_name.paginate").and_return([team4, team1, team3, team2])
        allow(Hubstats).to receive_message_chain(:config, :github_config, :[]).with("ignore_users_list") { ["user"] }
        get :index
        expect(response).to have_http_status(200)
      end
    end

    describe "#show" do
      it "should return the team and all of its users and pull requests" do
        team = create(:team, :name => "Team Tests Passing", :hubstats => true, :id => 1)
        user1 = create(:user, :id => 101010, :login => "examplePerson1", :updated_at => Date.today)
        user2 = create(:user, :id => 202020, :login => "examplePerson2", :updated_at => Date.today)
        repo = create(:repo, :updated_at => Date.today)
        team.users << user1
        team.users << user2
        team.users << user2
        pull1 = create(:pull_request, :user => user1, :id => 303030, :team => team, :repo_id => repo.id, :updated_at => Date.today)
        pull2 = create(:pull_request, :user => user2, :id => 404040, :team => team, :repo => pull1.repo, :updated_at => Date.today)
        allow(Hubstats).to receive_message_chain(:config, :github_config, :[]).with("ignore_users_list") { ["user"] }
        get :show, params: { id: 1 }
        expect(assigns(:team)).to eq(team)
        expect(pull1.team_id).to eq(team.id)
        expect(pull2.team_id).to eq(team.id)
        expect(assigns(:team).users).to contain_exactly(user1, user2, user2)
        expect(assigns(:users)).to contain_exactly(user1, user2)
        expect(assigns(:active_user_count)).to eq(2)
        expect(response).to have_http_status(200)
      end
    end
  end
end
