"use client";

import { useEffect, useRef } from "react";
import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import { OUTREACH_STATUS_COLORS, type OutreachTarget } from "@/types";

const API_KEY = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || "";
let loaderInitialized = false;

interface Props {
  targets: OutreachTarget[];
  selectedId: string | null;
  hoveredId: string | null;
  onSelect: (id: string | null) => void;
  onHover: (id: string | null) => void;
}

export default function OutreachMap({ targets, selectedId, hoveredId, onSelect, onHover }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<google.maps.Map | null>(null);
  const markersRef = useRef<Map<string, google.maps.marker.AdvancedMarkerElement>>(new Map());
  const lastTargetIdsRef = useRef<string>("");

  useEffect(() => {
    if (!containerRef.current || !API_KEY) return;
    let cancelled = false;

    async function init() {
      if (!loaderInitialized) {
        setOptions({ key: API_KEY, v: "weekly" });
        loaderInitialized = true;
      }
      await importLibrary("maps");
      await importLibrary("marker");
      if (cancelled || !containerRef.current) return;

      const map = new google.maps.Map(containerRef.current, {
        center: { lat: 68.15, lng: 14.0 },
        zoom: 9,
        disableDefaultUI: true,
        zoomControl: true,
        zoomControlOptions: { position: google.maps.ControlPosition.RIGHT_BOTTOM },
        gestureHandling: "greedy",
        clickableIcons: false,
        mapId: "tuno-outreach-map",
        mapTypeId: "hybrid",
      });

      mapRef.current = map;
      renderMarkers();
    }

    init();

    return () => {
      cancelled = true;
      markersRef.current.forEach((m) => (m.map = null));
      markersRef.current.clear();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function buildPin(target: OutreachTarget, isSelected: boolean, isHovered: boolean): HTMLElement {
    const wrap = document.createElement("div");
    const color = OUTREACH_STATUS_COLORS[target.status];
    const size = isSelected ? 18 : isHovered ? 16 : 12;
    wrap.style.cssText = `
      width:${size}px;height:${size}px;border-radius:50%;
      background:${color};border:2px solid #fff;
      box-shadow:0 2px 6px rgba(0,0,0,0.35);
      transition:transform 120ms ease;
      cursor:pointer;
      ${isSelected ? "transform:scale(1.4);outline:2px solid #46C185;outline-offset:2px;" : ""}
    `;
    return wrap;
  }

  function renderMarkers() {
    const map = mapRef.current;
    if (!map) return;
    const currentIds = targets.map((t) => t.id).sort().join(",");

    // Full rebuild on data change.
    if (currentIds !== lastTargetIdsRef.current) {
      markersRef.current.forEach((m) => (m.map = null));
      markersRef.current.clear();

      targets.forEach((t) => {
        if (t.lat == null || t.lng == null) return;
        const marker = new google.maps.marker.AdvancedMarkerElement({
          map,
          position: { lat: t.lat, lng: t.lng },
          content: buildPin(t, t.id === selectedId, t.id === hoveredId),
          title: t.name,
        });
        marker.addListener("click", () => onSelect(t.id));
        marker.addListener("mouseenter", () => onHover(t.id));
        marker.addListener("mouseleave", () => onHover(null));
        markersRef.current.set(t.id, marker);
      });
      lastTargetIdsRef.current = currentIds;

      if (targets.length > 0) {
        const bounds = new google.maps.LatLngBounds();
        targets.forEach((t) => {
          if (t.lat != null && t.lng != null) bounds.extend({ lat: t.lat, lng: t.lng });
        });
        if (!bounds.isEmpty()) {
          map.fitBounds(bounds, { top: 60, right: 60, bottom: 60, left: 60 });
        }
      }
      return;
    }

    // Selection/hover-only update — just rerender content of affected pins.
    targets.forEach((t) => {
      const m = markersRef.current.get(t.id);
      if (!m) return;
      m.content = buildPin(t, t.id === selectedId, t.id === hoveredId);
    });
  }

  useEffect(() => {
    renderMarkers();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [targets, selectedId, hoveredId]);

  if (!API_KEY) {
    return (
      <div className="flex h-full items-center justify-center bg-neutral-100 text-sm text-neutral-500">
        Mangler NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
      </div>
    );
  }

  return <div ref={containerRef} className="h-full w-full" />;
}
