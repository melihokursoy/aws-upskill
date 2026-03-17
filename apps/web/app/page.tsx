import { getUser } from '../lib/get-user';
import { JwtPayload } from './components/molecules/jwt-payload';

export default async function HomePage() {
  const user = await getUser();

  return (
    <main className="mx-auto max-w-5xl px-4 py-16">
      <h1 className="text-3xl font-semibold tracking-tight text-foreground">
        Welcome to aws-upskill
      </h1>
      {user ? (
        <JwtPayload claims={user.rawClaims} />
      ) : (
        <p className="mt-4 text-muted-foreground">Sign in to access protected features.</p>
      )}
    </main>
  );
}
