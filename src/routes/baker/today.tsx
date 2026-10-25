import { createFileRoute } from "@tanstack/react-router";
import { FoundationPage } from "@/components/bq/foundation-page";
export const Route = createFileRoute("/baker/today")({
  component: () => <FoundationPage role="baker" title="Today" view="home" />,
});
