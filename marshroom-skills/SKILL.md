# Marshroom Skills

Marshroom is a macOS developer productivity tool that uses GitHub Issues as the Single Source of Truth (SSOT) for task management. These agent skills integrate Claude Code with the Marshroom workflow.

## How It Works

Marshroom manages a **cart** of GitHub issues. The macOS app tracks these issues and writes their state to `~/.config/marshroom/state.json`, which these skills read to understand the current task context.

## The GOAT Flow

Marshroom follows a five-stage execution pipeline:

1. **Draft** — Pick an issue from your cart in the Marshroom app (status: `soon`)
2. **Inject** — `/start-issue` creates a branch and injects issue + project context (status: `running`)
3. **Execute** — Work on the issue with full context awareness
4. **Review** — `/create-pr` creates a PR with proper closing keywords (status: `pending`)
5. **Ship** — `/validate-pr` ensures the PR meets all conventions before merge (status: `completed`)

## Available Skills

| Skill | Description |
|-------|-------------|
| `/start-issue` | Start working on a cart issue — creates branch, injects context, updates status |
| `/create-pr` | Create a Pull Request with proper `Closes #N` keyword and update status |
| `/validate-pr` | Validate PR branch name, body, and status against Marshroom conventions |

## State Management

All skills read from `~/.config/marshroom/state.json` (v3 schema). See `references/state-schema.md` for the full schema documentation.

## Prerequisites

- `gh` CLI (GitHub CLI) — installed and authenticated
- `git` — available in PATH
- Marshroom macOS app — running with issues in cart
- `marsh` CLI (optional) — for status updates in tmux HUD
