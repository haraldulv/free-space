"use client";

import dynamic from "next/dynamic";
import { Listing } from "@/types";
import type { MapBounds } from "./SearchMapInner";

const SearchMapInner = dynamic(() => import("./SearchMapInner"), {
  ssr: false,
  loading: () => (
    <div className="flex h-full w-full items-center justify-center bg-neutral-100">
      <p className="text-sm text-neutral-400">Laster kart…</p>
    </div>
  ),
});

interface SearchMapProps {
  listings: Listing[];
  hoveredListingId: string | null;
  selectedListingId: string | null;
  onHover: (id: string | null) => void;
  onSelect: (id: string | null) => void;
  onBoundsChange: (bounds: MapBounds) => void;
}

export type { MapBounds };

export default function SearchMap(props: SearchMapProps) {
  return (
    <div className="absolute top-3 right-3 bottom-3.5 left-0">
      <div className="h-full w-full overflow-hidden rounded-xl border border-neutral-200">
        <SearchMapInner {...props} />
      </div>
    </div>
  );
}
