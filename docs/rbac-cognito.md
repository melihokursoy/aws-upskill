# RBAC with AWS Cognito

## Overview

Authentication and role-based access control is handled by AWS Cognito via the Application Load Balancer (ALB). The ALB authenticates users through the Cognito Hosted UI and forwards a signed JWT in the `x-amzn-oidc-data` request header to all services. Neither the API nor the web app performs signature verification — the ALB is the trust boundary.

## Architecture

```
Browser → ALB (authenticate-cognito action)
              → Cognito Hosted UI (if no session)
              ← Set-Cookie: AWSELBAuthSessionCookie
              → Forward request + x-amzn-oidc-data header
                    → Web (Next.js)   — middleware + getUser()
                    → API (NestJS)    — AlbAuthMiddleware
```

### Public paths (bypassed by ALB — no auth required)

| Path | Service |
|---|---|
| `/_next/*` | Web static assets |
| `/favicon.ico` | Web |
| `/403` | Web error page |
| `/nextapi/health` | Web health check |
| `/auth/signout` | Web logout handler |
| `/api/health`, `/api/db-health` | API health checks |

### The `x-amzn-oidc-data` header

A signed JWT injected by the ALB. The payload (middle base64url segment) contains standard OIDC claims:

| JWT claim | Mapped field |
|---|---|
| `sub` | `sub` |
| `email` | `email` |
| `name` | `name` |
| `family_name` | `familyName` |
| `birthdate` | `birthdate` |
| `phone_number` | `phoneNumber` |
| `address` | `address` |
| `picture` | `picture` |
| `gender` | `gender` |
| `locale` | `locale` |
| `zoneinfo` | `zoneinfo` |
| `cognito:groups` | `roles` |

## Roles

Three Cognito user groups are provisioned:

| Group | Access |
|---|---|
| `admin` | `/admin`, `/manage`, and all authenticated routes |
| `moderator` | `/manage` and all authenticated routes |
| `user` | All authenticated routes only |

## NestJS API — decorators

### `@CurrentUser()`

Parameter decorator — injects the decoded `AuthUser` from `request.user`.

```typescript
import { CurrentUser, AuthUser } from '@org/auth';

@Get('/profile')
getProfile(@CurrentUser() user: AuthUser) {
  return user;
}
```

### `@Roles(...roles)`

Combined with `RolesGuard`, restricts a route to users with at least one of the given roles.

```typescript
import { Roles, RolesGuard, CurrentUser, AuthUser } from '@org/auth';
import { UseGuards } from '@nestjs/common';

@Get('/admin-only')
@Roles('admin')
@UseGuards(RolesGuard)
adminOnly(@CurrentUser() user: AuthUser) {
  return user;
}
```

- No `@Roles()` → route is accessible to all authenticated users
- Unauthenticated request (no header) → 401 Unauthorized
- Wrong role → 403 Forbidden

## Sign-in flow

The Sign In button navigates to `/manage` — a path protected by the ALB's `/*` authenticate-cognito rule.

**Why not link directly to Cognito?** The ALB's `/oauth2/idpresponse` callback is **stateful**. It only completes token exchanges for auth flows the ALB itself initiated (it generates and validates its own `state` parameter). If the app builds a Cognito URL directly, the callback returns `401 Authorization Required` and sets no session cookie, because the ALB has no matching state for the code.

The correct flow:
1. User clicks **Sign In** → browser navigates to `/manage`
2. ALB: no session cookie → redirects to Cognito (ALB builds the URL with its own state)
3. User authenticates in Cognito Hosted UI
4. Cognito redirects to `<APP_URL>/oauth2/idpresponse?code=...`
5. ALB intercepts, validates state, exchanges code for tokens with Cognito
6. ALB sets `AWSELBAuthSessionCookie` (httponly) and forwards to `/manage` with `x-amzn-oidc-data` set

## Sign-out flow

Navigate to `/auth/signout`. The route handler:

1. **Expires the ALB session cookies** (`AWSELBAuthSessionCookie-0` and `-1`) in the response headers — this is the critical step. Without it, the browser still holds a valid ALB session cookie and the user appears logged in even after Cognito clears its session.
2. **Redirects to Cognito logout:**

```
https://<COGNITO_DOMAIN>/logout?client_id=<CLIENT_ID>&logout_uri=<APP_URL>
```

Cognito clears its own session and redirects the browser to `<APP_URL>` (the home page). The user arrives unauthenticated with no ALB cookie.

## Seed users

The `infra/scripts/seed-cognito.sh` script creates three test users:

| Username | Group | Password |
|---|---|---|
| `seed-admin` | `admin` | `$COGNITO_SEED_PASSWORD` |
| `seed-moderator` | `moderator` | `$COGNITO_SEED_PASSWORD` |
| `seed-user` | `user` | `$COGNITO_SEED_PASSWORD` |

```bash
cd infra
export COGNITO_SEED_PASSWORD=YourTestPassword1!
./scripts/seed-cognito.sh dev
```

Each user is created with sample OIDC attributes (name, picture via DiceBear, birthdate, etc.) to exercise the full claim pipeline.

## Local development

In local dev there is no ALB, so no `x-amzn-oidc-data` header is present. Use the bypass mode to inject a mock user.

### API (NestJS)

Set environment variables before starting the API:

```bash
LOCAL_AUTH_BYPASS=true \
LOCAL_AUTH_ROLE=admin \
LOCAL_AUTH_EMAIL=dev@localhost \
LOCAL_AUTH_NAME="Dev User" \
npm exec -- nx serve api-order
```

`AlbAuthMiddleware` will inject the mock user on every request. `LOCAL_AUTH_ROLE` defaults to `admin` if unset.

### Web (Next.js)

```bash
LOCAL_AUTH_BYPASS=true \
LOCAL_AUTH_ROLE=moderator \
npm exec -- nx serve web
```

The Next.js middleware skips the Cognito redirect check entirely. `getUser()` in Server Components still reads `x-amzn-oidc-data` — to test the full UI with a logged-in user locally, you can set the header manually via a browser extension (e.g. ModHeader):

1. Install [ModHeader](https://modheader.com/)
2. Add header: `x-amzn-oidc-data`
3. Set value to a fake JWT: `<base64-header>.<base64-payload>.<sig>`

Example payload for an admin user (base64url-encode this JSON):
```json
{
  "sub": "local-sub-1",
  "email": "admin@localhost",
  "name": "Local",
  "family_name": "Admin",
  "cognito:groups": ["admin"]
}
```

### Adding users to Cognito groups (AWS Console or CLI)

```bash
# Add existing user to a group
aws cognito-idp admin-add-user-to-group \
  --user-pool-id <POOL_ID> \
  --username <USERNAME> \
  --group-name admin
```

## Security note

Middleware is **defense-in-depth**:

- **Production**: The ALB is the primary auth gate. It will never forward a request to the web or API without a valid Cognito session (except for explicitly bypassed paths). Middleware adds a second layer of role enforcement.
- **Local dev**: `LOCAL_AUTH_BYPASS=true` is the primary mechanism. Never set this in production — it is only read when explicitly present in the environment.
