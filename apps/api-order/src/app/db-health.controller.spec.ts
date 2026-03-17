import { Test, TestingModule } from '@nestjs/testing';
import { DbHealthController } from './db-health.controller';
import { Client } from 'pg';

jest.mock('pg', () => ({
  Client: jest.fn(),
}));

const mockConnect = jest.fn();
const mockQuery = jest.fn();
const mockEnd = jest.fn();

const MockClient = Client as jest.MockedClass<typeof Client>;

beforeEach(() => {
  MockClient.mockImplementation(
    () =>
      ({
        connect: mockConnect,
        query: mockQuery,
        end: mockEnd,
      } as unknown as Client)
  );
  mockConnect.mockReset();
  mockQuery.mockReset();
  mockEnd.mockReset().mockResolvedValue(undefined);
});

describe('DbHealthController', () => {
  let controller: DbHealthController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [DbHealthController],
    }).compile();

    controller = module.get<DbHealthController>(DbHealthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should return healthy status when DB is reachable', async () => {
    mockConnect.mockResolvedValue(undefined);
    mockQuery.mockResolvedValue({ rows: [{ '?column?': 1 }] });

    const result = await controller.getDbHealth();

    expect(result.status).toBe('healthy');
    expect(result.database.connected).toBe(true);
    expect(result.database).toHaveProperty('latencyMs');
    expect(result).toHaveProperty('timestamp');
  });

  it('should return unhealthy status when DB connection fails', async () => {
    mockConnect.mockRejectedValue(new Error('Connection refused'));

    const result = await controller.getDbHealth();

    expect(result.status).toBe('unhealthy');
    expect(result.database.connected).toBe(false);
    expect(result.database.error).toBe('Connection refused');
  });

  it('should return unhealthy status when query fails', async () => {
    mockConnect.mockResolvedValue(undefined);
    mockQuery.mockRejectedValue(new Error('Query failed'));

    const result = await controller.getDbHealth();

    expect(result.status).toBe('unhealthy');
    expect(result.database.connected).toBe(false);
    expect(result.database.error).toBe('Query failed');
  });

  it('should always call client.end()', async () => {
    mockConnect.mockRejectedValue(new Error('fail'));

    await controller.getDbHealth();

    expect(mockEnd).toHaveBeenCalled();
  });
});
