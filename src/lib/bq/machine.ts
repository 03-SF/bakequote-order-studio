import type { Baker, CustomerOrder, Order, QuoteLine, Role, State, Status } from "./types";
import { sum } from "./pricing";
import { addDays } from "./dates";

export class RuleError extends Error {}
const fail = (m: string): never => {
  throw new RuleError(m);
};

export const ACTIVE: Status[] = ["pending", "confirmed", "baking", "ready"];
export const BOOKED: Status[] = ["confirmed", "baking", "ready", "delivered"];
export const CLOSED: Status[] = ["delivered", "declined", "withdrawn", "cancelled"];
export const STAGES: Status[] = ["pending", "confirmed", "baking", "ready", "delivered"];
const NEXT: Partial<Record<Status, Status>> = { confirmed: "baking", baking: "ready", ready: "delivered" };
export const nextStage = (s: Status) => NEXT[s] ?? null;

export const currentQuote = (o: Pick<Order, "quotes">) => {
  const quote = o.quotes.at(-1);
  if (!quote) throw new RuleError("This order has no quotation.");
  return quote;
};
export const isAgreed = (o: Pick<Order, "quotes" | "agreedVersion">) =>
  o.agreedVersion !== null && o.agreedVersion === currentQuote(o).version;
export const balance = (o: Pick<Order, "quotes" | "advance">) => currentQuote(o).total - o.advance;

const log = (o: Order, at: string, by: Role | "system", text: string, priv = false): Order => ({
  ...o,
  events: [...o.events, { at, by, text, ...(priv ? { private: true } : {}) }],
});

// ---------- availability ----------
export type DayStatus = "open" | "blocked" | "full" | "past" | "lead";
export function bookedOn(orders: Order[], date: string, excludeId?: string) {
  return orders.filter((o) => o.date === date && BOOKED.includes(o.status) && o.id !== excludeId).length;
}
/** Pending requests never reserve a date: only booked statuses count toward capacity. */
export function dayStatus(b: Baker, orders: Order[], date: string, today: string, excludeId?: string): DayStatus {
  if (date < today) return "past";
  if (b.blocked.includes(date)) return "blocked";
  if (bookedOn(orders, date, excludeId) >= b.capacityPerDay) return "full";
  if (date < addDays(today, b.leadDays)) return "lead";
  return "open";
}

// ---------- demo allowance (fixture, not a commercial plan) ----------
export const DEMO_ALLOWANCE = 8;
export function allowance(s: Pick<State, "orders" | "demo">, today: string) {
  const month = today.slice(0, 7);
  const used = s.orders.filter((o) => o.confirmedAt && o.confirmedAt.slice(0, 7) === month).length;
  const remaining = s.demo.allowanceReached ? 0 : Math.max(0, DEMO_ALLOWANCE - used);
  return { limit: DEMO_ALLOWANCE, used, remaining, forced: s.demo.allowanceReached };
}

// ---------- transitions (pure; each returns a new order or throws RuleError) ----------
export function reviseQuote(o: Order, lines: QuoteLine[], note: string, at: string): Order {
  if (o.source !== "app") fail("Manual orders have no customer quote flow.");
  if (o.status !== "pending") fail("Quotes can only be revised while the request is pending.");
  const clean = lines.filter((l) => l.label.trim());
  if (!clean.length) fail("Add at least one line item.");
  if (clean.some((l) => !Number.isFinite(l.amount) || l.amount < 0)) fail("Line amounts must be zero or more.");
  const total = sum(clean);
  if (total <= 0) fail("Quote total must be more than zero.");
  const prev = currentQuote(o);
  const version = prev.version + 1;
  const hadAgreement = isAgreed(o);
  const next: Order = { ...o, quotes: [...o.quotes, { version, lines: clean, total, note, at }], agreedVersion: null };
  return log(
    next,
    at,
    "baker",
    `Quote revised to v${version}: PKR ${total.toLocaleString("en")}${hadAgreement ? ` — agreement on v${prev.version} no longer applies` : ""}.`,
  );
}

export function agreeQuote(o: Order, version: number, at: string): Order {
  if (o.status !== "pending") fail("Only pending requests can be agreed.");
  if (version !== currentQuote(o).version) fail("This quote was revised. Review the latest version.");
  if (isAgreed(o)) fail("You already agreed to this quote.");
  return log({ ...o, agreedVersion: version }, at, "customer", `Customer agreed to quote v${version}.`);
}

export interface ConfirmCtx {
  today: string;
  baker: Baker;
  orders: Order[];
  allowanceRemaining: number;
  offline: boolean;
}
export function confirmChecks(o: Order, ctx: ConfirmCtx) {
  const ds = dayStatus(ctx.baker, ctx.orders, o.date, ctx.today, o.id);
  return {
    agreed: isAgreed(o),
    available: ds === "open" || ds === "lead",
    dayStatus: ds,
    allowance: ctx.allowanceRemaining > 0,
    online: !ctx.offline,
  };
}
export function confirmOrder(o: Order, dueTime: string, ctx: ConfirmCtx, at: string): Order {
  if (o.status !== "pending") fail(o.status === "confirmed" ? "Already confirmed." : "Only pending requests can be confirmed.");
  const c = confirmChecks(o, ctx);
  if (!c.online) fail("You're offline. Confirmation needs a connection.");
  if (!c.agreed) fail(`Customer hasn't agreed to the current quote (v${currentQuote(o).version}).`);
  if (!c.available) fail(`The date is ${c.dayStatus === "past" ? "in the past" : c.dayStatus}. Reschedule first.`);
  if (!c.allowance) fail("Demo allowance reached. The request stays pending.");
  if (!/^\d{2}:\d{2}$/.test(dueTime)) fail("Set a due time.");
  return log(
    { ...o, status: "confirmed", dueTime, confirmedAt: at },
    at,
    "baker",
    `Order confirmed for ${o.date} at ${dueTime} (quote v${currentQuote(o).version}).`,
  );
}

export function advanceStage(o: Order, to: Status, at: string): Order {
  if (o.cancelRequest?.status === "requested") fail("Resolve the cancellation request first.");
  if (nextStage(o.status) !== to) fail(`Can't move from ${o.status} to ${to}.`);
  return log({ ...o, status: to }, at, "baker", `Status: ${to}.`);
}

export function declineOrder(o: Order, reason: string, at: string): Order {
  if (o.status !== "pending") fail("Only pending requests can be declined.");
  if (!reason.trim()) fail("Give the customer a reason.");
  return log({ ...o, status: "declined" }, at, "baker", `Request declined: ${reason.trim()}`);
}

export function withdrawOrder(o: Order, reason: string, at: string): Order {
  if (o.status !== "pending") fail("Only pending requests can be withdrawn. Confirmed orders need a cancellation request.");
  return log({ ...o, status: "withdrawn" }, at, "customer", `Customer withdrew the request${reason.trim() ? `: ${reason.trim()}` : "."}`);
}

export function requestCancellation(o: Order, reason: string, at: string): Order {
  if (!["confirmed", "baking"].includes(o.status)) fail("Cancellation can be requested for confirmed or baking orders.");
  if (o.cancelRequest?.status === "requested") fail("A cancellation request is already open.");
  if (!reason.trim()) fail("Tell the baker why.");
  return log(
    { ...o, cancelRequest: { by: "customer", reason: reason.trim(), at, status: "requested" } },
    at,
    "customer",
    `Cancellation requested: ${reason.trim()}`,
  );
}

export function resolveCancellation(o: Order, approve: boolean, at: string): Order {
  if (o.cancelRequest?.status !== "requested") fail("No open cancellation request.");
  const cr = { ...o.cancelRequest!, status: approve ? ("approved" as const) : ("rejected" as const) };
  return log(
    { ...o, cancelRequest: cr, status: approve ? "cancelled" : o.status },
    at,
    "baker",
    approve ? "Cancellation approved. Order cancelled." : "Cancellation request declined; order continues.",
  );
}

export function reschedule(o: Order, date: string, reason: string, ctx: Omit<ConfirmCtx, "allowanceRemaining">, at: string): Order {
  if (!["pending", "confirmed", "baking"].includes(o.status)) fail("This order can't be rescheduled now.");
  if (date === o.date) fail("Pick a different date.");
  const ds = dayStatus(ctx.baker, ctx.orders, date, ctx.today, o.id);
  if (ds === "past" || ds === "blocked") fail(`That date is ${ds}.`);
  if (ds === "full" && o.status !== "pending") fail("That date is full.");
  return log({ ...o, date }, at, "baker", `Rescheduled from ${o.date} to ${date}${reason.trim() ? ` — ${reason.trim()}` : ""}.`);
}

export function recordAdvance(o: Order, amount: number, at: string): Order {
  if (["declined", "withdrawn", "cancelled"].includes(o.status)) fail("Closed orders can't take advances.");
  if (!Number.isFinite(amount) || amount <= 0) fail("Enter an amount above zero.");
  if (o.advance + amount > currentQuote(o).total) fail("Advance can't exceed the order total.");
  return log(
    { ...o, advance: o.advance + amount },
    at,
    "baker",
    `Advance of PKR ${amount.toLocaleString("en")} recorded (received outside the app).`,
  );
}

export function setPrivateNotes(o: Order, notes: string, at: string): Order {
  return log({ ...o, privateNotes: notes }, at, "baker", "Private notes updated.", true);
}

export const canReview = (o: Pick<Order, "status" | "source" | "reviewed">) =>
  o.status === "delivered" && o.source === "app" && !o.reviewed;
export function markReviewed(o: Order, at: string): Order {
  if (!canReview(o)) fail(o.reviewed ? "You already reviewed this order." : "Reviews open once an app order is delivered.");
  return log({ ...o, reviewed: true }, at, "customer", "Customer left a review.");
}

/** The only projection customer UI may use. Strips private notes & private events. */
export function toCustomerOrder(o: Order): CustomerOrder {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { privateNotes, ...rest } = o;
  return { ...rest, events: o.events.filter((e) => !e.private) };
}
