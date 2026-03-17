import { Test, TestingModule } from '@nestjs/testing';
import { HealthController } from './health.controller';

describe('HealthController', () => {
  let controller: HealthController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
    }).compile();

    controller = module.get<HealthController>(HealthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should return health status', () => {
    const result = controller.getHealth();
    expect(result).toHaveProperty('status');
    expect(result).toHaveProperty('timestamp');
    expect(result).toHaveProperty('service');
    expect(result).toHaveProperty('version');
  });

  it('should return status as healthy', () => {
    const result = controller.getHealth();
    expect(result.status).toBe('healthy');
  });

  it('should return service as order-api', () => {
    const result = controller.getHealth();
    expect(result.service).toBe('order-api');
  });

  it('should return valid ISO8601 timestamp', () => {
    const result = controller.getHealth();
    expect(new Date(result.timestamp)).toBeInstanceOf(Date);
    expect(isNaN(new Date(result.timestamp).getTime())).toBe(false);
  });

  it('should return version string', () => {
    const result = controller.getHealth();
    expect(typeof result.version).toBe('string');
    expect(result.version.length).toBeGreaterThan(0);
  });

  it('should return different timestamp on multiple calls', (done) => {
    const result1 = controller.getHealth();
    setTimeout(() => {
      const result2 = controller.getHealth();
      expect(result1.timestamp).not.toBe(result2.timestamp);
      done();
    }, 10);
  });
});
