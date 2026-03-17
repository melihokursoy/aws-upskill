import { AlbAuthMiddleware, AuthUser } from './alb-auth.middleware';

function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'ES256' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.fakesignature`;
}

function makeReq(header?: string): { headers: Record<string, string>; user: AuthUser | null } {
  return {
    headers: header ? { 'x-amzn-oidc-data': header } : {},
    user: null,
  };
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

  it('populates request.user from a valid x-amzn-oidc-data header', () => {
    const payload = {
      sub: 'user-123',
      email: 'test@example.com',
      name: 'Test User',
      family_name: 'User',
      birthdate: '1990-01-01',
      phone_number: '+441234567890',
      address: '1 Main St',
      picture: 'https://example.com/pic.jpg',
      gender: 'male',
      locale: 'en-GB',
      zoneinfo: 'Europe/London',
      'cognito:groups': ['admin'],
    };
    const req = makeReq(makeJwt(payload));
    middleware.use(req as never, {} as never, next);

    expect(req.user).toEqual({
      sub: 'user-123',
      email: 'test@example.com',
      name: 'Test User',
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

  it('defaults roles to [] when cognito:groups is absent', () => {
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
});
