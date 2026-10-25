const pad = (n: number) => String(n).padStart(2, "0");
export const iso = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const parseIso = (s: string) => {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
};
export const addDays = (s: string, n: number) => {
  const d = parseIso(s);
  d.setDate(d.getDate() + n);
  return iso(d);
};
export const todayIso = () => iso(new Date());
export const fmtDate = (s: string) =>
  parseIso(s).toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" });
export const fmtDateLong = (s: string) =>
  parseIso(s).toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric" });
export const fmtStamp = (s: string) =>
  new Date(s).toLocaleString("en-GB", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
export const fmtTime = (s: string) =>
  new Date(s).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
/** ISO timestamp for a given date + HH:mm, used by seed data. */
export const stamp = (date: string, hm = "10:00") => {
  const d = parseIso(date);
  const [h, m] = hm.split(":").map(Number);
  d.setHours(h, m, 0, 0);
  return d.toISOString();
};
