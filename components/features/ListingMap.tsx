"use client";

import { useEffect, useRef } from "react";
import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import type { SpotMarker } from "@/types";
import { isNative } from "@/lib/capacitor";

const API_KEY = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || "";

interface ListingMapProps {
  lat: number;
  lng: number;
  spotMarkers?: SpotMarker[];
  hideExactLocation?: boolean;
}

export default function ListingMap({ lat, lng, spotMarkers = [], hideExactLocation }: ListingMapProps) {
  const mapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!mapRef.current || !API_KEY) return;

    let cancelled = false;

    async function init() {
      setOptions({ key: API_KEY, v: "weekly" });
      const { Map: GoogleMap, Circle } = await importLibrary("maps") as google.maps.MapsLibrary;
      const { AdvancedMarkerElement } = await importLibrary("marker");

      if (cancelled || !mapRef.current) return;

      const map = new GoogleMap(mapRef.current!, {
        center: { lat, lng },
        zoom: hideExactLocation ? 14 : 17,
        mapId: "listing-detail-map",
        disableDefaultUI: true,
        zoomControl: !isNative(),
        gestureHandling: "cooperative",
        clickableIcons: false,
        mapTypeId: "hybrid",
      });

      if (hideExactLocation) {
        // Show approximate circle
        new Circle({
          map,
          center: { lat, lng },
          radius: 500,
          fillColor: "#46C185",
          fillOpacity: 0.1,
          strokeColor: "#46C185",
          strokeOpacity: 0.3,
          strokeWeight: 2,
        });
      } else if (spotMarkers.length > 0) {
        // Show individual spot markers
        spotMarkers.forEach((spot, i) => {
          const el = document.createElement("div");
          el.style.cssText = `
            width: 30px; height: 30px; border-radius: 50%;
            background: #46C185; color: white; font-size: 13px; font-weight: 700;
            display: flex; align-items: center; justify-content: center;
            border: 2px solid white; box-shadow: 0 2px 6px rgba(0,0,0,0.3);
          `;
          el.textContent = String(i + 1);

          new AdvancedMarkerElement({
            map,
            position: { lat: spot.lat, lng: spot.lng },
            content: el,
          });
        });
      } else {
        // Show single main marker
        new AdvancedMarkerElement({
          map,
          position: { lat, lng },
        });
      }
    }

    init();
    return () => { cancelled = true; };
  }, [lat, lng, spotMarkers, hideExactLocation]);

  return (
    <div
      ref={mapRef}
      className="h-[350px] w-full rounded-xl border border-neutral-200 overflow-hidden"
    />
  );
}
