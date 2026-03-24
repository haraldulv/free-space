"use client";

import { useState, useCallback } from "react";
import Image from "next/image";
import { ChevronLeft, ChevronRight } from "lucide-react";

interface ImageCarouselProps {
  images: string[];
  alt: string;
  aspectRatio?: string;
  sizes?: string;
}

export default function ImageCarousel({
  images,
  alt,
  aspectRatio = "aspect-[7/5]",
  sizes = "(max-width: 768px) 100vw, (max-width: 1200px) 33vw, 25vw",
}: ImageCarouselProps) {
  const [current, setCurrent] = useState(0);

  const prev = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();
      setCurrent((c) => (c === 0 ? images.length - 1 : c - 1));
    },
    [images.length],
  );

  const next = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();
      setCurrent((c) => (c === images.length - 1 ? 0 : c + 1));
    },
    [images.length],
  );

  return (
    <div className={`relative ${aspectRatio} overflow-hidden group/carousel`}>
      <Image
        src={images[current]}
        alt={`${alt} — bilde ${current + 1}`}
        fill
        className="object-cover transition-opacity duration-200"
        sizes={sizes}
      />

      {images.length > 1 && (
        <>
          <button
            onClick={prev}
            className="absolute left-1.5 top-1/2 -translate-y-1/2 flex h-6 w-6 items-center justify-center rounded-full bg-white/80 opacity-0 group-hover/carousel:opacity-100 transition-opacity hover:bg-white/95"
            aria-label="Forrige bilde"
          >
            <ChevronLeft className="h-3.5 w-3.5 text-neutral-600" />
          </button>
          <button
            onClick={next}
            className="absolute right-1.5 top-1/2 -translate-y-1/2 flex h-6 w-6 items-center justify-center rounded-full bg-white/80 opacity-0 group-hover/carousel:opacity-100 transition-opacity hover:bg-white/95"
            aria-label="Neste bilde"
          >
            <ChevronRight className="h-3.5 w-3.5 text-neutral-600" />
          </button>

          {/* Dots */}
          <div className="absolute bottom-1.5 left-1/2 -translate-x-1/2 flex gap-1">
            {images.slice(0, 5).map((_, i) => (
              <span
                key={i}
                className={`h-1.5 w-1.5 rounded-full transition-colors ${
                  i === current % 5 ? "bg-white" : "bg-white/50"
                }`}
              />
            ))}
          </div>
        </>
      )}
    </div>
  );
}
