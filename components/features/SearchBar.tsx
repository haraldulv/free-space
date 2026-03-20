"use client";

import { useState, useRef, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Search, X, Car, Truck, Caravan, Bus } from "lucide-react";
import { DateRange } from "react-day-picker";
import DatePicker from "@/components/ui/DatePicker";
import { VehicleType, vehicleLabels } from "@/types";

interface SearchBarProps {
  initialQuery?: string;
  initialVehicle?: VehicleType;
  initialCategory?: string;
}

const vehicleOptions: { value: VehicleType; icon: React.ElementType }[] = [
  { value: "car", icon: Car },
  { value: "van", icon: Truck },
  { value: "campervan", icon: Caravan },
  { value: "motorhome", icon: Bus },
];

export default function SearchBar({
  initialQuery = "",
  initialVehicle,
  initialCategory,
}: SearchBarProps) {
  const router = useRouter();
  const [location, setLocation] = useState(initialQuery);
  const [vehicle, setVehicle] = useState<VehicleType | undefined>(initialVehicle);
  const [dateRange, setDateRange] = useState<DateRange | undefined>();
  const [activeSegment, setActiveSegment] = useState<string | null>(null);
  const [mobileOpen, setMobileOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

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
    const qs = params.toString();
    router.push(qs ? `/?${qs}` : "/");
    setActiveSegment(null);
    setMobileOpen(false);
  };

  const dateLabel =
    dateRange?.from && dateRange?.to
      ? `${dateRange.from.toLocaleDateString("nb-NO", { day: "numeric", month: "short" })} – ${dateRange.to.toLocaleDateString("nb-NO", { day: "numeric", month: "short" })}`
      : undefined;

  const vehicleLabel = vehicle ? vehicleLabels[vehicle] : undefined;

  return (
    <>
      {/* Desktop pill search bar */}
      <div ref={containerRef} className="relative hidden md:block">
        <div className="flex items-center rounded-full border border-neutral-300 bg-white shadow-sm transition-shadow hover:shadow-md">
          {/* Hvor */}
          <button
            className={`flex-1 min-w-0 px-5 py-3 text-left rounded-l-full transition-colors ${
              activeSegment === "where" ? "bg-neutral-100" : "hover:bg-neutral-50"
            }`}
            onClick={() => setActiveSegment(activeSegment === "where" ? null : "where")}
          >
            <div className="text-xs font-semibold text-neutral-900">Hvor</div>
            {activeSegment === "where" ? (
              <input
                type="text"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                placeholder="Søk etter sted"
                className="w-full bg-transparent text-sm text-neutral-700 placeholder:text-neutral-400 focus:outline-none"
                autoFocus
              />
            ) : (
              <div className="text-sm text-neutral-400 truncate">
                {location || "Søk etter sted"}
              </div>
            )}
          </button>

          <div className="h-8 w-px bg-neutral-200 shrink-0" />

          {/* Når */}
          <button
            className={`flex-1 min-w-0 px-5 py-3 text-left transition-colors ${
              activeSegment === "when" ? "bg-neutral-100" : "hover:bg-neutral-50"
            }`}
            onClick={() => setActiveSegment(activeSegment === "when" ? null : "when")}
          >
            <div className="text-xs font-semibold text-neutral-900">Når</div>
            <div className={`text-sm truncate ${dateLabel ? "text-neutral-700" : "text-neutral-400"}`}>
              {dateLabel || "Legg til dato"}
            </div>
          </button>

          <div className="h-8 w-px bg-neutral-200 shrink-0" />

          {/* Kjøretøy */}
          <button
            className={`flex-1 min-w-0 px-5 py-3 text-left transition-colors ${
              activeSegment === "vehicle" ? "bg-neutral-100" : "hover:bg-neutral-50"
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
            className="m-2 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary-600 text-white transition-colors hover:bg-primary-700"
            aria-label="Søk"
          >
            <Search className="h-4 w-4" />
          </button>
        </div>

        {/* Dropdowns */}
        {activeSegment === "when" && (
          <div className="absolute left-1/2 -translate-x-1/2 mt-2 z-50 rounded-xl border border-neutral-200 bg-white p-4 shadow-lg">
            <DatePicker selected={dateRange} onSelect={setDateRange} />
          </div>
        )}

        {activeSegment === "vehicle" && (
          <div className="absolute right-12 mt-2 z-50 w-56 rounded-xl border border-neutral-200 bg-white py-2 shadow-lg">
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
            {/* Hvor */}
            <div>
              <label className="mb-1.5 block text-sm font-semibold text-neutral-900">
                Hvor
              </label>
              <input
                type="text"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                placeholder="Søk etter sted"
                className="w-full rounded-lg border border-neutral-300 px-4 py-3 text-sm placeholder:text-neutral-400 focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20"
              />
            </div>

            {/* Når */}
            <div>
              <label className="mb-1.5 block text-sm font-semibold text-neutral-900">
                Når
              </label>
              <DatePicker selected={dateRange} onSelect={setDateRange} />
            </div>

            {/* Kjøretøy */}
            <div>
              <label className="mb-1.5 block text-sm font-semibold text-neutral-900">
                Kjøretøy
              </label>
              <div className="grid grid-cols-2 gap-2">
                {vehicleOptions.map((opt) => {
                  const Icon = opt.icon;
                  const isSelected = vehicle === opt.value;
                  return (
                    <button
                      key={opt.value}
                      onClick={() =>
                        setVehicle(isSelected ? undefined : opt.value)
                      }
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
