import { createFileRoute } from "@tanstack/react-router";
import { FoundationPage } from "@/components/bq/foundation-page";
export const Route = createFileRoute("/baker/orders")({
  component: () => <FoundationPage role="baker" title="Orders" view="orders" />,
});
