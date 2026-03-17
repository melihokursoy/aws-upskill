import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';

/**
 * Attaches required role metadata to a route handler.
 * Read by RolesGuard to enforce access control.
 *
 * @example
 * @Roles('admin', 'moderator')
 * @UseGuards(RolesGuard)
 * @Get('manage')
 * getManage() { ... }
 */
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);
