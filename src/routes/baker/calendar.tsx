import { createFileRoute } from "@tanstack/react-router";
import { FoundationPage } from "@/components/bq/foundation-page";
export const Route = createFileRoute("/baker/calendar")({
  component: () => <FoundationPage role="baker" title="Calendar" view="calendar" />,
});
