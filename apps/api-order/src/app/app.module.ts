import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { AlbAuthMiddleware, AuthModule } from '@org/auth';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { HealthController } from './health.controller';
import { DbHealthController } from './db-health.controller';
import { RolesController } from './roles/roles.controller';

@Module({
  imports: [AuthModule],
  controllers: [
    AppController,
    HealthController,
    DbHealthController,
    RolesController,
  ],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    // Apply ALB auth middleware to all routes — decodes x-amzn-oidc-data into request.user.
    // Health check routes remain fully public (no ALB auth action on those listener rules).
    consumer.apply(AlbAuthMiddleware).forRoutes('*');
  }
}
