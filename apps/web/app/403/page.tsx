import Link from 'next/link';

export default function ForbiddenPage() {
  return (
    <main className="mx-auto max-w-5xl px-4 py-16">
      <h1 className="text-3xl font-semibold tracking-tight text-foreground">Access Denied</h1>
      <p className="mt-4 text-muted-foreground">
        You don&apos;t have permission to view this page.
      </p>
      <Link
        href="/"
        className="mt-6 inline-block text-sm text-primary underline-offset-4 hover:underline"
      >
        Back to home
      </Link>
    </main>
  );
}
