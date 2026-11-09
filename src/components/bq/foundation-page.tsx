import { useState } from "react";
import { AppShell } from "./shell";
import { Card, Empty, Money, Notice, StatusBadge, Button, Sheet } from "./ui";
import { Chat, ConfigBlock, EventList, QuoteBlock, StageTrack } from "./order-parts";
import { useBQ } from "@/lib/bq/store";
import { customerOrders, conversations } from "@/lib/bq/selectors";
import { currentQuote } from "@/lib/bq/machine";
import { fmtDate } from "@/lib/bq/dates";
import type { Role } from "@/lib/bq/types";

/** Working entry points for existing demo data, not a claim of completed workflows. */
export function FoundationPage({
  role,
  title,
  view,
}: {
  role: Role | "any";
  title: string;
  view: "home" | "orders" | "calendar" | "messages" | "account";
}) {
  return (
    <AppShell role={role} title={title}>
      <Content role={role} view={view} />
    </AppShell>
  );
}
function Content({
  role,
  view,
}: {
  role: Role | "any";
  view: "home" | "orders" | "calendar" | "messages" | "account";
}) {
  const state = useBQ((s) => s);
  const active = role === "any" ? (state.role ?? "customer") : role;
  const orders = active === "customer" ? customerOrders(state) : state.orders;
  const [selected, setSelected] = useState<string | null>(null);
  const order = orders.find((o) => o.id === selected);
  const items = conversations(state, active);
  return (
    <div className="space-y-5">
      <Notice title="Development preview">
        These are local demo records. Ordering, account editing and the live backend are still under
        development.
      </Notice>
      {view === "home" && (
        <Card>
          <h2 className="text-2xl font-semibold">
            {active === "baker" ? "Your bakery workspace" : state.baker.businessName}
          </h2>
          <p className="mt-2">{state.baker.about}</p>
          <p className="mt-2 text-sm text-muted-foreground">
            {state.baker.area}, {state.baker.city} · Baker code: {state.baker.code}
          </p>
        </Card>
      )}
      {view === "account" ? (
        <Card>
          <h2 className="font-semibold">
            {active === "customer" ? state.customer.name : state.baker.ownerName}
          </h2>
          <p>{active === "customer" ? state.customer.email : state.baker.email}</p>
          <p className="mt-3 text-sm">
            Use Demo controls to switch roles, change language, export or reset local data. Account
            editing and real sign-in are not implemented yet.
          </p>
        </Card>
      ) : view === "messages" ? (
        <>
          {items.length === 0 && <Empty title="No conversations yet" />}
          {items.map((c) => (
            <Card key={c.order.id}>
              <h2 className="font-semibold">
                {c.order.id} ·{" "}
                {active === "baker" ? c.order.customerName : state.baker.businessName}
              </h2>
              <p className="my-2 text-sm">
                {c.last?.text || "Start a conversation about this order."}
              </p>
              <Button onClick={() => setSelected(c.order.id)}>Open conversation</Button>
            </Card>
          ))}
        </>
      ) : (
        <>
          {view === "calendar" && (
            <Card>
              <h2 className="font-semibold">Order agenda</h2>
              <p className="text-sm text-muted-foreground">
                Calendar editing is still under development. Blocked dates:{" "}
                {state.baker.blocked.map(fmtDate).join(", ") || "None"}.
              </p>
            </Card>
          )}
          {orders.length === 0 && <Empty title="No orders yet" />}
          {[...orders]
            .sort((a, b) => a.date.localeCompare(b.date))
            .map((o) => (
              <Card key={o.id}>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h2 className="font-semibold">
                    {o.id} · {o.source === "manual" ? "Manual order" : o.customerName}
                  </h2>
                  <StatusBadge s={o.status} />
                </div>
                <p className="my-2">{o.description}</p>
                <div className="mb-3 flex justify-between gap-3 text-sm">
                  <span>
                    {fmtDate(o.date)} {o.dueTime}
                  </span>
                  <Money v={currentQuote(o).total} />
                </div>
                <Button variant="outline" onClick={() => setSelected(o.id)}>
                  View details
                </Button>
              </Card>
            ))}
        </>
      )}
      <Sheet open={!!order} onClose={() => setSelected(null)} title={order?.id ?? "Order"}>
        {order &&
          (view === "messages" ? (
            <Chat orderId={order.id} role={active} />
          ) : (
            <>
              <StageTrack o={order} />
              <ConfigBlock o={order} baker={state.baker} />
              <QuoteBlock o={order} />
              <EventList o={order} />
            </>
          ))}
      </Sheet>
    </div>
  );
}
