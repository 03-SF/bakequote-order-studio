import { cva, type VariantProps } from "class-variance-authority";
import { X } from "lucide-react";
import { forwardRef, useEffect, useId, useRef, useState, type ReactNode } from "react";
import { cn } from "@/lib/utils";
import type { Status } from "@/lib/bq/types";
import { useT } from "@/lib/bq/i18n";

export const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition-colors disabled:pointer-events-none disabled:opacity-50 select-none whitespace-nowrap",
  {
    variants: {
      variant: {
        primary: "bg-primary text-primary-foreground hover:bg-primary-strong shadow-soft",
        secondary: "bg-secondary text-secondary-foreground hover:bg-accent",
        outline: "border border-input bg-card text-foreground hover:bg-muted",
        ghost: "text-foreground hover:bg-muted",
        danger: "bg-destructive text-destructive-foreground hover:opacity-90",
        dangerOutline: "border border-destructive/40 text-destructive bg-card hover:bg-danger-soft",
      },
      size: { md: "h-11 px-4 text-sm", sm: "h-10 px-3 text-sm", lg: "h-12 px-5 text-base", icon: "h-11 w-11" },
      block: { true: "w-full" },
    },
    defaultVariants: { variant: "primary", size: "md" },
  },
);
type BtnProps = React.ButtonHTMLAttributes<HTMLButtonElement> & VariantProps<typeof buttonVariants>;
export const Button = forwardRef<HTMLButtonElement, BtnProps>(({ className, variant, size, block, type = "button", ...p }, ref) => (
  <button ref={ref} type={type} className={cn(buttonVariants({ variant, size, block }), className)} {...p} />
));
Button.displayName = "Button";

export function Card({ className, children, ...p }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn("card p-4 md:p-5", className)} {...p}>
      {children}
    </div>
  );
}
export function SectionTitle({ children, action }: { children: ReactNode; action?: ReactNode }) {
  return (
    <div className="mb-3 flex items-center justify-between gap-2">
      <h2 className="text-lg font-semibold">{children}</h2>
      {action}
    </div>
  );
}

const tone = {
  rose: "bg-secondary text-secondary-foreground",
  green: "bg-success-soft text-success",
  amber: "bg-warning-soft text-warning",
  blue: "bg-info-soft text-info",
  red: "bg-danger-soft text-destructive",
  gray: "bg-muted text-muted-foreground",
};
export function Badge({ t = "gray", children, className }: { t?: keyof typeof tone; children: ReactNode; className?: string }) {
  return <span className={cn("inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold", tone[t], className)}>{children}</span>;
}
const statusTone: Record<Status, keyof typeof tone> = {
  pending: "amber",
  confirmed: "blue",
  baking: "rose",
  ready: "green",
  delivered: "gray",
  declined: "red",
  withdrawn: "gray",
  cancelled: "red",
};
export function StatusBadge({ s }: { s: Status }) {
  const t = useT();
  return <Badge t={statusTone[s]}>{t(s[0].toUpperCase() + s.slice(1))}</Badge>;
}

export const Money = ({ v, className }: { v: number; className?: string }) => (
  <span className={cn("num", className)}>PKR {v.toLocaleString("en")}</span>
);
export const Ref = ({ id }: { id: string }) => <span className="num font-semibold">{id}</span>;

export function Field({ label, hint, error, children, htmlFor }: { label: string; hint?: string; error?: string; children: ReactNode; htmlFor?: string }) {
  return (
    <div className="space-y-1.5">
      <label htmlFor={htmlFor} className="block text-sm font-semibold">
        {label}
      </label>
      {children}
      {hint && !error && <p className="text-xs text-muted-foreground">{hint}</p>}
      {error && (
        <p role="alert" className="text-xs font-semibold text-destructive">
          {error}
        </p>
      )}
    </div>
  );
}
export const Input = forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(({ className, ...p }, ref) => (
  <input ref={ref} className={cn("field", className)} {...p} />
));
Input.displayName = "Input";
export const Textarea = (p: React.TextareaHTMLAttributes<HTMLTextAreaElement>) => <textarea rows={3} {...p} className={cn("field", p.className)} />;
export const Select = (p: React.SelectHTMLAttributes<HTMLSelectElement>) => <select {...p} className={cn("field", p.className)} />;

export function Toggle({ checked, onChange, label, desc }: { checked: boolean; onChange: (v: boolean) => void; label: string; desc?: string }) {
  const id = useId();
  return (
    <div className="flex min-h-11 items-center justify-between gap-4 py-2">
      <label htmlFor={id} className="min-w-0">
        <span className="block text-sm font-semibold">{label}</span>
        {desc && <span className="block text-xs text-muted-foreground">{desc}</span>}
      </label>
      <button
        id={id}
        role="switch"
        aria-checked={checked}
        onClick={() => onChange(!checked)}
        className={cn("relative h-7 w-12 shrink-0 rounded-full transition-colors", checked ? "bg-primary" : "bg-input")}
      >
        <span className={cn("absolute top-1 h-5 w-5 rounded-full bg-card shadow-soft transition-all", checked ? "start-6" : "start-1")} />
      </button>
    </div>
  );
}

export function Tabs<T extends string>({ value, onChange, items, label }: { value: T; onChange: (v: T) => void; items: { v: T; label: string; count?: number }[]; label: string }) {
  return (
    <div role="tablist" aria-label={label} className="-mx-1 flex gap-1 overflow-x-auto px-1 pb-1">
      {items.map((i) => (
        <button
          key={i.v}
          role="tab"
          aria-selected={value === i.v}
          onClick={() => onChange(i.v)}
          className={cn(
            "h-10 shrink-0 rounded-full border px-4 text-sm font-semibold transition-colors",
            value === i.v ? "border-primary bg-primary text-primary-foreground" : "border-border bg-card text-muted-foreground hover:text-foreground",
          )}
        >
          {i.label}
          {i.count !== undefined && <span className="num ms-1.5 opacity-80">{i.count}</span>}
        </button>
      ))}
    </div>
  );
}

export function Chips<T extends string>({ value, onChange, items, multi, label }: { value: T | T[]; onChange: (v: T) => void; items: { v: T; label: string; sub?: string; disabled?: boolean }[]; multi?: boolean; label: string }) {
  const sel = (v: T) => (Array.isArray(value) ? value.includes(v) : value === v);
  return (
    <div role={multi ? "group" : "radiogroup"} aria-label={label} className="flex flex-wrap gap-2">
      {items.map((i) => (
        <button
          key={i.v}
          role={multi ? "checkbox" : "radio"}
          aria-checked={sel(i.v)}
          disabled={i.disabled}
          onClick={() => onChange(i.v)}
          className={cn(
            "min-h-11 rounded-xl border px-3 py-1.5 text-start text-sm transition-colors disabled:opacity-40",
            sel(i.v) ? "border-primary bg-secondary text-secondary-foreground ring-1 ring-primary" : "border-border bg-card hover:bg-muted",
          )}
        >
          <span className="block font-semibold">{i.label}</span>
          {i.sub && <span className="num block text-xs text-muted-foreground">{i.sub}</span>}
        </button>
      ))}
    </div>
  );
}

export function Sheet({ open, onClose, title, children, footer, desc }: { open: boolean; onClose: () => void; title: string; desc?: string; children: ReactNode; footer?: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const id = useId();
  useEffect(() => {
    if (!open) return;
    const prev = document.activeElement as HTMLElement | null;
    const k = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", k);
    document.body.style.overflow = "hidden";
    setTimeout(() => ref.current?.querySelector<HTMLElement>("input,textarea,select,button[data-autofocus]")?.focus() ?? ref.current?.focus(), 20);
    return () => {
      window.removeEventListener("keydown", k);
      document.body.style.overflow = "";
      prev?.focus?.();
    };
  }, [open, onClose]);
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center md:items-center">
      <div className="absolute inset-0 bg-overlay animate-in fade-in" onClick={onClose} aria-hidden />
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-labelledby={id}
        tabIndex={-1}
        className="relative flex max-h-[92dvh] w-full flex-col rounded-t-3xl bg-card shadow-lift animate-in slide-in-from-bottom-4 md:max-w-lg md:rounded-3xl"
      >
        <div className="flex items-start justify-between gap-3 border-b px-5 py-4">
          <div>
            <h2 id={id} className="text-lg font-semibold">
              {title}
            </h2>
            {desc && <p className="text-sm text-muted-foreground">{desc}</p>}
          </div>
          <Button variant="ghost" size="icon" onClick={onClose} aria-label="Close">
            <X className="h-5 w-5" />
          </Button>
        </div>
        <div className="flex-1 space-y-4 overflow-y-auto px-5 py-4">{children}</div>
        {footer && <div className="safe-bottom flex flex-wrap justify-end gap-2 border-t px-5 py-3">{footer}</div>}
      </div>
    </div>
  );
}

export function Notice({ t = "rose", title, children, action }: { t?: "rose" | "amber" | "red" | "green" | "blue"; title?: string; children?: ReactNode; action?: ReactNode }) {
  const c = { rose: "bg-secondary text-secondary-foreground", amber: "bg-warning-soft text-warning", red: "bg-danger-soft text-destructive", green: "bg-success-soft text-success", blue: "bg-info-soft text-info" }[t];
  return (
    <div role="status" className={cn("flex flex-wrap items-start justify-between gap-2 rounded-xl px-4 py-3 text-sm", c)}>
      <div className="min-w-0">
        {title && <p className="font-bold">{title}</p>}
        {children && <div className="opacity-90">{children}</div>}
      </div>
      {action}
    </div>
  );
}

export function Empty({ title, children, action }: { title: string; children?: ReactNode; action?: ReactNode }) {
  return (
    <div className="rounded-2xl border border-dashed bg-card/60 px-6 py-10 text-center">
      <p className="font-display text-lg font-semibold">{title}</p>
      {children && <p className="mx-auto mt-1 max-w-sm text-sm text-muted-foreground">{children}</p>}
      {action && <div className="mt-4 flex justify-center">{action}</div>}
    </div>
  );
}

export function Row({ k, v, strong }: { k: ReactNode; v: ReactNode; strong?: boolean }) {
  return (
    <div className={cn("flex items-baseline justify-between gap-3 py-1.5 text-sm", strong && "border-t pt-2.5 text-base font-bold")}>
      <span className={strong ? "" : "text-muted-foreground"}>{k}</span>
      <span className="text-end">{v}</span>
    </div>
  );
}

// ---------- toasts ----------
type T = { id: number; msg: string; kind: "ok" | "err" };
let tl: ((t: T) => void) | null = null;
let tid = 0;
export const toast = (msg: string, kind: "ok" | "err" = "ok") => tl?.({ id: ++tid, msg, kind });
export function Toaster() {
  const [items, set] = useState<T[]>([]);
  useEffect(() => {
    tl = (t) => {
      set((x) => [...x, t]);
      setTimeout(() => set((x) => x.filter((i) => i.id !== t.id)), 3800);
    };
    return () => {
      tl = null;
    };
  }, []);
  return (
    <div aria-live="polite" className="pointer-events-none fixed inset-x-0 top-3 z-[60] flex flex-col items-center gap-2 px-3">
      {items.map((i) => (
        <div key={i.id} className={cn("pointer-events-auto max-w-md rounded-xl px-4 py-3 text-sm font-semibold shadow-lift", i.kind === "ok" ? "bg-foreground text-background" : "bg-destructive text-destructive-foreground")}>
          {i.msg}
        </div>
      ))}
    </div>
  );
}
