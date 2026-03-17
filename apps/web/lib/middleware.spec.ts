/**
 * @jest-environment node
 */
/**
 * Tests for Next.js middleware — auth + role-based route protection.
 * Node environment is required because NextRequest relies on the native
 * Web Fetch API (Request), which Node 18+ provides but jsdom does not.
 */

import { NextRequest } from 'next/server';
import { middleware } from '../middleware';

const COGNITO_DOMAIN = 'upskill-dev.auth.eu-west-1.amazoncognito.com';
const CLIENT_ID = 'test-client-id';
const APP_URL = 'https://dev.example.com';

beforeEach(() => {
  process.env.COGNITO_DOMAIN = COGNITO_DOMAIN;
  process.env.COGNITO_CLIENT_ID = CLIENT_ID;
  process.env.NEXT_PUBLIC_APP_URL = APP_URL;
});

function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'ES256' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.fakesig`;
}

function makeRequest(pathname: string, oidcHeader?: string): NextRequest {
  const url = `${APP_URL}${pathname}`;
  const headers: Record<string, string> = {};
  if (oidcHeader) headers['x-amzn-oidc-data'] = oidcHeader;
  return new NextRequest(url, { headers });
}

describe('middleware — public paths', () => {
  it.each(['/', '/403', '/nextapi/health', '/nextapi/sign-out', '/_next/static/chunk.js', '/favicon.ico'])(
    'passes %s through without auth check',
    (path) => {
      const res = middleware(makeRequest(path));
      expect(res.status).toBe(200); // NextResponse.next() returns 200
    }
  );
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
  it('allows admin on /admin', () => {
    const jwt = makeJwt({ 'cognito:groups': ['admin'] });
    const res = middleware(makeRequest('/admin', jwt));
    expect(res.status).toBe(200);
  });

  it('allows moderator on /manage', () => {
    const jwt = makeJwt({ 'cognito:groups': ['moderator'] });
    const res = middleware(makeRequest('/manage', jwt));
    expect(res.status).toBe(200);
  });

  it('redirects moderator to /403 on /admin', () => {
    const jwt = makeJwt({ 'cognito:groups': ['moderator'] });
    const res = middleware(makeRequest('/admin', jwt));
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/403');
  });

  it('redirects user role to /403 on /manage', () => {
    const jwt = makeJwt({ 'cognito:groups': ['user'] });
    const res = middleware(makeRequest('/manage', jwt));
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toContain('/403');
  });

  it('allows any authenticated user with no role requirement', () => {
    const jwt = makeJwt({ 'cognito:groups': ['user'] });
    const res = middleware(makeRequest('/some-other-page', jwt));
    expect(res.status).toBe(200);
  });
});
