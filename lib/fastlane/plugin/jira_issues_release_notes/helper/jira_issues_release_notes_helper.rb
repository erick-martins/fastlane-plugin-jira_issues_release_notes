require 'fastlane_core/ui/ui'
require 'zk-jira-ruby'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class JiraIssuesReleaseNotesHelper

      def self.format_issue_link(issue:)
        # formats the link according to the output format we need
        link = @jira_helper.url(issue: issue)
        case @format
        when "slack"
          "*<#{link}|#{issue.key}>*: #{issue.summary}"
        when "markdown"
          "- **[#{issue.key}](#{link})**: #{issue.summary}"
        when "html"
          "&nbsp;&nbsp;- <strong><a href=\"#{link}\" target=\"_blank\">#{issue.key}</a><strong>: #{issue.summary}"
        else
          "- #{issue.key}: #{issue.summary} (#{link})"
        end
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
          when "html"
            "<h1>#{text}</h1>"
          else
            text
          end
        when "heading"
          case @format
          when "markdown"
            "### #{text}"
          when "slack"
            "*#{text}*"
          when "html"
            "<h3>#{text}</h3>"
          else
            "#{text}:"
          end
        when "bold"
          case @format
          when "markdown"
            "**#{text}**"
          when "slack"
            "*#{text}*"
          when "html"
            "<strong>#{text}</strong>"
          else
            text
          end
        else
          text # catchall, shouldn't be needed
        end
      end

      def self.get_commit_after_latest_tag(tag_regex:, tag_version_match:, debug:)
        unless Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_COMMITS_FROM_HASH] then
          
          # Try to find the tag
          command = "git describe --tags --match=#{tag_regex}"
          tag = Actions.sh(command, log: debug)

          if tag.empty?
            UI.message("First commit of the branch is taken as a begining of next release")
            # If there is no tag found we taking the first commit of current branch
            hash = Actions.sh('git rev-list --max-parents=0 HEAD', log: debug).chomp
          else
            # Tag's format is v2.3.4-5-g7685948
            # Get a hash of last version tag
            tag_name = tag.split('-')[0...-2].join('-').strip
            parsed_version = tag_name.match(tag_version_match)

            if parsed_version.nil?
              UI.user_error!("Error while parsing version from tag #{tag_name} by using tag_version_match - #{tag_version_match}. Please check if the tag contains version as you expect and if you are using single brackets for tag_version_match parameter.")
            end

            version = parsed_version[0]

            # Get a hash of last version tag
            command = "git rev-list -n 1 refs/tags/#{tag_name}"
            hash = Actions.sh(command, log: debug).chomp

            UI.message("Found a tag #{tag_name} associated with version #{version}")
          end

          # Get commits log between last version and head
          commits = git_log(
            pretty: '%s|%b|>',
            start: hash,
            debug: debug
          )

          Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_LAST_TAG] = tag
          Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_LAST_TAG_HASH] = hash
          Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_COMMITS_FROM_HASH] = commits
        end

        Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_COMMITS_FROM_HASH]
      rescue StandardError => error
        UI.error error.message
        UI.message("Tag was not found for match pattern - #{tag_regex}")
        nil
      end

      def self.get_key_from_commit_after_latest_tag(tag_regex:, tag_version_match:, issue_key_regex:, debug:)
        unless Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_LAST_KEYS_FROM_COMMITS] then
          commits = get_commit_after_latest_tag(
            tag_regex: tag_regex, 
            tag_version_match: tag_version_match, 
            debug: debug,
          )

          return nil unless commits

          last_keys_from_commits = commits
            .to_enum(:scan, issue_key_regex)
            .map { $& }
            .reject(&:empty?)
            .uniq

          Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_LAST_KEYS_FROM_COMMITS] = last_keys_from_commits
        end

        Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_LAST_KEYS_FROM_COMMITS]
      end
      
      def self.get_issues_from_commit_after_latest_tag(tag_regex:, tag_version_match:, issue_key_regex:, debug:)
        unless Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_LAST_ISSUES_FROM_COMMITS] then
          unless @jira_helper then
            UI.user_error! "Uninitialized jira client"
          end

          keys = get_key_from_commit_after_latest_tag(
            tag_regex: tag_regex, 
            tag_version_match: tag_version_match, 
            issue_key_regex: issue_key_regex, 
            debug: debug
          )

          issues = @jira_helper.get(keys: keys)
          Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_LAST_ISSUES_FROM_COMMITS] = issues
        end

        Actions.lane_context[Fastlane::Actions::SharedValues::FL_JIRA_LAST_ISSUES_FROM_COMMITS]
      end
      
      def self.git_log(params)
        command = "git log --pretty='#{params[:pretty]}' --reverse #{params[:start]}..HEAD"
        Actions.sh(command, log: params[:debug]).chomp
      end

      def self.generate_changelog(groups:, line_break_format:)
        changelog = []

        groups.each do |label, issues|
          changelog.concat(['']) unless changelog.to_s.empty?
          changelog.concat(format_issues(label: label, issues: issues)) unless issues.empty?
        end
        # changes = format_issues(issues: issues)

        changelog.join(line_break_format)
      end

      def self.format_issues(label:, issues:)
        [
          style_text(text: "► #{label}", style: 'heading'),
          issues.map { |issue| format_issue_link(issue: issue) }
        ].flatten!
      end

      def self.extract_key_from_branch(branch:, ticket_prefix:)
        regex = Regexp.new("(#{ticket_prefix}-\\d+)")
        
        ticket_code = regex.match branch

        ticket_code
      end


      def self.initialize_jira(host:, api_version:, username:, password:, context_path:, disable_ssl_verification:)
        unless @jira_helper then
          @jira_helper = jira_helper(
            host: host,
            api_version: api_version,
            username: username,
            password: password,
            context_path: context_path,
            disable_ssl_verification: disable_ssl_verification
          ) 
        end

        @jira_helper
      end

      def self.jira_helper(host:, api_version:, username:, password:, context_path:, disable_ssl_verification:)
        JiraHelper.new(
          host: host,
          api_version: api_version,
          username: username,
          password: password,
          context_path: context_path,
          disable_ssl_verification: disable_ssl_verification
        )
      end

      class JiraClientHelper
        def self.client(host:, api_version:, username:, password:, context_path:, disable_ssl_verification:)
          options = {
           site: host,
           context_path: context_path,
           auth_type: :basic,
           username: username,
           password: password,
           rest_base_path: "/rest/api/#{api_version}",
           ssl_verify_mode: disable_ssl_verification ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
          }

          JIRA::Client.new(options)
        end
      end

      class JiraHelper
        def initialize(host:, api_version:, username:, password:, context_path:, disable_ssl_verification:, jira_client_helper: nil)
          @host = host
          @context_path = context_path

          @client ||= JiraClientHelper.client(
            host: host,
            api_version: api_version,
            username: username,
            password: password,
            context_path: context_path,
            disable_ssl_verification: disable_ssl_verification
          )
        end

        def get(keys:, extra_fields: [])
          return [] if keys.to_a.empty?

          fields = [:key, :summary, :status, :issuetype, :description]
          fields.concat extra_fields

          begin
            @client.Issue.jql("KEY IN (#{keys.join(',')})", fields: fields, validate_query: false)
          rescue StandardError => e
            UI.important('Jira Client: Failed to get issue.')
            UI.important("Jira Client: Reason - #{e.message}")
            []
          end
        end

        def list_versions(project_id_or_key:, query: nil, order_by: nil, status: nil)
          @client.Version.find(
            project_id_or_key: project_id_or_key,
            query: query, 
            orderBy: order_by, 
            status: status
          )
        end
      

        def add_comment(comment:, issues:)
          return if issues.to_a.empty?

          issues.each do |issue|
            issue.comments.build.save({ 'body' => comment })
          rescue StandardError => e
            UI.important("Jira Client: Failed to comment on issues - #{issue.key}")
            UI.important("Jira Client: Reason - #{e.message}")
          end
        end

        def url(issue:)
          [@host, @context_path, 'browse', issue.key].reject(&:empty?).join('/')
        end
      end
    end
  end
end
