# Health Endpoint Documentation

## Overview

The health endpoint is a public endpoint that allows external monitoring systems to verify that services are running and responding correctly.

- **Web App:** `GET /health`
- **API Service:** `GET /health`

Both endpoints require no authentication and always return 200 status code with health information.

## Response Format

```json
{
  "status": "healthy",
  "timestamp": "2026-03-14T21:54:30Z",
  "service": "web",
  "version": "1.0.0"
}
```

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Service status. Always "healthy" if responding. |
| `timestamp` | string | ISO 8601 formatted timestamp of the health check. |
| `service` | string | Service name ("web" or "api"). |
| `version` | string | Service version or Git commit SHA. |

## Endpoints

### Web App Health Check

**Endpoint:** `GET /health`
**Authentication:** None required
**Response Time:** < 500ms
**Status Code:** 200

**Example:**
```bash
curl http://localhost:3300/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-03-14T21:54:30Z",
  "service": "web",
  "version": "1.0.0"
}
```

### API Service Health Check

**Endpoint:** `GET /health`
**Authentication:** None required
**Response Time:** < 500ms
**Status Code:** 200

**Example:**
```bash
curl http://localhost:3301/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-03-14T21:54:30Z",
  "service": "api",
  "version": "1.0.0"
}
```

## Usage in Monitoring

### Health Check Monitoring

The health endpoint can be used with monitoring tools to detect service availability:

```bash
# Check if service is up every 30 seconds
watch -n 30 'curl -s http://localhost:3300/health | jq'
```

### Load Balancer Integration

Load balancers can use the health endpoint to route traffic only to healthy instances:

```
Health check path: /health
Expected status: 200
Interval: 30 seconds
Timeout: 5 seconds
Healthy threshold: 2
Unhealthy threshold: 3
```

### Kubernetes Integration

For future Kubernetes deployments, separate probes can be configured:

- `/health` - Liveness probe (is the service running?)
- `/ready` - Readiness probe (is the service ready to serve?) [Future]
- `/live` - Alternative liveness probe [Future]

## Implementation Details

### Web App (Next.js)

Health endpoint implemented as a Next.js API route:

**File:** `apps/web/app/api/health/route.ts`

```typescript
// GET /api/health
// Returns health status without database checks
// No authentication required
```

### API Service (NestJS)

Health endpoint implemented as a NestJS controller:

**File:** `apps/api-order/src/app/health.controller.ts`

```typescript
// GET /health
// Returns health status without database checks
// No authentication required
```

## Performance Characteristics

- **Response Time Goal:** < 500ms
- **Resource Usage:** Minimal (no I/O, no database queries)
- **Concurrency:** Handles multiple concurrent requests
- **Side Effects:** None (read-only)

## Notes

- Health endpoint is **always available** even during service startup
- No database connectivity checks (database not available at this time)
- Future versions may include `/ready` and `/live` endpoints for Kubernetes-style health probes
