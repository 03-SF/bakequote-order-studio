import { Check, ImagePlus, RotateCw, ShieldAlert } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";
import type { Baker, CustomerOrder, Message, Order, Role } from "@/lib/bq/types";
import { STAGES, balance, currentQuote, isAgreed } from "@/lib/bq/machine";
import { fmtDate, fmtStamp, fmtTime } from "@/lib/bq/dates";
import { act, useBQ } from "@/lib/bq/store";
import { fileToDataUrl } from "@/lib/bq/media";
import { Badge, Button, Card, Money, Notice, Row, Sheet, Textarea, toast } from "./ui";

type AnyOrder = CustomerOrder | Order;

export function StageTrack({ o }: { o: AnyOrder }) {
  const off = ["declined", "withdrawn", "cancelled"].includes(o.status);
  const idx = STAGES.indexOf(o.status);
  return (
    <ol className="flex items-center gap-1" aria-label="Order progress">
      {STAGES.map((s, i) => {
        const done = !off && i <= idx;
        return (
          <li key={s} className="flex min-w-0 flex-1 flex-col items-center gap-1">
            <span className={cn("h-1.5 w-full rounded-full", done ? "bg-primary" : "bg-muted")} />
            <span className={cn("truncate text-[11px] font-semibold capitalize", done ? "text-foreground" : "text-muted-foreground")} aria-current={i === idx ? "step" : undefined}>
              {s}
            </span>
          </li>
        );
      })}
    </ol>
  );
}

export function QuoteBlock({ o }: { o: AnyOrder }) {
  const q = currentQuote(o);
  const [hist, setHist] = useState(false);
  return (
    <div>
      <div className="mb-2 flex flex-wrap items-center gap-2">
        <Badge t="rose">Quote v{q.version}</Badge>
        {o.source === "manual" ? (
          <Badge>Manual total</Badge>
        ) : isAgreed(o) ? (
          <Badge t="green">
            <Check className="h-3 w-3" /> Customer agreed v{o.agreedVersion}
          </Badge>
        ) : o.status === "pending" ? (
          <Badge t="amber">Awaiting customer agreement</Badge>
        ) : null}
      </div>
      {q.lines.map((l, i) => (
        <Row key={i} k={l.label} v={<Money v={l.amount} />} />
      ))}
      <Row strong k="Total" v={<Money v={q.total} />} />
      {q.note && <p className="mt-1 text-xs text-muted-foreground">Note: {q.note}</p>}
      <div className="mt-3 rounded-xl bg-muted px-3 py-2">
        <Row k="Advance recorded" v={<Money v={o.advance} />} />
        <Row k="Balance due" v={<Money v={balance(o)} className="font-bold text-foreground" />} />
        <p className="text-xs text-muted-foreground">Payments happen outside BakeQuote; the baker records them here. Nothing is processed in-app.</p>
      </div>
      {o.quotes.length > 1 && (
        <div className="mt-3">
          <Button variant="ghost" size="sm" onClick={() => setHist(!hist)} aria-expanded={hist}>
            {hist ? "Hide" : "Show"} quote history ({o.quotes.length} versions)
          </Button>
          {hist && (
            <ul className="mt-2 space-y-2">
              {[...o.quotes].reverse().map((v) => (
                <li key={v.version} className="rounded-xl border px-3 py-2 text-sm">
                  <div className="flex justify-between font-semibold">
                    <span>v{v.version} · {fmtStamp(v.at)}</span>
                    <Money v={v.total} />
                  </div>
                  <p className="text-xs text-muted-foreground">{v.lines.map((l) => `${l.label} ${l.amount}`).join(" · ")}</p>
                  {v.version !== q.version && <p className="text-xs text-muted-foreground">Superseded — any agreement on this version no longer applies.</p>}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}

export function ConfigBlock({ o, baker }: { o: AnyOrder; baker: Baker }) {
  const c = o.config;
  if (!c) return <p className="text-sm">{o.description}</p>;
  const p = baker.products.find((x) => x.id === c.productId);
  const name = (list: { id: string; label: string }[], id: string) => list.find((x) => x.id === id)?.label ?? "—";
  return (
    <div>
      <Row k="Item" v={p?.name ?? "Item no longer on menu"} />
      <Row k={p?.kind === "cupcake" ? "Quantity" : "Weight"} v={p ? name(p.options, c.optionId) : "—"} />
      <Row k="Flavour" v={name(baker.flavours, c.flavourId)} />
      <Row k="Finish" v={name(baker.finishes, c.finishId)} />
      <Row k="Extras" v={c.extraIds.length ? c.extraIds.map((i) => name(baker.extras, i)).join(", ") : "None"} />
      {c.cakeMessage && <Row k="Message on cake" v={`“${c.cakeMessage}”`} />}
      <Row k="Date" v={<span className="num">{fmtDate(o.date)}{o.dueTime ? ` · ${o.dueTime}` : ""}</span>} />
      <Row k="Fulfilment" v={o.fulfilment === "delivery" ? `Delivery · ${name(baker.zones.map((z) => ({ id: z.id, label: z.name })), c.zoneId)}` : "Pickup"} />
      {o.fulfilment === "delivery" && <Row k="Address" v={c.address} />}
      {c.instructions && <p className="mt-2 rounded-xl bg-muted px-3 py-2 text-sm">{c.instructions}</p>}
      {c.images.length > 0 && (
        <div className="mt-3 flex flex-wrap gap-2">
          {c.images.map((src, i) => (
            <img key={i} src={src} alt={`Reference image ${i + 1}`} className="h-24 w-24 rounded-xl border object-cover" />
          ))}
        </div>
      )}
    </div>
  );
}

export function EventList({ o }: { o: AnyOrder }) {
  return (
    <ol className="relative space-y-3 border-s ps-4">
      {[...o.events].reverse().map((e, i) => (
        <li key={i} className="relative">
          <span className={cn("absolute -start-[21px] top-1.5 h-2.5 w-2.5 rounded-full", e.private ? "bg-warning" : "bg-primary")} />
          <p className="text-sm">{e.text}</p>
          <p className="text-xs text-muted-foreground">
            <span className="num">{fmtStamp(e.at)}</span> · {e.by}
            {e.private ? " · private" : ""}
          </p>
        </li>
      ))}
    </ol>
  );
}

let mid = 0;
export function Chat({ orderId, role, height = "h-[52dvh]" }: { orderId: string; role: Role; height?: string }) {
  const msgs = useBQ((s) => s.messages.filter((m) => m.orderId === orderId));
  const demo = useBQ((s) => s.demo);
  const [text, setText] = useState("");
  const [report, setReport] = useState(false);
  const [rKind, setRKind] = useState("Report conversation");
  const end = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const last = msgs[msgs.length - 1]?.at;
  useEffect(() => {
    end.current?.scrollIntoView({ block: "end" });
    act((d) => {
      d.reads[orderId] = { ...(d.reads[orderId] ?? { customer: "", baker: "" }), [role]: new Date().toISOString() };
    });
  }, [last, orderId, role]);

  const push = (m: Omit<Message, "id" | "at" | "status" | "orderId" | "from">) => {
    const failed = demo.offline || (!!m.image && demo.failUploads);
    act((d) => {
      d.messages.push({ ...m, id: `m-${Date.now()}-${++mid}`, orderId, from: role, at: new Date().toISOString(), status: failed ? "failed" : "sent" });
    });
    if (failed) toast(demo.offline ? "Offline — message not sent. Tap retry." : "Image upload failed (simulated). Tap retry.", "err");
  };
  const retry = (id: string) => {
    const m = msgs.find((x) => x.id === id);
    if (!m) return;
    if (demo.offline || (m.image && demo.failUploads)) return toast("Still failing — turn off the simulation in Demo controls.", "err");
    act((d) => {
      const x = d.messages.find((y) => y.id === id)!;
      x.status = "sent";
      x.at = new Date().toISOString();
    });
  };
  return (
    <div className="flex flex-col">
      <div className="flex items-center justify-between gap-2 rounded-xl bg-secondary px-3 py-2 text-xs text-secondary-foreground">
        <span className="flex items-center gap-1.5"><ShieldAlert className="h-4 w-4 shrink-0" /> Chat can't confirm or change an order — use the order page.</span>
        <button className="shrink-0 font-semibold underline" onClick={() => setReport(true)}>Report / block</button>
      </div>
      <div className={cn("mt-2 space-y-2 overflow-y-auto rounded-xl border bg-background p-3", height)} aria-live="polite">
        {msgs.length === 0 && <p className="py-8 text-center text-sm text-muted-foreground">No messages yet. Say hello!</p>}
        {msgs.map((m) => {
          const mine = m.from === role;
          return (
            <div key={m.id} className={cn("flex", mine ? "justify-end" : "justify-start")}>
              <div className={cn("max-w-[80%] rounded-2xl px-3 py-2 text-sm", mine ? "bg-primary text-primary-foreground" : "border bg-card", m.status === "failed" && "opacity-70")}>
                {m.image && <img src={m.image} alt="Shared image" className="mb-1 max-h-48 rounded-lg" />}
                {m.text && <p className="whitespace-pre-wrap break-words">{m.text}</p>}
                <p className={cn("num mt-0.5 text-[10px]", mine ? "text-primary-foreground/80" : "text-muted-foreground")}>{fmtTime(m.at)}</p>
                {m.status === "failed" && (
                  <button onClick={() => retry(m.id)} className="mt-1 flex items-center gap-1 text-xs font-bold underline">
                    <RotateCw className="h-3 w-3" /> Not sent — retry
                  </button>
                )}
              </div>
            </div>
          );
        })}
        <div ref={end} />
      </div>
      <form
        className="mt-2 flex items-end gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          if (!text.trim()) return;
          push({ text: text.trim() });
          setText("");
        }}
      >
        <Button variant="outline" size="icon" aria-label="Attach image" onClick={() => fileRef.current?.click()}>
          <ImagePlus className="h-5 w-5" />
        </Button>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="hidden"
          aria-label="Image to send"
          onChange={async (e) => {
            const f = e.target.files?.[0];
            e.target.value = "";
            if (!f) return;
            try {
              push({ text: "", image: await fileToDataUrl(f, 600) });
            } catch (err) {
              toast((err as Error).message, "err");
            }
          }}
        />
        <label className="sr-only" htmlFor={`msg-${orderId}`}>Message</label>
        <Textarea id={`msg-${orderId}`} rows={1} value={text} onChange={(e) => setText(e.target.value)} placeholder="Write a message…" className="min-h-11 flex-1 resize-none" />
        <Button type="submit" disabled={!text.trim()}>Send</Button>
      </form>
      <Sheet open={report} onClose={() => setReport(false)} title="Report or block" desc="Demo only: this records an acknowledgement. No moderation team reviews it."
        footer={<><Button variant="outline" onClick={() => setReport(false)}>Cancel</Button><Button variant="danger" onClick={() => { act((d) => void d.reports.push({ at: new Date().toISOString(), orderId, by: role, kind: rKind })); setReport(false); toast(`${rKind}: acknowledged (demo).`); }}>Submit</Button></>}>
        {["Report conversation", "Block this person (demo)"].map((k) => (
          <label key={k} className="flex min-h-11 items-center gap-3 rounded-xl border px-3">
            <input type="radio" name="rk" checked={rKind === k} onChange={() => setRKind(k)} /> {k}
          </label>
        ))}
      </Sheet>
    </div>
  );
}

export function OrderRow({ o, to, showCustomer }: { o: AnyOrder; to: React.ReactNode; showCustomer?: boolean }) {
  void o; void showCustomer;
  return <>{to}</>;
}

export { Card, Notice };
