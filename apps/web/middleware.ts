import { NextRequest, NextResponse } from 'next/server';

const PUBLIC_PATHS = new Set(['/', '/403', '/nextapi/health', '/nextapi/sign-out']);
const PUBLIC_PREFIXES = ['/_next/', '/favicon.ico'];

// Routes and the minimum roles needed to access them
const ROLE_REQUIREMENTS: Record<string, string[]> = {
  '/manage': ['admin', 'moderator'],
  '/admin': ['admin'],
};

function isPublic(pathname: string): boolean {
  if (PUBLIC_PATHS.has(pathname)) return true;
  return PUBLIC_PREFIXES.some((prefix) => pathname.startsWith(prefix));
}

function decodeRoles(oidcData: string): string[] {
  try {
    const parts = oidcData.split('.');
    if (parts.length !== 3) return [];
    const payloadBase64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = payloadBase64.padEnd(
      payloadBase64.length + ((4 - (payloadBase64.length % 4)) % 4),
      '='
    );
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const claims: Record<string, any> = JSON.parse(
      Buffer.from(padded, 'base64').toString('utf8')
    );
    return Array.isArray(claims['cognito:groups']) ? claims['cognito:groups'] : [];
  } catch {
    return [];
  }
}

function buildSignInUrl(pathname: string): string {
  const domain = process.env.COGNITO_DOMAIN ?? '';
  const clientId = process.env.COGNITO_CLIENT_ID ?? '';
  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? '';
  const redirectUri = encodeURIComponent(appUrl);
  const state = encodeURIComponent(pathname);
  return `https://${domain}/login?client_id=${clientId}&response_type=code&redirect_uri=${redirectUri}&state=${state}`;
}

export function middleware(request: NextRequest): NextResponse {
  const { pathname } = request.nextUrl;

  // Pass public paths through unconditionally
  if (isPublic(pathname)) return NextResponse.next();

  const oidcData = request.headers.get('x-amzn-oidc-data');

  // Tier 1 — authentication: no valid session header → redirect to Cognito
  if (!oidcData) {
    return NextResponse.redirect(buildSignInUrl(pathname));
  }

  // Tier 2 — role check for protected routes
  const requiredRoles = ROLE_REQUIREMENTS[pathname] ?? ROLE_REQUIREMENTS[Object.keys(ROLE_REQUIREMENTS).find((r) => pathname.startsWith(r)) ?? ''];

  if (requiredRoles && requiredRoles.length > 0) {
    const userRoles = decodeRoles(oidcData);
    const hasRole = requiredRoles.some((r) => userRoles.includes(r));
    if (!hasRole) {
      return NextResponse.redirect(new URL('/403', request.url));
    }
  }

  return NextResponse.next();
}

export const config = {
  // Run middleware on all routes except Next.js internal paths and static files
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
