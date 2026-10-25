export type Role = "customer" | "baker";
export type Lang = "en" | "ur";
export type Status =
  | "pending"
  | "confirmed"
  | "baking"
  | "ready"
  | "delivered"
  | "declined"
  | "withdrawn"
  | "cancelled";
export type ImageKey = "chocolate" | "cupcakes" | "floral";

export interface Option {
  id: string;
  label: string;
  price: number;
}
export interface Product {
  id: string;
  kind: "cake" | "cupcake";
  name: string;
  description: string;
  image: ImageKey;
  options: Option[]; // weights for cakes, pack quantities for cupcakes
  active: boolean;
}
export interface Zone {
  id: string;
  name: string;
  fee: number;
}
export interface Baker {
  id: string;
  code: string;
  businessName: string;
  ownerName: string;
  email: string;
  phone: string;
  area: string;
  city: string;
  about: string;
  seedRating: number;
  seedReviewCount: number;
  pickup: boolean;
  delivery: boolean;
  pickupAddress: string;
  zones: Zone[];
  leadDays: number;
  minOrder: number;
  capacityPerDay: number;
  products: Product[];
  flavours: Option[];
  finishes: Option[];
  extras: Option[];
  blocked: string[];
  active: boolean;
  setupComplete: boolean;
}
export interface OrderConfig {
  productId: string;
  optionId: string;
  flavourId: string;
  finishId: string;
  extraIds: string[];
  instructions: string;
  cakeMessage: string;
  images: string[];
  date: string;
  fulfilment: "pickup" | "delivery";
  zoneId: string;
  address: string;
  contactName: string;
  contactPhone: string;
}
export interface QuoteLine {
  label: string;
  amount: number;
}
export interface Quote {
  version: number;
  lines: QuoteLine[];
  total: number;
  note: string;
  at: string;
}
export interface OrderEvent {
  at: string;
  by: Role | "system";
  text: string;
  private?: boolean;
}
export interface CancelRequest {
  by: Role;
  reason: string;
  at: string;
  status: "requested" | "approved" | "rejected";
}
export interface Order {
  id: string;
  source: "app" | "manual";
  customerId: string | null;
  customerName: string;
  customerPhone: string;
  bakerId: string;
  config: OrderConfig | null;
  description: string;
  date: string;
  dueTime: string | null;
  fulfilment: "pickup" | "delivery";
  address: string;
  status: Status;
  quotes: Quote[];
  agreedVersion: number | null;
  confirmedAt: string | null;
  advance: number;
  privateNotes: string;
  events: OrderEvent[];
  cancelRequest: CancelRequest | null;
  reviewed: boolean;
  createdAt: string;
}
/** Customer-safe projection: private notes and private events are never present. */
export type CustomerOrder = Omit<Order, "privateNotes">;

export interface Message {
  id: string;
  orderId: string;
  from: Role;
  text: string;
  image?: string;
  at: string;
  status: "sent" | "failed";
}
export interface Review {
  id: string;
  orderId: string | null;
  bakerId: string;
  customerName: string;
  rating: number;
  text: string;
  at: string;
}
export interface Customer {
  id: string;
  name: string;
  phone: string;
  email: string;
  savedBakers: string[];
  recentBakers: string[];
  notif: { orderUpdates: boolean; messages: boolean; reminders: boolean };
}
export type Draft = Partial<OrderConfig> & { step: number; code: string };

export interface State {
  schema: 1;
  baseDate: string;
  role: Role | null;
  sessions: { customer: boolean; baker: boolean };
  lang: Lang;
  demo: { offline: boolean; failUploads: boolean; allowanceReached: boolean };
  baker: Baker;
  bakerNotif: { newRequests: boolean; messages: boolean; dailySummary: boolean };
  customer: Customer;
  orders: Order[];
  messages: Message[];
  reviews: Review[];
  reads: Record<string, { customer: string; baker: string }>;
  draft: Draft | null;
  nextOrderNo: number;
  reports: { at: string; orderId: string; by: Role; kind: string }[];
}
