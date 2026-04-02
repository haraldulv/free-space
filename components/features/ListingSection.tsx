"use client";

import { useRef, useState, useEffect, useCallback } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Listing } from "@/types";
import ListingCard from "./ListingCard";
import Container from "@/components/ui/Container";

interface ListingSectionProps {
  title: string;
  listings: Listing[];
}

export default function ListingSection({ title, listings }: ListingSectionProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);

  const checkScroll = useCallback(() => {
    const el = scrollRef.current;
    if (!el) return;
    setCanScrollLeft(el.scrollLeft > 4);
    setCanScrollRight(el.scrollLeft < el.scrollWidth - el.clientWidth - 4);
  }, []);

  useEffect(() => {
    checkScroll();
    const el = scrollRef.current;
    if (!el) return;
    el.addEventListener("scroll", checkScroll, { passive: true });
    const ro = new ResizeObserver(checkScroll);
    ro.observe(el);
    return () => {
      el.removeEventListener("scroll", checkScroll);
      ro.disconnect();
    };
  }, [checkScroll, listings]);

  const scroll = (direction: "left" | "right") => {
    const el = scrollRef.current;
    if (!el) return;
    const amount = el.clientWidth * 0.75;
    el.scrollBy({
      left: direction === "left" ? -amount : amount,
      behavior: "smooth",
    });
  };

  if (listings.length === 0) return null;

  return (
    <section className="py-5">
      <Container>
        {/* Header with title + arrows */}
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg sm:text-xl font-semibold text-neutral-900">{title}</h2>
          <div className="flex items-center gap-2">
            <button
              onClick={() => scroll("left")}
              disabled={!canScrollLeft}
              className={`flex h-9 w-9 items-center justify-center rounded-full border border-neutral-300 transition-colors ${
                canScrollLeft
                  ? "bg-white text-neutral-700 hover:bg-neutral-50"
                  : "bg-neutral-100 text-neutral-300 cursor-default"
              }`}
              aria-label="Forrige"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            <button
              onClick={() => scroll("right")}
              disabled={!canScrollRight}
              className={`flex h-9 w-9 items-center justify-center rounded-full border border-neutral-300 transition-colors ${
                canScrollRight
                  ? "bg-white text-neutral-700 hover:bg-neutral-50"
                  : "bg-neutral-100 text-neutral-300 cursor-default"
              }`}
              aria-label="Neste"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>

        {/* Scrollable card row — hidden scrollbar */}
        <div
          ref={scrollRef}
          className="flex gap-4 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        >
          {listings.map((listing) => (
            <div key={listing.id} className="w-[200px] sm:w-[220px] md:w-[240px] shrink-0">
              <ListingCard listing={listing} />
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
