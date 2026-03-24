"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import Input from "@/components/ui/Input";

const API_KEY = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || "";

interface LocationStepProps {
  address: string;
  city: string;
  region: string;
  lat: number;
  lng: number;
  onChange: (field: string, value: string | number) => void;
  errors: Record<string, string>;
}

export default function LocationStep({
  address,
  city,
  region,
  lat,
  lng,
  onChange,
  errors,
}: LocationStepProps) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<google.maps.Map | null>(null);
  const markerRef = useRef<google.maps.marker.AdvancedMarkerElement | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const [mapReady, setMapReady] = useState(false);

  const updatePosition = useCallback(
    (newLat: number, newLng: number) => {
      onChange("lat", newLat);
      onChange("lng", newLng);
      if (markerRef.current) {
        markerRef.current.position = { lat: newLat, lng: newLng };
      }
    },
    [onChange],
  );

  useEffect(() => {
    if (!mapRef.current || !API_KEY) return;

    let cancelled = false;

    async function init() {
      setOptions({ key: API_KEY, v: "weekly" });
      const { Map: GoogleMap } = await importLibrary("maps");
      const { AdvancedMarkerElement } = await importLibrary("marker");
      const { Autocomplete } = await importLibrary("places") as google.maps.PlacesLibrary;

      if (cancelled || !mapRef.current) return;

      const center = lat && lng ? { lat, lng } : { lat: 59.91, lng: 10.75 };

      const map = new GoogleMap(mapRef.current!, {
        center,
        zoom: lat && lng ? 15 : 5,
        mapId: "location-picker",
        disableDefaultUI: true,
        zoomControl: true,
        gestureHandling: "greedy",
        clickableIcons: false,
      });

      const marker = new AdvancedMarkerElement({
        map,
        position: center,
        gmpDraggable: true,
      });

      marker.addListener("dragend", () => {
        const pos = marker.position;
        if (pos && typeof pos.lat === "number") {
          updatePosition(pos.lat, pos.lng as number);
        }
      });

      map.addListener("click", (e: google.maps.MapMouseEvent) => {
        if (e.latLng) {
          updatePosition(e.latLng.lat(), e.latLng.lng());
          map.panTo(e.latLng);
        }
      });

      mapInstanceRef.current = map;
      markerRef.current = marker;

      // Autocomplete
      if (inputRef.current) {
        const autocomplete = new Autocomplete(inputRef.current, {
          types: ["address"],
          componentRestrictions: { country: "no" },
          fields: ["formatted_address", "geometry", "address_components"],
        });

        autocomplete.addListener("place_changed", () => {
          const place = autocomplete.getPlace();
          if (!place.geometry?.location) return;

          const loc = place.geometry.location;
          updatePosition(loc.lat(), loc.lng());
          map.panTo(loc);
          map.setZoom(16);

          onChange("address", place.formatted_address || "");

          // Extract city and region from address components
          const components = place.address_components || [];
          const cityComp = components.find((c) => c.types.includes("locality") || c.types.includes("postal_town"));
          const regionComp = components.find((c) => c.types.includes("administrative_area_level_1"));
          if (cityComp) onChange("city", cityComp.long_name);
          if (regionComp) onChange("region", regionComp.long_name);
        });
      }

      setMapReady(true);
    }

    init();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Sync marker if lat/lng change externally
  useEffect(() => {
    if (mapReady && lat && lng && markerRef.current && mapInstanceRef.current) {
      markerRef.current.position = { lat, lng };
    }
  }, [lat, lng, mapReady]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">Hvor er plassen?</h2>
        <p className="mt-1 text-sm text-neutral-500">Søk etter adressen eller klikk på kartet</p>
      </div>

      <Input
        ref={inputRef}
        id="address"
        label="Adresse"
        placeholder="Søk etter adresse..."
        value={address}
        onChange={(e) => onChange("address", e.target.value)}
        error={errors.address}
      />

      <div className="grid gap-4 sm:grid-cols-2">
        <Input
          id="city"
          label="By"
          placeholder="Oslo"
          value={city}
          onChange={(e) => onChange("city", e.target.value)}
          error={errors.city}
        />
        <Input
          id="region"
          label="Region"
          placeholder="Oslo"
          value={region}
          onChange={(e) => onChange("region", e.target.value)}
          error={errors.region}
        />
      </div>

      <div
        ref={mapRef}
        className="h-[300px] w-full rounded-xl border border-neutral-200 overflow-hidden"
      />

      {errors.lat && <p className="text-sm text-red-500">{errors.lat}</p>}
    </div>
  );
}
