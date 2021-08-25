# Jira Issues Release Notes - Fastlane Plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-jira_issues_release_notes)



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



### branch_jira_issues_release_notes

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

    release_notes = branch_jira_issues_release_notes(
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
          "Donwload it here" => link_to_download
      },
      success: true
    )
	end
end
```



### jira_issues_release_notes

This action creates a changelog based on the issue keys extracted from your commits since the latest published tag. 

It should be used to generate version to validate in QA stage. 

**Usage example:**

```ruby
platform :android do 
	lane :develop do 
    # Build a apk for staging environment
    build_staging
    link_to_download = upload_to_s3	

		release_notes = jira_issues_release_notes(
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
          "Donwload it here" => link_to_download
      },
      success: true
    )
  end
end
```

**Arguments:**

| Argument           | Type                                    | Description                                    | Optional | Default           | Env Name                   |
| ------------------ | --------------------------------------- | ---------------------------------------------- | -------- | ----------------- | -------------------------- |
| tag_prefix         | `Regex`                                 | Match prefix to find latest tag. Example: `v*` |          |                   |                            |
| ticket_prefix      | `String` or `Regex`                     | The prefix for yours jira issues               | ✓        | `[A_Z]+`          | `FL_FIND_TICKETS_MATCHING` |
| tag_version_match  | `String`                                | To parse version number from tag name          | ✓        | `/\d+\.\d+\.\d+/` |                            |
| validated_status   | `Array`                                 | List of jira issues status already validated   |          |                   | FL_JIRA_VALIDATED_STATUS   |
| to_validate_status | `Array`                                 | List of jira issues status to be validated     |          |                   | FL_JIRA_TO_VALIDATE_STATUS |
| format             | `slack`, `markdown` , `html` or `plain` | Defines the result format                      | ✓        | `markdown`        |                            |



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
