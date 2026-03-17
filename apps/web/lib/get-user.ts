import { headers } from 'next/headers';

export interface WebUser {
  sub: string;
  email: string;
  name: string;
  familyName: string | null;
  birthdate: string | null;
  phoneNumber: string | null;
  address: string | null;
  picture: string | null;
  gender: string | null;
  locale: string | null;
  zoneinfo: string | null;
  roles: string[];
}

/**
 * Reads the x-amzn-oidc-data header injected by the ALB after authenticate-cognito
 * and decodes the JWT payload into a typed user object.
 *
 * Must be called inside a Server Component or Route Handler (Next.js headers() API).
 * Returns null when the header is absent (unauthenticated) or malformed.
 */
export async function getUser(): Promise<WebUser | null> {
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

    return {
      sub: claims['sub'] ?? '',
      email: claims['email'] ?? '',
      name: claims['name'] ?? '',
      familyName: claims['family_name'] ?? null,
      birthdate: claims['birthdate'] ?? null,
      phoneNumber: claims['phone_number'] ?? null,
      address: claims['address'] ?? null,
      picture: claims['picture'] ?? null,
      gender: claims['gender'] ?? null,
      locale: claims['locale'] ?? null,
      zoneinfo: claims['zoneinfo'] ?? null,
      roles: Array.isArray(claims['cognito:groups']) ? claims['cognito:groups'] : [],
    };
  } catch {
    return null;
  }
}
