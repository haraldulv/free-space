"use client";

import { formatDistanceToNow } from "date-fns";
import { nb, enGB } from "date-fns/locale";
import { useLocale, useTranslations } from "next-intl";
import type { Review } from "@/types";
import StarRating from "./StarRating";

interface ReviewCardProps {
  review: Review;
}

export default function ReviewCard({ review }: ReviewCardProps) {
  const t = useTranslations("dashboard");
  const locale = useLocale();
  const dateLocale = locale === "en" ? enGB : nb;
  return (
    <div className="border-b border-neutral-100 pb-5 last:border-0">
      <div className="flex items-center gap-3">
        {review.userAvatar ? (
          <img
            src={review.userAvatar}
            alt={review.userName || ""}
            className="h-10 w-10 rounded-full object-cover"
          />
        ) : (
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-neutral-200 text-sm font-medium text-neutral-600">
            {(review.userName || "A").charAt(0).toUpperCase()}
          </div>
        )}
        <div>
          <p className="text-sm font-medium text-neutral-900">{review.userName || t("anonymous")}</p>
          <p className="text-xs text-neutral-400">
            {formatDistanceToNow(new Date(review.createdAt), { addSuffix: true, locale: dateLocale })}
          </p>
        </div>
      </div>
      <div className="mt-2">
        <StarRating rating={review.rating} size="sm" />
      </div>
      {review.comment && (
        <p className="mt-2 text-sm text-neutral-600 leading-relaxed">{review.comment}</p>
      )}
    </div>
  );
}
