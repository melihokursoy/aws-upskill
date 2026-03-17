import Link from 'next/link';
import { getUser } from '../../../lib/get-user';
import { AuthButtons } from '../molecules/auth-buttons';
import { AvatarDropdown } from '../molecules/avatar-dropdown';

/**
 * Server component — reads the ALB OIDC header to determine auth state.
 * Renders Sign Up + Sign In for unauthenticated users, avatar dropdown for authenticated.
 */
export async function Header() {
  const user = await getUser();

  return (
    <header className="sticky top-0 z-50 border-b border-border bg-background">
      <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-4">
        {/* Left — app name + nav */}
        <div className="flex items-center gap-6">
          <Link href="/" className="text-sm font-semibold text-foreground hover:text-primary">
            aws-upskill
          </Link>
          <nav className="flex items-center gap-4 text-sm text-muted-foreground">
            <Link href="/" className="hover:text-foreground">
              Home
            </Link>
          </nav>
        </div>

        {/* Right — auth state */}
        <div className="flex items-center gap-2">
          {user ? <AvatarDropdown user={user} /> : <AuthButtons />}
        </div>
      </div>
    </header>
  );
}
