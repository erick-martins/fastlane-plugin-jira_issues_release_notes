lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/jira_issues_release_notes/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-jira_issues_release_notes'
  spec.version       = Fastlane::JiraIssuesReleaseNotes::VERSION
  spec.author        = 'Erick Martins'
  spec.email         = 'ericknmp@gmail.com'

  spec.summary       = 'It generates a release note based on the issues keys and descriptions found in the commits'
  spec.homepage      = "https://github.com/erick-martins/fastlane-plugin-jira_issues_release_notes"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.5'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  # spec.add_dependency 'your-dependency', '~> 1.0.0'
  spec.add_runtime_dependency('zk-jira-ruby', '~> 2.1')

  spec.add_development_dependency('bundler')
  spec.add_development_dependency('fastlane', '>= 2.99.0')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rubocop', '0.49.1')
  spec.add_development_dependency('rubocop-require_tools')
  spec.add_development_dependency('simplecov')
end
