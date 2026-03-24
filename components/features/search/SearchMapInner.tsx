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

// Custom OverlayView for price pill markers
class PriceMarkerOverlay extends google.maps.OverlayView {
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
    el.textContent = `${listing.price} kr`;
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
      transition: background 0.15s, color 0.15s, border-color 0.15s, transform 0.15s;
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

  getPosition() {
    return this.position;
  }
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
  const markersRef = useRef<Map<string, PriceMarkerOverlay>>(new Map());
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
        disableDefaultUI: true,
        zoomControl: true,
        zoomControlOptions: {
          position: google.maps.ControlPosition.RIGHT_BOTTOM,
        },
        gestureHandling: "greedy",
        clickableIcons: false,
        styles: [
          // Airbnb-inspired clean style — muted colors, minimal labels
          { elementType: "geometry", stylers: [{ color: "#f5f5f5" }] },
          { elementType: "labels.icon", stylers: [{ visibility: "off" }] },
          { elementType: "labels.text.fill", stylers: [{ color: "#616161" }] },
          { elementType: "labels.text.stroke", stylers: [{ color: "#f5f5f5" }] },
          { featureType: "administrative.land_parcel", elementType: "labels.text.fill", stylers: [{ color: "#bdbdbd" }] },
          { featureType: "poi", elementType: "geometry", stylers: [{ color: "#eeeeee" }] },
          { featureType: "poi", elementType: "labels.text.fill", stylers: [{ color: "#757575" }] },
          { featureType: "poi.park", elementType: "geometry", stylers: [{ color: "#e5e5e5" }] },
          { featureType: "poi.park", elementType: "labels.text.fill", stylers: [{ color: "#9e9e9e" }] },
          { featureType: "road", elementType: "geometry", stylers: [{ color: "#ffffff" }] },
          { featureType: "road.arterial", elementType: "labels.text.fill", stylers: [{ color: "#757575" }] },
          { featureType: "road.highway", elementType: "geometry", stylers: [{ color: "#dadada" }] },
          { featureType: "road.highway", elementType: "labels.text.fill", stylers: [{ color: "#616161" }] },
          { featureType: "road.local", elementType: "labels.text.fill", stylers: [{ color: "#9e9e9e" }] },
          { featureType: "transit.line", elementType: "geometry", stylers: [{ color: "#e5e5e5" }] },
          { featureType: "transit.station", elementType: "geometry", stylers: [{ color: "#eeeeee" }] },
          { featureType: "water", elementType: "geometry", stylers: [{ color: "#c9e7f5" }] },
          { featureType: "water", elementType: "labels.text.fill", stylers: [{ color: "#9e9e9e" }] },
        ],
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
        markersRef.current.forEach((overlay) => overlay.setMap(null));
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
    markersRef.current.forEach((overlay) => overlay.setMap(null));
    markersRef.current.clear();

    listings.forEach((listing) => {
      const overlay = new PriceMarkerOverlay(map, listing, onHover, onSelect);
      markersRef.current.set(listing.id, overlay);
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
    markersRef.current.forEach((overlay, id) => {
      const el = overlay.getElement();
      const isActive = hoveredListingId === id || selectedListingId === id;
      el.style.background = isActive ? "#1a4fd6" : "#fff";
      el.style.color = isActive ? "#fff" : "#171717";
      el.style.borderColor = isActive ? "#1a4fd6" : "#d4d4d4";
      el.style.transform = isActive
        ? "translate(-50%, -50%) scale(1.08)"
        : "translate(-50%, -50%)";
      el.style.zIndex = isActive ? "10" : "1";
    });
  }, [hoveredListingId, selectedListingId]);

  // Update info window on selection
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
        const infoWindow = new google.maps.InfoWindow({
          content: `
            <div style="min-width:160px;padding:4px 0;font-family:var(--font-dm-sans),system-ui,sans-serif">
              <p style="font-weight:600;font-size:14px;margin:0 0 4px">${listing.title}</p>
              <p style="color:#737373;font-size:12px;margin:0 0 4px">${listing.location.city}, ${listing.location.region}</p>
              <p style="font-weight:600;font-size:13px;margin:0">${listing.price} kr / ${unit}</p>
            </div>
          `,
          position: { lat: listing.location.lat, lng: listing.location.lng },
          pixelOffset: new google.maps.Size(0, -15),
        });

        infoWindow.open(map);
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
