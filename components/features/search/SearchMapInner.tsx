"use client";

import { useCallback, useEffect, useRef, useState } from "react";
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

interface PriceOverlay extends google.maps.OverlayView {
  getElement(): HTMLButtonElement;
  getId(): string;
}

// Deferred class — google.maps must be loaded first
let OverlayClass: new (
  map: google.maps.Map,
  listing: Listing,
  onHover: (id: string | null) => void,
  onSelect: (id: string | null) => void,
) => PriceOverlay;

function ensureOverlayClass() {
  if (OverlayClass) return;

  OverlayClass = class extends google.maps.OverlayView {
    private position: google.maps.LatLng;
    private container: HTMLButtonElement;
    private listing: Listing;

    constructor(
      map: google.maps.Map,
      listing: Listing,
      onHover: (id: string | null) => void,
      onSelect: (id: string | null) => void,
    ) {
      super();
      this.listing = listing;
      this.position = new google.maps.LatLng(listing.location.lat, listing.location.lng);

      const el = document.createElement("button");
      const zap = listing.instantBooking ? '<svg style="width:12px;height:12px;fill:#16a34a;display:inline;vertical-align:-1px;margin-right:2px" viewBox="0 0 24 24" stroke="none"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>' : "";
      const spotsLabel = listing.availableSpots !== undefined ? `${listing.availableSpots}/${listing.spots}p` : `${listing.spots}p`;
      const spots = listing.spots > 1 ? `<span style="margin-left:4px;opacity:0.5;font-weight:500;font-size:11px">${spotsLabel}</span>` : "";
      el.innerHTML = `${zap}${listing.price} kr${spots}`;
      el.style.cssText = `
        border-radius: 9999px;
        padding: 6px 14px;
        font-size: 14px;
        font-weight: 700;
        font-family: var(--font-dm-sans), system-ui, sans-serif;
        white-space: nowrap;
        cursor: pointer;
        border: none;
        background: #fff;
        color: #171717;
        box-shadow: 0 2px 8px rgba(0,0,0,0.18), 0 0 0 3px rgba(255,255,255,0.6);
        transition: background 0.15s, color 0.15s, transform 0.15s, box-shadow 0.15s;
        position: absolute;
        transform: translate(-50%, -50%);
      `;

      el.addEventListener("mouseenter", () => onHover(listing.id));
      el.addEventListener("mouseleave", () => onHover(null));
      el.addEventListener("click", (e) => {
        e.stopPropagation();
        onSelect(listing.id);
      });

      this.container = el;
      this.setMap(map);
    }

    onAdd() {
      const panes = this.getPanes();
      panes?.overlayMouseTarget.appendChild(this.container);
    }

    draw() {
      const projection = this.getProjection();
      if (!projection) return;
      const pos = projection.fromLatLngToDivPixel(this.position);
      if (pos) {
        this.container.style.left = `${pos.x}px`;
        this.container.style.top = `${pos.y}px`;
      }
    }

    onRemove() {
      this.container.remove();
    }

    getElement() {
      return this.container;
    }

    getId() {
      return this.listing.id;
    }
  } as unknown as typeof OverlayClass;
}

export default function SearchMapInner({
  listings,
  hoveredListingId,
  selectedListingId,
  onHover,
  onSelect,
  onBoundsChange,
}: SearchMapInnerProps) {
  const [mapType, setMapType] = useState<"roadmap" | "hybrid">("hybrid");
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<google.maps.Map | null>(null);
  const markersRef = useRef<Map<string, PriceOverlay>>(new Map());
  const infoWindowRef = useRef<google.maps.InfoWindow | null>(null);
  const listingIdsRef = useRef<string>("");
  const readyRef = useRef(false);

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

  const createMarkers = useCallback(
    (map: google.maps.Map, items: Listing[]) => {
      markersRef.current.forEach((overlay) => overlay.setMap(null));
      markersRef.current.clear();

      items.forEach((listing) => {
        const overlay = new OverlayClass(map, listing, onHover, onSelect);
        markersRef.current.set(listing.id, overlay);
      });
    },
    [onHover, onSelect],
  );

  // Initialize map
  useEffect(() => {
    if (!containerRef.current || !API_KEY) return;

    let cancelled = false;

    async function initMap() {
      if (!loaderInitialized) {
        setOptions({ key: API_KEY, v: "weekly" });
        loaderInitialized = true;
      }

      const { Map: GoogleMap } = await importLibrary("maps");

      if (cancelled || !containerRef.current) return;

      ensureOverlayClass();

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
        disableDefaultUI: true,
        zoomControl: true,
        zoomControlOptions: {
          position: google.maps.ControlPosition.RIGHT_BOTTOM,
        },
        gestureHandling: "greedy",
        clickableIcons: false,
        styles: [
          // Subtle, warm style — keep POIs and landmarks visible
          { featureType: "poi.business", elementType: "labels.icon", stylers: [{ visibility: "on" }] },
          { featureType: "poi.business", elementType: "labels.text.fill", stylers: [{ color: "#9e9e9e" }] },
          { featureType: "road.highway", elementType: "geometry.fill", stylers: [{ color: "#f0e6d3" }] },
          { featureType: "road.highway", elementType: "geometry.stroke", stylers: [{ color: "#e2d4bf" }] },
          { featureType: "water", elementType: "geometry", stylers: [{ color: "#bde0f5" }] },
          { featureType: "landscape.man_made", elementType: "geometry.fill", stylers: [{ color: "#f7f5f0" }] },
          { featureType: "landscape.natural", elementType: "geometry.fill", stylers: [{ color: "#eef2e6" }] },
          { featureType: "poi.park", elementType: "geometry.fill", stylers: [{ color: "#d4e8c4" }] },
        ],
      });

      map.addListener("idle", reportBounds);
      map.addListener("click", () => onSelect(null));
      mapRef.current = map;
      readyRef.current = true;

      // Create initial markers right away
      createMarkers(map, listings);
      listingIdsRef.current = listings.map((l) => l.id).sort().join(",");

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
        markersRef.current.forEach((overlay) => overlay.setMap(null));
        markersRef.current.clear();
        mapRef.current = null;
        readyRef.current = false;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Resize on container change
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const observer = new ResizeObserver(() => {
      if (mapRef.current) google.maps.event.trigger(mapRef.current, "resize");
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  // Update markers when listings change (after initial load)
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !readyRef.current) return;

    const newIds = listings.map((l) => l.id).sort().join(",");
    if (newIds === listingIdsRef.current) return;

    createMarkers(map, listings);
    listingIdsRef.current = newIds;

    if (listings.length > 0) {
      const bounds = new google.maps.LatLngBounds();
      listings.forEach((l) => bounds.extend({ lat: l.location.lat, lng: l.location.lng }));
      map.fitBounds(bounds, 50);
      setTimeout(reportBounds, 600);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [listings, createMarkers]);

  // Update marker styles on hover/select
  useEffect(() => {
    markersRef.current.forEach((overlay, id) => {
      const el = overlay.getElement();
      const isActive = hoveredListingId === id || selectedListingId === id;
      el.style.background = isActive ? "#171717" : "#fff";
      el.style.color = isActive ? "#fff" : "#171717";
      el.style.boxShadow = isActive
        ? "0 4px 12px rgba(0,0,0,0.3), 0 0 0 3px rgba(23,23,23,0.15)"
        : "0 2px 8px rgba(0,0,0,0.18), 0 0 0 3px rgba(255,255,255,0.6)";
      el.style.transform = isActive
        ? "translate(-50%, -50%) scale(1.08)"
        : "translate(-50%, -50%)";
      el.style.zIndex = isActive ? "10" : "1";
    });
  }, [hoveredListingId, selectedListingId]);

  // Popup card on selection
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    if (infoWindowRef.current) {
      infoWindowRef.current.close();
      infoWindowRef.current = null;
    }

    if (selectedListingId) {
      const listing = listings.find((l) => l.id === selectedListingId);
      if (listing) {
        const unit = listing.priceUnit === "time" ? "dag" : "natt";
        const images = listing.images || [];
        let imgIndex = 0;

        const card = document.createElement("div");
        card.style.cssText = "width:280px;font-family:var(--font-dm-sans),system-ui,sans-serif;";
        card.innerHTML = `
          <a href="/listings/${listing.id}" style="text-decoration:none;color:inherit;display:block">
            <div style="position:relative;width:100%;aspect-ratio:7/5;overflow:hidden;border-radius:12px 12px 0 0;background:#f5f5f5">
              <img src="${images[0] || ""}" alt="${listing.title}" style="width:100%;height:100%;object-fit:cover;" />
              ${images.length > 1 ? `
                <button data-dir="prev" style="position:absolute;left:6px;top:50%;transform:translateY(-50%);width:24px;height:24px;border-radius:50%;background:rgba(255,255,255,0.8);border:none;cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:14px;color:#525252">‹</button>
                <button data-dir="next" style="position:absolute;right:6px;top:50%;transform:translateY(-50%);width:24px;height:24px;border-radius:50%;background:rgba(255,255,255,0.8);border:none;cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:14px;color:#525252">›</button>
                <div data-dots style="position:absolute;bottom:6px;left:50%;transform:translateX(-50%);display:flex;gap:3px"></div>
              ` : ""}
            </div>
            <div style="padding:10px 12px 12px">
              <div style="display:flex;justify-content:space-between;align-items:start;gap:4px">
                <p style="font-weight:600;font-size:14px;margin:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1">${listing.title}</p>
                <span style="font-size:12px;color:#171717;white-space:nowrap;display:flex;align-items:center;gap:2px">★ ${listing.rating}</span>
              </div>
              <p style="color:#737373;font-size:12px;margin:2px 0 0">${listing.location.city}, ${listing.location.region}</p>
              <div style="display:flex;align-items:center;justify-content:space-between;margin:5px 0 0">
                <p style="font-size:14px;margin:0"><span style="font-weight:700">${listing.price} kr</span> <span style="color:#737373;font-weight:400">/ ${unit}</span></p>
                <div style="display:flex;align-items:center;gap:6px;font-size:11px;color:#737373">
                  ${listing.instantBooking ? '<svg style="width:13px;height:13px;fill:#16a34a" viewBox="0 0 24 24" stroke="none"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>' : ""}
                  ${listing.spots > 1 ? `<span style="display:flex;align-items:center;gap:2px"><svg style="width:12px;height:12px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/></svg>${listing.availableSpots !== undefined ? `${listing.availableSpots}/${listing.spots}` : listing.spots}</span>` : ""}
                </div>
              </div>
            </div>
          </a>
        `;

        // Image carousel logic
        if (images.length > 1) {
          const img = card.querySelector("img") as HTMLImageElement;
          const dotsContainer = card.querySelector("[data-dots]") as HTMLDivElement;

          function renderDots() {
            const count = Math.min(images.length, 5);
            dotsContainer.innerHTML = "";
            for (let i = 0; i < count; i++) {
              const dot = document.createElement("span");
              dot.style.cssText = `width:5px;height:5px;border-radius:50%;background:${i === imgIndex % count ? "#fff" : "rgba(255,255,255,0.5)"}`;
              dotsContainer.appendChild(dot);
            }
          }
          renderDots();

          card.querySelector("[data-dir='prev']")?.addEventListener("click", (e) => {
            e.preventDefault();
            e.stopPropagation();
            imgIndex = imgIndex === 0 ? images.length - 1 : imgIndex - 1;
            img.src = images[imgIndex];
            renderDots();
          });
          card.querySelector("[data-dir='next']")?.addEventListener("click", (e) => {
            e.preventDefault();
            e.stopPropagation();
            imgIndex = imgIndex === images.length - 1 ? 0 : imgIndex + 1;
            img.src = images[imgIndex];
            renderDots();
          });
        }

        const infoWindow = new google.maps.InfoWindow({
          content: card,
          position: { lat: listing.location.lat, lng: listing.location.lng },
          pixelOffset: new google.maps.Size(0, -15),
          maxWidth: 300,
        });

        infoWindow.open(map);
        infoWindow.addListener("closeclick", () => onSelect(null));
        infoWindowRef.current = infoWindow;
      }
    }
  }, [selectedListingId, listings, onSelect]);

  // Sync map type
  useEffect(() => {
    if (mapRef.current) {
      mapRef.current.setMapTypeId(mapType);
    }
  }, [mapType]);

  if (!API_KEY) {
    return (
      <div className="flex h-full w-full items-center justify-center bg-neutral-100">
        <p className="text-sm text-neutral-500">
          Mangler NEXT_PUBLIC_GOOGLE_MAPS_API_KEY i .env.local
        </p>
      </div>
    );
  }

  return (
    <div className="relative h-full w-full">
      <div ref={containerRef} className="h-full w-full" />
      <button
        onClick={() => setMapType((t) => t === "roadmap" ? "hybrid" : "roadmap")}
        className="absolute bottom-4 left-4 flex items-center gap-1.5 rounded-lg border border-neutral-200 bg-white px-3 py-2 text-xs font-medium text-neutral-700 shadow-md transition-all hover:shadow-lg"
        title={mapType === "roadmap" ? "Bytt til satellitt" : "Bytt til kart"}
      >
        {mapType === "roadmap" ? (
          <>
            <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>
            Satellitt
          </>
        ) : (
          <>
            <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polygon points="1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6"/><line x1="8" y1="2" x2="8" y2="18"/><line x1="16" y1="6" x2="16" y2="22"/></svg>
            Kart
          </>
        )}
      </button>
    </div>
  );
}
