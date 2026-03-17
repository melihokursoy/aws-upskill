import { ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from './roles.guard';
import { AuthUser } from './alb-auth.middleware';
import { ROLES_KEY } from './roles.decorator';

function makeCtx(user: AuthUser | null, roles?: string[]): ExecutionContext {
  const reflector = new Reflector();
  jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(roles ?? null);

  return {
    getHandler: () => ({}),
    getClass: () => ({}),
    switchToHttp: () => ({
      getRequest: () => ({ user }),
    }),
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
}

describe('RolesGuard', () => {
  let guard: RolesGuard;
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
    guard = new RolesGuard(reflector);
  });

  it('allows when no @Roles() metadata is set on the handler', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(null);
    const ctx = makeCtx(null);
    // Swap reflector on guard so spy works
    const g = new RolesGuard(reflector);
    expect(g.canActivate(ctx)).toBe(true);
  });

  it('allows when @Roles() is an empty array', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue([]);
    const ctx = makeCtx(null);
    const g = new RolesGuard(reflector);
    expect(g.canActivate(ctx)).toBe(true);
  });

  it('throws UnauthorizedException (401) when user is null and roles are required', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['admin']);
    const ctx = makeCtx(null);
    const g = new RolesGuard(reflector);
    expect(() => g.canActivate(ctx)).toThrow(UnauthorizedException);
  });

  it('allows when user has the exact required role', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['admin']);
    const user = { roles: ['admin'] } as AuthUser;
    const ctx = makeCtx(user);
    const g = new RolesGuard(reflector);
    expect(g.canActivate(ctx)).toBe(true);
  });

  it('allows when user has one of multiple required roles', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['admin', 'moderator']);
    const user = { roles: ['moderator'] } as AuthUser;
    const ctx = makeCtx(user);
    const g = new RolesGuard(reflector);
    expect(g.canActivate(ctx)).toBe(true);
  });

  it('throws ForbiddenException (403) when user role does not match', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['admin']);
    const user = { roles: ['user'] } as AuthUser;
    const ctx = makeCtx(user);
    const g = new RolesGuard(reflector);
    expect(() => g.canActivate(ctx)).toThrow(ForbiddenException);
  });

  it('throws ForbiddenException when user has no roles', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['admin']);
    const user = { roles: [] } as AuthUser;
    const ctx = makeCtx(user);
    const g = new RolesGuard(reflector);
    expect(() => g.canActivate(ctx)).toThrow(ForbiddenException);
  });

  it('uses ROLES_KEY when looking up metadata', () => {
    const spy = jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['admin']);
    const user = { roles: ['admin'] } as AuthUser;
    const ctx = makeCtx(user);
    const g = new RolesGuard(reflector);
    g.canActivate(ctx);
    expect(spy).toHaveBeenCalledWith(ROLES_KEY, expect.any(Array));
  });
});
