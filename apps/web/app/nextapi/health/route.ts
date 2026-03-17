import { NextResponse } from 'next/server';

export async function GET() {
  const healthResponse = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'web',
    version: process.env.APP_VERSION || '1.0.0',
  };

  return NextResponse.json(healthResponse, { status: 200 });
}
