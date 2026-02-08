Create a Pull Request for a Marshroom cart issue matching the current branch.

Steps:
1. Read `~/.config/marshroom/state.json` and parse the JSON
2. Run `git branch --show-current` to get the current branch name
3. Find the cart entry whose `branchName` matches the current git branch and current git repository. If no match, tell the user they're not on a cart issue branch
3-1. Commit the current changes. Give proper commit message to commits. Ask user permission if the changes are too large or suspicious (e.g. 100+ changes, dummy files, DB updates, logs, and so on)
4. Push the current branch: `git push -u origin HEAD`
5. Build the PR body:
   - Start with a brief description of the changes made
   - If the matched cart entry has an `issueBody` field (non-null), include it under a "## Original Issue" section for reviewer context
   - The body MUST include `close #<issueNumber>` (this is mandatory for auto-closing the issue)
6. Create the PR using `gh pr create`:
   - Title: the issue title from the matched cart entry
   - Body: the constructed body from step 5
7. After PR creation, verify the body contains the closing keyword:
   - Run `gh pr view --json body -q '.body'`
   - If `close #<issueNumber>` is NOT found in the body, fix it: `gh pr edit --body "$(gh pr view --json body -q '.body')\n\nclose #<issueNumber>"`
8. Capture the PR URL and number:
   - Run `gh pr view --json number,url -q '.number,.url'`
9. Update issue status: run `marsh pr` (if `marsh` is available in PATH). If `marsh` is not found, notify to user to install `marsh` command correctly.
10. Display the result:
    - PR URL
    - PR Number
    - Issue: #{issueNumber} {issueTitle}
    - Status: pending
