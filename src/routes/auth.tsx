import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { Wordmark, homeFor } from "@/components/bq/shell";
import { Button, Notice } from "@/components/bq/ui";
import { act } from "@/lib/bq/store";
import type { Role } from "@/lib/bq/types";
export const Route = createFileRoute("/auth")({
  validateSearch: (search: Record<string, unknown>): { role: Role; mode: "signin" } => ({
    role: search["role"] === "baker" ? "baker" : "customer",
    mode: "signin",
  }),
  component: DemoSignIn,
});
function DemoSignIn() {
  const { role } = Route.useSearch();
  const navigate = useNavigate();
  const [error, setError] = useState("");
  return (
    <main className="mx-auto max-w-md space-y-6 px-4 py-12">
      <Wordmark />
      <h1 className="text-2xl font-semibold">Explore the {role} demo</h1>
      <Notice>
        Local demo only. No account is created and no password is required. Real authentication is
        still under development.
      </Notice>
      {error && <p role="alert">{error}</p>}
      <Button
        block
        onClick={() => {
          const result = act((s) => {
            s.sessions[role] = true;
            s.role = role;
          });
          if (!result.ok) {
            setError(result.error);
            return;
          }
          void navigate({ to: homeFor(role) });
        }}
      >
        Continue as {role === "baker" ? "Ayesha" : "Sara"}
      </Button>
    </main>
  );
}
