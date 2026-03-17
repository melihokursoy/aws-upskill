# Todos: RBAC with AWS Cognito

## Checkpoint 1 — Terraform: Cognito Module

- [x] Create `infra/modules/cognito/variables.tf` with inputs: `project_name`, `environment_name`, `region`, `tags`, `allow_self_registration`, `app_domain` (for callback/logout URLs)
- [x] Create `infra/modules/cognito/main.tf`:
  - [x] `aws_cognito_user_pool` with email as username, self-registration controlled by variable
  - [x] `aws_cognito_user_pool_domain` for hosted UI
  - [x] `aws_cognito_user_pool_client` with Authorization Code Grant, `generate_secret = true`, `allowed_oauth_scopes = ["openid", "email", "profile", "phone"]`; `callback_urls = ["https://${app_domain}/oauth2/idpresponse"]`; `logout_urls = ["https://${app_domain}"]`; `read_attributes` and `write_attributes` include all standard OIDC claims: `email`, `name`, `given_name`, `family_name`, `picture`, `birthdate`, `phone_number`, `address`, `gender`, `locale`, `zoneinfo`
  - [x] `aws_cognito_user_group` × 3: `admin`, `moderator`, `user`
- [x] Create `infra/modules/cognito/outputs.tf`: `user_pool_id`, `user_pool_arn`, `client_id`, `cognito_domain`, `cognito_domain_url`, `issuer_url`
- [x] Add `module "cognito"` to `infra/main.tf`
- [x] Pass `var.domain_name` to Cognito module as `app_domain` in `infra/main.tf`
- [x] Add Cognito outputs to `infra/outputs.tf`
- [x] Verify: `terraform validate` passes
- [x] Create `infra/scripts/seed-cognito.sh`:
  - [x] Add script header: `set -euo pipefail`, `log/ok/skip` helpers, `.env` loader, `INFRA_DIR` setup
  - [x] Validate `<env>` argument and `COGNITO_SEED_PASSWORD` env var (exit with error if unset)
  - [x] Read `USER_POOL_ID` from `terraform output -raw cognito_user_pool_id`
  - [x] For each seed user (`seed-admin`, `seed-moderator`, `seed-user`):
    - [x] Check if user already exists via `aws cognito-idp admin-get-user`; skip creation if found
    - [x] Create user with `aws cognito-idp admin-create-user --temporary-password --message-action SUPPRESS --user-attributes` including: `picture` = `https://api.dicebear.com/9.x/avataaars/svg?seed=<username>`, `given_name`, `family_name`, `birthdate`, `gender`, `locale`, `zoneinfo` (sample values to test full claim pipeline)
    - [x] Set permanent password with `aws cognito-idp admin-set-user-password --permanent`
    - [x] Add user to group with `aws cognito-idp admin-add-user-to-group`
  - [x] Print usage instructions at end of script
- [x] Make script executable: `chmod +x infra/scripts/seed-cognito.sh`
- [x] Add `COGNITO_SEED_PASSWORD=` to `infra/.env.example`
- [x] Document usage in `infra/README.md` seed section

## Checkpoint 2 — Terraform: ALB Authentication

- [x] Add variables to `infra/modules/alb/variables.tf`: `cognito_user_pool_arn`, `cognito_user_pool_client_id`, `cognito_user_pool_domain`
- [x] Update `infra/modules/alb/main.tf`:
  - [x] Add high-priority `allow` listener rules for public paths: `/_next/*` (p1), `/favicon.ico` (p2), `/403` (p3), `/nextapi/health` (p4), `/nextapi/sign-out` (p5), `/api/health` + `/api/db-health` (p6)
  - [x] Add listener rule for `/` (p7) with `authenticate-cognito` action + `on_unauthenticated_request = "allow"` — forwards OIDC headers if session exists, passes through without headers if not (allows home page to show auth state)
  - [x] Update `/api/*` rule (p10) with `authenticate-cognito` + `on_unauthenticated_request = "authenticate"`
  - [x] Add `/*` catch-all rule (p100) with `authenticate-cognito` + `on_unauthenticated_request = "authenticate"` → web
- [x] Pass Cognito outputs from `module "cognito"` to `module "alb"` in `infra/main.tf`
- [x] Verify: `terraform validate` passes

## Checkpoint 3 — Terraform: SSM Parameters

- [x] Add Cognito SSM parameters to `infra/modules/ssm/main.tf`:
  - [x] `/app/cognito/user_pool_id`
  - [x] `/app/cognito/client_id`
  - [x] `/app/cognito/issuer_url`
  - [x] `/app/cognito/domain`
- [x] Add corresponding variables to `infra/modules/ssm/variables.tf`
- [x] Pass Cognito outputs to `module "ssm"` in `infra/main.tf`
- [x] Add Cognito env vars to ECS task definitions in `infra/modules/ecs/main.tf`:
  - [x] API task: `COGNITO_USER_POOL_ID`, `COGNITO_CLIENT_ID`, `COGNITO_ISSUER_URL`
  - [x] Web task: `COGNITO_DOMAIN`, `COGNITO_CLIENT_ID`, `NEXT_PUBLIC_APP_URL`
- [x] Add corresponding variables to `infra/modules/ecs/variables.tf`
- [x] Pass new ECS variables from root `infra/main.tf`
- [x] Verify: `terraform validate` passes

## Checkpoint 4 — Shared Auth Library (`libs/auth`)

- [ ] Scaffold the Nx library: `npm exec nx -- g @nx/nest:library auth --directory=libs/auth`
- [ ] Create `libs/auth/src/alb-auth.middleware.ts`:
  - [ ] Read `x-amzn-oidc-data` header from request
  - [ ] Base64-decode the middle JWT segment (payload only — no signature check)
  - [ ] Map decoded claims to camelCase: `{ sub, email, name, familyName, birthdate, phoneNumber, address, picture, gender, locale, zoneinfo, roles }` — `family_name` → `familyName`, `phone_number` → `phoneNumber`, `cognito:groups` → `roles`; optional string claims default to `null`; `roles` defaults to `[]`
  - [ ] Set `request.user` to decoded object; set `null` if header absent, malformed base64, or invalid JSON
- [ ] Create `libs/auth/src/current-user.decorator.ts` — parameter decorator returning `request.user`
- [ ] Create `libs/auth/src/roles.decorator.ts` — `@Roles(...roles)` metadata decorator
- [ ] Create `libs/auth/src/roles.guard.ts`:
  - [ ] If no `@Roles()` metadata on handler → allow through
  - [ ] If `request.user` is null → throw `UnauthorizedException` (401)
  - [ ] If `request.user.roles` does not intersect required roles → throw `ForbiddenException` (403)
- [ ] Create `libs/auth/src/auth.module.ts` — NestJS module that exports `AlbAuthMiddleware`, `RolesGuard`, `CurrentUser`, `Roles`
- [ ] Update `libs/auth/src/index.ts` — barrel export for all public symbols
- [ ] Unit tests for `AlbAuthMiddleware`:
  - [ ] Valid `x-amzn-oidc-data` → `request.user` populated correctly
  - [ ] Missing header → `request.user` is null
  - [ ] Malformed base64 → `request.user` is null
  - [ ] `cognito:groups` absent → `roles` defaults to `[]`
- [ ] Unit tests for `RolesGuard`:
  - [ ] No `@Roles()` decorator → passes through
  - [ ] User with matching role → passes
  - [ ] User with wrong role → 403
  - [ ] Null `request.user` → 401

## Checkpoint 5 — API Order: Auth Integration + Role Test Endpoints

- [ ] Add `@org/auth` as a dependency in `apps/api-order/package.json` (or via `nx g @nx/nest:library` workspace link)
- [ ] Import `AuthModule` from `@org/auth` in `apps/api-order/src/app/app.module.ts`
- [ ] Register `AlbAuthMiddleware` globally for all routes in `app.module.ts`
- [ ] Remove any local `auth/` directory from `api-order` (if it existed)
- [ ] Create `apps/api-order/src/app/roles/roles.controller.ts`:
  - [ ] `GET /roles/none` — no guard, no `@Roles()`; returns `{ message: "public endpoint" }`; works with or without auth header
  - [ ] `GET /roles/user` — `@Roles('admin', 'moderator', 'user')` + `RolesGuard`; returns `{ user }` for any authenticated role, 401 if unauthenticated
  - [ ] `GET /roles/moderator` — `@Roles('moderator', 'admin')` + `RolesGuard`; returns `{ user }` or 403
  - [ ] `GET /roles/admin` — `@Roles('admin')` + `RolesGuard`; returns `{ user }` or 403
- [ ] Register `RolesController` in `AppModule`
- [ ] Unit tests for `RolesController`:
  - [ ] `/roles/none` — always 200 regardless of user
  - [ ] `/roles/user` — 200 with user payload when authenticated, 401 when not
  - [ ] `/roles/moderator` — 200 for moderator/admin, 403 for user, 401 for unauthenticated
  - [ ] `/roles/admin` — 200 for admin, 403 for moderator/user, 401 for unauthenticated

## Checkpoint 6 — UI Foundation: shadcn/ui + Tailwind v4

- [ ] Install Tailwind v4 in `apps/web`: `npm install tailwindcss@next @tailwindcss/postcss@next`
- [ ] Update `apps/web/postcss.config.js` to use `@tailwindcss/postcss` plugin
- [ ] Replace `apps/web/app/globals.css` content:
  - [ ] `@import "tailwindcss";` at top
  - [ ] `@theme {}` block with color tokens (`--color-primary`, `--color-secondary`, `--color-muted`, `--color-border`, `--color-background`, `--color-foreground`, `--color-destructive`), `--font-sans`, `--radius`
  - [ ] Remove any v3 `@tailwind base/components/utilities` directives
- [ ] Install shadcn/ui: `npx shadcn@latest init` — select Tailwind v4, set component output to `app/components/ui/`
- [ ] Install required shadcn components: `npx shadcn@latest add button badge avatar dropdown-menu separator`
- [ ] Install utility packages: `npm install clsx tailwind-merge class-variance-authority`
- [ ] Create `apps/web/lib/utils.ts` — export `cn()` helper (clsx + tailwind-merge)
- [ ] Install `prettier-plugin-tailwindcss` and add to Prettier config for automatic class sorting
- [ ] Create component directories: `app/components/ui/`, `app/components/molecules/`, `app/components/organisms/`
- [ ] Verify: run `npm exec nx serve web` — app loads, shadcn button renders, no Tailwind errors

## Checkpoint 7 — Web: User Context + Protected Routes + Header

- [ ] Create `apps/web/lib/get-user.ts`:
  - [ ] Read `x-amzn-oidc-data` from Next.js headers
  - [ ] Decode payload (base64 middle segment), return `{ sub, email, name, familyName, birthdate, phoneNumber, address, picture, gender, locale, zoneinfo, roles }` or `null` — same shape as API `request.user`
- [ ] Create `apps/web/middleware.ts`:
  - [ ] Define public paths: `/`, `/403`, `/nextapi/health`, `/nextapi/sign-out`, `/_next/`, `/favicon.ico`
  - [ ] Tier 1 — authentication: if `x-amzn-oidc-data` absent on a non-public path, redirect to Cognito sign-in URL (built from `COGNITO_DOMAIN` + `COGNITO_CLIENT_ID` + `NEXT_PUBLIC_APP_URL`)
  - [ ] Tier 2 — role guard: decode roles; `/manage` requires `['admin','moderator']`, `/admin` requires `['admin']`; others → redirect to `/403`
- [ ] Create `apps/web/app/nextapi/sign-out/route.ts`:
  - [ ] Build logout URL: `https://${COGNITO_DOMAIN}/logout?client_id=${COGNITO_CLIENT_ID}&logout_uri=${NEXT_PUBLIC_APP_URL}`
  - [ ] Return 302 redirect to Cognito Hosted UI logout endpoint on `amazoncognito.com`
- [ ] Create `apps/web/app/components/molecules/auth-buttons.tsx`:
  - [ ] Server component — renders two `<Button>` atoms side by side, shown when unauthenticated
  - [ ] **Sign Up** (left, `variant="secondary"`): `https://${COGNITO_DOMAIN}/signup?client_id=${COGNITO_CLIENT_ID}&response_type=code&redirect_uri=${NEXT_PUBLIC_APP_URL}`
  - [ ] **Sign In** (right, `variant="primary"`): `https://${COGNITO_DOMAIN}/login?client_id=${COGNITO_CLIENT_ID}&response_type=code&redirect_uri=${NEXT_PUBLIC_APP_URL}`
  - [ ] Uses `cn()` for class composition, no inline styles
  - [ ] Env vars injected by ECS task definition from SSM
- [ ] Create `apps/web/app/components/molecules/avatar-dropdown.tsx`:
  - [ ] Accepts `user: { name, familyName, picture, roles }` prop
  - [ ] Trigger: circular avatar + "FirstName LastName" text + chevron
    - [ ] If `user.picture` is set: render as `<img src={picture}>` with circular clip
    - [ ] If `user.picture` is null/absent: render initials (first letter of `name` + first letter of `familyName`)
  - [ ] Dropdown items (role-conditional, not rendered if inaccessible):
    - [ ] "Manage" link → `/manage` (shown for `moderator` + `admin`)
    - [ ] "Admin" link → `/admin` (shown for `admin` only)
    - [ ] Separator
    - [ ] "Logout" link → `/nextapi/sign-out`
  - [ ] Dropdown closes on outside click or Escape key
  - [ ] Unit test: `user` role → only Logout; `moderator` → Manage + Logout; `admin` → Manage + Admin + Logout
- [ ] Create `apps/web/app/components/organisms/header.tsx`:
  - [ ] Server component — left side: app name + "Home" link; right side: calls `getUser()` — renders `<AuthButtons>` when null, `<AvatarDropdown>` when authenticated
  - [ ] Uses `<Separator>` atom from `ui/` for visual dividers if needed
- [ ] Replace `apps/web/app/page.tsx` (home):
  - [ ] Remove all Nx boilerplate (SVGs, external links, Nx branding)
  - [ ] Clean heading and page content (public — works for authenticated and unauthenticated)
- [ ] Create `apps/web/app/manage/page.tsx`:
  - [ ] Heading: "Manage"
  - [ ] Shows authenticated user's name and role
  - [ ] Placeholder content for future management features
- [ ] Create `apps/web/app/admin/page.tsx`:
  - [ ] Heading: "Admin"
  - [ ] Shows authenticated user's name and role
  - [ ] Placeholder content for future admin features
- [ ] Create `apps/web/app/403/page.tsx`:
  - [ ] Heading: "Access Denied"
  - [ ] Message: "You don't have permission to view this page."
  - [ ] Link back to home (`/`)
- [ ] Update `apps/web/app/layout.tsx`:
  - [ ] Include `<Header>` in shared layout
  - [ ] Remove Nx boilerplate styles/classes
- [ ] Unit tests for `getUser()` (valid header → decoded object, missing header → null, malformed payload → null)
- [ ] Unit tests for middleware (unauthenticated on protected path → Cognito redirect, public path → passes, `moderator` on `/admin` → `/403`, `admin` on `/admin` → passes)

## Checkpoint 8 — Local Dev Support

- [ ] Add `LOCAL_AUTH_BYPASS` env var support to `AlbAuthMiddleware` in `libs/auth` — if set, inject a configurable mock user (e.g. `LOCAL_AUTH_ROLE=admin`)
- [ ] Add `LOCAL_AUTH_BYPASS` support to web middleware — if set, skip redirect check
- [ ] Document local dev setup in `docs/rbac-cognito.md`:
  - [ ] How to set `LOCAL_AUTH_BYPASS` and mock role
  - [ ] How to manually set `x-amzn-oidc-data` header for testing specific roles
  - [ ] How to create test users in Cognito and assign them to groups
  - [ ] Note: middleware is defense-in-depth — ALB is the primary auth gate in production; middleware is primary in local dev

## Checkpoint 9 — Integration & E2E Tests

- [ ] API integration test: `GET /api/health` with no auth header → 200
- [ ] API integration test: `GET /roles/none` with no auth header → 200
- [ ] API integration test: `GET /roles/user` with valid `x-amzn-oidc-data` → 200 with user payload
- [ ] API integration test: `GET /roles/admin` with moderator token → 403
- [ ] API integration test: request with valid `x-amzn-oidc-data` → `request.user` populated
- [ ] Web E2E test: unauthenticated request to `/` → 200 (public home, no redirect)
- [ ] Web E2E test: unauthenticated request to `/manage` → 302 redirect to Cognito domain
- [ ] Web E2E test: `/nextapi/health` with no auth header → 200 (exempt from auth)
- [ ] Web E2E test: `user` role request to `/manage` → redirected to `/403`
- [ ] Web E2E test: `moderator` role request to `/admin` → redirected to `/403`
- [ ] Web E2E test: `admin` role request to `/admin` → 200

## Checkpoint 10 — Documentation

- [ ] Create `docs/ui-standards.md`:
  - [ ] Stack summary table (Tailwind v4, shadcn/ui, CVA, atomic design)
  - [ ] Tailwind v4 setup: `@theme {}` tokens, no config file
  - [ ] Component hierarchy diagram (`ui/` → `molecules/` → `organisms/`)
  - [ ] Layer rules table (state, business logic, imports allowed)
  - [ ] Server vs Client component decision guide
  - [ ] `cn()` usage with examples
  - [ ] CVA variants pattern with example
  - [ ] Tailwind class ordering rule (defer to prettier-plugin-tailwindcss)
  - [ ] Accessibility guidelines
  - [ ] Anti-patterns section (inline styles, implicit any props, manual class concat)
- [ ] Create `docs/rbac-cognito.md`:
  - [ ] Architecture overview (ALB OIDC flow diagram)
  - [ ] Roles: admin, moderator, user — what each maps to (note: permission enforcement deferred)
  - [ ] How `x-amzn-oidc-data` header works and what claims it contains
  - [ ] `@CurrentUser()` and `@Roles()` decorator usage examples
  - [ ] Sign-out flow
  - [ ] Local development setup
  - [ ] Seed script: how to run `seed-cognito.sh`, what `COGNITO_SEED_PASSWORD` to set, what users are created
  - [ ] Terraform: how to add users to groups via console or AWS CLI
- [ ] Update `infra/README.md` to reference the new Cognito module
- [ ] Run all tests: `npm exec -- nx run-many -t test`
- [ ] Verify no regressions in existing health check tests
