# state.json v3 Schema Reference

## File Location

```
~/.config/marshroom/state.json
```

The Marshroom macOS app writes this file atomically (`Data.write(options: .atomic)`) to prevent corruption from concurrent reads by Claude Code or the `marsh` CLI.

## Schema

```json
{
  "version": 3,
  "updatedAt": "2025-02-08T12:00:00Z",
  "cart": [ CartEntry ],
  "repos": [ RepoEntry ]
}
```

## CartEntry

| Field | Type | Description |
|-------|------|-------------|
| `repoFullName` | `string` | Repository in `owner/repo` format |
| `repoCloneURL` | `string` | HTTPS clone URL (e.g., `https://github.com/owner/repo.git`) |
| `repoSSHURL` | `string` | SSH clone URL (e.g., `git@github.com:owner/repo.git`) |
| `issueNumber` | `int` | GitHub issue number |
| `issueTitle` | `string` | Issue title |
| `branchName` | `string` | Git branch name (`Feature/#N` or `HotFix/#N`) |
| `status` | `string` | Pipeline status (see Status Values below) |
| `issueBody` | `string?` | Full issue description body (nullable) |
| `prNumber` | `int?` | Pull Request number after PR creation (nullable) |
| `prURL` | `string?` | Pull Request URL after PR creation (nullable) |

### Branch Name Convention

The `branchName` is derived from the issue title:
- If the title contains `Bug`, `Fix`, or `HotFix` → `HotFix/#N`
- Otherwise → `Feature/#N`

## RepoEntry

| Field | Type | Description |
|-------|------|-------------|
| `fullName` | `string` | Repository in `owner/repo` format |
| `cloneURL` | `string` | HTTPS clone URL |
| `sshURL` | `string` | SSH clone URL |
| `claudeMdCache` | `string?` | Cached contents of the repo's `CLAUDE.md` file (nullable) |
| `claudeMdCachedAt` | `string?` | ISO 8601 timestamp of when `claudeMdCache` was last fetched (nullable) |
| `localPath` | `string?` | Local filesystem path where the repo is cloned (nullable) |

## Status Values

Cart entries move through a linear pipeline:

```
soon → running → pending → completed
```

| Status | Meaning | Set By |
|--------|---------|--------|
| `soon` | In cart, not yet started. Default when an issue is added to cart. | Marshroom app (when adding `todo-today` label) |
| `running` | Claude Code is actively working on this issue. | `marsh start #N` or `/start-issue` skill |
| `pending` | PR created, awaiting review. | `marsh pr` or `/create-pr` skill |
| `completed` | Issue closed or PR merged. Entry is removed from cart after detection. | Marshroom poller (detects issue closure) |

## Status Transitions

```
[Add to cart] → soon
                  ↓
[/start-issue] → running
                  ↓
[/create-pr]  → pending
                  ↓
[PR merged]   → completed → [removed from cart]
```

Only forward transitions are expected. If an issue needs to go back (e.g., PR rejected), the developer should manage this manually.

## Example

```json
{
  "version": 3,
  "updatedAt": "2025-02-08T12:00:00Z",
  "cart": [
    {
      "repoFullName": "acme/webapp",
      "repoCloneURL": "https://github.com/acme/webapp.git",
      "repoSSHURL": "git@github.com:acme/webapp.git",
      "issueNumber": 42,
      "issueTitle": "Add dark mode support",
      "branchName": "Feature/#42",
      "status": "running",
      "issueBody": "We need dark mode for better nighttime usage.\n\n## Requirements\n- Toggle in settings\n- System preference detection",
      "prNumber": null,
      "prURL": null
    },
    {
      "repoFullName": "acme/api",
      "repoCloneURL": "https://github.com/acme/api.git",
      "repoSSHURL": "git@github.com:acme/api.git",
      "issueNumber": 15,
      "issueTitle": "Fix login timeout bug",
      "branchName": "HotFix/#15",
      "status": "pending",
      "issueBody": "Users report login times out after 5 seconds.",
      "prNumber": 23,
      "prURL": "https://github.com/acme/api/pull/23"
    }
  ],
  "repos": [
    {
      "fullName": "acme/webapp",
      "cloneURL": "https://github.com/acme/webapp.git",
      "sshURL": "git@github.com:acme/webapp.git",
      "claudeMdCache": "# Webapp\n\nNext.js application...",
      "claudeMdCachedAt": "2025-02-08T11:30:00Z",
      "localPath": "/Users/dev/projects/webapp"
    }
  ]
}
```

## Backward Compatibility

The `StateFileManager` handles migration from v2 to v3:
- v2 entries without `status` default to `"soon"`
- v2 entries without `issueBody`, `prNumber`, `prURL` default to `null`
- v2 repos without `claudeMdCache`, `claudeMdCachedAt`, `localPath` default to `null`
