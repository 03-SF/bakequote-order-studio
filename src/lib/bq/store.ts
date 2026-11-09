import { useSyncExternalStore } from "react";
import type { State } from "./types";
import { createSeed } from "./seed";
import { todayIso } from "./dates";
import { RuleError } from "./machine";

/** Mock persistence service: one shared localStorage document for both demo roles. */
export const STORAGE_KEY = "bakequote:v1";
let cache: State | null = null;
let serverSnap: State | null = null;
const listeners = new Set<() => void>();
const notify = () => listeners.forEach((l) => l());

export function validateState(x: unknown): x is State {
  const s = x as State;
  return (
    !!s &&
    typeof s === "object" &&
    s.schema === 1 &&
    typeof s.baseDate === "string" &&
    !!s.baker &&
    typeof s.baker.code === "string" &&
    Array.isArray(s.baker.products) &&
    Array.isArray(s.orders) &&
    s.orders.every((o) => typeof o.id === "string" && Array.isArray(o.quotes) && o.quotes.length > 0) &&
    Array.isArray(s.messages) &&
    Array.isArray(s.reviews) &&
    !!s.customer &&
    !!s.sessions &&
    !!s.demo
  );
}

function load(): State {
  if (cache) return cache;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (validateState(parsed)) return (cache = parsed);
    }
  } catch {
    /* fall through to seed */
  }
  cache = createSeed(todayIso());
  save(cache);
  return cache;
}
function save(s: State) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
}

export const getState = () => load();
const subscribe = (l: () => void) => {
  listeners.add(l);
  const onStorage = (e: StorageEvent) => {
    if (e.key === STORAGE_KEY) {
      cache = null;
      l();
    }
  };
  window.addEventListener("storage", onStorage);
  return () => {
    listeners.delete(l);
    window.removeEventListener("storage", onStorage);
  };
};
const getServer = () => (serverSnap ??= createSeed(todayIso()));

export function useBQ<T>(sel: (s: State) => T): T {
  const s = useSyncExternalStore(subscribe, load, getServer);
  return sel(s);
}

export type Result = { ok: true } | { ok: false; error: string };
/** Apply a mutation to a copy of state; RuleErrors become friendly results. */
export function act(fn: (draft: State) => void): Result {
  const next = structuredClone(load());
  try {
    fn(next);
  } catch (e) {
    return { ok: false, error: e instanceof RuleError || e instanceof Error ? e.message : String(e) };
  }
  try {
    save(next);
  } catch {
    return { ok: false, error: "Device storage is full. Try removing a large image." };
  }
  cache = next;
  notify();
  return { ok: true };
}

export function resetDemo() {
  window.localStorage.removeItem(STORAGE_KEY);
  cache = createSeed(todayIso());
  save(cache);
  notify();
}

export function exportState(): string {
  return JSON.stringify({ app: "BakeQuote demo export", exportedAt: new Date().toISOString(), state: load() }, null, 2);
}
export function importState(text: string): Result {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { ok: false, error: "That file isn't valid JSON." };
  }
  const st = (parsed as { state?: unknown })?.state ?? parsed;
  if (!validateState(st)) return { ok: false, error: "This file isn't a BakeQuote demo export (validation failed). Nothing was changed." };
  cache = st;
  save(st);
  notify();
  return { ok: true };
}
