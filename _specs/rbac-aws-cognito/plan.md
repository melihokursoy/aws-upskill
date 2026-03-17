# Technical Plan: RBAC with AWS Cognito

## Resolved Decisions

- **Sign-in UI**: Cognito Hosted UI on AWS subdomain (`amazoncognito.com`) — no custom domain, no custom sign-in page
- **Token storage**: ALB manages session cookie entirely — apps never handle raw tokens
- **Token refresh**: ALB handles session refresh — no refresh logic in the app
- **Registration**: Self-registration allowed via Cognito Hosted UI sign-up flow
- **Roles**: `admin`, `moderator`, `user` as Cognito User Pool Groups
- **Role permissions**: Deferred to future features — this feature delivers role claims only
- **Shared auth**: `AlbAuthMiddleware`, `RolesGuard`, decorators in `@org/auth` (`libs/auth`)
- **Seeding**: `infra/scripts/seed-cognito.sh` — one test user per role, AWS CLI, runs post-apply
- **Callback URL**: ALB's fixed OIDC callback at `https://<domain>/oauth2/idpresponse` — registered in Cognito User Pool Client `callback_urls`
- **Client secret**: `generate_secret = true` on User Pool Client; ALB retrieves it automatically via IAM — never exposed to browser or app code
- **Home page auth**: Uses `authenticate-cognito` with `on_unauthenticated_request = "allow"` — authenticated users see avatar, unauthenticated users see Sign In
- **Middleware**: Defense-in-depth layer — ALB is the primary auth gate in production; middleware is primary in local dev
- **User claims**: Full OIDC standard claims forwarded — `sub`, `email`, `name`, `family_name`, `birthdate`, `phone_number`, `address`, `picture`, `gender`, `locale`, `zoneinfo`, `cognito:groups`

---

## Architecture Overview

```
Browser
  │
  ▼
ALB (HTTPS listener)
  │  authenticate-cognito action on all protected listener rules
  │  ├── Unauthenticated → redirect to Cognito Hosted UI
  │  └── Authenticated   → forward request + x-amzn-oidc-data header
  │
  ├──► Next.js web (port 3300)
  │      Reads x-amzn-oidc-data → extracts name + cognito:groups → renders UI
  │
  └──► NestJS API (port 3301)
         Reads x-amzn-oidc-data → decodes JWT → exposes @CurrentUser() decorator
         Role guards use cognito:groups for future authorization
```

### ALB OIDC Flow

1. Browser hits a protected route (e.g. `/`)
2. ALB checks for its session cookie — if missing/expired, redirects to Cognito Hosted UI
3. User authenticates (sign-in or sign-up) on Cognito Hosted UI
4. Cognito redirects back to ALB callback with authorization code
5. ALB exchanges code for tokens, creates encrypted session cookie, sets it on the browser
6. ALB forwards original request to the backend with three headers:
   - `x-amzn-oidc-data` — JWT containing user claims including `cognito:groups`
   - `x-amzn-oidc-accesstoken` — raw Cognito access token
   - `x-amzn-oidc-identity` — user's sub (UUID)
7. Applications decode `x-amzn-oidc-data` (no signature verification needed — ALB already validated it)
8. Role claims are extracted from `cognito:groups` array in the decoded payload

### Sign-out Flow

1. Browser hits `/nextapi/sign-out` (a Next.js route handler)
2. Route handler redirects to `https://<cognito-domain>/logout?client_id=<id>&logout_uri=<url>`
3. Cognito clears its session
4. ALB session cookie expires (ALB cookie TTL matches Cognito session)
5. Browser lands on the post-logout redirect URI (e.g. the public home or sign-in page)

---

## Infrastructure Changes (Terraform)

### New Module: `infra/modules/cognito/`

**Resources to create:**

- `aws_cognito_user_pool` — user pool with self-registration enabled, email as username
- `aws_cognito_user_pool_domain` — hosted UI AWS subdomain prefix (`${project_name}-${environment_name}`), resulting in `https://${project_name}-${environment_name}.auth.${region}.amazoncognito.com` — no custom domain
- `aws_cognito_user_pool_client` — app client configured for ALB OIDC: Authorization Code Grant, `generate_secret = true` (ALB retrieves secret via IAM — never exposed to browser or app code), `allowed_oauth_scopes = ["openid", "email", "profile", "phone"]`; `callback_urls = ["https://${app_domain}/oauth2/idpresponse"]` (ALB's fixed OIDC callback endpoint); `logout_urls = ["https://${app_domain}"]` (post-logout redirect to home); `read_attributes` and `write_attributes` include all standard OIDC claims: `email`, `name`, `given_name`, `family_name`, `picture`, `birthdate`, `phone_number`, `address`, `gender`, `locale`, `zoneinfo`
- `aws_cognito_user_group` × 3 — groups: `admin`, `moderator`, `user`

**Module outputs:**

- `user_pool_id`
- `user_pool_arn`
- `client_id`
- `cognito_domain` (full HTTPS URL)
- `issuer_url` (`https://cognito-idp.<region>.amazonaws.com/<user_pool_id>`)

### Cognito Seed Script (`infra/scripts/seed-cognito.sh`)

A standalone bash script that creates one test user per role and assigns them to their Cognito group. Runs **after** `terraform apply` — the User Pool must already exist.

**Script behaviour:**

- Takes `<env>` argument (same convention as all other infra scripts)
- Reads `user_pool_id` from `terraform output -raw cognito_user_pool_id`
- Idempotent — checks if user already exists before creating
- Creates 3 users:

| Username         | Email                        | Group       |
| ---------------- | ---------------------------- | ----------- |
| `seed-admin`     | `seed-admin@example.com`     | `admin`     |
| `seed-moderator` | `seed-moderator@example.com` | `moderator` |
| `seed-user`      | `seed-user@example.com`      | `user`      |

Each seed user is created with these attributes for testing the full claim pipeline:

- `picture` — DiceBear `avataaars` avatar URL: `https://api.dicebear.com/9.x/avataaars/svg?seed=<username>` (unique per user, free, no API key)
- `given_name`, `family_name` — test values for avatar initials display
- `birthdate`, `gender`, `locale`, `zoneinfo` — sample values so all OIDC claims flow through the JWT end-to-end

- Sets each user's password to permanent state (bypasses Cognito's force-change-password flow) using `admin-set-user-password --permanent`
- Default seed password read from `COGNITO_SEED_PASSWORD` env var (required — not hardcoded); script exits with an error if unset
- `COGNITO_SEED_PASSWORD` should be set in `infra/.env` (already git-ignored)
- Password must meet Cognito complexity: min 8 chars, uppercase, lowercase, number, special char

**Usage:**

```bash
# After terraform apply dev
COGNITO_SEED_PASSWORD=MyTestPass1! ./infra/scripts/seed-cognito.sh dev
```

**Script follows existing patterns from `infra/scripts/`:**

- `set -euo pipefail`
- `log()`, `ok()`, `skip()` helpers
- Reads `.env` from `infra/` if present
- `cd "$INFRA_DIR"` before running Terraform output commands

### ALB Module Updates (`infra/modules/alb/`)

- Add `authenticate-cognito` action as the first action on the HTTPS listener default rule and any protected target group rules
- The authenticate action references the Cognito User Pool ARN, Client ID, and domain
- On unauthentication: `authenticate` (redirect to Cognito Hosted UI)
- Session cookie TTL: 3600 seconds (1 hour)
- Home page (`/`) uses `authenticate-cognito` with `on_unauthenticated_request = "allow"` — ALB forwards OIDC headers if the user has a valid session, passes the request through without headers if not. This allows the home page to render auth state (avatar dropdown) for authenticated users while remaining accessible to unauthenticated users.
- Other public paths (`/403`, `/nextapi/health`, `/api/health`, `/api/db-health`) use separate listener rules with `allow` action at higher priority — no auth processing

**New ALB module variables:**

- `cognito_user_pool_arn`
- `cognito_user_pool_client_id`
- `cognito_user_pool_domain`

**New Cognito module variables (in addition to `project_name`, `environment_name`, `region`, `tags`):**

- `app_domain` — domain name used for `callback_urls` and `logout_urls` (e.g., `dev.aws-upskill.codecrib.co.uk`), passed from `var.domain_name` in root module

### SSM Parameter Store (`infra/modules/ssm/`)

Add new parameters so containers can read Cognito config at startup:

- `/app/cognito/user_pool_id`
- `/app/cognito/client_id`
- `/app/cognito/issuer_url`
- `/app/cognito/domain`

### Root Module (`infra/main.tf`)

- Add `module "cognito"` block
- Pass Cognito outputs to `module "alb"` and `module "ssm"`

---

## Shared Auth Library (`libs/auth` → `@org/auth`)

All auth primitives live in a shared Nx library so every NestJS API service can import them without duplicating code.

### Library: `libs/auth`

- **Package name**: `@org/auth`
- **Type**: Nx library (Node/NestJS, not publishable — workspace-internal only)
- **Generator**: `nx g @nx/nest:library auth --directory=libs/auth`

**Exports:**

| Export              | Description                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `AlbAuthMiddleware` | NestJS middleware — reads `x-amzn-oidc-data`, decodes JWT payload, sets `request.user`                           |
| `CurrentUser`       | Parameter decorator returning `request.user` from execution context                                              |
| `Roles`             | Metadata decorator: `@Roles('admin', 'moderator')`                                                               |
| `RolesGuard`        | Guard that checks `request.user.roles` against required roles — 401 if unauthenticated, 403 if insufficient role |
| `AuthModule`        | NestJS module that exports middleware, guard, and decorators                                                     |

**`request.user` shape (set by `AlbAuthMiddleware`):**

```
{
  sub: string,               // Cognito user UUID
  email: string,
  name: string,              // full display name
  familyName: string | null, // family_name claim
  birthdate: string | null,  // ISO date string
  phoneNumber: string | null,// phone_number claim
  address: string | null,    // address claim (JSON string)
  picture: string | null,    // URL to profile image; null if not set
  gender: string | null,
  locale: string | null,
  zoneinfo: string | null,   // timezone (OIDC zoneinfo claim)
  roles: string[],           // cognito:groups array, e.g. ["admin"]
}
```

If `x-amzn-oidc-data` header is absent or malformed, `request.user` is set to `null`.

**Middleware behaviour:**

- Reads `x-amzn-oidc-data` header
- Base64-decodes the middle JWT segment (payload only — no signature verification; ALB already validated the token)
- Maps JWT claims to camelCase properties: `family_name` → `familyName`, `phone_number` → `phoneNumber`, `cognito:groups` → `roles`
- Defaults optional string claims to `null` if absent; defaults `roles` to `[]` if `cognito:groups` is absent
- Sets `request.user = null` on any error (missing header, malformed base64, invalid JSON)

---

## API Changes (NestJS — `apps/api-order`)

### Import Auth from Shared Library

- `apps/api-order` imports `AuthModule` from `@org/auth`
- No local `auth/` directory in `api-order` — all primitives come from the shared library
- `AlbAuthMiddleware` registered globally via `app.module.ts`

### Health Check Exemption

- `/api/health` and `/api/db-health` remain public (ALB `allow` rules)
- The ALB listener rules for `/`, `/403`, and health check paths use `allow` action at higher priority

### Role Test Endpoints (`RolesController`)

Example endpoints in `api-order` that demonstrate RBAC in action and serve as integration test targets.

**Base path:** `/roles`

| Endpoint               | Auth required | Role required          | Returns                          |
| ---------------------- | ------------- | ---------------------- | -------------------------------- |
| `GET /roles/none`      | No            | None                   | `{ message: "public endpoint" }` |
| `GET /roles/user`      | Yes           | Any authenticated      | `{ user: <decoded payload> }`    |
| `GET /roles/moderator` | Yes           | `moderator` or `admin` | `{ user: <decoded payload> }`    |
| `GET /roles/admin`     | Yes           | `admin` only           | `{ user: <decoded payload> }`    |

**Implementation details:**

- `GET /roles/none` — no `@Roles()` and no guard; `request.user` may be null; intentionally public
- `GET /roles/user` — `@Roles('admin', 'moderator', 'user')` + `RolesGuard`; returns 401 if unauthenticated, allows any authenticated role
- `GET /roles/moderator` — `@Roles('moderator', 'admin')` + `RolesGuard`
- `GET /roles/admin` — `@Roles('admin')` + `RolesGuard`
- All authenticated endpoints return the full decoded `request.user` object as `{ user }` — useful for verifying claims in dev/test

---

## UI Architecture & Standards

### Stack

| Concern            | Choice                         | Reason                                                                      |
| ------------------ | ------------------------------ | --------------------------------------------------------------------------- |
| Styling            | Tailwind v4                    | CSS-first config, no `tailwind.config.js`, native CSS cascade layers        |
| Component base     | shadcn/ui                      | Radix UI primitives + Tailwind, copy-paste ownership, no runtime dependency |
| Component pattern  | Atomic design                  | Clear hierarchy, prevents coupling, promotes reuse                          |
| Design tokens      | `@theme {}` in CSS             | Tailwind v4 native, single source of truth                                  |
| Class merging      | `cn()` (clsx + tailwind-merge) | Safe conditional classes, resolves Tailwind conflicts                       |
| Component variants | CVA (class-variance-authority) | Type-safe variant props, scales cleanly                                     |

---

### Tailwind v4 Setup

Tailwind v4 replaces `tailwind.config.js` with CSS-based configuration. All theme customisation lives in `apps/web/app/globals.css`:

```css
@import 'tailwindcss';

@theme {
  --color-primary: oklch(55% 0.2 250);
  --color-primary-foreground: oklch(98% 0 0);
  --color-secondary: oklch(92% 0.01 250);
  --color-secondary-foreground: oklch(20% 0 0);
  --color-muted: oklch(96% 0.005 250);
  --color-muted-foreground: oklch(45% 0 0);
  --color-destructive: oklch(55% 0.22 25);
  --color-border: oklch(90% 0.005 250);
  --color-background: oklch(100% 0 0);
  --color-foreground: oklch(10% 0 0);

  --font-sans: 'Inter', sans-serif;
  --radius: 0.5rem;
}
```

Tokens are then available as Tailwind utilities: `bg-primary`, `text-primary-foreground`, `border-border`, etc.

---

### Component Hierarchy (Atomic Design)

```
apps/web/app/components/
├── ui/             ← shadcn/ui generated atoms (Radix primitives + Tailwind)
│   ├── button.tsx      Button, ButtonProps, buttonVariants (CVA)
│   ├── badge.tsx       Badge, badgeVariants
│   ├── avatar.tsx      Avatar, AvatarImage, AvatarFallback
│   ├── dropdown-menu.tsx  DropdownMenu, DropdownMenuItem, ...
│   └── separator.tsx   Separator
│
├── molecules/      ← Composed from ui/ atoms; may have local state
│   ├── auth-buttons.tsx    Sign Up + Sign In side by side
│   └── avatar-dropdown.tsx Avatar trigger + role-conditional dropdown
│
└── organisms/      ← Composed from molecules; tied to app context
    └── header.tsx          Full page header with auth state
```

**Rules for each layer:**

| Layer        | Source              | State          | Business logic          | Import from         |
| ------------ | ------------------- | -------------- | ----------------------- | ------------------- |
| `ui/`        | shadcn/ui generated | None           | None — pure UI          | `@/components/ui/*` |
| `molecules/` | Handwritten         | Local only     | None                    | `@/components/ui/*` |
| `organisms/` | Handwritten         | Server context | Yes (reads user, roles) | Both layers above   |

---

### Coding Standards

#### Server vs Client Components

Default to **Server Components**. Add `"use client"` only when the component:

- Uses React hooks (`useState`, `useEffect`, etc.)
- Attaches browser event listeners
- Uses browser-only APIs

```
organisms/header.tsx     → Server (reads headers via getUser())
molecules/avatar-dropdown.tsx → Client (dropdown open/close state)
molecules/auth-buttons.tsx    → Server (just links, no interaction)
ui/button.tsx            → Client (Radix primitive needs client)
```

#### TypeScript Props

All components have explicit TypeScript interfaces. No `any`. No implicit prop spreading without explicit type.

```tsx
// ✅ Correct
interface AvatarDropdownProps {
  user: { name: string; picture: string | null; roles: string[] }
}

// ❌ Wrong
function AvatarDropdown(props: any) { ... }
```

#### Class Merging with `cn()`

All components use `cn()` (clsx + tailwind-merge) for conditional and merged classes:

```tsx
// ✅ Correct — safe merge, resolves conflicts
className={cn("px-4 py-2 rounded", isActive && "bg-primary", className)}

// ❌ Wrong — string concat breaks Tailwind conflict resolution
className={"px-4 py-2 " + (isActive ? "bg-primary" : "")}
```

#### Variants with CVA

Use `cva()` for components with multiple visual variants (size, intent, style):

```tsx
const buttonVariants = cva(
  'inline-flex items-center justify-center rounded font-medium transition',
  {
    variants: {
      variant: {
        primary: 'bg-primary text-primary-foreground hover:bg-primary/90',
        secondary:
          'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        ghost: 'hover:bg-muted hover:text-foreground',
      },
      size: { sm: 'h-8 px-3 text-sm', md: 'h-10 px-4', lg: 'h-12 px-6' },
    },
    defaultVariants: { variant: 'primary', size: 'md' },
  }
);
```

#### Tailwind Class Ordering

Classes are sorted automatically by `prettier-plugin-tailwindcss`. Never manually sort — just run Prettier.

Logical grouping when writing (Prettier enforces final order):

1. Layout (display, position, flex/grid)
2. Sizing (w, h, min/max)
3. Spacing (p, m, gap)
4. Typography (text, font)
5. Visual (bg, border, shadow, rounded)
6. State (hover:, focus:, disabled:)

#### Accessibility

shadcn/ui components are built on Radix UI which handles ARIA attributes, keyboard navigation, and focus management. Never override Radix ARIA props without understanding the impact. All interactive elements must be keyboard-reachable.

#### No Inline Styles

Zero `style={{ }}` props. All styling via Tailwind utilities. Exceptions only for dynamic values that cannot be expressed as utilities (e.g. a runtime pixel width from JS).

---

### Documentation

Standards are documented in `docs/ui-standards.md` for the full reference guide.

---

## Web Changes (Next.js — `apps/web`)

### Page Structure

| Route     | Title     | Public?           | Accessible by                                                     |
| --------- | --------- | ----------------- | ----------------------------------------------------------------- |
| `/`       | Home      | Yes — ALB `allow` | Anyone (unauthenticated sees Sign In; authenticated sees content) |
| `/manage` | Manage    | No                | `moderator` and `admin` only                                      |
| `/admin`  | Admin     | No                | `admin` only                                                      |
| `/403`    | Forbidden | Yes               | Anyone (error page)                                               |

Role access for protected routes is enforced in Next.js middleware — after ALB has authenticated the user. If a role check fails, the user is redirected to `/403`.

**Role guard logic in middleware:**

```
/manage  → requires roles: ['admin', 'moderator']  → others → /403
/admin   → requires roles: ['admin']               → others → /403
```

### Home Page (`/`) — Clean Replace, Public

The existing Nx boilerplate (`apps/web/app/page.tsx`) is replaced entirely. `/` is a public page (no forced auth from ALB — ALB uses `allow` for this path):

- App name heading
- When **unauthenticated** (`getUser()` returns null): shows a "Sign In" button on the right side of the header (see Header section below)
- When **authenticated**: shows avatar dropdown in header

No boilerplate Nx content, no external links to Nx docs, no SVG logos.

### Manage Page (`/manage`)

- Heading: "Manage"
- Displays the authenticated user's name and role
- Placeholder content indicating management functionality will be added in future features
- Navigation back to home via header

### Admin Page (`/admin`)

- Heading: "Admin"
- Displays the authenticated user's name and role
- Placeholder content indicating admin-specific functionality will be added in future features
- Navigation back to home via header

### 403 Forbidden Page (`/403`)

- Heading: "Access Denied"
- Message: "You don't have permission to view this page."
- Link back to home (`/`)
- Does not expose which roles are required

### Server-Side User Context

- A `getUser()` utility reads `x-amzn-oidc-data` from Next.js request headers (available in Route Handlers and Server Components)
- Decodes the JWT payload and returns the same shape as `request.user` in the API: `{ sub, email, name, familyName, birthdate, phoneNumber, address, picture, gender, locale, zoneinfo, roles }`
- Returns `null` if header is absent (unauthenticated or local dev)

### Protected Route Middleware (`middleware.ts`)

Two tiers of checks, in order:

1. **Authentication check**: if `x-amzn-oidc-data` header is absent on a protected path, redirect to Cognito sign-in URL (via Cognito Hosted UI URL built from env vars)
2. **Role check**: decode user roles from `x-amzn-oidc-data`; if roles don't satisfy the route requirement, redirect to `/403`

> **Defense-in-depth**: In production, ALB `authenticate-cognito` prevents unauthenticated requests from reaching protected paths — the middleware auth check is a second line of defense. In local development (no ALB), the middleware is the primary auth gate (unless `LOCAL_AUTH_BYPASS` is set).

Public paths exempt from **both** checks (pass through unconditionally):
`/`, `/403`, `/nextapi/health`, `/nextapi/sign-out`, `/_next/`, `/favicon.ico`

Protected path role requirements:

- `/manage` → `['admin', 'moderator']`
- `/admin` → `['admin']`

### Layout & Navigation

The shared header is present on every page (via root layout). Layout:

```
[App Name]   [Home]                      [Sign In] or [Avatar ▼]
             ← left nav (always visible)    ← right side, role-aware
```

**Right side — auth buttons (unauthenticated):**

- Shown only when `getUser()` returns null
- Two buttons rendered side by side:
  - **Sign Up** (secondary/outline style) — left — links to Cognito Hosted UI `/signup` endpoint
  - **Sign In** (primary style) — right — links to Cognito Hosted UI `/login` endpoint
- URL formats:
  - Sign Up: `https://${COGNITO_DOMAIN}/signup?client_id=${COGNITO_CLIENT_ID}&response_type=code&redirect_uri=${NEXT_PUBLIC_APP_URL}`
  - Sign In: `https://${COGNITO_DOMAIN}/login?client_id=${COGNITO_CLIENT_ID}&response_type=code&redirect_uri=${NEXT_PUBLIC_APP_URL}`

**Right side — Avatar dropdown (authenticated):**

- Trigger: circular avatar + "FirstName LastName" text + chevron
  - Avatar shows `picture` URL as `<img>` if the claim is present and non-empty
  - Falls back to initials (first letter of `name` + first letter of `familyName`) if `picture` is null/absent
- Clicking opens a dropdown menu containing:

| Item          | Shown to             | Action                          |
| ------------- | -------------------- | ------------------------------- |
| **Manage**    | `moderator`, `admin` | Navigate to `/manage`           |
| **Admin**     | `admin` only         | Navigate to `/admin`            |
| _(separator)_ | —                    | —                               |
| **Logout**    | All authenticated    | Redirect to `/nextapi/sign-out` |

- Items the user cannot access are **not rendered** (no disabled state)
- Dropdown closes on outside click or Escape key

The role check in middleware is the authoritative security gate. The dropdown is a UI convenience only.

### Sign-Out Route Handler (`/nextapi/sign-out`)

- Redirects browser to `https://<cognito-domain>/logout?client_id=<id>&logout_uri=<post_logout_uri>`
- `COGNITO_DOMAIN`, `COGNITO_CLIENT_ID`, and `NEXT_PUBLIC_APP_URL` read from environment variables (injected via ECS task definition from SSM)

---

## Environment Variables

Variables added to ECS task definitions (sourced from SSM at deploy time):

**API service:**

- `COGNITO_USER_POOL_ID`
- `COGNITO_CLIENT_ID`
- `COGNITO_ISSUER_URL`

**Web service:**

- `COGNITO_DOMAIN`
- `COGNITO_CLIENT_ID`
- `NEXT_PUBLIC_APP_URL` (for logout redirect URI)

---

## Testing Strategy

### Unit Tests (many)

**API — `AlbAuthMiddleware`:**

- Valid `x-amzn-oidc-data` header → `request.user` populated correctly
- Missing header → `request.user` is null
- Malformed JWT payload → `request.user` is null, no crash
- `cognito:groups` absent → `roles` defaults to empty array

**API — `RolesGuard`:**

- User with matching role → passes (returns true)
- User without matching role → throws `ForbiddenException`
- Null `request.user` on protected route → throws `UnauthorizedException`

**Web — `getUser()` utility:**

- Valid header → decoded user object returned
- Missing header → returns null

### Integration Tests (moderate)

**API routes:**

- `GET /api/health` with no auth header → 200 (exempt)
- `GET /api/db-health` with no auth header → 200 (exempt)
- Request with valid `x-amzn-oidc-data` → `request.user` available in controller

### E2E Tests (few — critical flows only)

- Unauthenticated request to protected web route → redirected (302) to Cognito domain
- Health check endpoints remain accessible without auth headers

---

## Local Development

ALB OIDC only runs in AWS (not locally). For local dev:

- `x-amzn-oidc-data` header can be manually set to a mock base64-encoded JWT payload
- A `LOCAL_AUTH_BYPASS` env var (truthy) makes the middleware/decorator return a mock user with configurable roles
- Health checks and non-protected routes work without any header

---

## File Structure After Implementation

```
infra/
└── modules/
    └── cognito/
        ├── main.tf        # User Pool, Domain, Client, Groups
        ├── variables.tf
        └── outputs.tf

libs/
└── auth/                  # @org/auth — shared NestJS auth library
    └── src/
        ├── index.ts                   # Public API barrel export
        ├── alb-auth.middleware.ts     # Decodes x-amzn-oidc-data → request.user
        ├── current-user.decorator.ts  # @CurrentUser() parameter decorator
        ├── roles.decorator.ts         # @Roles('admin', 'moderator')
        ├── roles.guard.ts             # RolesGuard — 401/403 enforcement
        └── auth.module.ts             # NestJS module exporting all of the above

infra/scripts/
└── seed-cognito.sh          # Creates 1 test user per role; runs after terraform apply

apps/api-order/src/
└── app/
    ├── app.module.ts        # imports AuthModule from @org/auth
    └── roles/
        └── roles.controller.ts  # GET /roles/none|user|moderator|admin

apps/web/
├── middleware.ts              # Auth + role-based route protection
├── lib/
│   └── get-user.ts            # ALB header decoder → { sub, email, name, familyName, ..., roles }
└── app/
    ├── layout.tsx             # Root layout with shared header
    ├── page.tsx               # Home page (public, clean replace of Nx boilerplate)
    ├── manage/
    │   └── page.tsx           # Manage page (moderator + admin)
    ├── admin/
    │   └── page.tsx           # Admin page (admin only)
    ├── 403/
    │   └── page.tsx           # Access denied page (public)
    ├── components/
    │   ├── ui/                    # shadcn/ui generated atoms
    │   │   ├── button.tsx
    │   │   ├── badge.tsx
    │   │   ├── avatar.tsx
    │   │   ├── dropdown-menu.tsx
    │   │   └── separator.tsx
    │   ├── molecules/
    │   │   ├── auth-buttons.tsx   # Sign Up (secondary) + Sign In (primary)
    │   │   └── avatar-dropdown.tsx # Avatar + "First Last" dropdown
    │   └── organisms/
    │       └── header.tsx         # Full page header with auth state
    └── nextapi/
        └── sign-out/
            └── route.ts       # Sign-out redirect handler
```
