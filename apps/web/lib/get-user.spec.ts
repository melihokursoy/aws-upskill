/**
 * Tests for getUser() — decodes x-amzn-oidc-data JWT payload from ALB header.
 * next/headers is mocked so these tests run outside a Next.js request context.
 */

jest.mock('next/headers', () => ({
  headers: jest.fn(),
}));

import { headers } from 'next/headers';
import { getUser } from './get-user';

function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'ES256' })).toString(
    'base64url'
  );
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.fakesig`;
}

function mockHeaders(oidcData: string | null, accessToken?: string | null) {
  (headers as jest.Mock).mockResolvedValue({
    get: jest.fn().mockImplementation((name: string) => {
      if (name === 'x-amzn-oidc-data') return oidcData;
      if (name === 'x-amzn-oidc-accesstoken') return accessToken ?? null;
      return null;
    }),
  });
}

describe('getUser() — LOCAL_AUTH_BYPASS', () => {
  beforeEach(() => {
    delete process.env.LOCAL_AUTH_BYPASS;
    delete process.env.LOCAL_AUTH_ROLE;
    delete process.env.LOCAL_AUTH_EMAIL;
    delete process.env.LOCAL_AUTH_NAME;
  });
  afterEach(() => {
    delete process.env.LOCAL_AUTH_BYPASS;
    delete process.env.LOCAL_AUTH_ROLE;
    delete process.env.LOCAL_AUTH_EMAIL;
    delete process.env.LOCAL_AUTH_NAME;
  });

  it('returns a mock admin user when LOCAL_AUTH_BYPASS=true', async () => {
    process.env.LOCAL_AUTH_BYPASS = 'true';
    const user = await getUser();
    expect(user).not.toBeNull();
    expect(user!.roles).toEqual(['admin']);
  });

  it('respects LOCAL_AUTH_ROLE when set', async () => {
    process.env.LOCAL_AUTH_BYPASS = 'true';
    process.env.LOCAL_AUTH_ROLE = 'moderator';
    const user = await getUser();
    expect(user!.roles).toEqual(['moderator']);
  });

  it('respects LOCAL_AUTH_EMAIL and LOCAL_AUTH_NAME when set', async () => {
    process.env.LOCAL_AUTH_BYPASS = 'true';
    process.env.LOCAL_AUTH_EMAIL = 'custom@test.com';
    process.env.LOCAL_AUTH_NAME = 'Custom Name';
    const user = await getUser();
    expect(user!.email).toBe('custom@test.com');
    expect(user!.name).toBe('Custom Name');
  });

  it('does not activate bypass when LOCAL_AUTH_BYPASS is not set', async () => {
    mockHeaders(null);
    expect(await getUser()).toBeNull();
  });
});

describe('getUser()', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.LOCAL_AUTH_BYPASS;
  });

  it('returns null when x-amzn-oidc-data header is absent', async () => {
    mockHeaders(null);
    expect(await getUser()).toBeNull();
  });

  it('decodes a valid header into a WebUser object', async () => {
    const oidcPayload = {
      sub: 'sub-abc',
      email: 'user@example.com',
      name: 'Jane Doe',
      given_name: 'Jane',
      family_name: 'Doe',
      birthdate: '1990-01-01',
      phone_number: '+441234567890',
      address: '1 Main St',
      picture: 'https://example.com/pic.svg',
      gender: 'female',
      locale: 'en-GB',
      zoneinfo: 'Europe/London',
    };
    const accessTokenPayload = { 'cognito:groups': ['moderator'] };
    mockHeaders(makeJwt(oidcPayload), makeJwt(accessTokenPayload));

    const user = await getUser();
    expect(user).toEqual({
      sub: 'sub-abc',
      email: 'user@example.com',
      name: 'Jane Doe',
      givenName: 'Jane',
      familyName: 'Doe',
      birthdate: '1990-01-01',
      phoneNumber: '+441234567890',
      address: '1 Main St',
      picture: 'https://example.com/pic.svg',
      gender: 'female',
      locale: 'en-GB',
      zoneinfo: 'Europe/London',
      roles: ['moderator'],
      rawClaims: { ...oidcPayload, 'cognito:groups': ['moderator'] },
    });
  });

  it('defaults optional claims to null when absent', async () => {
    mockHeaders(makeJwt({ sub: 's1', email: 'a@b.com', name: 'A' }));
    const user = await getUser();
    expect(user).not.toBeNull();
    expect(user!.givenName).toBeNull();
    expect(user!.familyName).toBeNull();
    expect(user!.picture).toBeNull();
    expect(user!.roles).toEqual([]);
  });

  it('returns null when the JWT has fewer than 3 parts', async () => {
    mockHeaders('onlyone');
    expect(await getUser()).toBeNull();
  });

  it('returns null when the payload is not valid JSON', async () => {
    const badPayload = Buffer.from('not-json').toString('base64url');
    mockHeaders(`header.${badPayload}.sig`);
    expect(await getUser()).toBeNull();
  });
});
