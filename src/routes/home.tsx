import { createFileRoute } from "@tanstack/react-router";
import { FoundationPage } from "@/components/bq/foundation-page";
export const Route = createFileRoute("/home")({
  component: () => <FoundationPage role="customer" title="Home" view="home" />,
});
