import Link from "next/link";
import Image from "next/image";
import { Star } from "lucide-react";
import { Listing } from "@/types";

interface ListingCardProps {
  listing: Listing;
}

export default function ListingCard({ listing }: ListingCardProps) {
  return (
    <Link href={`/listings/${listing.id}`} className="group block">
      <div className="overflow-hidden rounded-lg">
        <div className="relative aspect-square overflow-hidden rounded-lg">
          <Image
            src={listing.images[0]}
            alt={listing.title}
            fill
            className="object-cover transition-transform duration-300 group-hover:scale-105"
            sizes="200px"
          />
        </div>
        <div className="pt-2">
          <div className="flex items-start justify-between gap-1">
            <h3 className="text-sm font-medium text-neutral-900 line-clamp-1">
              {listing.title}
            </h3>
            <div className="flex shrink-0 items-center gap-0.5">
              <Star className="h-3 w-3 fill-neutral-900 text-neutral-900" />
              <span className="text-xs text-neutral-900">
                {listing.rating}
              </span>
            </div>
          </div>
          <p className="text-xs text-neutral-500 line-clamp-1">
            {listing.location.city}, {listing.location.region}
          </p>
          <p className="mt-0.5 text-sm text-neutral-900">
            <span className="font-semibold">{listing.price} kr</span>
            <span className="font-normal text-neutral-500">
              {" "}/ {listing.priceUnit === "time" ? "dag" : "natt"}
            </span>
          </p>
        </div>
      </div>
    </Link>
  );
}
