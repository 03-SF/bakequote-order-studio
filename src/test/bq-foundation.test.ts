import { beforeEach, describe, expect, it } from "vitest";
import { addDays, iso, parseIso, stamp } from "@/lib/bq/dates";
import {
  agreeQuote,
  advanceStage,
  confirmOrder,
  currentQuote,
  isAgreed,
  reviseQuote,
  toCustomerOrder,
} from "@/lib/bq/machine";
import { estimate } from "@/lib/bq/pricing";
import { createSeed, DEFAULT_DRAFT, seedBaker } from "@/lib/bq/seed";
import { act, exportState, getState, importState, resetDemo } from "@/lib/bq/store";
const day = "2026-10-25";
const at = "2026-10-25T12:00:00Z";
function pending() {
  const order = createSeed(day).orders.find((o) => o.source === "app" && o.status === "pending");
  if (!order) throw new Error("Missing pending fixture");
  return order;
}
describe("Date parsing", () => {
  it("handles month rollover and leap days", () => {
    expect(addDays("2026-10-31", 1)).toBe("2026-11-01");
    expect(iso(parseIso("2024-02-29"))).toBe("2024-02-29");
  });
  it.each(["", "2026-02-30", "2026-13-01", "2026-1-2"])("rejects invalid date %s", (value) => {
    expect(() => parseIso(value)).toThrow(RangeError);
  });
  it.each(["25:00", "12:60", "oops"])("rejects invalid time %s", (value) => {
    expect(() => stamp(day, value)).toThrow(RangeError);
  });
});
describe("Pricing and order rules", () => {
  it("itemizes the documented 4100 PKR estimate", () => {
    expect(estimate(seedBaker(), DEFAULT_DRAFT)).toMatchObject({
      productSubtotal: 3800,
      deliveryFee: 300,
      total: 4100,
    });
  });
  it("fails clearly for an order without a quote", () => {
    expect(() => currentQuote({ quotes: [] })).toThrow("no quotation");
  });
  it("invalidates old agreement after a revised quote", () => {
    const fixture = pending();
    fixture.quotes = [
      { version: 1, lines: estimate(seedBaker(), DEFAULT_DRAFT).lines, total: 4100, note: "", at },
    ];
    const agreed = agreeQuote(fixture, 1, at);
    expect(isAgreed(agreed)).toBe(true);
    const revised = reviseQuote(
      agreed,
      [...currentQuote(agreed).lines, { label: "Custom design", amount: 400 }],
      "",
      at,
    );
    expect(isAgreed(revised)).toBe(false);
    expect(currentQuote(revised).total).toBe(4500);
    expect(() => agreeQuote(revised, 1, at)).toThrow("revised");
  });
  it("requires agreement, allows only sequential production transitions", () => {
    const order = { ...pending(), date: addDays(day, 10) };
    const ctx = {
      today: day,
      baker: seedBaker(),
      orders: [],
      allowanceRemaining: 8,
      offline: false,
    };
    expect(() => confirmOrder(order, "16:00", ctx, at)).toThrow("agreed");
    const agreed = agreeQuote(order, 1, at);
    expect(() => confirmOrder(agreed, "16:00", { ...ctx, offline: true }, at)).toThrow("offline");
    expect(() => confirmOrder(agreed, "16:00", { ...ctx, allowanceRemaining: 0 }, at)).toThrow(
      "allowance",
    );
    const confirmed = confirmOrder(agreed, "16:00", ctx, at);
    expect(() => advanceStage(confirmed, "delivered", at)).toThrow("Can't move");
    expect(advanceStage(confirmed, "baking", at).status).toBe("baking");
  });
  it("removes private notes and events from customer data", () => {
    const order = {
      ...pending(),
      privateNotes: "secret",
      events: [{ at, by: "baker" as const, text: "secret", private: true }],
    };
    const customer = toCustomerOrder(order);
    expect(customer).not.toHaveProperty("privateNotes");
    expect(customer.events).toEqual([]);
  });
});
describe("Demo persistence", () => {
  beforeEach(() => {
    localStorage.clear();
    resetDemo();
  });
  it("exports, restores and resets saved changes", () => {
    expect(
      act((s) => {
        s.customer.name = "Changed";
      }).ok,
    ).toBe(true);
    const saved = exportState();
    resetDemo();
    expect(getState().customer.name).toBe("Sara Ahmed");
    expect(importState(saved).ok).toBe(true);
    expect(getState().customer.name).toBe("Changed");
  });
  it("does not replace current data with an invalid export", () => {
    const before = getState();
    expect(importState('{"state":{}}').ok).toBe(false);
    expect(getState()).toBe(before);
  });
});
