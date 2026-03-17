import { getUser } from '../../lib/get-user';

export default async function ManagePage() {
  const user = await getUser();

  return (
    <main className="mx-auto max-w-5xl px-4 py-16">
      <h1 className="text-3xl font-semibold tracking-tight text-foreground">Manage</h1>
      {user && (
        <p className="mt-4 text-muted-foreground">
          Signed in as <strong>{user.name}</strong> &mdash; roles:{' '}
          <strong>{user.roles.join(', ')}</strong>
        </p>
      )}
      <p className="mt-8 text-sm text-muted-foreground">
        Management features will be added in future updates.
      </p>
    </main>
  );
}
