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

    class JiraVersionsAction < Action
      def self.run(params)
        @jira_helper = Helper::JiraIssuesReleaseNotesHelper.initialize_jira(
          host: params[:host],
          api_version: params[:api_version],
          username: params[:username],
          password: params[:password],
          context_path: params[:context_path],
          disable_ssl_verification: params[:disable_ssl_verification]
        )

        versions = @jira_helper.list_versions(
          project_id_or_key: params[:project_id],
          query: params[:query],
          order_by: params[:order_by],
          status: params[:status]
        )

        versions.map { |version|
          {
            :id => version.self,
            :name => version.name,
            :archived => version.archived,
            :released => version.released,
            :user_release_date => defined? version.userReleaseDate ? version.userReleaseDate : nil,
            :overdue => defined? version.overdue ? version.overdue : false,
            :projectId => version.projectId,
          }
        }
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
            key: :project_id,
            env_name: 'FL_JIRA_PROJECT_ID',
            description: 'The project ID or project key',
            optional: false,
          ),
          FastlaneCore::ConfigItem.new(
            key: :query,
            description: 'Filter the results using a literal string. Versions with matching name or description are returned (case insensitive).',
            optional: true,
          ),
          FastlaneCore::ConfigItem.new(
            key: :order_by,
            description: 'Order the results by a field. Valid values: description, -description, +description, name, -name, +name, releaseDate, -releaseDate, +releaseDate, sequence, -sequence, +sequence, startDate, -startDate, +startDate',
            optional: true,
            verify_block: proc do |value|
              valid_order = ["description", "-description", "+description", "name", "-name", "+name", "releaseDate", "-releaseDate", "+releaseDate", "sequence", "-sequence", "+sequence", "startDate", "-startDate", "+startDate"]
              UI.user_error!("Invalid :order_by value! Valid values: #{valid_order.join(", ")}") unless valid_order.include?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :status,
            description: 'A list of status values used to filter the results by version status. This parameter accepts a comma-separated list. The status values are released, unreleased, and archived',
            optional: true,
            verify_block: proc do |value|
              valid_values = ["released", "unreleased", "archived"]
              UI.user_error!("Invalid :status value! Valid values: #{valid_values.join(", ")}") unless valid_values.include?(value)
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
