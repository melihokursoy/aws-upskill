import { test, expect } from '@playwright/test';

/**
 * E2E tests for the Next.js proxy middleware auth and role-based routing.
 *
 * Uses Playwright's HTTP request API (not browser navigation) to inject custom
 * headers, mimicking what the ALB injects in production. The middleware does not
 * verify JWT signatures — only the base64 payload is decoded — so we craft minimal
 * fake JWTs here.
 *
 * maxRedirects: 0 prevents the HTTP client from following redirects, letting us
 * assert on the 307 status and Location header directly.
 */

function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'ES256' })).toString(
    'base64url'
  );
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.fakesig`;
}

const oidcData = makeJwt({ sub: 'u1', email: 'u@example.com', name: 'Test' });

test.describe('public paths — no auth required', () => {
  test('GET / returns 200', async ({ request }) => {
    const res = await request.get('/', { maxRedirects: 0 });
    expect(res.status()).toBe(200);
  });

  test('GET /nextapi/health returns 200', async ({ request }) => {
    const res = await request.get('/nextapi/health', { maxRedirects: 0 });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body).toMatchObject({ status: 'healthy' });
  });

  test('GET /403 returns 200', async ({ request }) => {
    const res = await request.get('/403', { maxRedirects: 0 });
    expect(res.status()).toBe(200);
  });
});

test.describe('unauthenticated — protected paths redirect', () => {
  test('GET /manage without auth header redirects', async ({ request }) => {
    const res = await request.get('/manage', { maxRedirects: 0 });
    expect(res.status()).toBe(307);
    const location = res.headers()['location'] ?? '';
    expect(location).toBeTruthy();
    // redirect goes to Cognito login (or /login when COGNITO_DOMAIN is not set in local dev)
    expect(location).toContain('login');
  });

  test('GET /admin without auth header redirects', async ({ request }) => {
    const res = await request.get('/admin', { maxRedirects: 0 });
    expect(res.status()).toBe(307);
  });
});

test.describe('role-based access — injected ALB headers', () => {
  test('admin on /admin → 200', async ({ request }) => {
    const accessToken = makeJwt({ 'cognito:groups': ['admin'] });
    const res = await request.get('/admin', {
      headers: {
        'x-amzn-oidc-data': oidcData,
        'x-amzn-oidc-accesstoken': accessToken,
      },
      maxRedirects: 0,
    });
    expect(res.status()).toBe(200);
  });

  test('moderator on /manage → 200', async ({ request }) => {
    const accessToken = makeJwt({ 'cognito:groups': ['moderator'] });
    const res = await request.get('/manage', {
      headers: {
        'x-amzn-oidc-data': oidcData,
        'x-amzn-oidc-accesstoken': accessToken,
      },
      maxRedirects: 0,
    });
    expect(res.status()).toBe(200);
  });

  test('user role on /manage → redirects to /403', async ({ request }) => {
    const accessToken = makeJwt({ 'cognito:groups': ['user'] });
    const res = await request.get('/manage', {
      headers: {
        'x-amzn-oidc-data': oidcData,
        'x-amzn-oidc-accesstoken': accessToken,
      },
      maxRedirects: 0,
    });
    expect(res.status()).toBe(307);
    expect(res.headers()['location']).toContain('/403');
  });

  test('moderator on /admin → redirects to /403', async ({ request }) => {
    const accessToken = makeJwt({ 'cognito:groups': ['moderator'] });
    const res = await request.get('/admin', {
      headers: {
        'x-amzn-oidc-data': oidcData,
        'x-amzn-oidc-accesstoken': accessToken,
      },
      maxRedirects: 0,
    });
    expect(res.status()).toBe(307);
    expect(res.headers()['location']).toContain('/403');
  });
});
