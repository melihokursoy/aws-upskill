import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

export interface AuthUser {
  sub: string;
  email: string;
  name: string;
  familyName: string | null;
  birthdate: string | null;
  phoneNumber: string | null;
  address: string | null;
  picture: string | null;
  gender: string | null;
  locale: string | null;
  zoneinfo: string | null;
  roles: string[];
}

/**
 * Reads the x-amzn-oidc-data header injected by the ALB after authenticate-cognito.
 * Base64-decodes the JWT payload segment and maps Cognito claims to request.user.
 * No signature verification — the ALB has already validated the token.
 */
@Injectable()
export class AlbAuthMiddleware implements NestMiddleware {
  use(req: Request & { user: AuthUser | null }, _res: Response, next: NextFunction): void {
    const header = req.headers['x-amzn-oidc-data'] as string | undefined;

    if (!header) {
      req.user = null;
      return next();
    }

    try {
      // JWT structure: <header>.<payload>.<signature>
      const parts = header.split('.');
      if (parts.length !== 3) {
        req.user = null;
        return next();
      }

      // Pad base64url string to standard base64 before decoding
      const payloadBase64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
      const padded = payloadBase64.padEnd(
        payloadBase64.length + ((4 - (payloadBase64.length % 4)) % 4),
        '='
      );
      const json = Buffer.from(padded, 'base64').toString('utf8');
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const claims: Record<string, any> = JSON.parse(json);

      req.user = {
        sub: claims['sub'] ?? '',
        email: claims['email'] ?? '',
        name: claims['name'] ?? '',
        familyName: claims['family_name'] ?? null,
        birthdate: claims['birthdate'] ?? null,
        phoneNumber: claims['phone_number'] ?? null,
        address: claims['address'] ?? null,
        picture: claims['picture'] ?? null,
        gender: claims['gender'] ?? null,
        locale: claims['locale'] ?? null,
        zoneinfo: claims['zoneinfo'] ?? null,
        roles: Array.isArray(claims['cognito:groups']) ? claims['cognito:groups'] : [],
      };
    } catch {
      req.user = null;
    }

    next();
  }
}
