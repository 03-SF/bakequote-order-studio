import { createFileRoute } from "@tanstack/react-router";
import { FoundationPage } from "@/components/bq/foundation-page";
export const Route = createFileRoute("/account")({
  component: () => <FoundationPage role="customer" title="Account" view="account" />,
});
