import { AlbAuthMiddleware, AuthUser } from './alb-auth.middleware';

function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'ES256' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.fakesignature`;
}

function makeReq(
  oidcData?: string,
  accessToken?: string,
): { headers: Record<string, string>; user: AuthUser | null } {
  const headers: Record<string, string> = {};
  if (oidcData) headers['x-amzn-oidc-data'] = oidcData;
  if (accessToken) headers['x-amzn-oidc-accesstoken'] = accessToken;
  return { headers, user: null };
}

describe('AlbAuthMiddleware', () => {
  let middleware: AlbAuthMiddleware;
  const next = jest.fn();

  beforeEach(() => {
    middleware = new AlbAuthMiddleware();
    next.mockReset();
  });

  it('sets request.user to null when header is absent', () => {
    const req = makeReq();
    middleware.use(req as never, {} as never, next);
    expect(req.user).toBeNull();
    expect(next).toHaveBeenCalled();
  });

  it('populates request.user from oidc-data and roles from access token', () => {
    const oidcPayload = {
      sub: 'user-123',
      email: 'test@example.com',
      name: 'Test User',
      given_name: 'Test',
      family_name: 'User',
      birthdate: '1990-01-01',
      phone_number: '+441234567890',
      address: '1 Main St',
      picture: 'https://example.com/pic.jpg',
      gender: 'male',
      locale: 'en-GB',
      zoneinfo: 'Europe/London',
    };
    const req = makeReq(makeJwt(oidcPayload), makeJwt({ 'cognito:groups': ['admin'] }));
    middleware.use(req as never, {} as never, next);

    expect(req.user).toEqual({
      sub: 'user-123',
      email: 'test@example.com',
      name: 'Test User',
      givenName: 'Test',
      familyName: 'User',
      birthdate: '1990-01-01',
      phoneNumber: '+441234567890',
      address: '1 Main St',
      picture: 'https://example.com/pic.jpg',
      gender: 'male',
      locale: 'en-GB',
      zoneinfo: 'Europe/London',
      roles: ['admin'],
    });
  });

  it('defaults optional claims to null when absent from payload', () => {
    const payload = { sub: 'u1', email: 'a@b.com', name: 'A B' };
    const req = makeReq(makeJwt(payload));
    middleware.use(req as never, {} as never, next);

    expect(req.user).not.toBeNull();
    expect(req.user!.familyName).toBeNull();
    expect(req.user!.birthdate).toBeNull();
    expect(req.user!.phoneNumber).toBeNull();
    expect(req.user!.address).toBeNull();
    expect(req.user!.picture).toBeNull();
    expect(req.user!.gender).toBeNull();
    expect(req.user!.locale).toBeNull();
    expect(req.user!.zoneinfo).toBeNull();
  });

  it('defaults roles to [] when access token is absent', () => {
    const req = makeReq(makeJwt({ sub: 'u1', email: 'a@b.com', name: 'A B' }));
    middleware.use(req as never, {} as never, next);
    expect(req.user!.roles).toEqual([]);
  });

  it('sets request.user to null when header is malformed base64', () => {
    const req = makeReq('not.valid');
    middleware.use(req as never, {} as never, next);
    expect(req.user).toBeNull();
    expect(next).toHaveBeenCalled();
  });

  it('sets request.user to null when payload is not valid JSON', () => {
    const invalidPayload = Buffer.from('not-json').toString('base64url');
    const req = makeReq(`header.${invalidPayload}.sig`);
    middleware.use(req as never, {} as never, next);
    expect(req.user).toBeNull();
  });

  it('always calls next()', () => {
    middleware.use(makeReq() as never, {} as never, next);
    expect(next).toHaveBeenCalledTimes(1);
  });

  describe('LOCAL_AUTH_BYPASS', () => {
    afterEach(() => {
      delete process.env['LOCAL_AUTH_BYPASS'];
      delete process.env['LOCAL_AUTH_ROLE'];
      delete process.env['LOCAL_AUTH_EMAIL'];
      delete process.env['LOCAL_AUTH_NAME'];
      delete process.env['LOCAL_AUTH_SUB'];
    });

    it('injects a mock admin user when LOCAL_AUTH_BYPASS=true', () => {
      process.env['LOCAL_AUTH_BYPASS'] = 'true';
      const req = makeReq(); // no OIDC header
      middleware.use(req as never, {} as never, next);
      expect(req.user).not.toBeNull();
      expect(req.user!.roles).toEqual(['admin']);
      expect(next).toHaveBeenCalled();
    });

    it('uses LOCAL_AUTH_ROLE when set', () => {
      process.env['LOCAL_AUTH_BYPASS'] = 'true';
      process.env['LOCAL_AUTH_ROLE'] = 'moderator';
      const req = makeReq();
      middleware.use(req as never, {} as never, next);
      expect(req.user!.roles).toEqual(['moderator']);
    });

    it('uses LOCAL_AUTH_EMAIL and LOCAL_AUTH_NAME when set', () => {
      process.env['LOCAL_AUTH_BYPASS'] = 'true';
      process.env['LOCAL_AUTH_EMAIL'] = 'custom@test.com';
      process.env['LOCAL_AUTH_NAME'] = 'Custom Name';
      const req = makeReq();
      middleware.use(req as never, {} as never, next);
      expect(req.user!.email).toBe('custom@test.com');
      expect(req.user!.name).toBe('Custom Name');
    });

    it('does not activate bypass when LOCAL_AUTH_BYPASS is not set', () => {
      const req = makeReq(); // no header, no bypass
      middleware.use(req as never, {} as never, next);
      expect(req.user).toBeNull();
    });
  });
});
