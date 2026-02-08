Create a Pull Request for a Marshroom cart issue matching the current branch.

Steps:
1. Read `~/.config/marshroom/state.json` and parse the JSON
2. Run `git branch --show-current` to get the current branch name
3. Find the cart entry whose `branchName` matches the current git branch. If no match, tell the user they're not on a cart issue branch
4. Push the current branch: `git push -u origin HEAD`
5. Create the PR using `gh pr create`:
   - Title: the issue title from the matched cart entry
   - Body MUST include `Closes #<issueNumber>` (this is mandatory for auto-closing the issue)
   - Add any relevant description of the changes made
6. After PR creation, verify the body contains the closing keyword:
   - Run `gh pr view --json body -q '.body'`
   - If `Closes #<issueNumber>` is NOT found in the body, fix it: `gh pr edit --body "$(gh pr view --json body -q '.body')\n\nCloses #<issueNumber>"`
7. Display the PR URL to the user
