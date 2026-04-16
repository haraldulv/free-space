"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { createReviewAction } from "@/app/[locale]/(main)/reviews/actions";
import StarRating from "./StarRating";
import Button from "@/components/ui/Button";

interface ReviewFormProps {
  bookingId: string;
  listingId: string;
  onSuccess?: () => void;
}

export default function ReviewForm({ bookingId, listingId, onSuccess }: ReviewFormProps) {
  const t = useTranslations("reviews");
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (rating === 0) {
      setError(t("chooseRating"));
      return;
    }

    setSubmitting(true);
    setError("");

    const result = await createReviewAction({
      bookingId,
      listingId,
      rating,
      comment,
    });

    setSubmitting(false);

    if (result.error) {
      setError(result.error);
    } else {
      setSubmitted(true);
      onSuccess?.();
    }
  };

  if (submitted) {
    return (
      <div className="rounded-lg bg-green-50 p-4 text-center text-sm text-green-700">
        {t("success")}
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="mb-2 block text-sm font-medium text-neutral-700">{t("yourRating")}</label>
        <StarRating rating={rating} onRate={setRating} />
      </div>

      <div>
        <label htmlFor="review-comment" className="mb-2 block text-sm font-medium text-neutral-700">
          {t("commentOptional")}
        </label>
        <textarea
          id="review-comment"
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          placeholder={t("commentPlaceholder")}
          rows={3}
          className="w-full rounded-lg border border-neutral-300 px-3 py-2 text-sm text-neutral-900 placeholder:text-neutral-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
        />
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <Button type="submit" size="sm" disabled={submitting}>
        {submitting ? t("submitting") : t("submit")}
      </Button>
    </form>
  );
}
