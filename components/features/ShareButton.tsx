"use client";

import { Share2 } from "lucide-react";
import { Capacitor } from "@capacitor/core";
import { Share } from "@capacitor/share";
import { hapticLight } from "@/lib/haptics";

interface ShareButtonProps {
  title: string;
  listingId: string;
}

export default function ShareButton({ title, listingId }: ShareButtonProps) {
  const handleShare = async () => {
    hapticLight();
    const url = `https://www.tuno.no/listings/${listingId}`;

    if (Capacitor.isNativePlatform()) {
      await Share.share({ title, url });
    } else if (navigator.share) {
      await navigator.share({ title, url });
    } else {
      await navigator.clipboard.writeText(url);
    }
  };

  return (
    <button
      onClick={handleShare}
      className="p-2 rounded-full bg-neutral-100 transition-all hover:bg-neutral-200 active:scale-95"
      aria-label="Del annonse"
    >
      <Share2 className="h-5 w-5 text-neutral-600" />
    </button>
  );
}
