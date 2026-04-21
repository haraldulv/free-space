"use client";

import { useEffect, useRef, useState } from "react";
import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import { useTranslations } from "next-intl";
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
  const mapInstanceRef = useRef<google.maps.Map | null>(null);
  const t = useTranslations("listing");
  const [mapType, setMapType] = useState<"roadmap" | "hybrid">(
    hideExactLocation ? "roadmap" : "hybrid",
  );

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
        zoom: hideExactLocation ? 13 : 17,
        mapId: "listing-detail-map",
        disableDefaultUI: true,
        zoomControl: !isNative(),
        gestureHandling: "cooperative",
        clickableIcons: false,
        mapTypeId: mapType,
      });

      mapInstanceRef.current = map;

      if (hideExactLocation) {
        // Airbnb-inspirert flerlags-ring for skjult lokasjon
        new Circle({
          map,
          center: { lat, lng },
          radius: 600,
          fillColor: "#46C185",
          fillOpacity: 0.22,
          strokeColor: "#46C185",
          strokeOpacity: 0.85,
          strokeWeight: 2.5,
        });
        new Circle({
          map,
          center: { lat, lng },
          radius: 300,
          fillColor: "#46C185",
          fillOpacity: 0.18,
          strokeColor: "#46C185",
          strokeOpacity: 0,
          strokeWeight: 0,
        });
      } else if (spotMarkers.length > 0) {
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
        new AdvancedMarkerElement({
          map,
          position: { lat, lng },
        });
      }
    }

    init();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lat, lng, spotMarkers, hideExactLocation]);

  useEffect(() => {
    if (mapInstanceRef.current) {
      mapInstanceRef.current.setMapTypeId(mapType);
    }
  }, [mapType]);

  const toggleMapType = () => setMapType((t) => (t === "roadmap" ? "hybrid" : "roadmap"));

  return (
    <div className="relative">
      <div
        ref={mapRef}
        className="h-[350px] w-full rounded-xl border border-neutral-200 overflow-hidden"
      />
      <button
        type="button"
        onClick={toggleMapType}
        className="absolute top-3 right-3 rounded-full bg-white/95 backdrop-blur px-3 py-1.5 text-xs font-medium text-neutral-700 shadow-md hover:bg-white"
      >
        {mapType === "roadmap" ? t("showSatellite") : t("showMap")}
      </button>
    </div>
  );
}
