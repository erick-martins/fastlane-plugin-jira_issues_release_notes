describe Fastlane::Actions::JiraIssuesReleaseNotesAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The jira_issues_release_notes plugin is working!")

      Fastlane::Actions::JiraIssuesReleaseNotesAction.run(nil)
    end
  end
end
