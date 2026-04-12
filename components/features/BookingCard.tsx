"use client";

import { useState, useEffect } from "react";
import Image from "next/image";
import { CalendarDays, MapPin, Car, Tent, Star, User, ChevronDown, Clock, CreditCard, Navigation, Mail, CarFront, AlertCircle } from "lucide-react";
import Badge from "@/components/ui/Badge";
import Button from "@/components/ui/Button";
import ReviewForm from "@/components/features/ReviewForm";
import { getCancellationPreviewAction } from "@/app/(main)/book/actions";
import { Booking } from "@/types";

interface BookingCardProps {
  booking: Booking;
  variant?: "guest" | "host";
  onCancel?: (bookingId: string, reason?: string) => Promise<void>;
}

export default function BookingCard({ booking, variant = "guest", onCancel }: BookingCardProps) {
  const [cancelling, setCancelling] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [showReview, setShowReview] = useState(false);
  const [reviewed, setReviewed] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [cancelReason, setCancelReason] = useState("");
  const [refundPreview, setRefundPreview] = useState<{ refundAmount: number; policyLabel: string } | null>(null);
  const CategoryIcon = booking.listingCategory === "parking" ? Car : Tent;
  const checkIn = new Date(booking.checkIn).toLocaleDateString("nb-NO");
  const checkOut = new Date(booking.checkOut).toLocaleDateString("nb-NO");
  const canCancel = booking.status === "pending" || booking.status === "confirmed";
  const isPast = new Date(booking.checkOut) < new Date();
  const canReview = booking.status === "confirmed" && isPast && !reviewed;

  useEffect(() => {
    if (showConfirm && !refundPreview) {
      getCancellationPreviewAction(booking.id).then((r) => {
        if (!r.error) setRefundPreview({ refundAmount: r.refundAmount!, policyLabel: r.policyLabel! });
      });
    }
  }, [showConfirm, booking.id, refundPreview]);

  const handleCancel = async () => {
    if (!onCancel) return;
    setCancelling(true);
    await onCancel(booking.id, cancelReason || undefined);
    setCancelling(false);
    setShowConfirm(false);
  };

  const directionsUrl = booking.listingLat && booking.listingLng
    ? `https://www.google.com/maps/dir/?api=1&destination=${booking.listingLat},${booking.listingLng}`
    : undefined;

  const isCancelled = booking.status === "cancelled";

  return (
    <div className={`overflow-hidden rounded-xl border border-neutral-200 bg-white transition-shadow hover:shadow-sm ${isCancelled ? "opacity-60" : ""}`}>
      {/* Main row — always visible */}
      <button
        type="button"
        onClick={() => setExpanded(!expanded)}
        className="flex w-full gap-4 p-4 text-left"
      >
        <div className="relative h-20 w-20 shrink-0 overflow-hidden rounded-lg sm:h-24 sm:w-24">
          {booking.listingImage ? (
            <Image
              src={booking.listingImage}
              alt={booking.listingTitle}
              fill
              className="object-cover"
              sizes="96px"
            />
          ) : (
            <div className="h-full w-full bg-neutral-100" />
          )}
        </div>
        <div className="flex flex-1 flex-col justify-between min-w-0">
          <div>
            <div className="flex items-center gap-2">
              <Badge variant="primary">
                <CategoryIcon className="mr-1 h-3 w-3" />
                {booking.listingCategory === "parking" ? "Parkering" : "Campingplass"}
              </Badge>
              <Badge
                variant={
                  booking.status === "confirmed" ? "primary"
                  : booking.status === "pending" ? "secondary"
                  : "secondary"
                }
              >
                {booking.status === "confirmed" ? "Bekreftet"
                  : booking.status === "pending" ? "Venter"
                  : "Kansellert"}
              </Badge>
            </div>
            <h3 className="mt-1 font-semibold text-neutral-900 line-clamp-1">
              {booking.listingTitle}
            </h3>
            {variant === "host" && booking.guestName && (
              <p className="mt-0.5 flex items-center gap-1 text-sm text-neutral-500">
                <User className="h-3.5 w-3.5" />
                {booking.guestName}
              </p>
            )}
          </div>
          <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-neutral-500">
            <span className="flex items-center gap-1">
              <CalendarDays className="h-3.5 w-3.5" />
              {checkIn} – {checkOut}
            </span>
            <span className="font-medium text-neutral-900">
              {booking.totalPrice} kr
            </span>
            <ChevronDown className={`ml-auto h-4 w-4 text-neutral-400 transition-transform ${expanded ? "rotate-180" : ""}`} />
          </div>
        </div>
      </button>

      {/* Expanded details */}
      {expanded && (
        <div className="border-t border-neutral-100 px-4 py-4 space-y-4">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            {/* Location */}
            <div className="flex items-start gap-2 text-sm">
              <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
              <div>
                <p className="font-medium text-neutral-700">Adresse</p>
                <p className="text-neutral-500">{booking.listingAddress || booking.location}</p>
                {variant === "guest" && directionsUrl && (
                  <a
                    href={directionsUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="mt-1 inline-flex items-center gap-1 text-primary-600 hover:text-primary-700"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <Navigation className="h-3.5 w-3.5" />
                    Veibeskrivelse
                  </a>
                )}
              </div>
            </div>

            {/* Check-in / Check-out times */}
            <div className="flex items-start gap-2 text-sm">
              <Clock className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
              <div>
                <p className="font-medium text-neutral-700">Tider</p>
                <p className="text-neutral-500">
                  Innsjekk fra {booking.checkInTime || "15:00"}
                </p>
                <p className="text-neutral-500">
                  Utsjekk innen {booking.checkOutTime || "11:00"}
                </p>
              </div>
            </div>

            {/* License plate */}
            <div className="flex items-start gap-2 text-sm">
              <CarFront className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
              <div>
                <p className="font-medium text-neutral-700">Registreringsnummer</p>
                {booking.licensePlate ? (
                  <p className="font-mono text-neutral-900 tracking-wider">{booking.licensePlate}</p>
                ) : booking.isRentalCar ? (
                  <p className="text-amber-600">Leiebil — ikke oppgitt ennå</p>
                ) : (
                  <p className="text-neutral-400">Ikke oppgitt</p>
                )}
              </div>
            </div>

            {/* Payment status */}
            <div className="flex items-start gap-2 text-sm">
              <CreditCard className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
              <div>
                <p className="font-medium text-neutral-700">Betaling</p>
                <p className="text-neutral-500">
                  {booking.totalPrice} kr
                  {booking.paymentStatus === "paid" && " — betalt"}
                  {booking.paymentStatus === "pending" && " — venter"}
                  {booking.paymentStatus === "refunded" && ` — refundert${booking.refundAmount ? ` (${booking.refundAmount} kr)` : ""}`}
                  {booking.paymentStatus === "failed" && " — feilet"}
                </p>
              </div>
            </div>

            {/* Guest info (host view) */}
            {variant === "host" && (
              <div className="flex items-start gap-2 text-sm">
                <User className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
                <div>
                  <p className="font-medium text-neutral-700">Gjest</p>
                  <p className="text-neutral-500">{booking.guestName || "Anonym"}</p>
                  {booking.guestEmail && (
                    <a
                      href={`mailto:${booking.guestEmail}`}
                      className="mt-0.5 inline-flex items-center gap-1 text-primary-600 hover:text-primary-700"
                      onClick={(e) => e.stopPropagation()}
                    >
                      <Mail className="h-3.5 w-3.5" />
                      {booking.guestEmail}
                    </a>
                  )}
                </div>
              </div>
            )}

            {/* Cancellation info */}
            {isCancelled && booking.cancelledBy && (
              <div className="flex items-start gap-2 text-sm sm:col-span-2">
                <AlertCircle className="mt-0.5 h-4 w-4 shrink-0 text-red-400" />
                <div>
                  <p className="font-medium text-red-600">
                    Kansellert av {booking.cancelledBy === "host" ? "utleier" : "gjest"}
                  </p>
                  {booking.cancellationReason && (
                    <p className="text-neutral-500">{booking.cancellationReason}</p>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Actions */}
          <div className="flex flex-wrap items-center gap-3 border-t border-neutral-100 pt-3">
            {variant === "guest" && canReview && (
              <button
                onClick={() => setShowReview(!showReview)}
                className="flex items-center gap-1 text-sm text-primary-600 hover:text-primary-700 transition-colors"
              >
                <Star className="h-3.5 w-3.5" />
                Skriv anmeldelse
              </button>
            )}
            {canCancel && onCancel && !canReview && (
              <>
                {!showConfirm ? (
                  <button
                    onClick={() => setShowConfirm(true)}
                    className="text-sm text-red-500 hover:text-red-700 transition-colors"
                  >
                    Kanseller bestilling
                  </button>
                ) : (
                  <div className="w-full space-y-3">
                    {refundPreview && (
                      <div className="rounded-lg bg-amber-50 border border-amber-200 p-3 text-sm">
                        <p className="font-medium text-amber-800">{refundPreview.policyLabel}</p>
                        <p className="text-amber-700">
                          Refusjon: {refundPreview.refundAmount} kr av {booking.totalPrice} kr
                        </p>
                      </div>
                    )}
                    {variant === "host" && (
                      <input
                        type="text"
                        placeholder="Årsak til kansellering (valgfritt)"
                        value={cancelReason}
                        onChange={(e) => setCancelReason(e.target.value)}
                        className="w-full rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:border-primary-500 focus:outline-none"
                      />
                    )}
                    <div className="flex items-center gap-2">
                      <Button
                        size="sm"
                        variant="ghost"
                        className="bg-red-600 text-white hover:bg-red-700 hover:text-white text-xs"
                        onClick={handleCancel}
                        disabled={cancelling}
                      >
                        {cancelling ? "Kansellerer..." : "Bekreft kansellering"}
                      </Button>
                      <button
                        onClick={() => { setShowConfirm(false); setRefundPreview(null); }}
                        className="text-sm text-neutral-500 hover:text-neutral-700"
                        disabled={cancelling}
                      >
                        Avbryt
                      </button>
                    </div>
                  </div>
                )}
              </>
            )}
          </div>

          {showReview && (
            <div className="border-t border-neutral-100 pt-4">
              <ReviewForm
                bookingId={booking.id}
                listingId={booking.listingId}
                onSuccess={() => {
                  setShowReview(false);
                  setReviewed(true);
                }}
              />
            </div>
          )}
        </div>
      )}
    </div>
  );
}
