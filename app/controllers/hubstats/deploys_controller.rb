require_dependency "hubstats/application_controller"

module Hubstats
  class DeploysController < Hubstats::BaseController

    # Public - Will list the deploys that correspond with selected repos, users, orders, and groupings. Only shows
    # deploys within the @start_date and @end_date.
    #
    # Returns - the deploy data
    def index
      index_params = params.permit(:users, :repos, :teams, :group, :order, :page)
      @deploys = Hubstats::Deploy.includes(:repo, :pull_requests, :user)
        .belonging_to_users(index_params[:users]).belonging_to_repos(index_params[:repos]).belonging_to_teams(index_params[:teams])
        .group(index_params[:group])
        .order_with_date_range(@start_date, @end_date, index_params[:order])
        .paginate(:page => index_params[:page], :per_page => 15)

      grouping(index_params[:group], @deploys)
    end

    # Public - Shows the single deploy and all of the stats and pull requests about that deploy. Stats and PRs only
    # include info that happened between @start_date and @end_date.
    #
    # Returns - the stats and data of the deploy
    def show
      show_params = params.permit(:id)
      @deploy = Hubstats::Deploy.includes(:repo, :pull_requests).find(show_params[:id])
      repo = @deploy.repo
      @pull_requests = @deploy.pull_requests.limit(50)
      @pull_request_count = @pull_requests.length
      @stats_row_one = {
        pull_count: @pull_request_count,
        net_additions: @deploy.find_net_additions,
        comment_count: @deploy.find_comment_count,
        additions: @deploy.total_changes(:additions),
        deletions: @deploy.total_changes(:deletions)
      }
    end

    # Public - Creates a new deploy with the git_revision. Passed in the repo name and a string of PR ids
    # that are then used to find the repo_id, PR id array. The user_id is found through one of the pull requests.
    #
    # Returns - nothing, but makes a new deploy
    def create
      new_params = deploy_params
      if new_params[:git_revision].nil? || new_params[:repo_name].nil? || new_params[:pull_request_ids].nil?
        render plain: "Missing a necessary parameter: git revision, pull request ids, or repository name.", :status => 400 and return
      else
        @deploy = Deploy.new
        @deploy.deployed_at = new_params[:deployed_at]
        @deploy.git_revision = new_params[:git_revision]
        @repo = Hubstats::Repo.where(full_name: new_params[:repo_name])

        if !valid_repo(@repo)
          render plain: "Repository name is invalid.", :status => 400 and return
        else
          @deploy.repo_id = @repo.first.id.to_i
        end

        pull_request_id_array = new_params[:pull_request_ids].split(",").map {|i| i.strip.to_i}
        if !valid_pr_ids(pull_request_id_array)
          render plain: "No pull request ids given.", :status => 400 and return
        else
          @deploy.pull_requests = Hubstats::PullRequest.where(repo_id: @deploy.repo_id).where(number: pull_request_id_array)
        end

        if !valid_pulls
          render plain: "Pull requests not valid", :status => 400 and return
        end

        if @deploy.save
          head :ok
          return
        else
          head :bad_request
          return
        end
      end
    end

    # Public - Checks if the repo that's passed in is empty.
    #
    # repo - the repository
    #
    # Returns - true if the repo is valid
    def valid_repo(repo)
      return !repo.empty?
    end

    # Public - Checks if the array is empty or if the ids in the array are invalid.
    #
    # pull_id_array - the array of pull request ids
    #
    # Returns - returns true if the array neither is empty nor comes out to [0]
    def valid_pr_ids(pull_id_array)
      return !pull_id_array.empty? && pull_id_array != [0]
    end

    # Public - Checks if the first pull assigned to the new deploy is nil, if the merged_by part is nil. If nothing is
    # nil, it will set the user_id of the deploy to be the merged_by of the pull.
    #
    # Returns - true and changes the user_id of deploy, else returns false
    def valid_pulls
      pull = @deploy.pull_requests.first
      return false if pull.nil? || pull.merged_by.nil?
      @deploy.user_id = pull.merged_by
      return true
    end

    # Private - Allows only these parameters to be added when creating a deploy
    #
    # Returns - hash of parameters
    private def deploy_params
      params.permit(:git_revision, :repo_name, :deployed_at, :user_id, :pull_request_ids)
    end
  end
 end
