require 'fastlane/action'
require_relative '../helper/jira_issues_release_notes_helper'

module Fastlane
  module Actions
    class BranchJiraIssuesReleaseNotesAction < Action
      def self.run(params)
        branch = other_action.git_branch
        regex = Regexp.new("(#{params[:ticket_prefix]}-\\d+)")

        @format = params[:format]
        @extra_fields = params[:extra_fields]

        ticket_code = regex.match branch

        return ticket_not_found unless ticket_code

        UI.message "Found ticket code: #{ticket_code}"
        

        @jira_helper = Helper::JiraIssuesReleaseNotesHelper.jira_helper(
          host: params[:host],
          username: params[:username],
          password: params[:password],
          context_path: params[:context_path],
          disable_ssl_verification: params[:disable_ssl_verification]
        )

        issue = @jira_helper.get(issues: [ticket_code], extra_fields: @extra_fields.values).first

        return ticket_not_found ticket_code unless issue

        generate_message_with(issue: issue)

      #   tickets = tickets(commits: commits, regex: regex)
      #   UI.important("Jira tickets: #{tickets}")

      #   @jira_helper = Helper::JiraIssuesReleaseNotesHelper.jira_helper(
      #     host: params[:host],
      #     username: params[:username],
      #     password: params[:password],
      #     context_path: params[:context_path],
      #     disable_ssl_verification: params[:disable_ssl_verification]
      #   )
      #   issues = @jira_helper.get(issues: tickets)

      #   to_validate = issues.select { |issue| params[:to_validate_status].include?(issue.status.name) }
      #   validated = issues.select { |issue| params[:validated_status].include?(issue.status.name) }

      #   generate_changelog(to_validate: to_validate, validated: validated, format: params[:format], url: params[:build_url])
      # end

      # def self.generate_changelog(to_validate:, validated:, format:, url:)
      #   changelog = []
      #   changelog.concat(format_issues(label: 'Tasks to validate', issues: to_validate, format: format)) unless to_validate.empty?
      #   changelog.concat(['']) unless changelog.to_s.empty?
      #   changelog.concat(format_issues(label: 'Validated tasks', issues: validated, format: format)) unless validated.empty?
      #   # changes = format_issues(issues: issues)
      #   changelog = ['No changes included.'] if changelog.to_s.empty?

      #   changelog.join("\n")
      end

      def self.ticket_not_found(ticket_code = "")

        UI.important "No ticket code could be extracted from git branch name."
        UI.message "Trying to use latest git commit"
        last_commit = other_action.last_git_commit
        return UI.error "There is no commit" unless last_commit
        header_text = ticket_code ? "😅 Jira issue with key '#{ticket_code}' could not be found" : "😅 Jira issue could not be detected"

        return [
          style_text(text: header_text, style: 'heading'),
          style_text(text: "► Latest Commit:", style: 'bold'),
          last_commit[:message]
        ].join("\n")
      end

      def self.style_text(text:, style:)
        # formats the text according to the style we're looking to use

        # Skips all styling
        case style
        when "title"
          case @format
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

      def self.generate_message_with(issue:)
        link = @jira_helper.url(issue: issue)
        issue_type = issue.issuetype ? issue.issuetype.name : ''
        status = issue.status.name
        issue.attrs["fields"][:customfield_10040.to_s]
        case @format
        when "slack"
          extra = @extra_fields.map { |key, value| ["", "*► #{key.to_s}*", issue.attrs["fields"][value.to_s]] }
          [
            "*► #{issue_type}: <#{link}|#{issue.summary}>* (#{status})", 
            issue.description,
            extra.flatten!
          ]
          .flatten!
          .join("\n")
        when "markdown"
          extra = @extra_fields.map { |key, value| ["", "**► #{key.to_s}**", issue.attrs["fields"][value.to_s]] }
          [
            "**► #{issue_type}: [#{issue.summary}](#{link})** (#{status})", 
            issue.description, 
            extra.flatten!
          ]
          .flatten!
          .join("\n")
        else
          extra = @extra_fields.map { |key, value| ["", "► #{key.to_s}", issue.attrs["fields"][value.to_s]] }
          [
            "► #{issue_type}: #{issue.summary}(#{status}) #{link}", 
            issue.description, 
            extra.flatten!
          ]
          .flatten!
          .join("\n")
        end
      end

      def self.description
        "It generates a release note based on the issues keys found in branch name and descriptions found in the commits"
      end

      def self.authors
        ["Erick Martins"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "It generates a release note based on the issues keys found in branch name and descriptions found in the commits"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :ticket_prefix,
            env_name: 'FL_FIND_TICKETS_MATCHING',
            description:  'regex to extract ticket numbers',
            default_value: '[A-Z]+',
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_url,
            env_name: 'FL_RELEASE_NOTES_BUILD_URL',
            description:  'Link to the ci build',
            optional: true,
            default_value: ENV['BUILD_URL']
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
          FastlaneCore::ConfigItem.new(
            key: :extra_fields,
            description: "Extra jira fields",
            type: Hash,
            optional: true,
            default_value: {},
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
