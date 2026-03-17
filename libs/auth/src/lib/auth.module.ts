import { Module } from '@nestjs/common';
import { AlbAuthMiddleware } from './alb-auth.middleware';
import { RolesGuard } from './roles.guard';

/**
 * AuthModule — import this in your AppModule to enable ALB OIDC auth.
 *
 * Exports the AlbAuthMiddleware and RolesGuard providers so they can be
 * injected by NestJS. Register the middleware globally in AppModule.configure():
 *
 *   consumer.apply(AlbAuthMiddleware).forRoutes('*');
 *
 * @CurrentUser() and @Roles() are plain TypeScript decorators — import them
 * directly from '@org/auth', not via this NestJS module:
 *
 *   import { CurrentUser, Roles, RolesGuard } from '@org/auth';
 */
@Module({
  providers: [AlbAuthMiddleware, RolesGuard],
  exports: [AlbAuthMiddleware, RolesGuard],
})
export class AuthModule {}
