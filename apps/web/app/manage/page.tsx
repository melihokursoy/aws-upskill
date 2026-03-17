import { getUser } from '../../lib/get-user';
import { JwtPayload } from '../components/molecules/jwt-payload';

export default async function ManagePage() {
  const user = await getUser();

  return (
    <main className="mx-auto max-w-5xl px-4 py-16">
      <h1 className="text-3xl font-semibold tracking-tight text-foreground">Manage</h1>
      {user && <JwtPayload claims={user.rawClaims} />}
      <p className="mt-8 text-sm text-muted-foreground">
        Management features will be added in future updates.
      </p>
    </main>
  );
}
