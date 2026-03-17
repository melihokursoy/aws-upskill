import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { HealthController } from './health.controller';
import { DbHealthController } from './db-health.controller';

@Module({
  imports: [],
  controllers: [AppController, HealthController, DbHealthController],
  providers: [AppService],
})
export class AppModule {}
