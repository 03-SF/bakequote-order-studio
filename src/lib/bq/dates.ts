const pad = (n: number) => String(n).padStart(2, "0");
export const iso = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const parseIso = (s: string) => {
  const [y, m, d] = s.split("-").map(Number);
  if (y === undefined || m === undefined || d === undefined || !/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    throw new RangeError("Expected a date in YYYY-MM-DD format.");
  }
  const date = new Date(y, m - 1, d);
  if (!Number.isFinite(date.getTime()) || iso(date) !== s)
    throw new RangeError("Invalid calendar date.");
  return date;
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
  parseIso(s).toLocaleDateString("en-GB", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
export const fmtStamp = (s: string) =>
  new Date(s).toLocaleString("en-GB", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
export const fmtTime = (s: string) =>
  new Date(s).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
/** ISO timestamp for a given date + HH:mm, used by seed data. */
export const stamp = (date: string, hm = "10:00") => {
  const d = parseIso(date);
  const [h, m] = hm.split(":").map(Number);
  if (h === undefined || m === undefined || !/^\d{2}:\d{2}$/.test(hm) || h > 23 || m > 59) {
    throw new RangeError("Expected a time in HH:mm format.");
  }
  d.setHours(h, m, 0, 0);
  return d.toISOString();
};
