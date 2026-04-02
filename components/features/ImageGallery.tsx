"use client";

import { useState } from "react";
import Image from "next/image";
import { X, ChevronLeft, ChevronRight } from "lucide-react";

interface ImageGalleryProps {
  images: string[];
  alt: string;
}

export default function ImageGallery({ images, alt }: ImageGalleryProps) {
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);

  const openLightbox = (index: number) => {
    setActiveIndex(index);
    setLightboxOpen(true);
  };

  const prev = () =>
    setActiveIndex((i) => (i === 0 ? images.length - 1 : i - 1));
  const next = () =>
    setActiveIndex((i) => (i === images.length - 1 ? 0 : i + 1));

  return (
    <>
      <div className={`grid grid-cols-1 gap-2 ${images.length > 1 ? "sm:grid-cols-4 sm:grid-rows-2" : ""}`}>
        <div
          className={`relative cursor-pointer overflow-hidden rounded-xl ${
            images.length > 1
              ? "aspect-[4/3] sm:col-span-2 sm:row-span-2 sm:aspect-auto sm:min-h-[300px]"
              : "aspect-[21/9]"
          }`}
          onClick={() => openLightbox(0)}
        >
          <Image
            src={images[0]}
            alt={alt}
            fill
            className="object-cover transition-transform hover:scale-105"
            sizes="(max-width: 640px) 100vw, 50vw"
            priority
          />
        </div>
        {images.slice(1, 5).map((img, i) => (
          <div
            key={i}
            className="relative hidden aspect-[4/3] cursor-pointer overflow-hidden rounded-xl sm:block"
            onClick={() => openLightbox(i + 1)}
          >
            <Image
              src={img}
              alt={`${alt} ${i + 2}`}
              fill
              className="object-cover transition-transform hover:scale-105"
              sizes="25vw"
            />
          </div>
        ))}
      </div>

      {lightboxOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/90 p-4">
          <button
            onClick={() => setLightboxOpen(false)}
            className="absolute right-4 top-4 rounded-full bg-white/10 p-3 text-white transition-colors hover:bg-white/20"
            aria-label="Close"
          >
            <X className="h-6 w-6" />
          </button>
          <button
            onClick={prev}
            className="absolute left-4 rounded-full bg-white/10 p-3 text-white transition-colors hover:bg-white/20"
            aria-label="Previous"
          >
            <ChevronLeft className="h-6 w-6" />
          </button>
          <div className="relative h-[80vh] w-full max-w-4xl">
            <Image
              src={images[activeIndex]}
              alt={`${alt} ${activeIndex + 1}`}
              fill
              className="object-contain"
              sizes="80vw"
            />
          </div>
          <button
            onClick={next}
            className="absolute right-4 rounded-full bg-white/10 p-3 text-white transition-colors hover:bg-white/20"
            aria-label="Next"
          >
            <ChevronRight className="h-6 w-6" />
          </button>
          <div className="absolute bottom-4 text-sm text-white/70">
            {activeIndex + 1} / {images.length}
          </div>
        </div>
      )}
    </>
  );
}
