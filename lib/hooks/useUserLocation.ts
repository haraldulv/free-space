"use client";

import { useCallback, useEffect, useState } from "react";

export type GeoStatus = "idle" | "prompting" | "granted" | "denied" | "unavailable";

export interface UserLocation {
  lat: number;
  lng: number;
}

const STORAGE_KEY = "tuno-user-location";

/**
 * Hook for å hente brukerens posisjon via Geolocation API.
 * - Caches i sessionStorage så brukeren slipper å gi tillatelse på hver side.
 * - Returnerer null hvis ingen posisjon er kjent — UI viser da "Finn nær meg"-knapp.
 */
export function useUserLocation() {
  const [location, setLocation] = useState<UserLocation | null>(null);
  const [status, setStatus] = useState<GeoStatus>("idle");

  useEffect(() => {
    try {
      const cached = sessionStorage.getItem(STORAGE_KEY);
      if (cached) {
        const parsed = JSON.parse(cached) as UserLocation;
        if (typeof parsed.lat === "number" && typeof parsed.lng === "number") {
          setLocation(parsed);
          setStatus("granted");
        }
      }
    } catch {
      // sessionStorage kan være disabled — bare ignorer
    }
  }, []);

  const request = useCallback(() => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setStatus("unavailable");
      return;
    }
    setStatus("prompting");
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const loc = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        setLocation(loc);
        setStatus("granted");
        try {
          sessionStorage.setItem(STORAGE_KEY, JSON.stringify(loc));
        } catch {
          // ignore
        }
      },
      () => {
        setStatus("denied");
      },
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 600000 },
    );
  }, []);

  const clear = useCallback(() => {
    setLocation(null);
    setStatus("idle");
    try {
      sessionStorage.removeItem(STORAGE_KEY);
    } catch {
      // ignore
    }
  }, []);

  return { location, status, request, clear };
}
