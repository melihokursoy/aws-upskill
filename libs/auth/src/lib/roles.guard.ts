import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthUser } from './alb-auth.middleware';
import { ROLES_KEY } from './roles.decorator';

/**
 * Guard that enforces role-based access control using Cognito group claims.
 *
 * - No @Roles() metadata on the handler → pass through (allow all)
 * - request.user is null (unauthenticated) → 401 UnauthorizedException
 * - request.user.roles has no intersection with required roles → 403 ForbiddenException
 * - Otherwise → allow
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);

    // No @Roles() on this handler — route is open
    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const request = ctx.switchToHttp().getRequest<{ user: AuthUser | null }>();

    if (!request.user) {
      throw new UnauthorizedException('Authentication required');
    }

    const hasRole = requiredRoles.some((role) => request.user!.roles.includes(role));
    if (!hasRole) {
      throw new ForbiddenException('Insufficient role');
    }

    return true;
  }
}
