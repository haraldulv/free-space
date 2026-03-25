"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import { MapPin, Trash2, EyeOff } from "lucide-react";
import Input from "@/components/ui/Input";
import Toggle from "@/components/ui/Toggle";
import type { SpotMarker } from "@/types";

const API_KEY = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || "";

interface LocationStepProps {
  address: string;
  city: string;
  region: string;
  lat: number;
  lng: number;
  spotMarkers: SpotMarker[];
  hideExactLocation: boolean;
  spots: number;
  onChange: (field: string, value: unknown) => void;
  errors: Record<string, string>;
}

export default function LocationStep({
  address,
  city,
  region,
  lat,
  lng,
  spotMarkers,
  hideExactLocation,
  spots,
  onChange,
  errors,
}: LocationStepProps) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<google.maps.Map | null>(null);
  const mainMarkerRef = useRef<google.maps.marker.AdvancedMarkerElement | null>(null);
  const spotMarkerRefs = useRef<google.maps.marker.AdvancedMarkerElement[]>([]);
  const inputRef = useRef<HTMLInputElement>(null);
  const [mapReady, setMapReady] = useState(false);
  const [placingSpots, setPlacingSpots] = useState(false);
  const AdvancedMarkerRef = useRef<typeof google.maps.marker.AdvancedMarkerElement | null>(null);

  const updatePosition = useCallback(
    (newLat: number, newLng: number) => {
      onChange("lat", newLat);
      onChange("lng", newLng);
      if (mainMarkerRef.current) {
        mainMarkerRef.current.position = { lat: newLat, lng: newLng };
      }
    },
    [onChange],
  );

  // Create a numbered pin element for spot markers
  const createSpotPin = useCallback((index: number) => {
    const el = document.createElement("div");
    el.className = "spot-pin";
    el.style.cssText = `
      width: 28px; height: 28px; border-radius: 50%;
      background: #1a4fd6; color: white; font-size: 12px; font-weight: 700;
      display: flex; align-items: center; justify-content: center;
      border: 2px solid white; box-shadow: 0 2px 6px rgba(0,0,0,0.3);
      cursor: pointer;
    `;
    el.textContent = String(index + 1);
    return el;
  }, []);

  // Sync spot markers on map
  const syncSpotMarkers = useCallback((markers: SpotMarker[]) => {
    // Remove old markers
    spotMarkerRefs.current.forEach((m) => (m.map = null));
    spotMarkerRefs.current = [];

    if (!mapInstanceRef.current || !AdvancedMarkerRef.current) return;

    markers.forEach((spot, i) => {
      const marker = new AdvancedMarkerRef.current!({
        map: mapInstanceRef.current!,
        position: { lat: spot.lat, lng: spot.lng },
        content: createSpotPin(i),
        gmpDraggable: true,
      });

      marker.addListener("dragend", () => {
        const pos = marker.position;
        if (pos && typeof pos.lat === "number") {
          const updated = [...markers];
          updated[i] = { ...updated[i], lat: pos.lat, lng: pos.lng as number };
          onChange("spotMarkers", updated);
        }
      });

      spotMarkerRefs.current.push(marker);
    });
  }, [createSpotPin, onChange]);

  useEffect(() => {
    if (!mapRef.current || !API_KEY) return;

    let cancelled = false;

    async function init() {
      setOptions({ key: API_KEY, v: "weekly" });
      const { Map: GoogleMap } = await importLibrary("maps");
      const { AdvancedMarkerElement } = await importLibrary("marker");
      const { Autocomplete } = await importLibrary("places") as google.maps.PlacesLibrary;

      if (cancelled || !mapRef.current) return;

      AdvancedMarkerRef.current = AdvancedMarkerElement;

      const center = lat && lng ? { lat, lng } : { lat: 59.91, lng: 10.75 };

      const map = new GoogleMap(mapRef.current!, {
        center,
        zoom: lat && lng ? 17 : 5,
        mapId: "location-picker",
        disableDefaultUI: true,
        zoomControl: true,
        gestureHandling: "greedy",
        clickableIcons: false,
        mapTypeId: "hybrid",
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

      mapInstanceRef.current = map;
      mainMarkerRef.current = marker;

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
          map.setZoom(17);

          onChange("address", place.formatted_address || "");

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

  // Sync main marker if lat/lng change
  useEffect(() => {
    if (mapReady && lat && lng && mainMarkerRef.current) {
      mainMarkerRef.current.position = { lat, lng };
    }
  }, [lat, lng, mapReady]);

  // Sync spot markers when they change
  useEffect(() => {
    if (mapReady) {
      syncSpotMarkers(spotMarkers);
    }
  }, [spotMarkers, mapReady, syncSpotMarkers]);

  // Handle map click for placing spots
  useEffect(() => {
    if (!mapReady || !mapInstanceRef.current) return;

    const map = mapInstanceRef.current;
    const listener = map.addListener("click", (e: google.maps.MapMouseEvent) => {
      if (!e.latLng) return;

      if (placingSpots) {
        const newMarker: SpotMarker = { lat: e.latLng.lat(), lng: e.latLng.lng() };
        onChange("spotMarkers", [...spotMarkers, newMarker]);
      } else {
        updatePosition(e.latLng.lat(), e.latLng.lng());
        map.panTo(e.latLng);
      }
    });

    return () => google.maps.event.removeListener(listener);
  }, [mapReady, placingSpots, spotMarkers, onChange, updatePosition]);

  const removeSpot = (index: number) => {
    onChange("spotMarkers", spotMarkers.filter((_, i) => i !== index));
  };

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

      {/* Map */}
      <div>
        <div className="mb-2 flex items-center justify-between">
          <p className="text-sm font-medium text-neutral-700">
            {placingSpots ? "Klikk på kartet for å plassere plasser" : "Dra markøren for å justere posisjon"}
          </p>
          <button
            type="button"
            onClick={() => setPlacingSpots(!placingSpots)}
            className={`flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition-colors ${
              placingSpots
                ? "bg-primary-600 text-white"
                : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"
            }`}
          >
            <MapPin className="h-3.5 w-3.5" />
            {placingSpots ? "Plasserer..." : "Marker plasser"}
          </button>
        </div>
        <div
          ref={mapRef}
          className="h-[350px] w-full rounded-xl border border-neutral-200 overflow-hidden"
        />
        {errors.lat && <p className="mt-1 text-sm text-red-500">{errors.lat}</p>}
      </div>

      {/* Spot markers list */}
      {spotMarkers.length > 0 && (
        <div>
          <p className="text-sm font-medium text-neutral-700 mb-2">
            Markerte plasser ({spotMarkers.length}{spots > 0 ? ` av ${spots}` : ""})
          </p>
          <div className="flex flex-wrap gap-2">
            {spotMarkers.map((_, i) => (
              <div key={i} className="flex items-center gap-1.5 rounded-full bg-primary-50 px-3 py-1.5 text-xs font-medium text-primary-700">
                <div className="flex h-4 w-4 items-center justify-center rounded-full bg-primary-600 text-[10px] text-white">
                  {i + 1}
                </div>
                Plass {i + 1}
                <button onClick={() => removeSpot(i)} className="ml-0.5 text-primary-400 hover:text-red-500 transition-colors">
                  <Trash2 className="h-3 w-3" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Privacy toggle */}
      <div className="rounded-xl border border-neutral-200 p-4">
        <div className="flex items-start gap-3">
          <EyeOff className="mt-0.5 h-5 w-5 text-neutral-400 shrink-0" />
          <div className="flex-1">
            <Toggle
              checked={hideExactLocation}
              onChange={(v) => onChange("hideExactLocation", v)}
              label="Skjul eksakt adresse"
              description="Leietakere ser omtrentlig område, ikke nøyaktig posisjon. Eksakt adresse deles etter booking."
            />
          </div>
        </div>
      </div>
    </div>
  );
}
