# ---------------------------------------------------------------------------
# API Application (NestJS) — Multi-stage Docker build
#
# Stage 1 (deps):    Install all dependencies (dev + prod, needed for nx build)
# Stage 2 (builder): Build the NestJS app via NX
# Stage 3 (runner):  Minimal runtime — only dist/main.js needed
#
# webpack.config.js sets externalDependencies: 'none' which bundles all
# node_modules into main.js. No node_modules needed at runtime.
#
# Build context: project root (monorepo root)
# ---------------------------------------------------------------------------

FROM node:20-alpine AS deps
WORKDIR /monorepo

COPY package.json package-lock.json ./
RUN npm install

# ---------------------------------------------------------------------------
# Builder stage — run NX build for the API app
# ---------------------------------------------------------------------------

FROM node:20-alpine AS builder
WORKDIR /monorepo

COPY --from=deps /monorepo/node_modules ./node_modules

# Copy all workspace config files required by NX and ESLint
COPY package.json package-lock.json nx.json tsconfig.base.json tsconfig.json eslint.config.mjs ./

# Copy the API app source
COPY apps/api-order ./apps/api-order

# Sync NX workspace (fixes tsconfig project references — required in non-interactive environments)
ENV NX_DAEMON=false

RUN npx nx sync

# Build NestJS app via NX (all deps bundled into dist/main.js via externalDependencies: 'none')
RUN npx nx build api-order --prod

# ---------------------------------------------------------------------------
# Runner stage — minimal production image
# ---------------------------------------------------------------------------

FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3301

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nestjs

# Copy the self-contained webpack bundle (no node_modules needed)
COPY --from=builder --chown=nestjs:nodejs /monorepo/apps/api-order/dist/main.js ./main.js

USER nestjs

EXPOSE 3301

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O- http://localhost:3301/api/health || exit 1

CMD ["node", "main.js"]
