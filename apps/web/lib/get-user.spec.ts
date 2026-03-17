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
  const header = Buffer.from(JSON.stringify({ alg: 'ES256' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.fakesig`;
}

function mockHeader(value: string | null) {
  (headers as jest.Mock).mockResolvedValue({
    get: jest.fn().mockReturnValue(value),
  });
}

describe('getUser()', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns null when x-amzn-oidc-data header is absent', async () => {
    mockHeader(null);
    expect(await getUser()).toBeNull();
  });

  it('decodes a valid header into a WebUser object', async () => {
    const payload = {
      sub: 'sub-abc',
      email: 'user@example.com',
      name: 'Jane',
      family_name: 'Doe',
      birthdate: '1990-01-01',
      phone_number: '+441234567890',
      address: '1 Main St',
      picture: 'https://example.com/pic.svg',
      gender: 'female',
      locale: 'en-GB',
      zoneinfo: 'Europe/London',
      'cognito:groups': ['moderator'],
    };
    mockHeader(makeJwt(payload));

    const user = await getUser();
    expect(user).toEqual({
      sub: 'sub-abc',
      email: 'user@example.com',
      name: 'Jane',
      familyName: 'Doe',
      birthdate: '1990-01-01',
      phoneNumber: '+441234567890',
      address: '1 Main St',
      picture: 'https://example.com/pic.svg',
      gender: 'female',
      locale: 'en-GB',
      zoneinfo: 'Europe/London',
      roles: ['moderator'],
    });
  });

  it('defaults optional claims to null when absent', async () => {
    mockHeader(makeJwt({ sub: 's1', email: 'a@b.com', name: 'A' }));
    const user = await getUser();
    expect(user).not.toBeNull();
    expect(user!.familyName).toBeNull();
    expect(user!.picture).toBeNull();
    expect(user!.roles).toEqual([]);
  });

  it('returns null when the JWT has fewer than 3 parts', async () => {
    mockHeader('onlyone');
    expect(await getUser()).toBeNull();
  });

  it('returns null when the payload is not valid JSON', async () => {
    const badPayload = Buffer.from('not-json').toString('base64url');
    mockHeader(`header.${badPayload}.sig`);
    expect(await getUser()).toBeNull();
  });
});
