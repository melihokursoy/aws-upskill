# ---------------------------------------------------------------------------
# Web Application (Next.js) — Multi-stage Docker build
#
# Stage 1 (deps):    Install production + dev dependencies
# Stage 2 (builder): Build the Next.js app with NX
# Stage 3 (runner):  Minimal runtime image using Next.js standalone output
#
# Standalone output (next.config.js output: 'standalone') creates a
# self-contained server at .next/standalone/server.js — no node_modules needed.
#
# Build context: project root (monorepo root)
# ---------------------------------------------------------------------------

FROM node:20-alpine AS deps
WORKDIR /monorepo

# Copy root package files needed for npm install
COPY package.json package-lock.json ./

# Install all dependencies (dev included — needed for nx build)
RUN npm install

# ---------------------------------------------------------------------------
# Builder stage — run NX build for the web app
# ---------------------------------------------------------------------------

FROM node:20-alpine AS builder
WORKDIR /monorepo

# Copy installed dependencies from deps stage
COPY --from=deps /monorepo/node_modules ./node_modules

# Copy all workspace config files required by NX and ESLint
COPY package.json package-lock.json nx.json tsconfig.base.json tsconfig.json eslint.config.mjs ./

# Copy the web app source
COPY apps/web ./apps/web

# Sync NX workspace (fixes tsconfig project references — required in non-interactive environments)
# Disable daemon since it's not available inside Docker
ENV NX_DAEMON=false

RUN npx nx sync

# Build Next.js app via NX
# Output lands in apps/web/.next (standalone mode enabled in next.config.js)
RUN npx nx build web --prod

# ---------------------------------------------------------------------------
# Runner stage — minimal production image
# ---------------------------------------------------------------------------

FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3300
ENV HOSTNAME=0.0.0.0

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy Next.js standalone server (self-contained, no node_modules needed)
COPY --from=builder --chown=nextjs:nodejs /monorepo/apps/web/.next/standalone ./

# Copy static assets (JS, CSS chunks served by Next.js)
COPY --from=builder --chown=nextjs:nodejs /monorepo/apps/web/.next/static ./apps/web/.next/static

# Copy public folder (images, fonts, etc.)
COPY --from=builder --chown=nextjs:nodejs /monorepo/apps/web/public ./apps/web/public

USER nextjs

EXPOSE 3300

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O- http://localhost:3300/api/health || exit 1

# The standalone server.js is placed relative to the app root in the monorepo
CMD ["node", "apps/web/server.js"]
