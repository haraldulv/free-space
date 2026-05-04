"use client";

import { useRef, useState, useEffect, useCallback } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { useTranslations } from "next-intl";
import { Listing } from "@/types";
import ListingCard from "./ListingCard";
import Container from "@/components/ui/Container";

interface ListingSectionProps {
  title: string;
  listings: Listing[];
}

export default function ListingSection({ title, listings }: ListingSectionProps) {
  const t = useTranslations("common");
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
          <div className="flex items-center gap-3">
            <button
              onClick={() => scroll("left")}
              disabled={!canScrollLeft}
              className={`flex h-7 w-7 items-center justify-center transition-opacity ${
                canScrollLeft
                  ? "text-neutral-800 opacity-100 hover:opacity-70"
                  : "text-neutral-300 opacity-50 cursor-default"
              }`}
              style={{ filter: canScrollLeft ? "drop-shadow(0 1px 2px rgba(0,0,0,0.18))" : undefined }}
              aria-label={t("previous")}
            >
              <ChevronLeft className="h-5 w-5" strokeWidth={2.25} />
            </button>
            <button
              onClick={() => scroll("right")}
              disabled={!canScrollRight}
              className={`flex h-7 w-7 items-center justify-center transition-opacity ${
                canScrollRight
                  ? "text-neutral-800 opacity-100 hover:opacity-70"
                  : "text-neutral-300 opacity-50 cursor-default"
              }`}
              style={{ filter: canScrollRight ? "drop-shadow(0 1px 2px rgba(0,0,0,0.18))" : undefined }}
              aria-label={t("next")}
            >
              <ChevronRight className="h-5 w-5" strokeWidth={2.25} />
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
