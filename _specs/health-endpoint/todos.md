# Todos: Health Endpoint for Web and APIs

## Checkpoint 1 - Initial Implementation

### Web App Health Endpoint
- [ ] Create health check controller/handler in web app
- [ ] Add response formatting (status, timestamp, service, version)
- [ ] Wire health endpoint (`GET /health`) in web app routing
- [ ] Verify response format is correct JSON

### API Service Health Endpoint
- [ ] Create health check controller/handler in API app
- [ ] Add response formatting (consistent with web app)
- [ ] Wire health endpoint (`GET /health`) in API app routing
- [ ] Verify response format is correct JSON

### Testing
- [ ] Create unit tests for web health endpoint
  - [ ] Returns 200
  - [ ] Response includes all required fields (status, timestamp, service, version)
  - [ ] Endpoint accessible without authentication
- [ ] Create unit tests for API health endpoint (same as web)
- [ ] Verify endpoints handle concurrent requests
- [ ] Verify response time is under 500ms

### Documentation
- [ ] Add health endpoint documentation to README or API docs
- [ ] Document response format with example
- [ ] Document expected status codes (200 vs 503)
- [ ] Add example curl commands

### Pre-commit Verification
- [ ] Run all tests: `npm exec -- nx run-many -t test`
- [ ] Run e2e tests: `npm exec -- nx run-many -t e2e`
- [ ] Verify no linting errors
- [ ] Test endpoints manually (curl or Postman)

## Status

- Total tasks: 16
- Completed: 0
- In progress: 0
