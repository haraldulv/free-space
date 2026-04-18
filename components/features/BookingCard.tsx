"use client";

import { useState, useEffect } from "react";
import Image from "next/image";
import { CalendarDays, MapPin, Car, Tent, Star, User, ChevronDown, Clock, CreditCard, Navigation, Mail, CarFront, AlertCircle, Phone, MessageCircle } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { bcpLocale } from "@/lib/i18n-helpers";
import Badge from "@/components/ui/Badge";
import Button from "@/components/ui/Button";
import ReviewForm from "@/components/features/ReviewForm";
import { getCancellationPreviewAction } from "@/app/[locale]/(main)/book/actions";
import { getBookingReviewStatusAction } from "@/app/[locale]/(main)/reviews/actions";
import { getOrCreateConversationAction } from "@/app/[locale]/(main)/meldinger/actions";
import { Booking } from "@/types";

interface BookingCardProps {
  booking: Booking;
  variant?: "guest" | "host";
  onCancel?: (bookingId: string, reason?: string) => Promise<void>;
  onApprove?: (bookingId: string) => Promise<void>;
  onDecline?: (bookingId: string) => Promise<void>;
}

export default function BookingCard({ booking, variant = "guest", onCancel, onApprove, onDecline }: BookingCardProps) {
  const t = useTranslations("booking");
  const tCategory = useTranslations("category");
  const tCommon = useTranslations("common");
  const locale = useLocale();
  const dateLocale = bcpLocale(locale);

  const [cancelling, setCancelling] = useState(false);
  const [responding, setResponding] = useState<"approve" | "decline" | null>(null);
  const [showConfirm, setShowConfirm] = useState(false);
  const [showReview, setShowReview] = useState(false);
  const [reviewed, setReviewed] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [cancelReason, setCancelReason] = useState("");
  const [refundPreview, setRefundPreview] = useState<{ refundAmount: number; policyLabel: string } | null>(null);
  const CategoryIcon = booking.listingCategory === "parking" ? Car : Tent;
  const checkIn = new Date(booking.checkIn).toLocaleDateString(dateLocale);
  const checkOut = new Date(booking.checkOut).toLocaleDateString(dateLocale);
  const isRequested = booking.status === "requested";
  const canCancel = (booking.status === "pending" || booking.status === "confirmed") && !isRequested;
  const isPast = new Date(booking.checkOut) < new Date();
  const [reviewStatus, setReviewStatus] = useState<{
    hasMyReview: boolean;
    hasCounterpart: boolean;
    counterpartVisible: boolean;
    counterpart: { rating: number; comment: string; createdAt: string } | null;
  } | null>(null);
  const canReview = booking.status === "confirmed" && isPast && !reviewed && reviewStatus !== null && !reviewStatus.hasMyReview;
  const canRespond = isRequested && variant === "host" && onApprove && onDecline;
  const deadlineMs = booking.approvalDeadline ? new Date(booking.approvalDeadline).getTime() - Date.now() : null;
  const deadlineHours = deadlineMs != null ? Math.max(0, Math.floor(deadlineMs / 3600000)) : null;
  const deadlineMinutes = deadlineMs != null ? Math.max(0, Math.floor((deadlineMs % 3600000) / 60000)) : null;

  useEffect(() => {
    if (showConfirm && !refundPreview) {
      getCancellationPreviewAction(booking.id).then((r) => {
        if (!r.error) setRefundPreview({ refundAmount: r.refundAmount!, policyLabel: r.policyLabel! });
      });
    }
  }, [showConfirm, booking.id, refundPreview]);

  useEffect(() => {
    if (booking.status === "confirmed" && isPast) {
      getBookingReviewStatusAction(booking.id).then((r) => {
        if (!r.error) {
          setReviewStatus({
            hasMyReview: !!r.hasMyReview,
            hasCounterpart: !!r.hasCounterpart,
            counterpartVisible: !!r.counterpartVisible,
            counterpart: r.counterpart || null,
          });
        }
      });
    }
  }, [booking.id, booking.status, isPast]);

  const handleCancel = async () => {
    if (!onCancel) return;
    setCancelling(true);
    await onCancel(booking.id, cancelReason || undefined);
    setCancelling(false);
    setShowConfirm(false);
  };

  const handleApprove = async () => {
    if (!onApprove) return;
    setResponding("approve");
    await onApprove(booking.id);
    setResponding(null);
  };

  const handleDecline = async () => {
    if (!onDecline) return;
    if (!confirm(t("confirmDeclineRequest"))) return;
    setResponding("decline");
    await onDecline(booking.id);
    setResponding(null);
  };

  const directionsUrl = booking.listingLat && booking.listingLng
    ? `https://www.google.com/maps/dir/?api=1&destination=${booking.listingLat},${booking.listingLng}`
    : undefined;

  const isCancelled = booking.status === "cancelled";

  const paymentStatusLabel = (() => {
    switch (booking.paymentStatus) {
      case "paid": return t("paid");
      case "pending": return t("pendingPayment");
      case "refunded":
        return booking.refundAmount
          ? t("refundedWithAmount", { amount: booking.refundAmount })
          : t("refunded");
      case "failed": return t("paymentFailed");
      default: return "";
    }
  })();

  return (
    <div className={`overflow-hidden rounded-xl border border-neutral-200 bg-white transition-shadow hover:shadow-sm ${isCancelled ? "opacity-60" : ""}`}>
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
                {booking.listingCategory === "parking" ? tCategory("parking") : tCategory("camping")}
              </Badge>
              <Badge
                variant={
                  booking.status === "confirmed" ? "primary"
                  : booking.status === "requested" ? "secondary"
                  : booking.status === "pending" ? "secondary"
                  : "secondary"
                }
              >
                {booking.status === "confirmed" ? t("statusConfirmed")
                  : booking.status === "requested" ? t("statusRequested")
                  : booking.status === "pending" ? t("statusPending")
                  : t("statusCancelled")}
              </Badge>
            </div>
            <h3 className="mt-1 font-semibold text-neutral-900 line-clamp-1">
              {booking.listingTitle}
            </h3>
            {variant === "host" && booking.guestName && (
              <p className="mt-0.5 flex items-center gap-1.5 text-sm text-neutral-500">
                <User className="h-3.5 w-3.5" />
                {booking.guestName}
                {booking.guestReviewCount && booking.guestReviewCount > 0 ? (
                  <span className="inline-flex items-center gap-0.5 text-xs text-neutral-600">
                    <Star className="h-3 w-3 fill-yellow-400 text-yellow-400" />
                    {booking.guestRating?.toFixed(1)} ({booking.guestReviewCount})
                  </span>
                ) : null}
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

      {expanded && (
        <div className="border-t border-neutral-100 px-4 py-4 space-y-4">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="flex items-start gap-2 text-sm">
              <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
              <div>
                <p className="font-medium text-neutral-700">{t("address")}</p>
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
                    {t("directions")}
                  </a>
                )}
              </div>
            </div>

            <div className="flex items-start gap-2 text-sm">
              <Clock className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
              <div>
                <p className="font-medium text-neutral-700">{t("times")}</p>
                <p className="text-neutral-500">
                  {t("checkInFrom", { time: booking.checkInTime || "15:00" })}
                </p>
                <p className="text-neutral-500">
                  {t("checkOutBy", { time: booking.checkOutTime || "11:00" })}
                </p>
              </div>
            </div>

            <div className="flex items-start gap-2 text-sm">
              <CarFront className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
              <div>
                <p className="font-medium text-neutral-700">{t("licensePlate")}</p>
                {booking.licensePlate ? (
                  <p className="font-mono text-neutral-900 tracking-wider">{booking.licensePlate}</p>
                ) : booking.isRentalCar ? (
                  <p className="text-amber-600">{t("rentalCarNotProvided")}</p>
                ) : (
                  <p className="text-neutral-400">{t("notProvided")}</p>
                )}
              </div>
            </div>

            <div className="flex items-start gap-2 text-sm">
              <CreditCard className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
              <div>
                <p className="font-medium text-neutral-700">{t("payment")}</p>
                <p className="text-neutral-500">
                  {booking.totalPrice} kr{paymentStatusLabel}
                </p>
              </div>
            </div>

            {variant === "guest" && booking.hostName && (
              <div className="flex items-start gap-2 text-sm">
                <User className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
                <div>
                  <p className="font-medium text-neutral-700">{t("host")}</p>
                  <p className="text-neutral-500">{booking.hostName}</p>
                  {booking.hostPhone && (
                    <a
                      href={`tel:${booking.hostPhone}`}
                      className="mt-0.5 inline-flex items-center gap-1 text-primary-600 hover:text-primary-700"
                      onClick={(e) => e.stopPropagation()}
                    >
                      <Phone className="h-3.5 w-3.5" />
                      {booking.hostPhone}
                    </a>
                  )}
                </div>
              </div>
            )}

            {variant === "host" && (
              <div className="flex items-start gap-2 text-sm">
                <User className="mt-0.5 h-4 w-4 shrink-0 text-neutral-400" />
                <div>
                  <p className="font-medium text-neutral-700">{t("guest")}</p>
                  <p className="text-neutral-500">{booking.guestName || t("guest")}</p>
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

            {isCancelled && booking.cancelledBy && (
              <div className="flex items-start gap-2 text-sm sm:col-span-2">
                <AlertCircle className="mt-0.5 h-4 w-4 shrink-0 text-red-400" />
                <div>
                  <p className="font-medium text-red-600">
                    {booking.cancelledBy === "host" ? t("cancelledByHost") : t("cancelledByGuest")}
                  </p>
                  {booking.cancellationReason && (
                    <p className="text-neutral-500">{booking.cancellationReason}</p>
                  )}
                </div>
              </div>
            )}
          </div>

          {isRequested && deadlineHours != null && (
            <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm">
              <p className="font-medium text-amber-800">
                {variant === "host" ? t("requestNeedsResponse") : t("requestAwaitingHost")}
              </p>
              <p className="mt-0.5 text-amber-700">
                {deadlineMs != null && deadlineMs > 0
                  ? t("requestExpiresIn", { hours: deadlineHours, minutes: deadlineMinutes ?? 0 })
                  : t("requestExpired")}
              </p>
            </div>
          )}

          {reviewStatus?.hasCounterpart && !reviewStatus.counterpartVisible && (
            <div className="rounded-lg border border-blue-200 bg-blue-50 p-3 text-sm">
              <p className="font-medium text-blue-800">{t("counterpartReviewedYou")}</p>
              <p className="mt-0.5 text-blue-700">{t("writeYoursToReveal")}</p>
            </div>
          )}

          {reviewStatus?.counterpartVisible && reviewStatus.counterpart && (
            <div className="rounded-lg border border-neutral-200 bg-neutral-50 p-3 text-sm">
              <div className="flex items-center gap-1">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Star
                    key={i}
                    className={`h-3.5 w-3.5 ${
                      i < reviewStatus.counterpart!.rating
                        ? "fill-yellow-400 text-yellow-400"
                        : "text-neutral-300"
                    }`}
                  />
                ))}
                <span className="ml-1 text-xs text-neutral-500">
                  {variant === "host" ? t("guestReviewedYou") : t("hostReviewedYou")}
                </span>
              </div>
              {reviewStatus.counterpart.comment && (
                <p className="mt-1 text-neutral-700">{reviewStatus.counterpart.comment}</p>
              )}
            </div>
          )}

          <div className="flex flex-wrap items-center gap-3 border-t border-neutral-100 pt-3">
            <ChatLink booking={booking} variant={variant} />
            {canRespond && (
              <>
                <Button
                  size="sm"
                  onClick={handleApprove}
                  disabled={!!responding}
                >
                  {responding === "approve" ? t("approving") : t("approveRequest")}
                </Button>
                <button
                  onClick={handleDecline}
                  disabled={!!responding}
                  className="text-sm text-red-500 hover:text-red-700 transition-colors disabled:opacity-50"
                >
                  {responding === "decline" ? t("declining") : t("declineRequest")}
                </button>
              </>
            )}
            {canReview && (
              <button
                onClick={() => setShowReview(!showReview)}
                className="flex items-center gap-1 text-sm text-primary-600 hover:text-primary-700 transition-colors"
              >
                <Star className="h-3.5 w-3.5" />
                {variant === "host" ? t("reviewGuest") : t("writeReview")}
              </button>
            )}
            {canCancel && onCancel && !canReview && (
              <>
                {!showConfirm ? (
                  <button
                    onClick={() => setShowConfirm(true)}
                    className="text-sm text-red-500 hover:text-red-700 transition-colors"
                  >
                    {t("cancelBookingBtn")}
                  </button>
                ) : (
                  <div className="w-full space-y-3">
                    {refundPreview && (
                      <div className="rounded-lg bg-amber-50 border border-amber-200 p-3 text-sm">
                        <p className="font-medium text-amber-800">{refundPreview.policyLabel}</p>
                        <p className="text-amber-700">
                          {t("refundInfo", { refund: refundPreview.refundAmount, total: booking.totalPrice })}
                        </p>
                      </div>
                    )}
                    {variant === "host" && (
                      <input
                        type="text"
                        placeholder={t("cancellationReasonPlaceholder")}
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
                        {cancelling ? t("cancelling") : t("confirmCancellation")}
                      </Button>
                      <button
                        onClick={() => { setShowConfirm(false); setRefundPreview(null); }}
                        className="text-sm text-neutral-500 hover:text-neutral-700"
                        disabled={cancelling}
                      >
                        {tCommon("cancel")}
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

function ChatLink({ booking, variant }: { booking: Booking; variant: "guest" | "host" }) {
  const t = useTranslations("booking");
  const [opening, setOpening] = useState(false);

  const label = variant === "host" ? t("chatWithGuest") : t("chatWithHost");

  if (booking.conversationId) {
    return (
      <Link
        href={{ pathname: "/dashboard", query: { tab: "messages", conversation: booking.conversationId } }}
        className="flex items-center gap-1 text-sm text-primary-600 hover:text-primary-700 transition-colors"
        onClick={(e) => e.stopPropagation()}
      >
        <MessageCircle className="h-3.5 w-3.5" />
        {label}
      </Link>
    );
  }

  if (variant !== "guest" || !booking.hostId) return null;
  const hostId = booking.hostId;

  const handleClick = async (e: React.MouseEvent) => {
    e.stopPropagation();
    setOpening(true);
    const result = await getOrCreateConversationAction({
      listingId: booking.listingId,
      hostId,
    });
    setOpening(false);
    if (result.conversationId) {
      window.location.href = `/dashboard?tab=messages&conversation=${result.conversationId}`;
    } else if (result.error) {
      alert(result.error);
    }
  };

  return (
    <button
      onClick={handleClick}
      disabled={opening}
      className="flex items-center gap-1 text-sm text-primary-600 hover:text-primary-700 transition-colors disabled:opacity-50"
    >
      <MessageCircle className="h-3.5 w-3.5" />
      {opening ? t("opening") : label}
    </button>
  );
}
