"use client";

import { useCallback, useEffect, useRef } from "react";
import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import { Listing } from "@/types";

const API_KEY = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || "";
let loaderInitialized = false;

export interface MapBounds {
  north: number;
  south: number;
  east: number;
  west: number;
}

interface SearchMapInnerProps {
  listings: Listing[];
  hoveredListingId: string | null;
  selectedListingId: string | null;
  onHover: (id: string | null) => void;
  onSelect: (id: string | null) => void;
  onBoundsChange: (bounds: MapBounds) => void;
}

function createPriceEl(price: number): HTMLButtonElement {
  const el = document.createElement("button");
  el.textContent = `${price} kr`;
  el.style.cssText = `
    border-radius: 9999px;
    padding: 4px 10px;
    font-size: 12px;
    font-weight: 600;
    font-family: var(--font-dm-sans), system-ui, sans-serif;
    white-space: nowrap;
    cursor: pointer;
    border: 1px solid #d4d4d4;
    background: #fff;
    color: #171717;
    box-shadow: 0 2px 6px rgba(0,0,0,0.15);
    transition: background 0.15s, color 0.15s, border-color 0.15s;
  `;
  return el;
}

export default function SearchMapInner({
  listings,
  hoveredListingId,
  selectedListingId,
  onHover,
  onSelect,
  onBoundsChange,
}: SearchMapInnerProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<google.maps.Map | null>(null);
  const markersRef = useRef<
    Map<string, { marker: google.maps.marker.AdvancedMarkerElement; el: HTMLButtonElement }>
  >(new Map());
  const infoWindowRef = useRef<google.maps.InfoWindow | null>(null);
  const listingIdsRef = useRef<string>("");

  const reportBounds = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;
    const b = map.getBounds();
    if (!b) return;
    onBoundsChange({
      north: b.getNorthEast().lat(),
      south: b.getSouthWest().lat(),
      east: b.getNorthEast().lng(),
      west: b.getSouthWest().lng(),
    });
  }, [onBoundsChange]);

  // Initialize map
  useEffect(() => {
    if (!containerRef.current || !API_KEY) return;

    let cancelled = false;

    async function initMap() {
      if (!loaderInitialized) {
        setOptions({
          key: API_KEY,
          v: "weekly",
        });
        loaderInitialized = true;
      }

      const { Map: GoogleMap } = await importLibrary("maps");
      await importLibrary("marker");

      if (cancelled || !containerRef.current) return;

      // Calculate initial bounds
      let center = { lat: 64.5, lng: 14 };
      let zoom = 4;
      if (listings.length > 0) {
        const bounds = new google.maps.LatLngBounds();
        listings.forEach((l) => bounds.extend({ lat: l.location.lat, lng: l.location.lng }));
        center = { lat: bounds.getCenter().lat(), lng: bounds.getCenter().lng() };
        const latSpan = bounds.getNorthEast().lat() - bounds.getSouthWest().lat();
        if (latSpan < 0.5) zoom = 12;
        else if (latSpan < 2) zoom = 9;
        else if (latSpan < 5) zoom = 7;
        else zoom = 5;
      }

      const map = new GoogleMap(containerRef.current!, {
        center,
        zoom,
        mapId: "free-space-map",
        disableDefaultUI: true,
        zoomControl: true,
        zoomControlOptions: {
          position: google.maps.ControlPosition.RIGHT_BOTTOM,
        },
        gestureHandling: "greedy",
        clickableIcons: false,
      });

      map.addListener("idle", () => {
        reportBounds();
      });

      mapRef.current = map;

      // Fit to listings after init
      if (listings.length > 0) {
        const bounds = new google.maps.LatLngBounds();
        listings.forEach((l) => bounds.extend({ lat: l.location.lat, lng: l.location.lng }));
        map.fitBounds(bounds, 50);
      }
    }

    initMap();

    return () => {
      cancelled = true;
      if (mapRef.current) {
        // Clean up markers
        markersRef.current.forEach(({ marker }) => (marker.map = null));
        markersRef.current.clear();
        mapRef.current = null;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Resize map when container changes (fullscreen toggle)
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const observer = new ResizeObserver(() => {
      if (mapRef.current) {
        google.maps.event.trigger(mapRef.current, "resize");
      }
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  // Create markers and fit bounds when listings change
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    // Remove old markers
    markersRef.current.forEach(({ marker }) => (marker.map = null));
    markersRef.current.clear();

    listings.forEach((listing) => {
      const el = createPriceEl(listing.price);

      el.addEventListener("mouseenter", () => onHover(listing.id));
      el.addEventListener("mouseleave", () => onHover(null));
      el.addEventListener("click", (e) => {
        e.stopPropagation();
        onSelect(listing.id);
      });

      const marker = new google.maps.marker.AdvancedMarkerElement({
        map,
        position: { lat: listing.location.lat, lng: listing.location.lng },
        content: el,
      });

      markersRef.current.set(listing.id, { marker, el });
    });

    // Fly to new bounds if listings actually changed (new search)
    const newIds = listings.map((l) => l.id).sort().join(",");
    if (newIds !== listingIdsRef.current && listings.length > 0) {
      listingIdsRef.current = newIds;
      const bounds = new google.maps.LatLngBounds();
      listings.forEach((l) => bounds.extend({ lat: l.location.lat, lng: l.location.lng }));
      map.fitBounds(bounds, 50);
      setTimeout(reportBounds, 600);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [listings]);

  // Update marker styles on hover/select
  useEffect(() => {
    markersRef.current.forEach(({ el }, id) => {
      const isActive = hoveredListingId === id || selectedListingId === id;
      el.style.background = isActive ? "#1a4fd6" : "#fff";
      el.style.color = isActive ? "#fff" : "#171717";
      el.style.borderColor = isActive ? "#1a4fd6" : "#d4d4d4";
    });
  }, [hoveredListingId, selectedListingId]);

  // Update info window on selection
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    // Remove existing info window
    if (infoWindowRef.current) {
      infoWindowRef.current.close();
      infoWindowRef.current = null;
    }

    if (selectedListingId) {
      const listing = listings.find((l) => l.id === selectedListingId);
      if (listing) {
        const unit = listing.priceUnit === "time" ? "dag" : "natt";
        const infoWindow = new google.maps.InfoWindow({
          content: `
            <div style="min-width:160px;padding:4px 0;font-family:var(--font-dm-sans),system-ui,sans-serif">
              <p style="font-weight:600;font-size:14px;margin:0 0 4px">${listing.title}</p>
              <p style="color:#737373;font-size:12px;margin:0 0 4px">${listing.location.city}, ${listing.location.region}</p>
              <p style="font-weight:600;font-size:13px;margin:0">${listing.price} kr / ${unit}</p>
            </div>
          `,
          pixelOffset: new google.maps.Size(0, -10),
        });

        const markerData = markersRef.current.get(listing.id);
        if (markerData) {
          infoWindow.open({ map, anchor: markerData.marker });
        }

        infoWindow.addListener("closeclick", () => onSelect(null));
        infoWindowRef.current = infoWindow;
      }
    }
  }, [selectedListingId, listings, onSelect]);

  if (!API_KEY) {
    return (
      <div className="flex h-full w-full items-center justify-center bg-neutral-100">
        <p className="text-sm text-neutral-500">
          Mangler NEXT_PUBLIC_GOOGLE_MAPS_API_KEY i .env.local
        </p>
      </div>
    );
  }

  return <div ref={containerRef} className="h-full w-full" />;
}
