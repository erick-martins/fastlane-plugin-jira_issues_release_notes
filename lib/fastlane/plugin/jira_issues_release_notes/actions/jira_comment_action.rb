require 'fastlane/action'
require_relative '../helper/jira_issues_release_notes_helper'

module Fastlane
  module Actions
    module SharedValues
      FL_JIRA_LAST_TAG ||= :S3_APK_OUTPUT_PATH
      FL_JIRA_LAST_TAG_HASH ||= :FL_JIRA_LAST_TAG_HASH
      FL_JIRA_COMMITS_FROM_HASH ||= :FL_JIRA_COMMITS_FROM_HASH
      FL_JIRA_LAST_KEYS_FROM_COMMITS ||= :FL_JIRA_LAST_KEYS_FROM_COMMITS
      FL_JIRA_LAST_ISSUES_FROM_COMMITS ||= :FL_JIRA_LAST_ISSUES_FROM_COMMITS
    end

    class JiraCommentAction < Action
      def self.run(params)
        api_version = params[:api_version].to_i

        UI.user_error! "Comments block are only available from api version 3 or earlier" if api_version < 3 and params[:comment_block]

        @jira_helper = Helper::JiraIssuesReleaseNotesHelper.initialize_jira(
          host: params[:host],
          api_version: api_version,
          username: params[:username],
          password: params[:password],
          context_path: params[:context_path],
          disable_ssl_verification: params[:disable_ssl_verification]
        )

        issues = []
        if params[:extract_from_branch] then
          branch = other_action.git_branch
          ticket_key = Helper::JiraIssuesReleaseNotesHelper.extract_key_from_branch(
            branch: branch,
            ticket_prefix: params[:ticket_prefix]
          )

          unless ticket_key
            UI.error "Could not extract issue key from branch #{branch}" 
            false
          end 

          issues = @jira_helper.get(keys: [ticket_key])
        else

          issue_key_regex = Regexp.new("(#{params[:ticket_prefix]}-\\d+)")

          issues = Helper::JiraIssuesReleaseNotesHelper.get_issues_from_commit_after_latest_tag(
            tag_regex: params[:tag_prefix],
            tag_version_match: params[:tag_version_match],
            issue_key_regex: issue_key_regex,
            debug: params[:debug]
          )
        end

        unless !issues.empty?
          UI.error "No issue could be matched with (#{params[:ticket_prefix]}-\\d+)" 
          false
        end 

        @jira_helper.add_comment(
          comment: params[:comment_block] || params[:comment],
          issues: issues
        )

      end

      def self.description
        "It generates a release note based on the issues keys found in branch name and descriptions found in the commits"
      end

      def self.authors
        ["Erick Martins"]
      end

      def self.return_value
        "boolean value"
      end

      def self.details
        # Optional:
        "It generates a release note based on the issues keys found in branch name and descriptions found in the commits"
      end

      def self.available_options
        conflict_extraction_method = Proc.new do |other|
          UI.user_error! "Unexpected conflict with option #{other}" unless [:extract_from_branch, :tag_prefix].include?(other)
        end

        conflict_comment = Proc.new do |other|
          UI.user_error! "Unexpected conflict with option #{other}" unless [:comment_block, :comment].include?(other)
        end

        [
          FastlaneCore::ConfigItem.new(
            key: :tag_prefix,
            description: "Match parameter of git describe. See man page of git describe for more info",
            optional: true,
            conflicting_options: [:extract_from_branch],
            conflict_block: conflict_extraction_method
          ),
          FastlaneCore::ConfigItem.new(
            key: :ticket_prefix,
            env_name: 'FL_FIND_TICKETS_MATCHING',
            description:  'regex to extract ticket numbers',
            default_value: '[A-Z]+',
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :tag_version_match,
            description: "To parse version number from tag name",
            default_value: '\d+\.\d+\.\d+',
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :extract_from_branch,
            description: "If true it will search for jira issue key in the current branch name. In this case do NOT set :tag_prefix",
            conflicting_options: [:tag_prefix],
            conflict_block: conflict_extraction_method,
            default_value: false,
            optional: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :comment,
            description: 'Comment to add to the ticket',
            conflicting_options: [:comment_block],
            conflict_block: conflict_comment,
            optional: true,
            type: String,
          ),
          FastlaneCore::ConfigItem.new(
            key: :comment_block,
            description: 'Comment block to add to the ticket',
            conflicting_options: [:comment],
            optional: true,
            conflict_block: conflict_comment,
            type: Hash,
          ),

          # Jira Client options
          FastlaneCore::ConfigItem.new(
            key: :username,
            env_name: 'FL_JIRA_USERNAME',
            description:  'Jira user',
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :password,
            env_name: 'FL_JIRA_PASSWORD',
            description:  'Jira user',
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :host,
            env_name: 'FL_JIRA_HOST',
            description:  'Jira location',
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :api_version,
            env_name: 'FL_JIRA_API_VERSION',
            description:  'Jira api version',
            default_value: '3',
            optional: true,
          ),
          FastlaneCore::ConfigItem.new(
            key: :context_path,
            env_name: 'FL_JIRA_CONTEXT_PATH',
            description:  'Jira context path',
            optional: true,
            default_value: ''
          ),
          FastlaneCore::ConfigItem.new(
            key: :disable_ssl_verification,
            env_name: 'FL_JIRA_DISABLE_SSL_VERIFICATION',
            description:  'Jira SSL Verification mode',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :debug,
            description: "True if you want to log out a debug info",
            default_value: false,
            type: Boolean,
            optional: true
          )
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
