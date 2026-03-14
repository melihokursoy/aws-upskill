# Git Workflow - Complete Changes Before Committing

Always follow this workflow to maintain clean git history:

1. **Plan all changes** - Understand the full scope before starting
2. **Make all changes** - Keep working until the complete solution is ready
3. **Test everything** - Before committing, verify:
   - All unit tests pass (`npm exec -- nx run-many -t test`)
   - All e2e tests pass (`npm exec -- nx run-many -t e2e`)
   - Any manual verification needed
4. **Commit once** - Single commit with all related changes and clear message
5. **Never commit incomplete work** - A commit should represent finished, tested functionality

## Why This Matters

- Commits document logical units of work
- Clean history makes debugging and reviews easier
- Prevents needing to fix broken commits later
- Keeps the codebase in a working state at each commit

## If Issues are Found After Committing

- Revert the entire commit (`git revert <commit>`) and start over
- Or create a new separate commit with the fix (clearly documented as a fix)
- Do NOT go back and modify the previous commit

## Todos and Checkpoints

Once a task is marked `[x]` and committed, NEVER change or remove it from the todo list. Committed tasks are part of the historical record.

If scope changes or new tasks emerge during implementation:
- Create a NEW checkpoint section with a timestamp or label
- Add new unchecked tasks under this new section
- Update plan.md to document why scope changed
- Each checkpoint gets its own commit

Example:
```markdown
## Checkpoint 1 - Initial Implementation
- [x] Task 1
- [x] Task 2

## Checkpoint 2 - Additional Refinements (discovered during implementation)
- [ ] New Task A
- [ ] New Task B
```
