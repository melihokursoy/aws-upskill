import { Controller, Get, UseGuards } from '@nestjs/common';
import { CurrentUser, AuthUser, Roles, RolesGuard } from '@org/auth';

@Controller('roles')
export class RolesController {
  /**
   * GET /roles/none — public endpoint, no auth required.
   * Demonstrates that AlbAuthMiddleware does not block requests without a header.
   */
  @Get('none')
  getNone(): { message: string } {
    return { message: 'public endpoint' };
  }

  /**
   * GET /roles/user — any authenticated user (admin, moderator, or user).
   * Returns 401 if unauthenticated, 200 + decoded user for any role.
   */
  @Roles('admin', 'moderator', 'user')
  @UseGuards(RolesGuard)
  @Get('user')
  getUser(@CurrentUser() user: AuthUser): { user: AuthUser } {
    return { user };
  }

  /**
   * GET /roles/moderator — moderator or admin only.
   * Returns 403 for the `user` role, 401 if unauthenticated.
   */
  @Roles('moderator', 'admin')
  @UseGuards(RolesGuard)
  @Get('moderator')
  getModerator(@CurrentUser() user: AuthUser): { user: AuthUser } {
    return { user };
  }

  /**
   * GET /roles/admin — admin only.
   * Returns 403 for moderator/user, 401 if unauthenticated.
   */
  @Roles('admin')
  @UseGuards(RolesGuard)
  @Get('admin')
  getAdmin(@CurrentUser() user: AuthUser): { user: AuthUser } {
    return { user };
  }
}
