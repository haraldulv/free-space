"use client";

import { useCallback, useEffect, useRef } from "react";
import mapboxgl from "mapbox-gl";
import "mapbox-gl/dist/mapbox-gl.css";
import { Listing } from "@/types";

const MAPBOX_TOKEN = process.env.NEXT_PUBLIC_MAPBOX_TOKEN || "";

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
  const mapRef = useRef<mapboxgl.Map | null>(null);
  const markersRef = useRef<Map<string, { marker: mapboxgl.Marker; el: HTMLButtonElement }>>(new Map());
  const popupRef = useRef<mapboxgl.Popup | null>(null);

  // Resize map when container changes (fullscreen toggle)
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const observer = new ResizeObserver(() => {
      if (mapRef.current) {
        mapRef.current.resize();
      }
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const reportBounds = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;
    const b = map.getBounds();
    if (!b) return;
    onBoundsChange({
      north: b.getNorth(),
      south: b.getSouth(),
      east: b.getEast(),
      west: b.getWest(),
    });
  }, [onBoundsChange]);

  // Initialize map
  useEffect(() => {
    if (!containerRef.current || !MAPBOX_TOKEN) return;

    mapboxgl.accessToken = MAPBOX_TOKEN;

    // Calculate initial bounds from listings so we skip the "whole Norway" flash
    let initCenter: [number, number] = [14, 64.5];
    let initZoom = 4;
    if (listings.length > 0) {
      const b = new mapboxgl.LngLatBounds();
      listings.forEach((l) => b.extend([l.location.lng, l.location.lat]));
      initCenter = [b.getCenter().lng, b.getCenter().lat];
      // Rough zoom estimate based on bounds span
      const latSpan = b.getNorth() - b.getSouth();
      if (latSpan < 0.5) initZoom = 12;
      else if (latSpan < 2) initZoom = 9;
      else if (latSpan < 5) initZoom = 7;
      else initZoom = 5;
    }

    const map = new mapboxgl.Map({
      container: containerRef.current,
      style: "mapbox://styles/mapbox/streets-v12",
      center: initCenter,
      zoom: initZoom,
      attributionControl: true,
    });

    map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), "top-right");

    map.on("load", () => {
      // Fine-tune fit after load
      if (listings.length > 0) {
        const bounds = new mapboxgl.LngLatBounds();
        listings.forEach((l) => bounds.extend([l.location.lng, l.location.lat]));
        map.fitBounds(bounds, { padding: 50, maxZoom: 13, duration: 0 });
      }
      setTimeout(reportBounds, 150);
    });

    map.on("moveend", reportBounds);

    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Track listing IDs to detect when search results actually change
  const listingIdsRef = useRef<string>("");

  // Create markers and fit bounds when listings change
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    // Remove old markers
    markersRef.current.forEach(({ marker }) => marker.remove());
    markersRef.current.clear();

    listings.forEach((listing) => {
      const el = createPriceEl(listing.price);

      el.addEventListener("mouseenter", () => onHover(listing.id));
      el.addEventListener("mouseleave", () => onHover(null));
      el.addEventListener("click", (e) => {
        e.stopPropagation();
        onSelect(listing.id);
      });

      const marker = new mapboxgl.Marker({ element: el, anchor: "center" })
        .setLngLat([listing.location.lng, listing.location.lat])
        .addTo(map);

      markersRef.current.set(listing.id, { marker, el });
    });

    // Fly to new bounds if the listings actually changed (new search)
    const newIds = listings.map((l) => l.id).sort().join(",");
    if (newIds !== listingIdsRef.current && listings.length > 0) {
      listingIdsRef.current = newIds;
      const bounds = new mapboxgl.LngLatBounds();
      listings.forEach((l) => bounds.extend([l.location.lng, l.location.lat]));
      map.fitBounds(bounds, { padding: 50, maxZoom: 13, duration: 500 });
      setTimeout(reportBounds, 600);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [listings]);

  // Update marker styles on hover/select (without recreating)
  useEffect(() => {
    markersRef.current.forEach(({ el }, id) => {
      const isActive = hoveredListingId === id || selectedListingId === id;
      el.style.background = isActive ? "#1a4fd6" : "#fff";
      el.style.color = isActive ? "#fff" : "#171717";
      el.style.borderColor = isActive ? "#1a4fd6" : "#d4d4d4";
    });
  }, [hoveredListingId, selectedListingId]);

  // Update popup on selection
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    // Remove existing popup
    if (popupRef.current) {
      popupRef.current.remove();
      popupRef.current = null;
    }

    if (selectedListingId) {
      const listing = listings.find((l) => l.id === selectedListingId);
      if (listing) {
        const unit = listing.priceUnit === "time" ? "dag" : "natt";
        const popup = new mapboxgl.Popup({ offset: 20, closeButton: false, closeOnClick: true })
          .setLngLat([listing.location.lng, listing.location.lat])
          .setHTML(`
            <div style="min-width:160px;padding:12px;font-family:var(--font-dm-sans),system-ui,sans-serif">
              <p style="font-weight:600;font-size:14px;margin:0 0 4px">${listing.title}</p>
              <p style="color:#737373;font-size:12px;margin:0 0 4px">${listing.location.city}, ${listing.location.region}</p>
              <p style="font-weight:600;font-size:13px;margin:0">${listing.price} kr / ${unit}</p>
            </div>
          `)
          .addTo(map);

        popup.on("close", () => onSelect(null));
        popupRef.current = popup;
      }
    }
  }, [selectedListingId, listings, onSelect]);

  if (!MAPBOX_TOKEN) {
    return (
      <div className="flex h-full w-full items-center justify-center bg-neutral-100">
        <p className="text-sm text-neutral-500">
          Mangler NEXT_PUBLIC_MAPBOX_TOKEN i .env.local
        </p>
      </div>
    );
  }

  return <div ref={containerRef} className="h-full w-full" />;
}
