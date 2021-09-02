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

    class JiraReleaseValidationAction < Action
      def self.run(params)
        Helper::JiraIssuesReleaseNotesHelper.initialize_jira(
          host: params[:host],
          username: params[:username],
          password: params[:password],
          context_path: params[:context_path],
          api_version: params[:api_version],
          disable_ssl_verification: params[:disable_ssl_verification]
        )

        @format = params[:format]
        @format_line_break = @format === 'html' ? '<br />' : "\n"

        issue_key_regex = Regexp.new("(#{params[:ticket_prefix]}-\\d+)")

        issues = Helper::JiraIssuesReleaseNotesHelper.get_issues_from_commit_after_latest_tag(
          tag_regex: params[:tag_prefix],
          tag_version_match: params[:tag_version_match],
          issue_key_regex: issue_key_regex,
          debug: params[:debug]
        )

        return '' unless issues

        grouped_issues = {
          "Tasks to validate" => issues.select { |issue| params[:to_validate_status].include?(issue.status.name) },
          "Validated tasks" => issues.select { |issue| params[:validated_status].include?(issue.status.name) }
        }

        Helper::JiraIssuesReleaseNotesHelper.generate_changelog(
          groups: grouped_issues, 
          line_break_format: @format_line_break
        )
      end

      def self.description
        "It generates a release note based on the issues keys and descriptions found in the commits"
      end

      def self.authors
        ["Erick Martins"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "It generates a release note based on the issues keys and descriptions found in the commits"
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
          FastlaneCore::ConfigItem.new(
            key: :validated_status,
            env_name: 'FL_JIRA_VALIDATED_STATUS',
            description:  'List of jira issues status already validated',
            optional: false,
            type: Array
          ),
          FastlaneCore::ConfigItem.new(
            key: :to_validate_status,
            env_name: 'FL_JIRA_TO_VALIDATE_STATUS',
            description:  'List of jira issues status to be validated',
            optional: false,
            type: Array
          ),
          FastlaneCore::ConfigItem.new(
            key: :format,
            description: "You can use either markdown, slack, html or plain",
            default_value: "markdown",
            optional: true,
            verify_block: proc do |value|
              UI.user_error!("Invalid format! You can use either markdown, slack, html or plain") unless ['markdown', 'html', 'slack', 'plain'].include?(value)
            end
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
            description:  'Jira user password',
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
