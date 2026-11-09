import type { Baker, Message, Order, OrderConfig, State } from "./types";
import { addDays, stamp } from "./dates";
import { estimate } from "./pricing";

export const SARA_ID = "cust-sara";

export function seedBaker(): Baker {
  return {
    id: "baker-ayesha",
    code: "SWEETCRUMB",
    businessName: "Sweet Crumb by Ayesha",
    ownerName: "Ayesha Siddiqui",
    email: "ayesha@sweetcrumb.demo",
    phone: "0300 1234567",
    area: "F-10",
    city: "Islamabad",
    about: "Small-batch celebration cakes and cupcakes baked at home in F-10. Real butter, Belgian cocoa, and designs made to order.",
    seedRating: 4.8,
    seedReviewCount: 3,
    pickup: true,
    delivery: true,
    pickupAddress: "Street 12, F-10/2, Islamabad",
    zones: [
      { id: "z-f10", name: "F-10 / F-11", fee: 300 },
      { id: "z-f7", name: "F-6 / F-7 / F-8", fee: 450 },
      { id: "z-e11", name: "E-11", fee: 400 },
      { id: "z-g", name: "G-9 to G-11", fee: 500 },
    ],
    leadDays: 2,
    minOrder: 1500,
    capacityPerDay: 2,
    products: [
      {
        id: "p-choc",
        kind: "cake",
        name: "Chocolate Birthday Cake",
        description: "Moist chocolate sponge, fudge layers, finished your way.",
        image: "chocolate",
        active: true,
        options: [
          { id: "w1", label: "1 lb", price: 1800 },
          { id: "w2", label: "2 lb", price: 3000 },
          { id: "w3", label: "3 lb", price: 4200 },
          { id: "w4", label: "4 lb", price: 5400 },
        ],
      },
      {
        id: "p-floral",
        kind: "cake",
        name: "Floral Celebration Cake",
        description: "Vanilla bean sponge with hand-piped sugar flowers.",
        image: "floral",
        active: true,
        options: [
          { id: "w2", label: "2 lb", price: 3400 },
          { id: "w3", label: "3 lb", price: 4800 },
        ],
      },
      {
        id: "p-cup",
        kind: "cupcake",
        name: "Classic Cupcakes",
        description: "Swirled buttercream cupcakes in a gift box.",
        image: "cupcakes",
        active: true,
        options: [
          { id: "q6", label: "Box of 6", price: 1500 },
          { id: "q12", label: "Box of 12", price: 2800 },
          { id: "q24", label: "Box of 24", price: 5200 },
        ],
      },
    ],
    flavours: [
      { id: "f-choc", label: "Chocolate fudge", price: 0 },
      { id: "f-van", label: "Vanilla bean", price: 0 },
      { id: "f-rv", label: "Red velvet", price: 200 },
      { id: "f-lotus", label: "Lotus Biscoff", price: 300 },
    ],
    finishes: [
      { id: "fin-bc", label: "Buttercream", price: 500 },
      { id: "fin-wc", label: "Whipped cream", price: 300 },
      { id: "fin-fd", label: "Fondant", price: 1200 },
      { id: "fin-naked", label: "Semi-naked", price: 0 },
    ],
    extras: [
      { id: "x-topper", label: "Custom topper", price: 300 },
      { id: "x-flowers", label: "Fresh flowers", price: 600 },
      { id: "x-plaque", label: "Message plaque", price: 200 },
      { id: "x-candles", label: "Candle set", price: 150 },
    ],
    blocked: [],
    active: true,
    setupComplete: true,
  };
}

export const DEFAULT_DRAFT: Omit<OrderConfig, "date"> = {
  productId: "p-choc",
  optionId: "w2",
  flavourId: "f-choc",
  finishId: "fin-bc",
  extraIds: ["x-topper"],
  instructions: "",
  cakeMessage: "",
  images: [],
  fulfilment: "delivery",
  zoneId: "z-f10",
  address: "",
  contactName: "Sara Ahmed",
  contactPhone: "0333 7654321",
};

export function createSeed(base: string): State {
  const baker = seedBaker();
  baker.blocked = [addDays(base, 6)];
  const t = (n: number, hm?: string) => stamp(addDays(base, n), hm);

  const app = (
    id: string,
    who: { id: string | null; name: string; phone: string },
    cfg: Partial<OrderConfig>,
    dayOffset: number,
    status: Order["status"],
    extra: Partial<Order> = {},
  ): Order => {
    const config: OrderConfig = { ...DEFAULT_DRAFT, address: "House 5, Street 3, F-10/3", ...cfg, date: addDays(base, dayOffset), contactName: who.name, contactPhone: who.phone };
    const est = estimate(baker, config);
    const created = t(dayOffset - 7, "11:20");
    return {
      id,
      source: "app",
      customerId: who.id,
      customerName: who.name,
      customerPhone: who.phone,
      bakerId: baker.id,
      config,
      description: "",
      date: config.date,
      dueTime: status === "pending" || status === "declined" ? null : "16:00",
      fulfilment: config.fulfilment,
      address: config.address,
      status,
      quotes: [{ version: 1, lines: est.lines, total: est.total, note: "Estimate from menu", at: created }],
      agreedVersion: status === "pending" || status === "declined" ? null : 1,
      confirmedAt: BOOKEDLIKE.includes(status) ? t(-1, "09:00") : null,
      advance: 0,
      privateNotes: "",
      events: [{ at: created, by: "customer", text: "Request submitted (pending)." }],
      cancelRequest: null,
      reviewed: false,
      createdAt: created,
      ...extra,
    };
  };
  const manual = (id: string, name: string, phone: string, desc: string, dayOffset: number, total: number, adv: number, notes: string, due = "15:00"): Order => ({
    id,
    source: "manual",
    customerId: null,
    customerName: name,
    customerPhone: phone,
    bakerId: baker.id,
    config: null,
    description: desc,
    date: addDays(base, dayOffset),
    dueTime: due,
    fulfilment: "pickup",
    address: "",
    status: "confirmed",
    quotes: [{ version: 1, lines: [{ label: desc, amount: total }], total, note: "Manual order", at: t(-2) }],
    agreedVersion: 1,
    confirmedAt: t(-2),
    advance: adv,
    privateNotes: notes,
    events: [{ at: t(-2), by: "baker", text: "Manual order recorded by baker." }],
    cancelRequest: null,
    reviewed: false,
    createdAt: t(-2),
  });

  const sara = { id: SARA_ID, name: "Sara Ahmed", phone: "0333 7654321" };
  const orders: Order[] = [
    app("BQ-1037", sara, { productId: "p-floral", optionId: "w2", flavourId: "f-van", finishId: "fin-bc", extraIds: [] }, -6, "delivered", { advance: 1500 }),
    app("BQ-1038", { id: "cust-hina", name: "Hina Malik", phone: "0321 5550101" }, { productId: "p-choc", optionId: "w3", extraIds: ["x-plaque"], cakeMessage: "Happy 10th Anniversary" }, -1, "ready", { dueTime: "17:00", advance: 2000 }),
    app("BQ-1039", { id: "cust-omar", name: "Omar Shah", phone: "0345 2223344" }, { productId: "p-cup", optionId: "q12", flavourId: "f-rv", finishId: "fin-bc", extraIds: [], fulfilment: "pickup" }, 0, "baking", { dueTime: "18:30", advance: 1000 }),
    app("BQ-1040", sara, { productId: "p-cup", optionId: "q12", flavourId: "f-van", finishId: "fin-wc", extraIds: [] }, 9, "confirmed", { dueTime: "12:00" }),
    app("BQ-1041", { id: "cust-zainab", name: "Zainab Ali", phone: "0312 8889900" }, { productId: "p-floral", optionId: "w3", flavourId: "f-lotus", finishId: "fin-fd", extraIds: ["x-flowers"], instructions: "Bridal shower — ivory and dusty pink." }, 4, "pending"),
    app("BQ-1035", { id: "cust-bilal", name: "Bilal Khan", phone: "0300 4445566" }, { productId: "p-choc", optionId: "w4" }, -2, "declined"),
    manual("BQ-1036", "Mrs. Rehman", "0301 9990001", "3 lb pineapple cake, whipped cream", 2, 6500, 2000, "Regular customer — prefers less sugar. Collects herself."),
    manual("BQ-1033", "Office order (Kamran)", "0302 1112223", "24 mini cupcakes for office", 2, 5200, 5200, "Paid in full via bank transfer to me.", "11:00"),
  ];
  const declined = orders.find((o) => o.id === "BQ-1035")!;
  declined.events.push({ at: t(-8, "13:00"), by: "baker", text: "Request declined: Fully booked that weekend." });
  const d1037 = orders.find((o) => o.id === "BQ-1037")!;
  d1037.events.push(
    { at: t(-7, "09:00"), by: "customer", text: "Customer agreed to quote v1." },
    { at: t(-7, "09:30"), by: "baker", text: `Order confirmed for ${d1037.date} at 16:00 (quote v1).` },
    { at: t(-6, "15:50"), by: "baker", text: "Status: delivered." },
  );
  d1037.confirmedAt = t(-7, "09:30");
  const o1041 = orders.find((o) => o.id === "BQ-1041")!;
  o1041.privateNotes = "Check fondant stock before confirming.";

  const msg = (orderId: string, from: Message["from"], text: string, at: string): Message => ({ id: `m-${orderId}-${at}`, orderId, from, text, at, status: "sent" });
  const messages: Message[] = [
    msg("BQ-1037", "customer", "Thank you so much, the cake was beautiful!", t(-6, "20:10")),
    msg("BQ-1037", "baker", "So glad you loved it, Sara!", t(-6, "20:40")),
    msg("BQ-1040", "customer", "Can the cupcakes have pastel sprinkles?", t(-1, "18:00")),
    msg("BQ-1040", "baker", "Yes, no extra charge.", t(-1, "18:30")),
    msg("BQ-1041", "customer", "Hi! Is fondant possible in dusty pink?", t(-1, "21:15")),
    msg("BQ-1039", "customer", "I'll pick up around 6:30.", t(0, "08:05")),
  ];
  const reads: State["reads"] = {
    "BQ-1037": { customer: t(-6, "21:00"), baker: t(-6, "21:00") },
    "BQ-1040": { customer: t(-1, "18:00"), baker: t(-1, "18:30") },
    "BQ-1041": { customer: t(-1, "21:15"), baker: t(-2) },
    "BQ-1039": { customer: t(0, "08:05"), baker: t(-2) },
  };

  return {
    schema: 1,
    baseDate: base,
    role: null,
    sessions: { customer: false, baker: false },
    lang: "en",
    demo: { offline: false, failUploads: false, allowanceReached: false },
    baker,
    bakerNotif: { newRequests: true, messages: true, dailySummary: false },
    customer: {
      id: SARA_ID,
      name: "Sara Ahmed",
      phone: "0333 7654321",
      email: "sara@example.demo",
      savedBakers: ["SWEETCRUMB"],
      recentBakers: ["SWEETCRUMB"],
      notif: { orderUpdates: true, messages: true, reminders: false },
    },
    orders,
    messages,
    reviews: [
      { id: "r1", orderId: null, bakerId: baker.id, customerName: "Mehwish R.", rating: 5, text: "Best chocolate cake in Islamabad. On time and beautifully boxed.", at: t(-30) },
      { id: "r2", orderId: null, bakerId: baker.id, customerName: "Usman T.", rating: 5, text: "Cupcakes were a hit at the office.", at: t(-21) },
      { id: "r3", orderId: null, bakerId: baker.id, customerName: "Fatima K.", rating: 4, text: "Lovely design, slightly sweet for us.", at: t(-12) },
    ],
    reads,
    draft: null,
    nextOrderNo: 1042,
    reports: [],
  };
}
const BOOKEDLIKE = ["confirmed", "baking", "ready", "delivered"];
