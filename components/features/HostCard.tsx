"use client";

import Avatar from "@/components/ui/Avatar";
import { Host } from "@/types";
import { Star, Home } from "lucide-react";
import { useTranslations } from "next-intl";
import ContactHostButton from "./ContactHostButton";

interface HostCardProps {
  host: Host;
  listingId?: string;
}

export default function HostCard({ host, listingId }: HostCardProps) {
  const t = useTranslations("listing");
  const hasRating = typeof host.rating === "number" && (host.reviewCount ?? 0) > 0;

  return (
    <div className="rounded-xl border border-neutral-200 p-6">
      <div className="flex items-center gap-4">
        <Avatar src={host.avatar} alt={host.name} size="lg" />
        <div>
          <h3 className="font-semibold text-neutral-900">
            {t("hostedBy", { name: host.name || t("anonymousHost") })}
          </h3>
          {host.joinedYear ? (
            <p className="text-sm text-neutral-500">
              {t("memberSince", { year: host.joinedYear, count: host.listingsCount })}
            </p>
          ) : (
            <p className="text-sm text-neutral-500">{t("hostLabel")}</p>
          )}
        </div>
      </div>

      {host.bio && host.bio.trim().length > 0 && (
        <p className="mt-4 text-sm leading-relaxed text-neutral-700 whitespace-pre-line">
          {host.bio.trim()}
        </p>
      )}

      <div className="mt-4 grid grid-cols-3 gap-4">
        <div>
          <div className="flex items-center gap-1 text-base font-semibold text-neutral-900">
            {hasRating ? (
              <>
                <Star className="h-4 w-4 fill-amber-400 text-amber-400" />
                {host.rating!.toFixed(1)}
              </>
            ) : (
              "—"
            )}
          </div>
          <p className="mt-0.5 text-xs text-neutral-500">
            {hasRating ? t("hostStatsReviews", { count: host.reviewCount! }) : t("hostStatsNoReviews")}
          </p>
        </div>
        <div>
          <div className="flex items-center gap-1 text-base font-semibold text-neutral-900">
            <Home className="h-4 w-4 text-primary-600" />
            {host.listingsCount ?? 0}
          </div>
          <p className="mt-0.5 text-xs text-neutral-500">{t("hostStatsListings")}</p>
        </div>
        <div>
          <div className="text-base font-semibold text-neutral-900">{host.responseRate}%</div>
          <p className="mt-0.5 text-xs text-neutral-500">{t("hostStatsResponse")}</p>
        </div>
      </div>
      {listingId && (
        <ContactHostButton listingId={listingId} hostId={host.id} />
      )}
    </div>
  );
}
