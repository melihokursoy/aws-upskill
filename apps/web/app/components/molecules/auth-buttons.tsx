'use client';

import { usePathname } from 'next/navigation';
import { Button } from '../ui/button';

/**
 * Client component — renders a Sign In button for unauthenticated users.
 *
 * Links to /auth/signin?returnTo=<current-path> so the user is returned to the
 * page they were on after the ALB completes the Cognito auth flow.
 */
export function AuthButtons() {
  const pathname = usePathname();
  const signInUrl = `/auth/signin?returnTo=${encodeURIComponent(pathname)}`;

  return (
    <Button variant="default" asChild>
      <a href={signInUrl}>Sign In</a>
    </Button>
  );
}
