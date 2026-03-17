# Spec for RBAC with AWS Cognito
branch: feature/rbac-aws-cognito

## Summary

Implement role-based access control (RBAC) for the web and API services using AWS Cognito as the identity provider. Users authenticate via the Cognito Hosted UI. ALB handles the auth flow and forwards the decoded JWT payload to backend services via the `x-amzn-oidc-data` header. Applications use the role claims in that header to control access.

## Functional Requirements

### Authentication

- Unauthenticated users are redirected to the Cognito Hosted UI (on `amazoncognito.com`) when accessing a protected route
- ALB performs the OIDC Authorization Code exchange with Cognito and sets an encrypted session cookie on the browser
- On subsequent requests, ALB validates the session cookie and forwards the decoded JWT claims as HTTP headers to the app — the app never handles raw tokens
- Sign-out clears the Cognito session by redirecting to the Cognito Hosted UI logout endpoint

### Roles and Groups

- Roles are represented as Cognito User Pool Groups
- Role claims are forwarded by ALB in the `x-amzn-oidc-data` header under `cognito:groups`
- Three roles: `admin` (highest), `moderator` (intermediate), `user` (standard)
- Permission enforcement per role is deferred to future feature specs — this feature delivers role claims to apps only

### API Authorization

- `AlbAuthMiddleware` (shared library `@org/auth`) decodes `x-amzn-oidc-data` on every request and attaches user context to `request.user`
- `RolesGuard` enforces role requirements — 401 if unauthenticated, 403 if insufficient role
- Role test endpoints in `api-order` at `/roles/*` demonstrate and verify the guards

### Web App

- Home page (`/`) is public — shows Sign In button when unauthenticated, avatar dropdown when authenticated
- `/manage` requires `moderator` or `admin` role
- `/admin` requires `admin` role
- Insufficient role redirects to `/403`
- Header: Sign In button (unauthenticated) → Avatar + "First Last" dropdown (authenticated) with Manage, Admin (role-conditional), Logout

### Infrastructure (Terraform)

- Cognito User Pool, Hosted UI domain (AWS subdomain — no custom domain), User Pool Client, and Groups provisioned via a new `cognito` Terraform module
- ALB listener uses `authenticate-cognito` action; home page (`/`) uses `authenticate-cognito` with `on_unauthenticated_request = "allow"` (auth-aware but not forced); other public paths (`/403`, health checks) use `allow` action at higher priority
- Cognito config written to SSM Parameter Store for container startup
- Seed script (`seed-cognito.sh`) creates one test user per role after `terraform apply`

## Possible Edge Cases

- User belongs to multiple Cognito groups — use most permissive matching role
- User removed from a group while session is active — role change takes effect on next ALB session refresh
- Missing `cognito:groups` claim — `roles` defaults to `[]` (least privilege)
- `x-amzn-oidc-data` header malformed — `request.user` set to null, protected endpoints return 401

## Acceptance Criteria

- [ ] Unauthenticated user navigating to `/manage` is redirected to Cognito Hosted UI
- [ ] After sign-in, user lands on home page with avatar dropdown showing their name
- [ ] `admin` user sees Manage and Admin links in dropdown; `moderator` sees only Manage; `user` sees neither
- [ ] `GET /roles/admin` returns user payload for admin, 403 for moderator/user, 401 for unauthenticated
- [ ] `GET /roles/moderator` returns user payload for moderator and admin, 403 for user
- [ ] `GET /roles/user` returns user payload for any authenticated role
- [ ] `GET /roles/none` returns 200 with no auth required
- [ ] Sign-out clears session and returns to home with Sign In button visible
- [ ] Cognito User Pool, Client, Groups, ALB OIDC rules, and SSM parameters provisioned by Terraform
- [ ] Seed script creates `seed-admin`, `seed-moderator`, `seed-user` in correct Cognito groups

## Resolved Decisions

- **Sign-in UI**: Cognito Hosted UI on AWS subdomain (`amazoncognito.com`) — no custom domain, no custom sign-in page
- **Token storage**: ALB manages session cookie entirely — apps never handle raw tokens
- **Token refresh**: ALB handles session refresh transparently — no refresh logic needed in the app
- **Registration**: Self-registration allowed via Cognito Hosted UI sign-up flow
- **Roles**: `admin`, `moderator`, `user` as Cognito User Pool Groups
- **Role permissions**: Deferred to future features — this feature delivers role claims only
- **JWT delivery**: ALB forwards decoded claims in `x-amzn-oidc-data` header; apps decode payload without re-validating the signature (ALB already validated it)
- **Shared auth**: `AlbAuthMiddleware`, `RolesGuard`, `@CurrentUser()`, `@Roles()` live in shared library `@org/auth` (`libs/auth`) for reuse across all NestJS API services
- **Avatar image**: stored as Cognito `picture` attribute (URL string only — Cognito never stores binary); flows through ALB JWT claims to the app; avatar component renders image if present, falls back to initials (first letter of name + family name); profile picture upload UI deferred to a future feature
- **Seeding**: `infra/scripts/seed-cognito.sh` creates one test user per role with a DiceBear `avataaars` robot avatar (`api.dicebear.com/9.x/avataaars/svg?seed=<username>`) using AWS CLI after `terraform apply`
- **User claims**: Full OIDC standard claims forwarded via `x-amzn-oidc-data`: `sub`, `email`, `name`, `family_name`, `birthdate`, `phone_number`, `address`, `picture`, `gender`, `locale`, `zoneinfo`, `cognito:groups`; mapped to camelCase in application code
- **Callback URL**: ALB's fixed OIDC callback at `https://<domain>/oauth2/idpresponse` — registered in Cognito User Pool Client
- **Client secret**: `generate_secret = true` on User Pool Client; ALB retrieves it automatically via IAM — never exposed to browser or app code
- **Home page auth**: Home page (`/`) uses `authenticate-cognito` with `on_unauthenticated_request = "allow"` — authenticated users see avatar, unauthenticated users see Sign In
- **Middleware role**: Defense-in-depth — ALB is primary auth gate in production; Next.js middleware is primary in local dev

## Testing Guidelines

- Unit tests for `AlbAuthMiddleware` — valid header populates `request.user`; missing/malformed header sets null; missing `cognito:groups` defaults to `[]`
- Unit tests for `RolesGuard` — matching role passes; wrong role → 403; null user → 401; no `@Roles()` decorator → passes
- Unit tests for `AvatarDropdown` — correct links shown per role; inaccessible items not rendered
- Unit tests for Next.js middleware — unauthenticated on protected path → redirect; wrong role → `/403`; public paths pass through
- Integration tests for `/roles/*` endpoints covering all role/auth combinations
- E2E: unauthenticated request to `/manage` → redirect to Cognito domain
