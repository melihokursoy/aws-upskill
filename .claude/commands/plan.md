---
description: Create a technical plan for the spec file
argument-hint: Short technical implementation details
allowed-tools: Read, Write, Glob
---

You are helping to create technical plan provided in the spec file. Always adhere to any rules or requirements set out in any CLAUDE.md files when responding.

User input: $ARGUMENTS

## High level behavior

Your job will be to turn the spec file into a technical plan:

- A human friendly feature title in kebab-case (e.g. new-heist-form)
- A safe git branch name not already taken (e.g. feature/new-heist-form)
- A detailed markdown plan file under the \_specs/<feature_slug> directory

Then save the plan.md file to disk and print a short summary of what you did.

## Step 1. Extract Feature Slug

extract <feature_slug> from the current branch that is defined in spec file and inform user that you started working for <feature_slug> and will generate a plan.md file in \_spec/<feature_slug>

## Step 2. Parse the arguments

From `$ARGUMENTS`, extract technical implementation details mentioned by user

## Step 3. Check for existing plan

Read the plan.md if there is already one created read it and iterate on that

## Step 4. Ask questions

Aask questions iteratively when you cannot decide with options each to chose from like A,B and one open end option lets user decide.

## Step 5. Draft the plan content

Create a markdown plan document that Plan mode can use directly and save it in \_spec/<feature_slug>/plan.md.

## Step 6. Create todos with Implementation Checkpoints

Create a checkable todo list in \_spec/<feature_slug>/todos.md organized by implementation phases/checkpoints.

**Guidelines for checkpoint structure:**
- Each checkpoint represents a logical phase that can be implemented, tested, and committed independently
- Order checkpoints by implementation dependency (what must be done first)
- Within each checkpoint, order tasks sequentially (prerequisites first)
- Example structure:
  ```markdown
  ## Checkpoint 1 - Phase Name (e.g., "Core Feature")
  - [ ] Task that must be done first
  - [ ] Task that depends on above
  - [ ] Verification or testing for this phase

  ## Checkpoint 2 - Next Phase (e.g., "Integration")
  - [ ] Task for phase 2
  - [ ] Another task

  ## Checkpoint 3 - Documentation & Testing
  - [ ] Tests
  - [ ] Documentation
  ```

**Why this structure matters:**
- Implementer can work through one checkpoint at a time
- Each checkpoint can be a separate commit (following Git Workflow from CLAUDE.md)
- Clear dependencies and what to do next
- Makes it obvious when a checkpoint is complete and ready to commit

**For each task:**
- Be specific and actionable (not vague)
- Include acceptance criteria or success indicators where relevant
- Group related tasks together
- Sub-tasks should be indented with `  - [ ]` format

## Step 7. Update Spec with Resolved Decisions

Once the plan is finalized:
- Read the spec.md file
- Check for "Open Questions" section
- Replace it with "Resolved Decisions" section that documents the decisions made in the plan
- For each open question, add a bullet point with the resolved answer
- Example:
  ```markdown
  ## Resolved Decisions

  - **Database checks**: INCLUDE database connectivity checks (not minimal)
  - **Response codes**: Use 200 for healthy, 503 for degraded
  - **Architecture**: Plan for future extensibility with `/ready` and `/live` endpoints
  ```
- Save the updated spec.md

This ensures the spec documents the actual decisions made, not just open questions.

## Step 8. Final output to the user

After the files are saved, respond to the user with a short summary in this exact format:

plan file: \_specs/<feature_slug>/plan.md
todos file: \_specs/<feature_slug>/todos.md

Do not repeat the full plan in the chat output unless the user explicitly asks to see it. The main goal is to save the plan and todos files and report where they live.

Note: The spec.md file has also been updated with resolved decisions.
