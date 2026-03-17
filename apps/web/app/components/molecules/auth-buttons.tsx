import { Button } from '../ui/button';

/**
 * Server component — renders Sign Up + Sign In buttons when the user is unauthenticated.
 * Links point to Cognito Hosted UI endpoints. Env vars are injected by the ECS task definition.
 */
export function AuthButtons() {
  const domain = process.env.COGNITO_DOMAIN ?? '';
  const clientId = process.env.COGNITO_CLIENT_ID ?? '';
  const appUrl = encodeURIComponent(process.env.NEXT_PUBLIC_APP_URL ?? '/');

  const signUpUrl = `https://${domain}/signup?client_id=${clientId}&response_type=code&redirect_uri=${appUrl}`;
  const signInUrl = `https://${domain}/login?client_id=${clientId}&response_type=code&redirect_uri=${appUrl}`;

  return (
    <div className="flex items-center gap-2">
      <Button variant="secondary" asChild>
        <a href={signUpUrl}>Sign Up</a>
      </Button>
      <Button variant="default" asChild>
        <a href={signInUrl}>Sign In</a>
      </Button>
    </div>
  );
}
