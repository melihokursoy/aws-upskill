export function JwtPayload({ claims }: { claims: Record<string, unknown> }) {
  return (
    <div className="mt-6">
      <h2 className="text-sm font-semibold uppercase tracking-widest text-muted-foreground">
        JWT Payload
      </h2>
      <pre className="mt-2 overflow-auto rounded-lg border bg-muted p-4 text-xs text-foreground">
        {JSON.stringify(claims, null, 2)}
      </pre>
    </div>
  );
}
