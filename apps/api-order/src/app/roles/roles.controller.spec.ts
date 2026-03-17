import { Test, TestingModule } from '@nestjs/testing';
import {
  ExecutionContext,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesController } from './roles.controller';
import { RolesGuard, AuthUser } from '@org/auth';

function makeUser(roles: string[]): AuthUser {
  return {
    sub: 'user-123',
    email: 'test@example.com',
    name: 'Test User',
    familyName: 'User',
    birthdate: null,
    phoneNumber: null,
    address: null,
    picture: null,
    gender: null,
    locale: null,
    zoneinfo: null,
    roles,
  };
}

describe('RolesController', () => {
  let controller: RolesController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [RolesController],
    }).compile();

    controller = module.get<RolesController>(RolesController);
  });

  describe('GET /roles/none', () => {
    it('returns public endpoint message', () => {
      expect(controller.getNone()).toEqual({ message: 'public endpoint' });
    });
  });

  describe('GET /roles/user', () => {
    it('returns user payload for an authenticated user', () => {
      const user = makeUser(['user']);
      expect(controller.getUser(user)).toEqual({ user });
    });

    it('returns user payload for admin role', () => {
      const user = makeUser(['admin']);
      expect(controller.getUser(user)).toEqual({ user });
    });
  });

  describe('GET /roles/moderator', () => {
    it('returns user payload for moderator role', () => {
      const user = makeUser(['moderator']);
      expect(controller.getModerator(user)).toEqual({ user });
    });

    it('returns user payload for admin role', () => {
      const user = makeUser(['admin']);
      expect(controller.getModerator(user)).toEqual({ user });
    });
  });

  describe('GET /roles/admin', () => {
    it('returns user payload for admin role', () => {
      const user = makeUser(['admin']);
      expect(controller.getAdmin(user)).toEqual({ user });
    });
  });
});

describe('RolesGuard integration with RolesController', () => {
  let guard: RolesGuard;
  let reflector: Reflector;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [RolesController],
      providers: [RolesGuard, Reflector],
    }).compile();

    guard = module.get<RolesGuard>(RolesGuard);
    reflector = module.get<Reflector>(Reflector);
  });

  function makeCtx(
    user: AuthUser | null,
    handler: (...args: unknown[]) => unknown
  ): ExecutionContext {
    return {
      getHandler: () => handler,
      getClass: () => RolesController,
      switchToHttp: () => ({
        getRequest: () => ({ user }),
      }),
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } as any;
  }

  it('/roles/none — guard passes with null user (no @Roles)', () => {
    const controller = new RolesController();
    const ctx = makeCtx(null, controller.getNone);
    // getNone has no @Roles, so guard should allow
    expect(guard.canActivate(ctx)).toBe(true);
  });

  it('/roles/user — guard throws 401 when user is null', () => {
    const controller = new RolesController();
    const ctx = makeCtx(null, controller.getUser);
    jest
      .spyOn(reflector, 'getAllAndOverride')
      .mockReturnValue(['admin', 'moderator', 'user']);
    expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
  });

  it('/roles/admin — guard throws 403 for moderator role', () => {
    const controller = new RolesController();
    const ctx = makeCtx(makeUser(['moderator']), controller.getAdmin);
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['admin']);
    expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
  });

  it('/roles/moderator — guard throws 403 for user role', () => {
    const controller = new RolesController();
    const ctx = makeCtx(makeUser(['user']), controller.getModerator);
    jest
      .spyOn(reflector, 'getAllAndOverride')
      .mockReturnValue(['moderator', 'admin']);
    expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
  });

  it('/roles/admin — guard allows admin role', () => {
    const controller = new RolesController();
    const ctx = makeCtx(makeUser(['admin']), controller.getAdmin);
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['admin']);
    expect(guard.canActivate(ctx)).toBe(true);
  });
});
