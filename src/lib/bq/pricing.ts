import type { Baker, OrderConfig, QuoteLine } from "./types";

export interface Estimate {
  lines: QuoteLine[];
  productSubtotal: number;
  deliveryFee: number;
  total: number;
}

export const sum = (lines: QuoteLine[]) => lines.reduce((t, l) => t + l.amount, 0);

/** Itemised estimate from the baker's live catalog. Pure: no UI or storage. */
export function estimate(b: Baker, cfg: Partial<OrderConfig>): Estimate {
  const lines: QuoteLine[] = [];
  const product = b.products.find((p) => p.id === cfg.productId && p.active);
  const opt = product?.options.find((o) => o.id === cfg.optionId);
  if (product && opt) lines.push({ label: `${product.name} · ${opt.label}`, amount: opt.price });
  const fl = b.flavours.find((f) => f.id === cfg.flavourId);
  if (fl && fl.price > 0) lines.push({ label: `Flavour: ${fl.label}`, amount: fl.price });
  const fin = b.finishes.find((f) => f.id === cfg.finishId);
  if (fin && fin.price > 0) lines.push({ label: `Finish: ${fin.label}`, amount: fin.price });
  for (const id of cfg.extraIds ?? []) {
    const ex = b.extras.find((e) => e.id === id);
    if (ex) lines.push({ label: `Extra: ${ex.label}`, amount: ex.price });
  }
  const productSubtotal = sum(lines);
  let deliveryFee = 0;
  if (cfg.fulfilment === "delivery") {
    const z = b.zones.find((z) => z.id === cfg.zoneId);
    if (z) {
      deliveryFee = z.fee;
      lines.push({ label: `Delivery: ${z.name}`, amount: z.fee });
    }
  }
  return { lines, productSubtotal, deliveryFee, total: productSubtotal + deliveryFee };
}

export const startingPrice = (b: Baker, productId: string) => {
  const p = b.products.find((x) => x.id === productId);
  return p && p.options.length ? Math.min(...p.options.map((o) => o.price)) : 0;
};

/** Returns notices for draft fields that no longer exist in the catalog. */
export function catalogConflicts(b: Baker, cfg: Partial<OrderConfig>): string[] {
  const out: string[] = [];
  const p = b.products.find((x) => x.id === cfg.productId);
  if (cfg.productId && (!p || !p.active)) out.push("The item you picked is no longer on the menu.");
  else if (p && cfg.optionId && !p.options.some((o) => o.id === cfg.optionId)) out.push("The size you picked is no longer offered.");
  if (cfg.flavourId && !b.flavours.some((f) => f.id === cfg.flavourId)) out.push("The flavour you picked was removed.");
  if (cfg.finishId && !b.finishes.some((f) => f.id === cfg.finishId)) out.push("The finish you picked was removed.");
  if ((cfg.extraIds ?? []).some((id) => !b.extras.some((e) => e.id === id))) out.push("An extra you picked was removed.");
  if (cfg.fulfilment === "delivery" && (!b.delivery || (cfg.zoneId && !b.zones.some((z) => z.id === cfg.zoneId))))
    out.push("Your delivery zone is no longer available.");
  if (cfg.fulfilment === "pickup" && !b.pickup) out.push("Pickup is no longer offered.");
  return out;
}
