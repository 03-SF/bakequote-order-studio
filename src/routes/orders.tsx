import { createFileRoute } from "@tanstack/react-router";
import { FoundationPage } from "@/components/bq/foundation-page";
export const Route = createFileRoute("/orders")({
  component: () => <FoundationPage role="customer" title="Orders" view="orders" />,
});
