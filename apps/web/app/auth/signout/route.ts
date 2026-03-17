import { NextResponse } from 'next/server';

/**
 * GET /auth/signout
 *
 * Clears the ALB session cookies, then redirects to Cognito's logout endpoint.
 *
 * Two-step reason: Cognito logout clears the Cognito session, but the ALB's own
 * AWSELBAuthSessionCookie remains valid in the browser until it expires. Without
 * expiring it here the user returns to the app still appearing authenticated.
 * The ALB sets up to two numbered cookies (AWSELBAuthSessionCookie-0/1).
 */
export async function GET(): Promise<NextResponse> {
  // In local dev there is no real ALB session — skip Cognito logout and go straight home.
  if (process.env.LOCAL_AUTH_BYPASS === 'true') {
    return NextResponse.redirect(
      new URL('/', process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000')
    );
  }

  const domain = process.env.COGNITO_DOMAIN ?? '';
  const clientId = process.env.COGNITO_CLIENT_ID ?? '';
  const logoutUri = encodeURIComponent(process.env.NEXT_PUBLIC_APP_URL ?? '/');

  const logoutUrl = `${domain}/logout?client_id=${clientId}&logout_uri=${logoutUri}`;

  const response = NextResponse.redirect(logoutUrl, { status: 302 });

  const expired =
    'expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; secure; httponly; samesite=none';
  response.headers.append(
    'Set-Cookie',
    `AWSELBAuthSessionCookie-0=; ${expired}`
  );
  response.headers.append(
    'Set-Cookie',
    `AWSELBAuthSessionCookie-1=; ${expired}`
  );

  return response;
}
