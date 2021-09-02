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

    class JiraIssuesKeysFromCommitsAction < Action
      def self.run(params)
        Helper::JiraIssuesReleaseNotesHelper.initialize_jira(
          host: params[:host],
          api_version: params[:api_version],
          username: params[:username],
          password: params[:password],
          context_path: params[:context_path],
          disable_ssl_verification: params[:disable_ssl_verification]
        )

        issue_key_regex = Regexp.new("(#{params[:ticket_prefix]}-\\d+)")

        Helper::JiraIssuesReleaseNotesHelper.get_keys_from_commit_after_latest_tag(
          tag_regex: params[:tag_prefix],
          tag_version_match: params[:tag_version_match],
          issue_key_regex: issue_key_regex,
          debug: params[:debug]
        )
      end

      def self.description
        "It generates a release note based on the issues keys found in branch name and descriptions found in the commits"
      end

      def self.authors
        ["Erick Martins"]
      end

      def self.return_value
        ["ABC-123",  "ABC-321"]
      end

      def self.details
        # Optional:
        "It generates a release note based on the issues keys found in branch name and descriptions found in the commits"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :tag_prefix,
            description: "Match parameter of git describe. See man page of git describe for more info",
            verify_block: proc do |value|
              UI.user_error!("No match for analyze_commits action given, pass using `match: 'expr'`") unless value && !value.empty?
            end
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
            default_value: '\d+\.\d+\.\d+'
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
            default_value: '2',
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
