import { NextResponse } from 'next/server';

/**
 * GET /nextapi/sign-out
 *
 * Redirects to Cognito's logout endpoint, which clears the Cognito session.
 * The ALB session cookie expires when Cognito invalidates the session.
 * After logout Cognito redirects to NEXT_PUBLIC_APP_URL (the public home page).
 */
export async function GET(): Promise<NextResponse> {
  const domain = process.env.COGNITO_DOMAIN ?? '';
  const clientId = process.env.COGNITO_CLIENT_ID ?? '';
  const logoutUri = encodeURIComponent(process.env.NEXT_PUBLIC_APP_URL ?? '/');

  const logoutUrl = `https://${domain}/logout?client_id=${clientId}&logout_uri=${logoutUri}`;

  return NextResponse.redirect(logoutUrl, { status: 302 });
}
