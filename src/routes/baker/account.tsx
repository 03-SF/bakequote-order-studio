import { createFileRoute } from "@tanstack/react-router";
import { FoundationPage } from "@/components/bq/foundation-page";
export const Route = createFileRoute("/baker/account")({
  component: () => <FoundationPage role="baker" title="Account" view="account" />,
});
