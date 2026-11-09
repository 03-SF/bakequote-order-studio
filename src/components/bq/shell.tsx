import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import { useHydrated } from "@tanstack/react-router";
import { ArrowLeft, CalendarDays, ClipboardList, Home, MessageCircle, Settings2, Sun, User, WifiOff } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { cn } from "@/lib/utils";
import { act, exportState, importState, resetDemo, useBQ } from "@/lib/bq/store";
import { useT } from "@/lib/bq/i18n";
import { unreadTotal } from "@/lib/bq/selectors";
import { allowance } from "@/lib/bq/machine";
import { todayIso } from "@/lib/bq/dates";
import type { Role } from "@/lib/bq/types";
import { Button, Notice, Sheet, Toaster, Toggle, buttonVariants, toast } from "./ui";

export function Wordmark({ className }: { className?: string }) {
  return (
    <span className={cn("wordmark inline-flex items-center gap-1.5 text-xl text-foreground", className)} dir="ltr">
      <svg viewBox="0 0 24 24" aria-hidden className="h-6 w-6 text-primary" fill="currentColor">
        <path d="M4 13h16v6a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-6Z" opacity=".35" />
        <path d="M5 9.5C5 7.6 6.6 6 8.5 6h7C17.4 6 19 7.6 19 9.5V12H5V9.5Z" />
        <circle cx="12" cy="3.5" r="1.5" />
      </svg>
      Bake<span className="text-primary">Quote</span>
    </span>
  );
}

const NAV: Record<Role, { to: string; label: string; icon: typeof Home }[]> = {
  customer: [
    { to: "/home", label: "Home", icon: Home },
    { to: "/orders", label: "Orders", icon: ClipboardList },
    { to: "/messages", label: "Messages", icon: MessageCircle },
    { to: "/account", label: "Account", icon: User },
  ],
  baker: [
    { to: "/baker/today", label: "Today", icon: Sun },
    { to: "/baker/calendar", label: "Calendar", icon: CalendarDays },
    { to: "/baker/orders", label: "Orders", icon: ClipboardList },
    { to: "/messages", label: "Messages", icon: MessageCircle },
    { to: "/baker/account", label: "Account", icon: User },
  ],
};
export const homeFor = (r: Role) => (r === "customer" ? "/home" : "/baker/today");

export function useLangDir() {
  const lang = useBQ((s) => s.lang);
  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ur" ? "rtl" : "ltr";
  }, [lang]);
}

export function Splash() {
  return (
    <div className="flex min-h-dvh items-center justify-center" aria-busy="true">
      <div className="animate-pulse text-center">
        <Wordmark className="text-3xl" />
        <p className="mt-2 text-sm text-muted-foreground">Loading your demo…</p>
      </div>
    </div>
  );
}

/** Wraps every signed-in screen. `role` = required role, or "any" for shared screens (messages). */
export function AppShell({ role, title, back, actions, children, wide }: { role: Role | "any"; title: string; back?: string; actions?: ReactNode; children: ReactNode; wide?: boolean }) {
  const hydrated = useHydrated();
  if (!hydrated) return <Splash />;
  return (
    <Inner role={role} title={title} {...(back !== undefined ? { back } : {})} actions={actions} {...(wide !== undefined ? { wide } : {})}>
      {children}
    </Inner>
  );
}

function Inner({ role, title, back, actions, children, wide }: { role: Role | "any"; title: string; back?: string; actions?: ReactNode; children: ReactNode; wide?: boolean }) {
  useLangDir();
  const s = useBQ((x) => x);
  const t = useT();
  const path = useRouterState({ select: (r) => r.location.pathname });
  const active: Role | null = role === "any" ? s.role : role;
  const [demoOpen, setDemoOpen] = useState(false);

  useEffect(() => {
    if (role !== "any" && s.sessions[role] && s.role !== role) act((d) => void (d.role = role));
  }, [role, s.role, s.sessions]);

  if (!active || !s.sessions[active]) {
    return (
      <div className="flex min-h-dvh items-center justify-center px-4">
        <div className="card max-w-sm p-6 text-center">
          <Wordmark className="text-2xl" />
          <h1 className="mt-4 text-xl font-semibold">Sign in to continue</h1>
          <p className="mt-1 text-sm text-muted-foreground">This screen belongs to the {active ?? "demo"} side. Sign-in is simulated.</p>
          <div className="mt-5 flex flex-col gap-2">
            {active && (
              <Link to="/auth" search={{ role: active, mode: "signin" }} className={buttonVariants({ block: true })}>
                Sign in as {active}
              </Link>
            )}
            <Link to="/" className={buttonVariants({ variant: "outline", block: true })}>
              Back to welcome
            </Link>
          </div>
        </div>
      </div>
    );
  }
  const unread = unreadTotal(s, active);
  const nav = NAV[active];
  const isOn = (to: string) => path === to || (to !== "/" && path.startsWith(to + "/"));

  return (
    <div className="min-h-dvh md:flex">
      <Toaster />
      {/* Desktop sidebar */}
      <aside className="sticky top-0 hidden h-dvh w-64 shrink-0 flex-col border-e bg-card px-4 py-6 md:flex">
        <Link to={homeFor(active)} aria-label="BakeQuote home" className="px-2">
          <Wordmark />
        </Link>
        <p className="mt-1 px-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">{t(active === "customer" ? "Customer" : "Baker")} demo</p>
        <nav className="mt-6 flex flex-col gap-1" aria-label="Main">
          {nav.map((n) => (
            <Link key={n.to} to={n.to} className={cn("flex h-11 items-center gap-3 rounded-xl px-3 text-sm font-semibold", isOn(n.to) ? "bg-secondary text-secondary-foreground" : "text-muted-foreground hover:bg-muted hover:text-foreground")}>
              <n.icon className="h-5 w-5" aria-hidden />
              {t(n.label)}
              {n.label === "Messages" && unread > 0 && <span className="num ms-auto rounded-full bg-primary px-2 text-xs text-primary-foreground">{unread}</span>}
            </Link>
          ))}
        </nav>
        <div className="mt-auto space-y-2">
          <Button variant="outline" block onClick={() => setDemoOpen(true)}>
            <Settings2 className="h-4 w-4" /> {t("Demo controls")}
          </Button>
        </div>
      </aside>

      <div className="min-w-0 flex-1">
        <header className="sticky top-0 z-30 border-b bg-background/95 backdrop-blur">
          <div className={cn("mx-auto flex h-14 items-center gap-2 px-4", wide ? "max-w-6xl" : "max-w-4xl")}>
            {back ? (
              <Link to={back} aria-label={t("Back")} className={buttonVariants({ variant: "ghost", size: "icon" })}>
                <ArrowLeft className="h-5 w-5 rtl:rotate-180" />
              </Link>
            ) : (
              <Link to={homeFor(active)} className="md:hidden" aria-label="BakeQuote home">
                <Wordmark className="text-lg" />
              </Link>
            )}
            <h1 className={cn("min-w-0 truncate text-base font-semibold md:text-lg", !back && "hidden md:block")}>{title}</h1>
            <div className="ms-auto flex items-center gap-1">
              {actions}
              <button
                onClick={() => setDemoOpen(true)}
                className="flex h-10 items-center gap-1.5 rounded-full border bg-card px-3 text-xs font-semibold text-muted-foreground hover:text-foreground md:hidden"
                aria-label={`${t("Demo controls")}: ${active} view`}
              >
                <span className={cn("h-2 w-2 rounded-full", active === "customer" ? "bg-info" : "bg-primary")} />
                {t(active === "customer" ? "Customer" : "Baker")}
              </button>
            </div>
          </div>
          {s.demo.offline && (
            <div className="flex items-center justify-center gap-2 bg-warning-soft px-4 py-1.5 text-xs font-semibold text-warning">
              <WifiOff className="h-3.5 w-3.5" /> Simulated offline: you can browse and edit drafts; submitting and confirming are paused.
            </div>
          )}
        </header>
        <main className={cn("mx-auto px-4 pb-32 pt-5 md:pb-12", wide ? "max-w-6xl" : "max-w-4xl")}>{children}</main>
      </div>

      {/* Mobile bottom nav */}
      <nav aria-label="Main" className="safe-bottom fixed inset-x-0 bottom-0 z-40 border-t bg-card md:hidden">
        <div className="mx-auto grid max-w-md" style={{ gridTemplateColumns: `repeat(${nav.length}, minmax(0,1fr))` }}>
          {nav.map((n) => (
            <Link key={n.to} to={n.to} aria-current={isOn(n.to) ? "page" : undefined} className={cn("relative flex h-16 flex-col items-center justify-center gap-0.5 text-[11px] font-semibold", isOn(n.to) ? "text-primary" : "text-muted-foreground")}>
              <n.icon className="h-5 w-5" aria-hidden />
              {t(n.label)}
              {n.label === "Messages" && unread > 0 && <span className="num absolute top-2 start-1/2 ms-2 min-w-5 rounded-full bg-primary px-1 text-center text-[10px] text-primary-foreground">{unread}</span>}
            </Link>
          ))}
        </div>
      </nav>
      <DemoControls open={demoOpen} onClose={() => setDemoOpen(false)} />
    </div>
  );
}

export function DemoControls({ open, onClose }: { open: boolean; onClose: () => void }) {
  const s = useBQ((x) => x);
  const t = useT();
  const nav = useNavigate();
  const fileRef = useRef<HTMLInputElement>(null);
  const [confirmReset, setConfirmReset] = useState(false);
  const al = allowance(s, todayIso());
  const switchTo = (r: Role) => {
    onClose();
    if (!s.sessions[r]) return nav({ to: "/auth", search: { role: r, mode: "signin" } });
    act((d) => void (d.role = r));
    return nav({ to: homeFor(r) });
  };
  const download = () => {
    const blob = new Blob([exportState()], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "bakequote-demo-export.json";
    a.click();
    toast("Demo data exported (plain JSON, not encrypted).");
  };
  return (
    <Sheet open={open} onClose={onClose} title={t("Demo controls")} desc="Prototype tools. Both roles share one local data set in this browser.">
      <div>
        <p className="mb-2 text-sm font-semibold">{t("Switch role")}</p>
        <div className="grid grid-cols-2 gap-2">
          {(["customer", "baker"] as Role[]).map((r) => (
            <Button key={r} variant={s.role === r ? "primary" : "outline"} onClick={() => switchTo(r)}>
              {r === "customer" ? "Sara (customer)" : "Ayesha (baker)"}
            </Button>
          ))}
        </div>
      </div>
      <div>
        <p className="mb-2 text-sm font-semibold">{t("Language")}</p>
        <div className="grid grid-cols-2 gap-2">
          <Button variant={s.lang === "en" ? "primary" : "outline"} onClick={() => act((d) => void (d.lang = "en"))}>
            English
          </Button>
          <Button variant={s.lang === "ur" ? "primary" : "outline"} onClick={() => act((d) => void (d.lang = "ur"))}>
            اردو
          </Button>
        </div>
        <p className="mt-1 text-xs text-muted-foreground">Urdu covers navigation and key labels only; most content stays in English.</p>
      </div>
      <div className="divide-y rounded-xl border px-3">
        <Toggle label="Simulate offline" desc="Blocks submit, agree, confirm and sending." checked={s.demo.offline} onChange={(v) => act((d) => void (d.demo.offline = v))} />
        <Toggle label="Simulate image upload failure" desc="Image messages fail and can be retried." checked={s.demo.failUploads} onChange={(v) => act((d) => void (d.demo.failUploads = v))} />
        <Toggle label="Simulate demo allowance reached" desc={`Demo fixture: ${al.used}/${al.limit} confirmations this month. Not a real plan limit.`} checked={s.demo.allowanceReached} onChange={(v) => act((d) => void (d.demo.allowanceReached = v))} />
      </div>
      <div className="space-y-2">
        <p className="text-sm font-semibold">Demo export / restore</p>
        <p className="text-xs text-muted-foreground">A plain JSON file of this browser's demo data. Not encrypted and not a production backup.</p>
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" size="sm" onClick={download}>
            Export JSON
          </Button>
          <Button variant="outline" size="sm" onClick={() => fileRef.current?.click()}>
            Restore from JSON
          </Button>
          <input
            ref={fileRef}
            type="file"
            accept="application/json,.json"
            className="hidden"
            aria-label="Restore demo file"
            onChange={async (e) => {
              const f = e.target.files?.[0];
              e.target.value = "";
              if (!f) return;
              const r = importState(await f.text());
              toast(r.ok ? "Demo data restored." : r.error, r.ok ? "ok" : "err");
            }}
          />
        </div>
      </div>
      {confirmReset ? (
        <Notice t="red" title="Reset all demo data?" action={
          <div className="flex gap-2">
            <Button size="sm" variant="outline" onClick={() => setConfirmReset(false)}>Keep</Button>
            <Button size="sm" variant="danger" onClick={() => { resetDemo(); setConfirmReset(false); onClose(); nav({ to: "/" }); toast("Demo data reset."); }}>Reset</Button>
          </div>
        }>Orders, messages, settings and sessions return to the seeded state.</Notice>
      ) : (
        <Button variant="dangerOutline" block onClick={() => setConfirmReset(true)}>
          {t("Reset demo data")}
        </Button>
      )}
    </Sheet>
  );
}
