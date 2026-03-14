# Core Guidelines

See these rule files for detailed guidance:

- [.claude/rules/nx.md](./.claude/rules/nx.md) - Nx workspace patterns and commands
- [.claude/rules/git-workflow.md](./.claude/rules/git-workflow.md) - Git commit and branch workflow


# Self-Improvement Loop

**Purpose**: `.claude/rules/` files capture patterns and mistakes discovered during development, preventing recurring issues.

**When to create/update rules:**

- After user correction or feedback
- When discovering a non-obvious pattern in the codebase
- When a bug is fixed (capture the root cause pattern)
- After architectural decisions are made

**Rule file structure** (`.claude/rules/<TOPIC>.md`):

```markdown
# <Topic>

## Pattern

[Describe the pattern/rule clearly]

## Why This Matters

[Explain the impact of following/breaking this rule]

## Example (What Not To Do)

[Show incorrect approach with code or process]

## Example (Correct Approach)

[Show correct approach]

## Checklist

- [ ] Apply before starting related work
- [ ] Review when similar task arises
```

**Example rule files for this project:**

- `.claude/rules/nx.md` - Nx command patterns and gotchas
- `.claude/rules/testing.md` - Testing patterns and test-first approach
- `.claude/rules/git-workflow.md` - Commit, branch, and PR conventions

**Review process:**

- At session start, check `.claude/rules/` for topics relevant to current task
- Before implementing, scan rules for gotchas
- Update rules when patterns change or new insights emerge
