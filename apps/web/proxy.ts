import { NextRequest, NextResponse } from 'next/server';

const PUBLIC_PATHS = new Set(['/', '/403', '/nextapi/health', '/auth/signin', '/auth/signout']);
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

function decodeRoles(accessToken: string | null): string[] {
  if (!accessToken) return [];
  try {
    const parts = accessToken.split('.');
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

/**
 * Builds a Cognito Hosted UI login URL for unauthenticated requests.
 *
 * ⚠️  WARNING — stateful ALB callback limitation:
 * The ALB's /oauth2/idpresponse endpoint only completes token exchanges for auth flows
 * the ALB itself initiated. It generates and validates its own state parameter.
 * A URL built here bypasses the ALB's state, so the callback returns 401 and sets no cookie.
 *
 * This function is therefore only safe to call in LOCAL DEV (no ALB present).
 * In production, the ALB's authenticate-cognito rule intercepts unauthenticated requests
 * for ALL protected paths before they reach Next.js, so this code path is never hit.
 * Public paths (/, /403, etc.) pass through isPublic() above and never reach here.
 *
 * redirect_uri is still /oauth2/idpresponse so it matches Cognito's callback_urls list,
 * but in local dev there is no ALB listening at that path — LOCAL_AUTH_BYPASS=true should
 * be used instead, which returns before this function is called.
 */
function buildSignInUrl(pathname: string): string {
  const domain = process.env.COGNITO_DOMAIN ?? '';
  const clientId = process.env.COGNITO_CLIENT_ID ?? '';
  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? '';
  const redirectUri = encodeURIComponent(`${appUrl}/oauth2/idpresponse`);
  const state = encodeURIComponent(pathname);
  return `${domain}/login?client_id=${clientId}&response_type=code&redirect_uri=${redirectUri}&state=${state}`;
}

export function proxy(request: NextRequest): NextResponse {
  const { pathname } = request.nextUrl;

  // Pass public paths through unconditionally
  if (isPublic(pathname)) return NextResponse.next();

  // Local dev bypass — skip Cognito redirect but still enforce role checks
  // using LOCAL_AUTH_ROLE so role-based access behaves as in production.
  if (process.env.LOCAL_AUTH_BYPASS === 'true') {
    const requiredRoles = ROLE_REQUIREMENTS[pathname] ?? ROLE_REQUIREMENTS[Object.keys(ROLE_REQUIREMENTS).find((r) => pathname.startsWith(r)) ?? ''];
    if (requiredRoles && requiredRoles.length > 0) {
      const userRole = process.env.LOCAL_AUTH_ROLE ?? 'admin';
      if (!requiredRoles.includes(userRole)) {
        return NextResponse.redirect(new URL('/403', request.url));
      }
    }
    return NextResponse.next();
  }

  const oidcData = request.headers.get('x-amzn-oidc-data');

  // Tier 1 — authentication: no valid session header → redirect to Cognito
  if (!oidcData) {
    return NextResponse.redirect(buildSignInUrl(pathname));
  }

  // Tier 2 — role check for protected routes
  // Roles come from the access token (x-amzn-oidc-accesstoken) which contains
  // cognito:groups. The userinfo-derived x-amzn-oidc-data header does not include groups.
  const requiredRoles = ROLE_REQUIREMENTS[pathname] ?? ROLE_REQUIREMENTS[Object.keys(ROLE_REQUIREMENTS).find((r) => pathname.startsWith(r)) ?? ''];

  if (requiredRoles && requiredRoles.length > 0) {
    const userRoles = decodeRoles(request.headers.get('x-amzn-oidc-accesstoken'));
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
