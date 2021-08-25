require 'fastlane/action'
require_relative '../helper/jira_issues_release_notes_helper'

module Fastlane
  module Actions
    class JiraIssuesReleaseNotesAction < Action
      def self.get_last_tag(params)
        # Try to find the tag
        command = "git describe --tags --match=#{params[:match]}"
        Actions.sh(command, log: params[:debug])
      rescue StandardError
        UI.message("Tag was not found for match pattern - #{params[:match]}")
        ''
      end

      def self.get_last_tag_hash(params)
        command = "git rev-list -n 1 refs/tags/#{params[:tag_name]}"
        Actions.sh(command, log: params[:debug]).chomp
      end

      def self.get_commits_from_hash(params)
        Helper::JiraIssuesReleaseNotesHelper.git_log(
          pretty: '%s|%b|>',
          start: params[:hash],
          debug: params[:debug]
        )
      end

      def self.run(params)
        tag = get_last_tag(
          match: params[:tag_prefix],
          debug: params[:debug]
        )

        if tag.empty?
          UI.message("First commit of the branch is taken as a begining of next release")
          # If there is no tag found we taking the first commit of current branch
          hash = Actions.sh('git rev-list --max-parents=0 HEAD', log: params[:debug]).chomp
        else
          # Tag's format is v2.3.4-5-g7685948
          # Get a hash of last version tag
          tag_name = tag.split('-')[0...-2].join('-').strip
          parsed_version = tag_name.match(params[:tag_version_match])

          if parsed_version.nil?
            UI.user_error!("Error while parsing version from tag #{tag_name} by using tag_version_match - #{params[:tag_version_match]}. Please check if the tag contains version as you expect and if you are using single brackets for tag_version_match parameter.")
          end

          version = parsed_version[0]

          # Get a hash of last version tag
          hash = get_last_tag_hash(
            tag_name: tag_name,
            debug: params[:debug]
          )

          UI.message("Found a tag #{tag_name} associated with version #{version}")
        end

        # Get commits log between last version and head
        commits = get_commits_from_hash(
          hash: hash,
          debug: params[:debug]
        )

        regex = Regexp.new("(#{params[:ticket_prefix]}-\\d+)")

        tickets = tickets(commits: commits, regex: regex)
        UI.important("Jira tickets: #{tickets}")

        @jira_helper = Helper::JiraIssuesReleaseNotesHelper.jira_helper(
          host: params[:host],
          username: params[:username],
          password: params[:password],
          context_path: params[:context_path],
          disable_ssl_verification: params[:disable_ssl_verification]
        )
        issues = @jira_helper.get(issues: tickets)

        to_validate = issues.select { |issue| params[:to_validate_status].include?(issue.status.name) }
        validated = issues.select { |issue| params[:validated_status].include?(issue.status.name) }

        generate_changelog(to_validate: to_validate, validated: validated, format: params[:format])
      end

      def self.generate_changelog(to_validate:, validated:, format:)
        changelog = []
        changelog.concat(format_issues(label: 'Tasks to validate', issues: to_validate, format: format)) unless to_validate.empty?
        changelog.concat(['']) unless changelog.to_s.empty?
        changelog.concat(format_issues(label: 'Validated tasks', issues: validated, format: format)) unless validated.empty?
        # changes = format_issues(issues: issues)
        changelog = ['No changes included.'] if changelog.to_s.empty?

        changelog.join("\n")
      end

      def self.style_text(text:, format:, style:)
        # formats the text according to the style we're looking to use

        # Skips all styling
        case style
        when "title"
          case format
          when "markdown"
            "# #{text}"
          when "slack"
            "*#{text}*"
          else
            text
          end
        when "heading"
          case format
          when "markdown"
            "### #{text}"
          when "slack"
            "*#{text}*"
          else
            "#{text}:"
          end
        when "bold"
          case format
          when "markdown"
            "**#{text}**"
          when "slack"
            "*#{text}*"
          else
            text
          end
        else
          text # catchall, shouldn't be needed
        end
      end

      def self.format_issue_link(issue:, format:)
        # formats the link according to the output format we need

        case format
        when "slack"
          "*<#{@jira_helper.url(issue: issue)}|#{issue.key}>*: #{issue.summary}"
        when "markdown"
          "- **[#{issue.key}](#{@jira_helper.url(issue: issue)})**: #{issue.summary}"
        else
          "- #{issue.key}: #{issue.summary} (#{@jira_helper.url(issue: issue)})"
        end
      end

      def self.format_issues(label:, issues:, format:)
        [
          style_text(text: "► #{label}", style: 'heading', format: format),
          issues.map { |issue| format_issue_link(issue: issue, format: format) }
        ].flatten!
      end

      def self.tickets(commits:, regex:)
        commits
          .to_enum(:scan, regex)
          .map { $& }
          .reject(&:empty?)
          .uniq
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
            description: "You can use either markdown, slack or plain",
            default_value: "markdown",
            optional: true,
            verify_block: proc do |value|
              UI.user_error!("Invalid format! You can use either markdown, slack or plain") unless ['markdown', 'slack', 'plain'].include?(value)
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
