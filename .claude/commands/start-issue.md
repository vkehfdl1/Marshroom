Start working on a Marshroom cart issue in the current repository.

Steps:
1. Read `~/.config/marshroom/state.json` and parse the JSON
2. Extract the `cart` array. If the cart is empty, tell the user to add issues in the Marshroom app
3. Run `git remote get-url origin` to get the current repo's remote URL
4. Extract `owner/repo` from the remote URL (handle both HTTPS and SSH formats)
5. Filter cart entries where `repoCloneURL` (HTTPS) or `repoSSHURL` (SSH) matches the current remote. Compare by extracting `owner/repo` from each
6. If no matching cart entries, tell the user this repo has no cart issues
7. If `$ARGUMENTS` contains an issue number, find that entry; otherwise if multiple matches, list them and ask the user to pick one
8. Run `git checkout main && git pull origin main` to ensure main is up to date
9. Create and checkout the branch: `git checkout -b {branchName}`
10. Confirm the branch was created and display:
   - Issue: #{issueNumber} {issueTitle}
   - Branch: {branchName}
   - Repository: {repoFullName}
