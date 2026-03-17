import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

export interface AuthUser {
  sub: string;
  email: string;
  name: string;
  givenName: string | null;
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
 *
 * LOCAL DEVELOPMENT: Set LOCAL_AUTH_BYPASS=true to inject a mock user without
 * a real ALB session. Optionally set LOCAL_AUTH_ROLE (default: 'admin'),
 * LOCAL_AUTH_SUB, LOCAL_AUTH_EMAIL, LOCAL_AUTH_NAME.
 */
@Injectable()
export class AlbAuthMiddleware implements NestMiddleware {
  use(
    req: Request & { user: AuthUser | null },
    _res: Response,
    next: NextFunction
  ): void {
    if (process.env['LOCAL_AUTH_BYPASS'] === 'true') {
      req.user = {
        sub: process.env['LOCAL_AUTH_SUB'] ?? 'local-dev-sub',
        email: process.env['LOCAL_AUTH_EMAIL'] ?? 'dev@localhost',
        name: process.env['LOCAL_AUTH_NAME'] ?? 'Dev User',
        familyName: null,
        birthdate: null,
        phoneNumber: null,
        address: null,
        picture: null,
        gender: null,
        locale: null,
        zoneinfo: null,
        roles: [process.env['LOCAL_AUTH_ROLE'] ?? 'admin'],
      };
      return next();
    }

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

      // Roles come from the access token — cognito:groups is not in the userinfo-derived
      // x-amzn-oidc-data header. The ALB also forwards x-amzn-oidc-accesstoken which
      // is the raw Cognito access token JWT and always contains cognito:groups.
      const roles = decodeAccessTokenRoles(
        req.headers['x-amzn-oidc-accesstoken'] as string | undefined
      );

      req.user = {
        sub: claims['sub'] ?? '',
        email: claims['email'] ?? '',
        name: claims['name'] ?? '',
        givenName: claims['given_name'] ?? null,
        familyName: claims['family_name'] ?? null,
        birthdate: claims['birthdate'] ?? null,
        phoneNumber: claims['phone_number'] ?? null,
        address: claims['address'] ?? null,
        picture: claims['picture'] ?? null,
        gender: claims['gender'] ?? null,
        locale: claims['locale'] ?? null,
        zoneinfo: claims['zoneinfo'] ?? null,
        roles,
      };
    } catch {
      req.user = null;
    }

    next();
  }
}

function decodeAccessTokenRoles(accessToken: string | undefined): string[] {
  if (!accessToken) return [];
  try {
    const parts = accessToken.split('.');
    if (parts.length !== 3) return [];
    const payloadBase64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = payloadBase64.padEnd(
      payloadBase64.length + ((4 - (payloadBase64.length % 4)) % 4),
      '='
    );
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const claims: Record<string, any> = JSON.parse(
      Buffer.from(padded, 'base64').toString('utf8')
    );
    return Array.isArray(claims['cognito:groups'])
      ? claims['cognito:groups']
      : [];
  } catch {
    return [];
  }
}
