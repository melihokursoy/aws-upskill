# Todos: Health Endpoint for Web and APIs

## Checkpoint 1 - Web App Health Endpoint

- [ ] Create health check controller/handler in web app
  - [ ] Endpoint: `GET /health`
  - [ ] Returns 200 status
  - [ ] No authentication required
- [ ] Add response formatting (status, timestamp, service, version)
  - [ ] Include timestamp in ISO8601 format
  - [ ] Include service name and version
- [ ] Wire health endpoint in web app routing
- [ ] Create unit tests for web health endpoint
  - [ ] Returns 200
  - [ ] Response includes all required fields
  - [ ] Endpoint accessible without authentication
- [ ] Verify response format is correct JSON
- [ ] Verify response time is under 500ms

## Checkpoint 2 - API Service Health Endpoint

- [ ] Create health check controller/handler in API app
  - [ ] Endpoint: `GET /health`
  - [ ] Returns 200 status
  - [ ] No authentication required
- [ ] Add response formatting (consistent with web app)
  - [ ] Same format: status, timestamp, service, version
- [ ] Wire health endpoint in API app routing
- [ ] Create unit tests for API health endpoint (same as web)
  - [ ] Returns 200
  - [ ] Response includes all required fields
  - [ ] Endpoint accessible without authentication
- [ ] Verify response format is correct JSON
- [ ] Verify response time is under 500ms

## Checkpoint 3 - Cross-Service Testing

- [ ] Verify endpoints handle concurrent requests
  - [ ] Test both web and API concurrently
  - [ ] No race conditions or errors
- [ ] Test both endpoints manually (curl or Postman)
  - [ ] Verify JSON response format
  - [ ] Verify timestamp is current
  - [ ] Verify service name and version are correct

## Checkpoint 4 - Documentation

- [ ] Add health endpoint documentation to README or API docs
  - [ ] Document both web and API endpoints
  - [ ] Explain response format
  - [ ] Add example curl commands
  - [ ] Note: No authentication required
  - [ ] Note: Always returns 200

## Checkpoint 5 - Final Verification & Commit

- [ ] Run all unit tests: `npm exec -- nx run-many -t test`
- [ ] Run all e2e tests: `npm exec -- nx run-many -t e2e`
- [ ] Verify no linting errors
- [ ] Verify both endpoints are working manually
- [ ] Ready to commit

## Implementation Flow

1. **Checkpoint 1** - Web app endpoint (can be committed independently)
2. **Checkpoint 2** - API endpoint (can be committed independently)
3. **Checkpoint 3** - Cross-service testing and verification
4. **Checkpoint 4** - Documentation
5. **Checkpoint 5** - Final verification before merge

Each checkpoint is ordered by implementation dependency and can be completed and tested before moving to the next.

## Status

- Total checkpoints: 5
- Completed: 0
- In progress: 0
