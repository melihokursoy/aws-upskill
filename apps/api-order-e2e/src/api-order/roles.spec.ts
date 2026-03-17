import axios from 'axios';

/**
 * Integration tests for auth and role-based endpoints.
 * Runs against the real API server (localhost:3301).
 *
 * The AlbAuthMiddleware does not verify JWT signatures — it only base64-decodes
 * the payload segment. We craft minimal fake JWTs here to exercise the middleware
 * and role guard end-to-end without a real Cognito session.
 */

function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'ES256' })).toString(
    'base64url'
  );
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.fakesig`;
}

describe('GET /api/health — no auth required', () => {
  it('returns 200 without any auth header', async () => {
    const res = await axios.get('/api/health');
    expect(res.status).toBe(200);
    expect(res.data).toMatchObject({ status: 'healthy' });
  });
});

describe('GET /api/roles/none — public endpoint', () => {
  it('returns 200 without any auth header', async () => {
    const res = await axios.get('/api/roles/none');
    expect(res.status).toBe(200);
    expect(res.data).toEqual({ message: 'public endpoint' });
  });
});

describe('GET /api/roles/user — any authenticated role', () => {
  it('returns 200 with user payload when admin token provided', async () => {
    const oidcData = makeJwt({
      sub: 'u1',
      email: 'admin@test.com',
      name: 'Admin User',
      given_name: 'Admin',
    });
    const accessToken = makeJwt({ 'cognito:groups': ['admin'] });

    const res = await axios.get('/api/roles/user', {
      headers: {
        'x-amzn-oidc-data': oidcData,
        'x-amzn-oidc-accesstoken': accessToken,
      },
    });

    expect(res.status).toBe(200);
    expect(res.data.user).toMatchObject({
      sub: 'u1',
      email: 'admin@test.com',
      name: 'Admin User',
      givenName: 'Admin',
      roles: ['admin'],
    });
  });

  it('returns 401 when no auth header', async () => {
    await expect(axios.get('/api/roles/user')).rejects.toMatchObject({
      response: { status: 401 },
    });
  });
});

describe('GET /api/roles/admin — admin only', () => {
  it('returns 200 for admin', async () => {
    const oidcData = makeJwt({ sub: 'u2', email: 'a@test.com', name: 'A' });
    const accessToken = makeJwt({ 'cognito:groups': ['admin'] });

    const res = await axios.get('/api/roles/admin', {
      headers: {
        'x-amzn-oidc-data': oidcData,
        'x-amzn-oidc-accesstoken': accessToken,
      },
    });

    expect(res.status).toBe(200);
    expect(res.data.user.roles).toEqual(['admin']);
  });

  it('returns 403 for moderator', async () => {
    const oidcData = makeJwt({ sub: 'u3', email: 'm@test.com', name: 'M' });
    const accessToken = makeJwt({ 'cognito:groups': ['moderator'] });

    await expect(
      axios.get('/api/roles/admin', {
        headers: {
          'x-amzn-oidc-data': oidcData,
          'x-amzn-oidc-accesstoken': accessToken,
        },
      })
    ).rejects.toMatchObject({ response: { status: 403 } });
  });

  it('returns 401 when unauthenticated', async () => {
    await expect(axios.get('/api/roles/admin')).rejects.toMatchObject({
      response: { status: 401 },
    });
  });
});

describe('x-amzn-oidc-data header → request.user populated', () => {
  it('maps all standard OIDC claims correctly', async () => {
    const oidcData = makeJwt({
      sub: 'u4',
      email: 'full@test.com',
      name: 'Full User',
      given_name: 'Full',
      family_name: 'User',
      birthdate: '1990-01-01',
      phone_number: '+441234567890',
      address: '1 Main St',
      picture: 'https://example.com/pic.jpg',
      gender: 'other',
      locale: 'en-GB',
      zoneinfo: 'Europe/London',
    });
    const accessToken = makeJwt({ 'cognito:groups': ['admin'] });

    const res = await axios.get('/api/roles/admin', {
      headers: {
        'x-amzn-oidc-data': oidcData,
        'x-amzn-oidc-accesstoken': accessToken,
      },
    });

    expect(res.status).toBe(200);
    expect(res.data.user).toMatchObject({
      sub: 'u4',
      email: 'full@test.com',
      name: 'Full User',
      givenName: 'Full',
      familyName: 'User',
      birthdate: '1990-01-01',
      phoneNumber: '+441234567890',
      address: '1 Main St',
      picture: 'https://example.com/pic.jpg',
      gender: 'other',
      locale: 'en-GB',
      zoneinfo: 'Europe/London',
      roles: ['admin'],
    });
  });
});
