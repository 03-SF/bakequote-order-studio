import { createFileRoute } from "@tanstack/react-router";
import { FoundationPage } from "@/components/bq/foundation-page";
export const Route = createFileRoute("/messages")({
  component: () => <FoundationPage role="any" title="Messages" view="messages" />,
});
