"use client";

import { useState } from "react";
import { X, Download, QrCode } from "lucide-react";
import Button from "@/components/ui/Button";
import type { Listing } from "@/types";

interface QrCodeModalProps {
  listing: Listing;
  onClose: () => void;
}

function getQrUrl(listingId: string, spot: number): string {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://spotshare.no";
  const targetUrl = `${siteUrl}/listings/${listingId}?spot=${spot}`;
  return `https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=${encodeURIComponent(targetUrl)}`;
}

function getListingUrl(listingId: string, spot: number): string {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://spotshare.no";
  return `${siteUrl}/listings/${listingId}?spot=${spot}`;
}

async function downloadQr(listingId: string, spot: number, title: string) {
  const url = getQrUrl(listingId, spot);
  const res = await fetch(url);
  const blob = await res.blob();
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `${title.replace(/[^a-zA-Z0-9æøåÆØÅ ]/g, "").replace(/\s+/g, "-")}-plass-${spot}.png`;
  a.click();
  URL.revokeObjectURL(a.href);
}

export default function QrCodeModal({ listing, onClose }: QrCodeModalProps) {
  const [downloading, setDownloading] = useState<number | null>(null);
  const spots = Array.from({ length: listing.spots }, (_, i) => i + 1);

  const handleDownload = async (spot: number) => {
    setDownloading(spot);
    await downloadQr(listing.id, spot, listing.title);
    setDownloading(null);
  };

  const handleDownloadAll = async () => {
    setDownloading(-1);
    for (const spot of spots) {
      await downloadQr(listing.id, spot, listing.title);
    }
    setDownloading(null);
  };

  return (
    <>
      <div className="fixed inset-0 z-50 bg-black/50" onClick={onClose} />
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div
          className="relative max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-2xl bg-white p-6 shadow-xl"
          onClick={(e) => e.stopPropagation()}
        >
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold text-neutral-900">QR-koder</h2>
              <p className="text-sm text-neutral-500">{listing.title}</p>
            </div>
            <button
              onClick={onClose}
              className="flex h-8 w-8 items-center justify-center rounded-full hover:bg-neutral-100"
            >
              <X className="h-4 w-4 text-neutral-500" />
            </button>
          </div>

          <p className="mt-3 text-sm text-neutral-600">
            Skriv ut og heng opp QR-kodene ved hver plass. Gjester scanner koden for å komme direkte til annonsen.
          </p>

          {spots.length > 1 && (
            <div className="mt-4">
              <Button
                variant="outline"
                size="sm"
                onClick={handleDownloadAll}
                disabled={downloading !== null}
              >
                <Download className="mr-1.5 h-3.5 w-3.5" />
                {downloading === -1 ? "Laster ned..." : `Last ned alle (${spots.length})`}
              </Button>
            </div>
          )}

          <div className="mt-5 space-y-4">
            {spots.map((spot) => (
              <div
                key={spot}
                className="flex items-center gap-4 rounded-xl border border-neutral-200 p-4"
              >
                <img
                  src={getQrUrl(listing.id, spot)}
                  alt={`QR-kode plass ${spot}`}
                  width={120}
                  height={120}
                  className="rounded-lg"
                />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-neutral-900">
                    Plass {spot}
                  </p>
                  <p className="mt-1 text-xs text-neutral-400 truncate">
                    {getListingUrl(listing.id, spot)}
                  </p>
                  <button
                    onClick={() => handleDownload(spot)}
                    disabled={downloading !== null}
                    className="mt-2 inline-flex items-center gap-1.5 text-sm font-medium text-primary-600 hover:text-primary-700 disabled:opacity-50"
                  >
                    <Download className="h-3.5 w-3.5" />
                    {downloading === spot ? "Laster ned..." : "Last ned PNG"}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}
