/**
 * This is not a production server yet!
 * This is only a minimal backend to get started.
 */

// reflect-metadata must be the first import — NestJS decorators depend on it
// being initialized before any class decorator is evaluated.
// With webpack bundling (externalDependencies: 'none') import order is not
// guaranteed unless this is explicitly first.
import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app/app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const globalPrefix = 'api';
  app.setGlobalPrefix(globalPrefix);
  const port = process.env.PORT || 3301;
  await app.listen(port, '0.0.0.0');
  Logger.log(
    `🚀 Application is running on: http://localhost:${port}/${globalPrefix}`
  );
}

bootstrap();
