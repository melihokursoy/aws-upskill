import { NextRequest, NextResponse } from 'next/server';

/**
 * GET /auth/signin?returnTo=<path>
 *
 * This route exists solely to trigger the ALB's authenticate-cognito flow and then
 * return the user to where they came from.
 *
 * Why a dedicated route instead of linking directly to the destination page:
 *   - The home page (/) uses on_unauthenticated_request=allow, so navigating there
 *     doesn't trigger the ALB auth flow.
 *   - /auth/signin falls under the ALB's /* catch-all rule (authenticate), so any
 *     unauthenticated request here is redirected to Cognito by the ALB — which owns
 *     the full stateful OAuth flow (state param, /oauth2/idpresponse callback, cookie).
 *   - Once authenticated, the ALB forwards back to this route with the returnTo param
 *     intact, and this handler redirects the user to their original page.
 *
 * Security: returnTo is validated to be a relative path to prevent open redirect attacks.
 */
export async function GET(request: NextRequest): Promise<NextResponse> {
  const returnTo = request.nextUrl.searchParams.get('returnTo') ?? '/';
  // Only allow relative paths — reject anything with a host (e.g. //evil.com or https://...)
  const safePath =
    returnTo.startsWith('/') && !returnTo.startsWith('//') ? returnTo : '/';

  // Use NEXT_PUBLIC_APP_URL as the base — request.url reflects the internal container
  // binding address (HOSTNAME=0.0.0.0, PORT=3300) not the external ALB/domain URL.
  const baseUrl =
    process.env.NEXT_PUBLIC_APP_URL ??
    `${request.nextUrl.protocol}//${
      request.headers.get('x-forwarded-host') ?? request.nextUrl.host
    }`;

  return NextResponse.redirect(new URL(safePath, baseUrl));
}
