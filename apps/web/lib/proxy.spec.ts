/**
 * @jest-environment node
 */
/**
 * Tests for Next.js middleware — auth + role-based route protection.
 * Node environment is required because NextRequest relies on the native
 * Web Fetch API (Request), which Node 18+ provides but jsdom does not.
 */

import { NextRequest } from 'next/server';
import { proxy as middleware } from '../proxy';

const COGNITO_DOMAIN = 'https://upskill-dev.auth.eu-west-1.amazoncognito.com';
const CLIENT_ID = 'test-client-id';
const APP_URL = 'https://dev.example.com';

beforeEach(() => {
  process.env.COGNITO_DOMAIN = COGNITO_DOMAIN;
  process.env.COGNITO_CLIENT_ID = CLIENT_ID;
  process.env.NEXT_PUBLIC_APP_URL = APP_URL;
  delete process.env.LOCAL_AUTH_BYPASS;
});

function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'ES256' })).toString(
    'base64url'
  );
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.fakesig`;
}

function makeRequest(
  pathname: string,
  oidcData?: string,
  accessToken?: string
): NextRequest {
  const url = `${APP_URL}${pathname}`;
  const headers: Record<string, string> = {};
  if (oidcData) headers['x-amzn-oidc-data'] = oidcData;
  if (accessToken) headers['x-amzn-oidc-accesstoken'] = accessToken;
  return new NextRequest(url, { headers });
}

describe('middleware — public paths', () => {
  it.each([
    '/',
    '/403',
    '/nextapi/health',
    '/auth/signin',
    '/auth/signout',
    '/_next/static/chunk.js',
    '/favicon.ico',
  ])('passes %s through without auth check', (path) => {
    const res = middleware(makeRequest(path));
    expect(res.status).toBe(200); // NextResponse.next() returns 200
  });
});

describe('middleware — unauthenticated on protected path', () => {
  it('redirects to Cognito sign-in when no OIDC header on /manage', () => {
    const res = middleware(makeRequest('/manage'));
    expect(res.status).toBe(307);
    const location = res.headers.get('location') ?? '';
    expect(location).toContain(COGNITO_DOMAIN);
    expect(location).toContain('login');
  });

  it('redirects to Cognito sign-in when no OIDC header on /admin', () => {
    const res = middleware(makeRequest('/admin'));
    expect(res.status).toBe(307);
    const location = res.headers.get('location') ?? '';
    expect(location).toContain(COGNITO_DOMAIN);
  });
});

describe('middleware — role checks', () => {
  // oidcData provides authentication (any valid JWT); accessToken carries cognito:groups
  const oidcData = makeJwt({ sub: 'u1', email: 'u@example.com' });

  it('allows admin on /admin', () => {
    const accessToken = makeJwt({ 'cognito:groups': ['admin'] });
    const res = middleware(makeRequest('/admin', oidcData, accessToken));
    expect(res.status).toBe(200);
  });

  it('allows moderator on /manage', () => {
    const accessToken = makeJwt({ 'cognito:groups': ['moderator'] });
    const res = middleware(makeRequest('/manage', oidcData, accessToken));
    expect(res.status).toBe(200);
  });

  it('redirects moderator to /403 on /admin', () => {
    const accessToken = makeJwt({ 'cognito:groups': ['moderator'] });
    const res = middleware(makeRequest('/admin', oidcData, accessToken));
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/403');
  });

  it('redirects user role to /403 on /manage', () => {
    const accessToken = makeJwt({ 'cognito:groups': ['user'] });
    const res = middleware(makeRequest('/manage', oidcData, accessToken));
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/403');
  });

  it('allows any authenticated user with no role requirement', () => {
    const accessToken = makeJwt({ 'cognito:groups': ['user'] });
    const res = middleware(
      makeRequest('/some-other-page', oidcData, accessToken)
    );
    expect(res.status).toBe(200);
  });
});

describe('middleware — LOCAL_AUTH_BYPASS', () => {
  afterEach(() => {
    delete process.env.LOCAL_AUTH_BYPASS;
    delete process.env.LOCAL_AUTH_ROLE;
  });

  it('allows admin on /admin when LOCAL_AUTH_BYPASS=true and LOCAL_AUTH_ROLE=admin', () => {
    process.env.LOCAL_AUTH_BYPASS = 'true';
    process.env.LOCAL_AUTH_ROLE = 'admin';
    expect(middleware(makeRequest('/admin')).status).toBe(200);
  });

  it('allows moderator on /manage when LOCAL_AUTH_BYPASS=true and LOCAL_AUTH_ROLE=moderator', () => {
    process.env.LOCAL_AUTH_BYPASS = 'true';
    process.env.LOCAL_AUTH_ROLE = 'moderator';
    expect(middleware(makeRequest('/manage')).status).toBe(200);
  });

  it('redirects moderator to /403 on /admin when LOCAL_AUTH_BYPASS=true', () => {
    process.env.LOCAL_AUTH_BYPASS = 'true';
    process.env.LOCAL_AUTH_ROLE = 'moderator';
    const res = middleware(makeRequest('/admin'));
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/403');
  });

  it('still enforces auth when LOCAL_AUTH_BYPASS is not set', () => {
    const res = middleware(makeRequest('/admin')); // no bypass, no header
    expect(res.status).toBe(307);
  });
});
