---
description: Implement the work described in the spec and plan files
argument-hint: Optional implementation notes or specific tasks to focus on
allowed-tools: Read, Write, Glob, Bash, Edit, Agent
---

You are helping to implement the work described in the spec file. Always adhere to any rules or requirements set out in any CLAUDE.md files when responding.

User input: $ARGUMENTS

## High level behavior

Your job will be to:

- Extract the `<feature_slug>` from the current branch
- Read the spec.md and plan.md files to understand requirements and approach
- Read todos.md to track completed vs remaining work
- Guide the user through implementation step-by-step
- Update todos.md as work is completed
- Follow the Git Workflow rules from CLAUDE.md: plan all changes, complete all changes, test everything, then commit once

## Step 1. Extract Feature Slug

Extract `<feature_slug>` from the current branch name (e.g., `feature/card-component` → `card-component`).

If not on a feature branch, inform the user they should be on a feature branch (created via `/spec` command) before implementing.

## Step 2. Load Spec and Plan

Read the following files:
- `_specs/<feature_slug>/spec.md` - Feature requirements and acceptance criteria
- `_specs/<feature_slug>/plan.md` - Technical implementation approach
- `_specs/<feature_slug>/todos.md` - Checklist of tasks (create if doesn't exist)

If any file is missing, inform the user and ask if they want to create it first.

## Step 3. Parse User Input

From `$ARGUMENTS`, extract:
- Any specific tasks the user wants to focus on
- Any implementation notes or context the user wants to provide
- Clarifications or scope changes

## Step 4. Check Repository State

Verify the working directory is clean (no uncommitted changes). If there are changes:
- Ask the user to commit or stash them first
- DO NOT PROCEED until the repository is clean

## Step 5. Create or Update Todos

If `todos.md` doesn't exist, generate one from the plan.md requirements with checkboxes:
```markdown
- [ ] Task 1 description
- [ ] Task 2 description
...
- [ ] Run all tests before committing
```

Display the current todos and their status. Ask the user which task to start with.

**IMPORTANT - Never Modify Committed Todos:**
- Once a task is marked `[x]` and the work is committed, NEVER change or remove it from the todo list
- Committed tasks document what was done in that commit and are part of the historical record
- If scope changes or new tasks emerge during implementation:
  - Create a NEW checkpoint section in todos.md with a timestamp or label (e.g., "## Checkpoint 2 - Additional Requirements")
  - Add new unchecked tasks under this new section
  - This maintains clarity about what was planned vs what emerged during work
  - Example:
    ```markdown
    ## Checkpoint 1 - Initial Implementation
    - [x] Task 1
    - [x] Task 2

    ## Checkpoint 2 - Additional Refinements (discovered during implementation)
    - [ ] New Task A
    - [ ] New Task B
    ```

## Step 6. Guide Implementation

For each task in the todos:
1. Explain what needs to be done with context from spec/plan
2. Ask clarifying questions if needed
3. Work collaboratively through the implementation
4. After each task completes, ask user to confirm it's done
5. Update todos.md with completed items (change `[ ]` to `[x]`)

**If scope changes or new tasks emerge:**
- Do NOT modify previously completed tasks
- Create a new checkpoint in todos.md with the additional work
- Update plan.md to document the scope change and why it occurred
- Inform the user that this will require a follow-up commit after this checkpoint completes

## Step 7. Testing and Verification

Before marking implementation complete:
- Run unit tests: `npm exec -- nx run-many -t test`
- Run e2e tests: `npm exec -- nx run-many -t e2e`
- Verify any manual testing from acceptance criteria

Inform user of any test failures and ask to fix before proceeding.

## Step 8. Final Commit

Once all todos are complete and tests pass:
- Summarize the changes made (reference spec.md)
- Invoke the `/commit` skill to create a commit message
- Ask user to confirm the commit
- Commit all changes with a single, comprehensive message

## Step 9. Summary Output

After implementation and commit, respond with:

```
Implementation complete for: <feature_title>
Branch: <branch_name>
Spec: _specs/<feature_slug>/spec.md
Plan: _specs/<feature_slug>/plan.md
Todos: _specs/<feature_slug>/todos.md
```

Reference the acceptance criteria from the spec to confirm all requirements were met.
