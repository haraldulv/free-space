import { Booking } from "@/types";

const BOOKINGS_KEY = "tuno_bookings";

export function getBookings(): Booking[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(BOOKINGS_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export function saveBooking(booking: Booking): void {
  const bookings = getBookings();
  bookings.unshift(booking);
  localStorage.setItem(BOOKINGS_KEY, JSON.stringify(bookings));
}

export function generateBookingId(): string {
  return `bk_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}
