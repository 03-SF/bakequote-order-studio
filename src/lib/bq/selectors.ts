import type { Role, State } from "./types";
import { toCustomerOrder } from "./machine";

export const customerOrders = (s: State) =>
  s.orders.filter((o) => o.customerId === s.customer.id).map(toCustomerOrder);

export const customerOrder = (s: State, id: string) => {
  const o = s.orders.find((x) => x.id === id && x.customerId === s.customer.id);
  return o ? toCustomerOrder(o) : null;
};

/** Conversations exist only for app orders. Customers see their own; the baker sees all app orders. */
export function conversations(s: State, role: Role) {
  const orders = s.orders.filter((o) => o.source === "app" && (role === "baker" || o.customerId === s.customer.id));
  return orders
    .map((o) => {
      const msgs = s.messages.filter((m) => m.orderId === o.id);
      const last = msgs[msgs.length - 1];
      const readAt = s.reads[o.id]?.[role] ?? "";
      const unread = msgs.filter((m) => m.from !== role && m.at > readAt).length;
      return { order: toCustomerOrder(o), last, unread, count: msgs.length };
    })
    .filter((c) => c.count > 0 || ["pending", "confirmed", "baking", "ready"].includes(c.order.status))
    .sort((a, b) => (b.last?.at ?? b.order.createdAt).localeCompare(a.last?.at ?? a.order.createdAt));
}

export const unreadTotal = (s: State, role: Role) => conversations(s, role).reduce((t, c) => t + c.unread, 0);

export const bakerRating = (s: State) => {
  const total = s.baker.seedRating * 0; // seed rating is derived from seeded reviews below
  void total;
  const rs = s.reviews.filter((r) => r.bakerId === s.baker.id);
  const avg = rs.length ? rs.reduce((t, r) => t + r.rating, 0) / rs.length : 0;
  return { avg: Math.round(avg * 10) / 10, count: rs.length };
};

export const nextId = (s: State) => `BQ-${s.nextOrderNo}`;
