import { Controller, Get } from '@nestjs/common';
import { Client } from 'pg';

@Controller('db-health')
export class DbHealthController {
  @Get()
  async getDbHealth() {
    const start = Date.now();

    const client = new Client({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT) || 5432,
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      connectionTimeoutMillis: 3000,
    });

    try {
      await client.connect();
      await client.query('SELECT 1');
      const latencyMs = Date.now() - start;
      return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        database: {
          connected: true,
          latencyMs,
          host: process.env.DB_HOST,
          port: Number(process.env.DB_PORT) || 5432,
          name: process.env.DB_NAME,
        },
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        database: {
          connected: false,
          latencyMs: Date.now() - start,
          host: process.env.DB_HOST,
          port: Number(process.env.DB_PORT) || 5432,
          name: process.env.DB_NAME,
          error: error instanceof Error ? error.message : String(error),
        },
      };
    } finally {
      await client.end().catch(() => undefined);
    }
  }
}
