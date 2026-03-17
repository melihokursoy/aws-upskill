import { headers } from 'next/headers';

export interface WebUser {
  sub: string;
  email: string;
  name: string;
  givenName: string | null;
  familyName: string | null;
  birthdate: string | null;
  phoneNumber: string | null;
  address: string | null;
  picture: string | null;
  gender: string | null;
  locale: string | null;
  zoneinfo: string | null;
  roles: string[];
  rawClaims: Record<string, unknown>;
}

/**
 * Reads the x-amzn-oidc-data header injected by the ALB after authenticate-cognito
 * and decodes the JWT payload into a typed user object.
 *
 * Must be called inside a Server Component or Route Handler (Next.js headers() API).
 * Returns null when the header is absent (unauthenticated) or malformed.
 *
 * LOCAL DEVELOPMENT: Set LOCAL_AUTH_BYPASS=true to return a mock user without
 * a real ALB session. Respects LOCAL_AUTH_ROLE, LOCAL_AUTH_EMAIL, LOCAL_AUTH_NAME.
 */
export async function getUser(): Promise<WebUser | null> {
  if (process.env.LOCAL_AUTH_BYPASS === 'true') {
    const mockClaims = {
      sub: process.env.LOCAL_AUTH_SUB ?? 'local-dev-sub',
      email: process.env.LOCAL_AUTH_EMAIL ?? 'dev@localhost',
      name: process.env.LOCAL_AUTH_NAME ?? 'Dev User',
      'cognito:groups': [process.env.LOCAL_AUTH_ROLE ?? 'admin'],
    };
    return {
      sub: mockClaims.sub,
      email: mockClaims.email,
      name: mockClaims.name,
      givenName: null,
      familyName: null,
      birthdate: null,
      phoneNumber: null,
      address: null,
      picture: null,
      gender: null,
      locale: null,
      zoneinfo: null,
      roles: mockClaims['cognito:groups'],
      rawClaims: mockClaims,
    };
  }

  const headerStore = await headers();
  const oidcData = headerStore.get('x-amzn-oidc-data');

  if (!oidcData) return null;

  try {
    const parts = oidcData.split('.');
    if (parts.length !== 3) return null;

    const payloadBase64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = payloadBase64.padEnd(
      payloadBase64.length + ((4 - (payloadBase64.length % 4)) % 4),
      '='
    );
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const claims: Record<string, any> = JSON.parse(
      Buffer.from(padded, 'base64').toString('utf8')
    );

    // Roles come from the access token — cognito:groups is not in the userinfo-derived
    // x-amzn-oidc-data header. The ALB also forwards x-amzn-oidc-accesstoken which
    // is the raw Cognito access token JWT and always contains cognito:groups.
    const roles = decodeAccessTokenRoles(headerStore.get('x-amzn-oidc-accesstoken'));

    return {
      sub: claims['sub'] ?? '',
      email: claims['email'] ?? '',
      name: claims['name'] ?? '',
      givenName: claims['given_name'] ?? null,
      familyName: claims['family_name'] ?? null,
      birthdate: claims['birthdate'] ?? null,
      phoneNumber: claims['phone_number'] ?? null,
      address: claims['address'] ?? null,
      picture: claims['picture'] ?? null,
      gender: claims['gender'] ?? null,
      locale: claims['locale'] ?? null,
      zoneinfo: claims['zoneinfo'] ?? null,
      roles,
      // Merge resolved roles into rawClaims so display components (e.g. JwtPayload)
      // see cognito:groups even though it came from a separate header.
      rawClaims: { ...claims, 'cognito:groups': roles },
    };
  } catch {
    return null;
  }
}

function decodeAccessTokenRoles(accessToken: string | null): string[] {
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
