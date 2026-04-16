import { Star } from "lucide-react";
import { useTranslations } from "next-intl";
import type { Review } from "@/types";
import ReviewCard from "./ReviewCard";

interface ReviewListProps {
  reviews: Review[];
  rating: number;
  reviewCount: number;
}

export default function ReviewList({ reviews, rating, reviewCount }: ReviewListProps) {
  const t = useTranslations("reviews");
  return (
    <div>
      <div className="flex items-center gap-2">
        <Star className="h-5 w-5 fill-neutral-900 text-neutral-900" />
        <h2 className="text-lg font-semibold text-neutral-900">
          {reviewCount > 0 ? t("header", { rating, count: reviewCount }) : t("noReviewsYet")}
        </h2>
      </div>

      {reviews.length > 0 && (
        <div className="mt-6 space-y-5">
          {reviews.map((review) => (
            <ReviewCard key={review.id} review={review} />
          ))}
        </div>
      )}
    </div>
  );
}
