module Hubstats
  class PullRequest < ActiveRecord::Base

    scope :closed_since, lambda {|time| where("closed_at > ?", time).order("closed_at DESC") }
    scope :belonging_to_repo, lambda {|repo_id| where(repo_id: repo_id)}
    scope :belonging_to_user, lambda {|user_id| where(user_id: user_id)}
    
    attr_accessible :id, :url, :html_url, :diff_url, :patch_url, :issue_url, :commits_url,
      :review_comments_url, :review_comment_url, :comments_url, :statuses_url, :number,
      :state, :title, :body, :created_at, :updated_at, :closed_at, :merged_at, 
      :merge_commit_sha, :merged, :mergeable, :comments, :commits, :additions,
      :deletions, :changed_files, :user_id, :repo_id

      belongs_to :user
      belongs_to :repo

      def self.create_or_update(github_pull)
        github_pull = github_pull.to_h if github_pull.respond_to? :to_h

        user = Hubstats::User.create_or_update(github_pull[:user])
        github_pull[:user_id] = user.id
        repo = Hubstats::Repo.create_or_update(github_pull[:repository])
        github_pull[:repo_id] = repo.id

        pull_data = github_pull.slice(*column_names.map(&:to_sym))

        pull = where(:id => pull_data[:id]).first_or_create(pull_data)
        return pull if pull.update_attributes(pull_data)
        Rails.logger.debug pull.errors.inspect
      end
  end
end
