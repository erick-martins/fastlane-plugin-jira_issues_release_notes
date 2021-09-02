# Jira Issues Release Notes - Fastlane Plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-jira_issues_release_notes)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/erick-martins/fastlane-plugin-jira_issues_release_notes/blob/master/LICENSE)
[![Gem Version](https://badge.fury.io/rb/fastlane-plugin-jira_issues_release_notes.svg)](https://badge.fury.io/rb/fastlane-plugin-jira_issues_release_notes)



It generates a release note based on the issues keys and descriptions found in the commits and branch name



## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-jira_issues_release_notes`, add it to your project by running:

```bash
fastlane add_plugin jira_issues_release_notes
```



## Actions

All actions requires some parameters to access Jira API. 
**These are the arguments the all share:**

| Argument                 | Type      | Description                      | Optional | Default | Env Name                           |
| ------------------------ | --------- | -------------------------------- | -------- | ------- | ---------------------------------- |
| username                 | `String`  | The prefix for yours jira issues |          |         | `FL_JIRA_USERNAME`                 |
| password                 | `String`  | Jira user password               |          |         | `FL_JIRA_PASSWORD`                 |
| host                     | `String`  | Jira location                    |          |         | `FL_JIRA_HOST`                     |
| context_path             | `String`  | Jira context path                | ✓        | Empty   | `FL_JIRA_CONTEXT_PATH`             |
| disable_ssl_verification | `Boolean` | Jira SSL Verification mode       | ✓        | `false` | `FL_JIRA_DISABLE_SSL_VERIFICATION` |
| api_version              | `String`  | Jira api version                 | ✓        | 2       | `FL_JIRA_API_VERSION`              |



### jira_issues_keys_from_commits

This action returns the list of jira issue keys extracted from your commits since the latest published tag.  

**Arguments:**

| Argument          | Type                | Description                                    | Optional | Default           | Env Name                   |
| ----------------- | ------------------- | ---------------------------------------------- | -------- | ----------------- | -------------------------- |
| tag_prefix        | `Regex`             | Match prefix to find latest tag. Example: `v*` |          |                   |                            |
| ticket_prefix     | `String` or `Regex` | The prefix for yours jira issues               | ✓        | `[A_Z]+`          | `FL_FIND_TICKETS_MATCHING` |
| tag_version_match | `String`            | To parse version number from tag name          | ✓        | `/\d+\.\d+\.\d+/` |                            |

**Usage example:**

```ruby
platform :android do 
  lane :develop do 
    keys = jira_issues_keys_from_commits(
      tag_prefix: 'v*',
      ticket_prefix: 'ABC',
      username: ENV["FL_JIRA_USERNAME"],
      password: ENV["FL_JIRA_PASSWORD"],
      host: ENV["FL_JIRA_HOST"],
    )
    
    puts keys
	end
end
```



### jira_feature_validation

This action creates a release note based on the issue key extracted from your branch name. For example a branch called `feature/ABC-1234-some-feature` will extract the `ABC-1234` issue key. 

It should be used to generate version to validate you branch's feature before you merge it. 

**Arguments:**

| Argument      | Type                                    | Description                                                  | Optional | Default              | Env Name                   |
| ------------- | --------------------------------------- | ------------------------------------------------------------ | -------- | -------------------- | -------------------------- |
| ticket_prefix | `String` or `Regex`                     | The prefix for yours jira issues                             | ✓        | `[A_Z]+`             | `FL_FIND_TICKETS_MATCHING` |
| extra_fields  | `Hash`                                  | A hash of extra Jira fields to display.<br />It should be a hash with key as the label for the key and value as the symbol representing the jira's key:<br />Example: `{ "My Custom Field" => :customfield_1 }` | ✓        | Empty Hash<br />`{}` |                            |
| format        | `slack`, `markdown` , `html` or `plain` | Defines the result format                                    | ✓        | `markdown`           |                            |

**Usage example:**

```ruby
# Branch: feature/ABC-1234-some-feature

platform :android do 
  lane :develop do 
    # Build a apk for development environment
    build_develop
    link_to_download = upload_to_s3	

    release_notes = jira_feature_validation(
      ticket_prefix: 'ABC',
      username: ENV["FL_JIRA_USERNAME"],
      password: ENV["FL_JIRA_PASSWORD"],
      host: ENV["FL_JIRA_HOST"],
      format: 'slack',
      extra_fields: {
        "What should we test?" => :customfield_1
      }
    )

    slack(
      pretext: ":android: A new android build is available for feature validation\n#{release_notes}", 
      payload: {
          "Download it here" => link_to_download
      },
      success: true
    )
	end
end
```



### jira_release_validation

This action creates a changelog based on the issue keys extracted from your commits since the latest published tag. 

It should be used to generate version to validate in QA stage. 

**Usage example:**

```ruby
platform :android do 
  lane :staging_validation do 
    # Build a apk for staging environment
    build_staging
    link_to_download = upload_to_s3	

		release_notes = jira_release_validation(
      tag_prefix: 'v*',
      ticket_prefix: 'ABC',
      username: ENV["FL_JIRA_USERNAME"],
      password: ENV["FL_JIRA_PASSWORD"],
      host: ENV["FL_JIRA_HOST"],
      validated_status: ['To Deploy', 'Done'],
      to_validate_status: ['To Test', 'To QA'],
      format: 'slack',
    )

    slack(
      pretext: ":android: A new android build is available for QA\n#{release_notes}", 
      payload: {
          "Download it here" => link_to_download
      },
      success: true
    )
  end
end
```

**Arguments:**

| Argument           | Type                                    | Description                                    | Optional | Default           | Env Name                     |
| ------------------ | --------------------------------------- | ---------------------------------------------- | -------- | ----------------- | ---------------------------- |
| tag_prefix         | `Regex`                                 | Match prefix to find latest tag. Example: `v*` |          |                   |                              |
| ticket_prefix      | `String` or `Regex`                     | The prefix for yours jira issues               | ✓        | `[A_Z]+`          | `FL_FIND_TICKETS_MATCHING`   |
| tag_version_match  | `String`                                | To parse version number from tag name          | ✓        | `/\d+\.\d+\.\d+/` |                              |
| validated_status   | `Array`                                 | List of jira issues status already validated   |          |                   | `FL_JIRA_VALIDATED_STATUS`   |
| to_validate_status | `Array`                                 | List of jira issues status to be validated     |          |                   | `FL_JIRA_TO_VALIDATE_STATUS` |
| format             | `slack`, `markdown` , `html` or `plain` | Defines the result format                      | ✓        | `markdown`        |                              |



### jira_release_changelog

This action creates a changelog based on the issue keys extracted from your commits since the latest published tag. 

It should be used to generate from a release version. 

**Usage example:**

```ruby
platform :android do 
  lane :release do 
    # Build and release a new version
    build_production
    release_production
		
    # Hash with grouped types with names by issue type. Use de key work "ANY_TYPE" as fallback.
		# The ordenation will reflect to the final result.
    grouped_by_types = { 
      "Added/Changed" => ["ANY_TYPE"],
      "Fixed" => ["Bug"]
    }	

		release_notes = jira_release_changelog(
      tag_prefix: 'v*',
      ticket_prefix: 'ABC',
      username: ENV["FL_JIRA_USERNAME"],
      password: ENV["FL_JIRA_PASSWORD"],
      host: ENV["FL_JIRA_HOST"],
      grouped_by_types: grouped_by_types,
      format: 'slack',
    )

    slack(
      pretext: ":android: A new android version was released\n#{release_notes}", 
      success: true
    )
  end
end
```

**Arguments:**

| Argument          | Type                                    | Description                                                  | Optional | Default           | Env Name                       |
| ----------------- | --------------------------------------- | ------------------------------------------------------------ | -------- | ----------------- | ------------------------------ |
| tag_prefix        | `Regex`                                 | Match prefix to find latest tag. Example: `v*`               |          |                   |                                |
| ticket_prefix     | `String` or `Regex`                     | The prefix for yours jira issues                             | ✓        | `[A_Z]+`          | `FL_FIND_TICKETS_MATCHING`     |
| tag_version_match | `String`                                | To parse version number from tag name                        | ✓        | `/\d+\.\d+\.\d+/` |                                |
| grouped_by_types  | `Hash`                                  | Hash with grouped types with names by issue type. Use de key work "ANY_TYPE" as fallback. |          |                   | `FL_JIRA_RELESE_GROUPED_TYPES` |
| format            | `slack`, `markdown` , `html` or `plain` | Defines the result format                                    | ✓        | `markdown`        |                                |



### jira_comment

This action adds comment to the issue keys extracted from your commits since the latest published tag or the issue extract from the name of the branch.

**Usage example:**

```ruby
def generate_comment_block(version: url:)
  {
      "type" => "doc",
      "version" => 1,
      "content" => [
        {
          "type" => "paragraph",
          "content" => [
            {
              "type" => "text",
              "text" => "A new Android build is available. (#{version})\n",
              "marks" => [
                {
                  "type" => "strong"
                }
              ]
            },
            {
              "type" => "text",
              "text" => "Download it here",
              "marks" => [
                {
                  "type" => "link",
                  "attrs" => {
                    "href" => "#{url}",
                    "title" => "Download it here"
                  }
                }
              ]
            }
          ]
        }
      ]
    }
end

platform :android do 
  lane :develop do 
    # Build a apk for development environment
    build_develop
    link_to_download = upload_to_s3	
    
    # Comment on issues
    comment_block = generate_comment_block(
      version: "v2.5.0",
      url: "https://some-link-to-download.com"
    )
    
    jira_comment(
      username: ENV["FL_JIRA_USERNAME"],
      password: ENV["FL_JIRA_PASSWORD"],
      host: ENV["FL_JIRA_HOST"],
      ticket_prefix: 'ABC',
      tag_prefix: "v*",
      comment_block: comment_block
    )
  end
  
  lane :staging_validation do 
    # Build a apk for staging environment
    # Build a apk for staging environment
    build_staging
    link_to_download = upload_to_s3	
    
    # Comment on issues
    comment_block = generate_comment_block(
      version: "v2.5.0",
      url: "https://some-link-to-download.com"
    )
    
    jira_comment(
      username: ENV["FL_JIRA_USERNAME"],
      password: ENV["FL_JIRA_PASSWORD"],
      host: ENV["FL_JIRA_HOST"],
      ticket_prefix: 'ABC',
      extract_from_branch: true,
      comment_block: comment_block
    )
  end
  
  lane :release do 
    # Build a apk for staging environment
    build_production
    release_production
    
    jira_comment(
      username: ENV["FL_JIRA_USERNAME"],
      password: ENV["FL_JIRA_PASSWORD"],
      host: ENV["FL_JIRA_HOST"],
      ticket_prefix: 'ABC',
      extract_from_branch: true,
      comment: "Resolved on version #{version} published #{now_date}"
    )
  end
end
```

**Arguments:**

| Argument            | Type                | Description                                                  | Optional                                                     | Default           | Env Name                   |
| ------------------- | ------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ----------------- | -------------------------- |
| tag_prefix          | `Regex`             | Match prefix to find latest tag. Example: `v*`               | ✓<br />Conflicts with `:extract_from_branch`<br /><br />If you set to extract keys from the branch, it should not be set |                   |                            |
| ticket_prefix       | `String` or `Regex` | The prefix for yours jira issues                             | ✓                                                            | `[A_Z]+`          | `FL_FIND_TICKETS_MATCHING` |
| tag_version_match   | `String`            | To parse version number from tag name                        | ✓                                                            | `/\d+\.\d+\.\d+/` |                            |
| extract_from_branch | `Boolean`           | If true it will search for jira issue key in the current branch name. In this case do NOT set `:tag_prefix` | ✓<br />Conflicts with `:tag_prefix`<br /><br />If you set `:tag_prefix`, it should not be set or set to `false` | `false`           |                            |
| comment             | `String`            | Comment to add to the ticket                                 | ✓<br />Conflicts with `:comment_block`<br /><br />If you set `:comment_block`, it should not be set. |                   |                            |
| comment_block       | `Hash`              | Comment block to add to the ticket                           | ✓<br />Conflicts with `:comment`<br /><br />If you set `:comment`, it should not be set. |                   |                            |



### jira_versions

This action searches jira versions and returns the list

**Arguments:**

| Argument   | Type     | Description                                                  | Optional | Env Name             |
| ---------- | -------- | ------------------------------------------------------------ | -------- | -------------------- |
| project_id | `String` | The project ID or project key                                |          | `FL_JIRA_PROJECT_ID` |
| query      | `String` | Filter the results using a literal string. Versions with matching `name` or `description` are returned (case insensitive). | ✓        |                      |
| order_by   | `String` | Order the results by a field.<br />Valid values: `description`, `-description`, `+description`, `name`, `-name`, `+name`, `releaseDate`, `-releaseDate`, `+releaseDate`, `sequence`, `-sequence`, `+sequence`, `startDate`, `-startDate`, `+startDate` | ✓        |                      |
| status     | `String` | A list of status values used to filter the results by version status. This parameter accepts a comma-separated list. The status values are `released`, `unreleased`, and `archived`. | ✓        |                      |

**Usage example:**

```ruby
platform :android do 
  lane :release do 
    versions = jira_versions(
      project_id: 'ABC',
      query: 'app_v2.5.0',
      status: 'released,archived',
      username: ENV["FL_JIRA_USERNAME"],
      password: ENV["FL_JIRA_PASSWORD"],
      host: ENV["FL_JIRA_HOST"],
    )
    
    puts versions
	end
end
```



## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```



## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.



## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.



## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).



## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
