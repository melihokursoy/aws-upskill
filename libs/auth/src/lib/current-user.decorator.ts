import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthUser } from './alb-auth.middleware';

/**
 * Parameter decorator that extracts the decoded Cognito user from request.user.
 * Returns null if the request has no valid x-amzn-oidc-data header.
 *
 * @example
 * @Get('profile')
 * getProfile(@CurrentUser() user: AuthUser) { ... }
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthUser | null => {
    const request = ctx.switchToHttp().getRequest<{ user: AuthUser | null }>();
    return request.user ?? null;
  }
);
