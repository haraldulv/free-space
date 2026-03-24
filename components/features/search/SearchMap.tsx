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
    <div className="absolute inset-0 p-2 pl-0 pb-2">
      <div className="h-full w-full overflow-hidden rounded-xl">
        <SearchMapInner {...props} />
      </div>
    </div>
  );
}
