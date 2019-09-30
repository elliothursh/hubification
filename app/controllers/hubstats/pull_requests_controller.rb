require_dependency "hubstats/application_controller"
require_dependency 'pry'

module Hubstats
  class PullRequestsController < Hubstats::BaseController

    # Public - Will correctly add the labels to the side of the page based on which PRs are showing, and will
    # come up with the list of PRs to show, based on users, repos, grouping, labels, and order. Only shows
    # PRs within @start_date and @end_date.
    #
    # Returns - the pull request data
    def index
      URI.decode(params[:label].try(:permit!).to_h) if params[:label]

      index_params = params.try(:permit!).to_h

      pull_requests = PullRequest.all_filtered(index_params, @start_date, @end_date)
      @labels = Hubstats::Label.count_by_pull_requests(pull_requests).order("pull_request_count DESC")
      @pull_requests = Hubstats::PullRequest.includes(:user, :repo, :team)
        .belonging_to_users(index_params[:users]).belonging_to_repos(index_params[:repos]).belonging_to_teams(index_params[:teams])
        .group(index_params[:group]).with_label(index_params[:label])
        .state_based_order(@start_date, @end_date, index_params[:state], index_params[:order])
        .paginate(:page => index_params[:page], :per_page => 15)

      grouping(index_params[:group], @pull_requests)
    end

    # Public - Will show the particular pull request selected, including all of the basic stats, deploy (only if
    # PR is closed), and comments associated with that PR within the @start_date and @end_date.
    #
    # Returns - the specific details of the pull request
    def show
      show_params = params.permit(:id, :repo).to_h
      @repo = Hubstats::Repo.where(name: show_params[:repo]).first
      @pull_request = Hubstats::PullRequest.belonging_to_repo(@repo.id).where(id: show_params[:id]).first
      @comments = Hubstats::Comment.belonging_to_pull_request(show_params[:id]).created_in_date_range(@start_date, @end_date).limit(50)
      comment_count = Hubstats::Comment.belonging_to_pull_request(show_params[:id]).created_in_date_range(@start_date, @end_date).count(:all)
      @deploys = Hubstats::Deploy.where(id: @pull_request.deploy_id).order("deployed_at DESC")
      @stats_row_one = {
        comment_count: comment_count,
        net_additions: @pull_request.additions.to_i - @pull_request.deletions.to_i,
        additions: @pull_request.additions.to_i,
        deletions: @pull_request.deletions.to_i
      }
    end
  end
end
