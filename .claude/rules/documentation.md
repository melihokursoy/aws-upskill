# Documentation Guidelines

## Pattern

All new features and endpoints must have corresponding documentation in the `/docs` directory at the project root.

Documentation should be clear, actionable, and include:

- Feature/endpoint overview
- Response format (for APIs)
- Usage examples (curl, code snippets)
- Integration guidance (for monitoring, load balancers, etc.)
- Implementation location (which files contain the code)
- Performance characteristics (if relevant)
- Future considerations or known limitations

## Why This Matters

- Team members can quickly understand how to use features without reading code
- Monitoring systems have clear guidance on integration
- Operations/DevOps teams can configure health checks and monitoring correctly
- Reduces support questions and integration errors
- Documentation is versioned alongside code (changes together, commits together)
- Makes onboarding new team members easier

## Documentation Structure

Each feature should have its own `.md` file in `/docs` directory:

```
docs/
├── health-endpoint.md          # Health check endpoint documentation
├── feature-name.md             # Future features
└── README.md                   # (Optional) Overview of docs
```

## When to Create Documentation

- When implementing a new public endpoint or API
- When adding a feature that others need to integrate with
- When configuration or setup is required to use the feature
- When the feature has performance characteristics to know about

**Don't create documentation for:**

- Internal implementation details
- Code that only developers need to understand (that goes in code comments)
- Temporary features or experiments

## Documentation Template

```markdown
# Feature Name Documentation

## Overview

Brief description of what the feature does.

## API/Usage

### Endpoint Name

- **Path:** endpoint path
- **Method:** HTTP method
- **Authentication:** Required? Yes/No
- **Response Time:** Typical response time

Example request and response.

## Implementation Details

### Location

Where in the codebase is this implemented?

### Configuration

Any setup or configuration needed?

## Integration Examples

Show common usage patterns (curl, code examples, configuration).

## Performance Characteristics

Response time, resource usage, concurrency handling, etc.

## Notes

Any important caveats, future plans, or limitations?
```

## File Location

Documentation files go in the **`/docs` directory at project root**, not in app-specific folders.

This keeps documentation discoverable and centralized.

## Linking to Documentation

When implementing a feature with documentation, reference it in:

- README files
- Code comments (if the doc explains usage)
- Spec files (optional, for context)

## Updating Documentation

When the feature changes:

1. Update the documentation file
2. Include the documentation update in the same commit as the feature change
3. Documentation and code should always be in sync
