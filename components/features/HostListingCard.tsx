"use client";

import Image from "next/image";
import Link from "next/link";
import { Pencil, Trash2, Zap, Users } from "lucide-react";
import { Listing } from "@/types";
import Badge from "@/components/ui/Badge";

interface HostListingCardProps {
  listing: Listing;
  onDelete: (id: string) => void;
}

export default function HostListingCard({ listing, onDelete }: HostListingCardProps) {
  return (
    <div className="flex gap-4 rounded-xl border border-neutral-200 bg-white p-3 transition-shadow hover:shadow-sm">
      {/* Image */}
      <div className="relative h-24 w-32 shrink-0 overflow-hidden rounded-lg">
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
            Ingen bilde
          </div>
        )}
      </div>

      {/* Info */}
      <div className="flex flex-1 flex-col justify-between min-w-0">
        <div>
          <div className="flex items-center gap-2">
            <h3 className="text-sm font-semibold text-neutral-900 truncate">{listing.title}</h3>
            {listing.instantBooking && (
              <Badge variant="primary">
                <Zap className="mr-0.5 h-3 w-3" />
                Direkte
              </Badge>
            )}
          </div>
          <p className="text-xs text-neutral-500">
            {listing.location.city}, {listing.location.region}
          </p>
        </div>
        <div className="flex items-center gap-3 text-xs text-neutral-500">
          <span className="font-semibold text-neutral-900">
            {listing.price} kr / {listing.priceUnit === "time" ? "time" : "natt"}
          </span>
          <span className="flex items-center gap-0.5">
            <Users className="h-3 w-3" />
            {listing.spots} {listing.spots === 1 ? "plass" : "plasser"}
          </span>
        </div>
      </div>

      {/* Actions */}
      <div className="flex shrink-0 flex-col gap-1.5">
        <Link
          href={`/bli-utleier/rediger/${listing.id}`}
          className="flex h-8 w-8 items-center justify-center rounded-lg border border-neutral-200 text-neutral-500 transition-colors hover:bg-neutral-50 hover:text-neutral-700"
        >
          <Pencil className="h-3.5 w-3.5" />
        </Link>
        <button
          onClick={() => {
            if (confirm("Er du sikker på at du vil slette denne annonsen?")) {
              onDelete(listing.id);
            }
          }}
          className="flex h-8 w-8 items-center justify-center rounded-lg border border-neutral-200 text-neutral-500 transition-colors hover:bg-red-50 hover:text-red-600"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}
