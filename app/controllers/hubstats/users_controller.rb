require_dependency "hubstats/application_controller"

module Hubstats
  class UsersController < ApplicationController

    # Public - Shows all of the users in either alphabetical order, by filter params, or that have done things in
    # github between the selected @start_date and @end_date.
    #
    # Returns - the user data
    def index
      params = params.try(:permit!).to_h

      if params[:query] ## For select 2
        @users = Hubstats::User.where("login LIKE ?", "%#{params[:query]}%").order("login ASC")
      elsif params[:id]
        @users = Hubstats::User.where(id: params[:id].split(",")).order("login ASC")
      else
        @users = Hubstats::User.with_all_metrics(@start_date, @end_date)
          .where.not(login: Hubstats.config.github_config["ignore_users_list"] || [])
          .with_id(params[:users])
          .custom_order(params[:order])
          .paginate(:page => params[:page], :per_page => 15)
      end

      respond_to do |format|
        format.html # index.html.erb
        format.json { render :json => @users}
      end
    end

    # Public - Will show the specific user along with the basic stats about that user, including all deploys
    # and merged PRs they've done within the @start_date and @end_date.
    #
    # Returns - the data of the specific user
    def show
      params = params.try(:permit!).to_h

      @user = Hubstats::User.where(login: params[:id]).first
      @pull_requests = Hubstats::PullRequest.belonging_to_user(@user.id).merged_in_date_range(@start_date, @end_date).order("updated_at DESC").limit(50)
      @pull_count = Hubstats::PullRequest.belonging_to_user(@user.id).merged_in_date_range(@start_date, @end_date).count(:all)
      @deploys = Hubstats::Deploy.belonging_to_user(@user.id).deployed_in_date_range(@start_date, @end_date).order("deployed_at DESC").limit(50)
      @deploy_count = Hubstats::Deploy.belonging_to_user(@user.id).deployed_in_date_range(@start_date, @end_date).count(:all)
      @qa_signoffs = Hubstats::QaSignoff.belonging_to_user(@user.id).signed_within_date_range(@start_date, @end_date).order("signed_at DESC").limit(50)
      @qa_signoff_count = Hubstats::QaSignoff.belonging_to_user(@user.id).signed_within_date_range(@start_date, @end_date).count(:all)
      @comment_count = Hubstats::Comment.belonging_to_user(@user.id).created_in_date_range(@start_date, @end_date).count(:all)
      @net_additions = Hubstats::PullRequest.merged_in_date_range(@start_date, @end_date).belonging_to_user(@user.id).sum(:additions).to_i -
                       Hubstats::PullRequest.merged_in_date_range(@start_date, @end_date).belonging_to_user(@user.id).sum(:deletions).to_i
      @additions = Hubstats::PullRequest.merged_in_date_range(@start_date, @end_date).belonging_to_user(@user.id).average(:additions)
      @deletions = Hubstats::PullRequest.merged_in_date_range(@start_date, @end_date).belonging_to_user(@user.id).average(:deletions)

      stats
    end

    # Public - Shows the basic stats for the user show page.
    #
    # Returns - the data in a hash
    def stats
      @additions ||= 0
      @deletions ||= 0
      @stats_row_one = {
        pull_count: @pull_count,
        comment_count: @comment_count,
        qa_signoff_count: @qa_signoff_count
      }
      @stats_row_two = {
        avg_additions: @additions.round.to_i,
        avg_deletions: @deletions.round.to_i,
        net_additions: @net_additions
      }
    end
  end
end
