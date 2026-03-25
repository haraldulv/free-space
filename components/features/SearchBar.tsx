"use client";

import { useState, useRef, useEffect, useMemo } from "react";
import { Search, X, Car, Truck, Caravan, Bus, MapPin } from "lucide-react";
import { DateRange } from "react-day-picker";
import DatePicker from "@/components/ui/DatePicker";
import { createClient } from "@/lib/supabase/client";
import { VehicleType, vehicleLabels } from "@/types";

interface SearchBarProps {
  initialQuery?: string;
  initialVehicle?: VehicleType;
  initialCategory?: string;
  initialCheckIn?: string;
  initialCheckOut?: string;
  compact?: boolean;
}

const vehicleOptions: { value: VehicleType; icon: React.ElementType }[] = [
  { value: "car", icon: Car },
  { value: "van", icon: Truck },
  { value: "campervan", icon: Caravan },
  { value: "motorhome", icon: Bus },
];

function formatLocalDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export default function SearchBar({
  initialQuery = "",
  initialVehicle,
  initialCategory,
  initialCheckIn,
  initialCheckOut,
  compact = false,
}: SearchBarProps) {
  const [location, setLocation] = useState(initialQuery);
  const [vehicle, setVehicle] = useState<VehicleType | undefined>(initialVehicle);
  const [dateRange, setDateRange] = useState<DateRange | undefined>(() => {
    if (initialCheckIn && initialCheckOut) {
      return { from: new Date(initialCheckIn + "T00:00:00"), to: new Date(initialCheckOut + "T00:00:00") };
    }
    return undefined;
  });
  const [activeSegment, setActiveSegment] = useState<string | null>(null);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [allPlaces, setAllPlaces] = useState<string[]>([]);
  const containerRef = useRef<HTMLDivElement>(null);

  // Fetch distinct cities from listings
  useEffect(() => {
    const supabase = createClient();
    supabase
      .from("listings")
      .select("city, region")
      .neq("is_active", false)
      .then(({ data }) => {
        if (!data) return;
        const seen = new Set<string>();
        const places: string[] = [];
        for (const row of data) {
          const key = `${row.city}|${row.region}`;
          if (!seen.has(key)) {
            seen.add(key);
            places.push(`${row.city}, ${row.region}`);
          }
        }
        places.sort((a, b) => a.localeCompare(b, "nb"));
        setAllPlaces(places);
      });
  }, []);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setActiveSegment(null);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleSearch = () => {
    const params = new URLSearchParams();
    if (location.trim()) params.set("query", location.trim());
    if (vehicle) params.set("vehicle", vehicle);
    if (initialCategory) params.set("category", initialCategory);
    if (dateRange?.from) params.set("checkIn", formatLocalDate(dateRange.from));
    if (dateRange?.to) params.set("checkOut", formatLocalDate(dateRange.to));
    const qs = params.toString();
    window.location.href = qs ? `/search?${qs}` : "/search";
  };

  const dateLabel =
    dateRange?.from && dateRange?.to
      ? `${dateRange.from.toLocaleDateString("nb-NO", { day: "numeric", month: "short" })} – ${dateRange.to.toLocaleDateString("nb-NO", { day: "numeric", month: "short" })}`
      : undefined;

  const vehicleLabel = vehicle ? vehicleLabels[vehicle] : undefined;

  const suggestions = useMemo(() => {
    if (activeSegment !== "where") return [];
    const q = location.toLowerCase().trim();
    if (!q) return allPlaces.slice(0, 8);
    return allPlaces.filter((p) => p.toLowerCase().includes(q)).slice(0, 8);
  }, [location, activeSegment, allPlaces]);

  // Close expanded compact bar on click outside
  useEffect(() => {
    if (!expanded) return;
    function handleClose(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setExpanded(false);
      }
    }
    document.addEventListener("mousedown", handleClose);
    return () => document.removeEventListener("mousedown", handleClose);
  }, [expanded]);

  const summaryParts = [
    location || "Hvor som helst",
    dateLabel || "Når som helst",
    vehicleLabel || "Kjøretøy",
  ];

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleSearch();
    }
  };

  // Shared suggestion list renderer
  const renderSuggestions = () => (
    <div className="animate-slide-down absolute left-0 mt-2 z-50 w-80 rounded-xl border border-neutral-200 bg-white py-2 shadow-xl max-h-80 overflow-y-auto">
      {suggestions.length > 0 ? (
        suggestions.map((place) => (
          <button
            key={place}
            onClick={() => {
              setLocation(place.split(",")[0]);
              setActiveSegment("when");
            }}
            className="flex w-full items-center gap-3 px-4 py-2.5 text-sm text-neutral-700 hover:bg-neutral-50 transition-colors"
          >
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-neutral-100">
              <MapPin className="h-4 w-4 text-neutral-500" />
            </div>
            {place}
          </button>
        ))
      ) : location.trim() ? (
        <div className="px-4 py-3 text-sm text-neutral-400">Ingen treff for &ldquo;{location}&rdquo;</div>
      ) : null}
    </div>
  );

  if (compact) {
    return (
      <>
        {/* Compact pill — desktop */}
        <div className="relative hidden md:block" ref={containerRef}>
          {!expanded ? (
            <button
              onClick={() => { setExpanded(true); setActiveSegment("where"); }}
              className="compact-pill flex items-center gap-1 rounded-full border border-neutral-200 bg-white py-2 pl-5 pr-3 shadow-sm"
            >
              <span className="text-sm font-medium text-neutral-900 truncate">
                {summaryParts[0]}
              </span>
              <span className="mx-1.5 h-5 w-px bg-neutral-200 shrink-0" />
              <span className="text-sm text-neutral-500 truncate">
                {summaryParts[1]}
              </span>
              <span className="mx-1.5 h-5 w-px bg-neutral-200 shrink-0" />
              <span className="text-sm text-neutral-500 truncate">
                {summaryParts[2]}
              </span>
              <div className="ml-2 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary-600 text-white">
                <Search className="h-3.5 w-3.5" />
              </div>
            </button>
          ) : (
            <div className="w-[min(600px,90vw)]">
              <div className={`search-pill flex items-center rounded-full border shadow-lg ${activeSegment ? "bg-neutral-100 border-neutral-200" : "bg-white border-neutral-200"}`}>
                <button
                  className={`flex-1 min-w-0 px-5 h-[48px] text-left rounded-full transition-all ${activeSegment === "where" ? "bg-white shadow-lg" : activeSegment ? "hover:bg-neutral-200/50" : "hover:bg-neutral-50"}`}
                  onClick={() => setActiveSegment("where")}
                >
                  <div className="text-xs font-semibold text-neutral-900">Hvor</div>
                  <input type="text" value={location} onChange={(e) => setLocation(e.target.value)} onKeyDown={handleKeyDown} onFocus={() => setActiveSegment("where")} placeholder="Søk etter sted" className="w-full bg-transparent text-sm text-neutral-700 placeholder:text-neutral-400 focus:outline-none truncate" tabIndex={activeSegment === "where" ? 0 : -1} readOnly={activeSegment !== "where"} autoFocus />
                </button>
                {!activeSegment && <div className="h-8 w-px bg-neutral-200 shrink-0" />}
                <button
                  className={`flex-1 min-w-0 px-5 h-[48px] text-left rounded-full transition-all ${activeSegment === "when" ? "bg-white shadow-lg" : activeSegment ? "hover:bg-neutral-200/50" : "hover:bg-neutral-50"}`}
                  onClick={() => setActiveSegment("when")}
                >
                  <div className="text-xs font-semibold text-neutral-900">Når</div>
                  <div className={`text-sm truncate ${dateLabel ? "text-neutral-700" : "text-neutral-400"}`}>{dateLabel || "Legg til dato"}</div>
                </button>
                {!activeSegment && <div className="h-8 w-px bg-neutral-200 shrink-0" />}
                <button
                  className={`flex-1 min-w-0 px-5 h-[48px] text-left rounded-full transition-all ${activeSegment === "vehicle" ? "bg-white shadow-lg" : activeSegment ? "hover:bg-neutral-200/50" : "hover:bg-neutral-50"}`}
                  onClick={() => setActiveSegment("vehicle")}
                >
                  <div className="text-xs font-semibold text-neutral-900">Kjøretøy</div>
                  <div className={`text-sm truncate ${vehicleLabel ? "text-neutral-700" : "text-neutral-400"}`}>{vehicleLabel || "Legg til kjøretøy"}</div>
                </button>
                <button onClick={handleSearch} className="m-1.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-r from-primary-600 to-primary-500 text-white shadow-md transition-all hover:shadow-lg active:scale-95" aria-label="Søk">
                  <Search className="h-3.5 w-3.5" />
                </button>
              </div>

              {activeSegment === "where" && renderSuggestions()}
              {activeSegment === "when" && (
                <div className="animate-slide-down absolute left-1/2 -translate-x-1/2 mt-2 z-50 rounded-xl border border-neutral-200 bg-white p-4 shadow-xl">
                  <DatePicker selected={dateRange} onSelect={setDateRange} />
                </div>
              )}
              {activeSegment === "vehicle" && (
                <div className="animate-slide-down absolute right-0 mt-2 z-50 w-56 rounded-xl border border-neutral-200 bg-white py-2 shadow-xl">
                  {vehicleOptions.map((opt) => {
                    const Icon = opt.icon;
                    const sel = vehicle === opt.value;
                    return (
                      <button key={opt.value} onClick={() => { setVehicle(sel ? undefined : opt.value); setActiveSegment(null); }} className={`flex w-full items-center gap-3 px-4 py-2.5 text-sm transition-colors ${sel ? "bg-primary-50 text-primary-700 font-medium" : "text-neutral-700 hover:bg-neutral-50"}`}>
                        <Icon className="h-5 w-5 shrink-0" />{vehicleLabels[opt.value]}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Compact pill — mobile */}
        <button
          className="flex md:hidden w-full items-center gap-3 rounded-full border border-neutral-300 bg-white px-5 py-2.5 shadow-sm"
          onClick={() => setMobileOpen(true)}
        >
          <Search className="h-4 w-4 text-neutral-900 shrink-0" />
          <div className="text-left min-w-0">
            <div className="text-sm font-medium text-neutral-900 truncate">
              {location || "Hvor vil du?"}
            </div>
            <div className="text-xs text-neutral-400 truncate">
              {[dateLabel, vehicleLabel].filter(Boolean).join(" · ") || "Sted · Dato · Kjøretøy"}
            </div>
          </div>
        </button>

        {/* Mobile overlay */}
        {mobileOpen && (
          <div className="fixed inset-0 z-[100] bg-white md:hidden">
            <div className="flex items-center justify-between border-b border-neutral-200 px-4 py-3">
              <button onClick={() => setMobileOpen(false)} className="rounded-full p-2 hover:bg-neutral-100" aria-label="Lukk">
                <X className="h-5 w-5" />
              </button>
              <span className="text-sm font-semibold">Søk</span>
              <div className="w-9" />
            </div>
            <div className="space-y-4 p-4">
              <div>
                <label className="mb-1.5 block text-sm font-semibold text-neutral-900">Hvor</label>
                <input type="text" value={location} onChange={(e) => setLocation(e.target.value)} onKeyDown={handleKeyDown} placeholder="Søk etter sted" className="w-full rounded-lg border border-neutral-300 px-4 py-3 text-sm placeholder:text-neutral-400 focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20" />
              </div>
              <div>
                <label className="mb-1.5 block text-sm font-semibold text-neutral-900">Når</label>
                <DatePicker selected={dateRange} onSelect={setDateRange} />
              </div>
              <div>
                <label className="mb-1.5 block text-sm font-semibold text-neutral-900">Kjøretøy</label>
                <div className="grid grid-cols-2 gap-2">
                  {vehicleOptions.map((opt) => { const Icon = opt.icon; const isSelected = vehicle === opt.value; return (<button key={opt.value} onClick={() => setVehicle(isSelected ? undefined : opt.value)} className={`flex items-center gap-2 rounded-lg border px-3 py-2.5 text-sm transition-colors ${isSelected ? "border-primary-600 bg-primary-50 text-primary-700 font-medium" : "border-neutral-200 text-neutral-700 hover:border-neutral-300"}`}><Icon className="h-4 w-4" />{vehicleLabels[opt.value]}</button>); })}
                </div>
              </div>
              <button onClick={handleSearch} className="w-full rounded-lg bg-primary-600 px-4 py-3 text-sm font-medium text-white transition-colors hover:bg-primary-700">
                <Search className="mr-2 inline-block h-4 w-4" />Søk
              </button>
            </div>
          </div>
        )}
      </>
    );
  }

  return (
    <>
      {/* Desktop pill search bar */}
      <div ref={containerRef} className="relative hidden md:block">
        <div className={`search-pill flex items-center rounded-full border shadow-sm ${activeSegment ? "bg-neutral-100 border-neutral-200" : "bg-white border-neutral-200"}`}>
          {/* Hvor */}
          <button
            className={`flex-1 min-w-0 px-5 h-[54px] text-left rounded-full transition-all ${
              activeSegment === "where"
                ? "bg-white shadow-lg"
                : activeSegment
                  ? "hover:bg-neutral-200/50"
                  : "hover:bg-neutral-50"
            }`}
            onClick={() => setActiveSegment(activeSegment === "where" ? null : "where")}
          >
            <div className="text-xs font-semibold text-neutral-900">Hvor</div>
            <input
              type="text"
              value={location}
              onChange={(e) => setLocation(e.target.value)}
              onKeyDown={handleKeyDown}
              onFocus={() => setActiveSegment("where")}
              placeholder="Søk etter sted"
              className="w-full bg-transparent text-sm text-neutral-700 placeholder:text-neutral-400 focus:outline-none truncate"
              tabIndex={activeSegment === "where" ? 0 : -1}
              readOnly={activeSegment !== "where"}
            />
          </button>

          {!activeSegment && <div className="h-8 w-px bg-neutral-200 shrink-0" />}

          {/* Når */}
          <button
            className={`flex-1 min-w-0 px-5 h-[54px] text-left rounded-full transition-all ${
              activeSegment === "when"
                ? "bg-white shadow-lg"
                : activeSegment
                  ? "hover:bg-neutral-200/50"
                  : "hover:bg-neutral-50"
            }`}
            onClick={() => setActiveSegment(activeSegment === "when" ? null : "when")}
          >
            <div className="text-xs font-semibold text-neutral-900">Når</div>
            <div className={`text-sm truncate ${dateLabel ? "text-neutral-700" : "text-neutral-400"}`}>
              {dateLabel || "Legg til dato"}
            </div>
          </button>

          {!activeSegment && <div className="h-8 w-px bg-neutral-200 shrink-0" />}

          {/* Kjøretøy */}
          <button
            className={`flex-1 min-w-0 px-5 h-[54px] text-left rounded-full transition-all ${
              activeSegment === "vehicle"
                ? "bg-white shadow-lg"
                : activeSegment
                  ? "hover:bg-neutral-200/50"
                  : "hover:bg-neutral-50"
            }`}
            onClick={() => setActiveSegment(activeSegment === "vehicle" ? null : "vehicle")}
          >
            <div className="text-xs font-semibold text-neutral-900">Kjøretøy</div>
            <div className={`text-sm truncate ${vehicleLabel ? "text-neutral-700" : "text-neutral-400"}`}>
              {vehicleLabel || "Legg til kjøretøy"}
            </div>
          </button>

          {/* Search button */}
          <button
            onClick={handleSearch}
            className="m-2 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gradient-to-r from-primary-600 to-primary-500 text-white shadow-md transition-all hover:shadow-lg hover:scale-105 active:scale-95"
            aria-label="Søk"
          >
            <Search className="h-4 w-4" />
          </button>
        </div>

        {/* Location suggestions */}
        {activeSegment === "where" && renderSuggestions()}

        {/* Date picker */}
        {activeSegment === "when" && (
          <div className="animate-slide-down absolute left-1/2 -translate-x-1/2 mt-2 z-50 rounded-xl border border-neutral-200 bg-white p-4 shadow-xl">
            <DatePicker selected={dateRange} onSelect={setDateRange} />
          </div>
        )}

        {/* Vehicle picker */}
        {activeSegment === "vehicle" && (
          <div className="animate-slide-down absolute right-12 mt-2 z-50 w-56 rounded-xl border border-neutral-200 bg-white py-2 shadow-xl">
            {vehicleOptions.map((opt) => {
              const Icon = opt.icon;
              const isSelected = vehicle === opt.value;
              return (
                <button
                  key={opt.value}
                  onClick={() => {
                    setVehicle(isSelected ? undefined : opt.value);
                    setActiveSegment(null);
                  }}
                  className={`flex w-full items-center gap-3 px-4 py-2.5 text-sm transition-colors ${
                    isSelected
                      ? "bg-primary-50 text-primary-700 font-medium"
                      : "text-neutral-700 hover:bg-neutral-50"
                  }`}
                >
                  <Icon className="h-5 w-5 shrink-0" />
                  {vehicleLabels[opt.value]}
                </button>
              );
            })}
          </div>
        )}
      </div>

      {/* Mobile compact search bar */}
      <button
        className="flex md:hidden w-full items-center gap-3 rounded-full border border-neutral-300 bg-white px-5 py-3 shadow-sm"
        onClick={() => setMobileOpen(true)}
      >
        <Search className="h-4 w-4 text-neutral-900 shrink-0" />
        <div className="text-left min-w-0">
          <div className="text-sm font-medium text-neutral-900 truncate">
            {location || "Hvor vil du?"}
          </div>
          <div className="text-xs text-neutral-400 truncate">
            {[dateLabel, vehicleLabel].filter(Boolean).join(" · ") || "Sted · Dato · Kjøretøy"}
          </div>
        </div>
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div className="fixed inset-0 z-[100] bg-white md:hidden">
          <div className="flex items-center justify-between border-b border-neutral-200 px-4 py-3">
            <button
              onClick={() => setMobileOpen(false)}
              className="rounded-full p-2 hover:bg-neutral-100"
              aria-label="Lukk"
            >
              <X className="h-5 w-5" />
            </button>
            <span className="text-sm font-semibold">Søk</span>
            <div className="w-9" />
          </div>

          <div className="space-y-4 p-4">
            <div>
              <label className="mb-1.5 block text-sm font-semibold text-neutral-900">Hvor</label>
              <input
                type="text"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Søk etter sted"
                className="w-full rounded-lg border border-neutral-300 px-4 py-3 text-sm placeholder:text-neutral-400 focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20"
              />
            </div>

            <div>
              <label className="mb-1.5 block text-sm font-semibold text-neutral-900">Når</label>
              <DatePicker selected={dateRange} onSelect={setDateRange} />
            </div>

            <div>
              <label className="mb-1.5 block text-sm font-semibold text-neutral-900">Kjøretøy</label>
              <div className="grid grid-cols-2 gap-2">
                {vehicleOptions.map((opt) => {
                  const Icon = opt.icon;
                  const isSelected = vehicle === opt.value;
                  return (
                    <button
                      key={opt.value}
                      onClick={() => setVehicle(isSelected ? undefined : opt.value)}
                      className={`flex items-center gap-2 rounded-lg border px-3 py-2.5 text-sm transition-colors ${
                        isSelected
                          ? "border-primary-600 bg-primary-50 text-primary-700 font-medium"
                          : "border-neutral-200 text-neutral-700 hover:border-neutral-300"
                      }`}
                    >
                      <Icon className="h-4 w-4" />
                      {vehicleLabels[opt.value]}
                    </button>
                  );
                })}
              </div>
            </div>

            <button
              onClick={handleSearch}
              className="w-full rounded-lg bg-primary-600 px-4 py-3 text-sm font-medium text-white transition-colors hover:bg-primary-700"
            >
              <Search className="mr-2 inline-block h-4 w-4" />
              Søk
            </button>
          </div>
        </div>
      )}
    </>
  );
}
