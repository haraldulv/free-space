"use client";

import { useState } from "react";
import Image from "next/image";
import { Pencil, Trash2, Zap, Users, Eye, EyeOff, QrCode } from "lucide-react";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { Listing, getDisplayPriceText } from "@/types";
import Badge from "@/components/ui/Badge";
import QrCodeModal from "@/components/features/QrCodeModal";

interface HostListingCardProps {
  listing: Listing;
  onDelete: (id: string) => void;
  onToggleActive: (id: string, isActive: boolean) => void;
}

export default function HostListingCard({ listing, onDelete, onToggleActive }: HostListingCardProps) {
  const t = useTranslations("dashboard");
  const tListing = useTranslations("listing");
  const [toggling, setToggling] = useState(false);
  const [showQr, setShowQr] = useState(false);
  const isActive = listing.isActive !== false;

  const handleToggle = async () => {
    if (toggling) return;
    setToggling(true);
    await onToggleActive(listing.id, !isActive);
    setToggling(false);
  };

  return (
    <div className={`flex gap-4 rounded-xl border bg-white p-3 transition-shadow hover:shadow-sm ${
      isActive ? "border-neutral-200" : "border-neutral-200 opacity-60"
    }`}>
      <Link href={`/dashboard/annonse/${listing.id}`} className="relative h-24 w-32 shrink-0 overflow-hidden rounded-lg">
        {listing.images[0] ? (
          <Image
            src={listing.images[0]}
            alt={listing.title}
            fill
            className="object-cover"
            sizes="128px"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-neutral-100 text-xs text-neutral-400">
            {t("noImage")}
          </div>
        )}
        {!isActive && (
          <div className="absolute inset-0 flex items-center justify-center bg-black/40 rounded-lg">
            <span className="text-xs font-medium text-white">{t("inactive")}</span>
          </div>
        )}
      </Link>

      <Link href={`/dashboard/annonse/${listing.id}`} className="flex flex-1 flex-col justify-between min-w-0">
        <div>
          <div className="flex items-center gap-2">
            <h3 className="text-sm font-semibold text-neutral-900 truncate">{listing.title}</h3>
            {listing.instantBooking && (
              <Badge variant="primary">
                <Zap className="mr-0.5 h-3 w-3" />
                {t("direct")}
              </Badge>
            )}
            {!isActive && (
              <Badge variant="secondary">{t("inactive")}</Badge>
            )}
          </div>
          <p className="text-xs text-neutral-500">
            {listing.location.city}, {listing.location.region}
          </p>
        </div>
        <div className="flex items-center gap-3 text-xs text-neutral-500">
          <span className="font-semibold text-neutral-900">
            {getDisplayPriceText(listing)} kr / {listing.priceUnit === "time" ? tListing("hour") : tListing("night")}
          </span>
          <span className="flex items-center gap-0.5">
            <Users className="h-3 w-3" />
            {tListing("spotsAvailable", { count: listing.spots })}
          </span>
        </div>
      </Link>

      <div className="flex shrink-0 flex-col gap-1.5">
        <button
          onClick={() => setShowQr(true)}
          title={t("qrCodes")}
          className="flex h-8 w-8 items-center justify-center rounded-lg border border-neutral-200 text-neutral-500 transition-colors hover:bg-neutral-50 hover:text-neutral-700"
        >
          <QrCode className="h-3.5 w-3.5" />
        </button>
        <button
          onClick={handleToggle}
          disabled={toggling}
          title={isActive ? t("deactivateListing") : t("activateListing")}
          className={`flex h-8 w-8 items-center justify-center rounded-lg border transition-colors disabled:opacity-50 ${
            isActive
              ? "border-neutral-200 text-neutral-500 hover:bg-neutral-50 hover:text-neutral-700"
              : "border-green-200 text-green-600 hover:bg-green-50 hover:text-green-700"
          }`}
        >
          {isActive ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
        </button>
        <Link
          href={`/bli-utleier/rediger/${listing.id}`}
          className="flex h-8 w-8 items-center justify-center rounded-lg border border-neutral-200 text-neutral-500 transition-colors hover:bg-neutral-50 hover:text-neutral-700"
        >
          <Pencil className="h-3.5 w-3.5" />
        </Link>
        <button
          onClick={() => {
            if (confirm(t("deleteConfirm"))) {
              onDelete(listing.id);
            }
          }}
          className="flex h-8 w-8 items-center justify-center rounded-lg border border-neutral-200 text-neutral-500 transition-colors hover:bg-red-50 hover:text-red-600"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>

      {showQr && <QrCodeModal listing={listing} onClose={() => setShowQr(false)} />}
    </div>
  );
}
