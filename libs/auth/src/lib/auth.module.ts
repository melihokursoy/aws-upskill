import { Module } from '@nestjs/common';
import { AlbAuthMiddleware } from './alb-auth.middleware';
import { RolesGuard } from './roles.guard';

/**
 * AuthModule — import this in your AppModule to enable ALB OIDC auth.
 *
 * After importing, register AlbAuthMiddleware globally in AppModule.configure():
 *
 *   consumer.apply(AlbAuthMiddleware).forRoutes('*');
 *
 * Use @Roles() + @UseGuards(RolesGuard) on individual route handlers.
 */
@Module({
  providers: [AlbAuthMiddleware, RolesGuard],
  exports: [AlbAuthMiddleware, RolesGuard],
})
export class AuthModule {}
