"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import { MapPin, Trash2, EyeOff, X, Sparkles } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { bcpLocale } from "@/lib/i18n-helpers";
import Input from "@/components/ui/Input";
import Toggle from "@/components/ui/Toggle";
import { AVAILABLE_EXTRAS, type SpotMarker, type ListingCategory, type ListingExtra, type ExtraId } from "@/types";

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
  category: ListingCategory;
  defaultPrice: number;
  perSpotPricing: boolean;
  priceUnit: "time" | "natt";
  checkinMessage?: string;
  perSpotCheckinMessage: boolean;
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
  category,
  defaultPrice,
  perSpotPricing,
  priceUnit,
  checkinMessage,
  perSpotCheckinMessage,
  onChange,
  errors,
}: LocationStepProps) {
  const t = useTranslations("host.location");
  const setPerSpotCheckinMessage = (enabled: boolean) => {
    onChange("perSpotCheckinMessage", enabled);
    if (enabled) {
      onChange("checkinMessage", "");
    } else {
      const next = spotMarkers.map((s) => ({ ...s, checkinMessage: undefined }));
      onChange("spotMarkers", next);
    }
  };
  const setPerSpotPricing = (enabled: boolean) => {
    onChange("perSpotPricing", enabled);
    const next = spotMarkers.map((s) => ({
      ...s,
      price: enabled ? (s.price ?? defaultPrice) : undefined,
    }));
    onChange("spotMarkers", next);
  };
  const priceLabel = priceUnit === "natt" ? t("pricePerNight") : t("pricePerHour");
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

  const syncSpotMarkers = useCallback((markers: SpotMarker[]) => {
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

  useEffect(() => {
    if (mapReady && lat && lng && mainMarkerRef.current) {
      mainMarkerRef.current.position = { lat, lng };
    }
  }, [lat, lng, mapReady]);

  useEffect(() => {
    if (mapReady) {
      syncSpotMarkers(spotMarkers);
    }
  }, [spotMarkers, mapReady, syncSpotMarkers]);

  useEffect(() => {
    if (!mapReady || !mapInstanceRef.current) return;

    const map = mapInstanceRef.current;
    const listener = map.addListener("click", (e: google.maps.MapMouseEvent) => {
      if (!e.latLng) return;

      if (placingSpots) {
        const newMarker: SpotMarker = {
          id: crypto.randomUUID(),
          lat: e.latLng.lat(),
          lng: e.latLng.lng(),
        };
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
        <h2 className="text-xl font-bold text-neutral-900">{t("title")}</h2>
        <p className="mt-1 text-sm text-neutral-500">{t("subtitle")}</p>
      </div>

      <Input
        ref={inputRef}
        id="address"
        label={t("addressLabel")}
        placeholder={t("addressPlaceholder")}
        value={address}
        onChange={(e) => onChange("address", e.target.value)}
        error={errors.address}
      />

      <div className="grid gap-4 sm:grid-cols-2">
        <Input
          id="city"
          label={t("cityLabel")}
          placeholder={t("cityPlaceholder")}
          value={city}
          onChange={(e) => onChange("city", e.target.value)}
          error={errors.city}
        />
        <Input
          id="region"
          label={t("regionLabel")}
          placeholder={t("regionPlaceholder")}
          value={region}
          onChange={(e) => onChange("region", e.target.value)}
          error={errors.region}
        />
      </div>

      {/* Map */}
      <div>
        <div className="mb-2 flex items-center justify-between">
          <p className="text-sm font-medium text-neutral-700">
            {placingSpots ? t("mapHintPlacing") : t("mapHintDefault")}
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
            {placingSpots ? t("placingSpots") : t("markSpots")}
          </button>
        </div>
        <div
          ref={mapRef}
          className="h-[350px] w-full rounded-xl border border-neutral-200 overflow-hidden"
        />
        {errors.lat && <p className="mt-1 text-sm text-red-500">{errors.lat}</p>}
      </div>

      {/* Prising */}
      {(lat !== 0 || lng !== 0) && (
        <div className="space-y-4 rounded-xl border border-neutral-200 bg-white p-4">
          <h3 className="text-base font-semibold text-neutral-900">{t("priceHeader")}</h3>

          <div>
            <label className="block text-sm font-medium text-neutral-700 mb-1.5">
              {perSpotPricing ? t("priceStandardLabel", { unit: priceLabel }) : t("priceUniformLabel", { unit: priceLabel })}
            </label>
            <div className="flex items-center gap-2">
              <input
                type="number"
                value={defaultPrice || ""}
                onChange={(e) => onChange("price", Math.max(0, Number(e.target.value)))}
                placeholder={t("pricePlaceholder")}
                className="w-40 rounded-lg border border-neutral-300 px-3 py-2 text-sm"
              />
              <span className="text-sm text-neutral-500">{t("priceCurrency")}</span>
            </div>
            {perSpotPricing && (
              <p className="mt-1 text-xs text-neutral-500">
                {t("priceFallbackNote")}
              </p>
            )}
            {errors.price && <p className="mt-1 text-sm text-red-500">{errors.price}</p>}
          </div>

          <div className="space-y-2">
            <button
              type="button"
              onClick={() => setPerSpotPricing(false)}
              className={`flex w-full items-start gap-3 rounded-lg border p-3 text-left transition ${!perSpotPricing ? "border-primary-600 bg-primary-50" : "border-neutral-200 bg-white"}`}
            >
              <div className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 ${!perSpotPricing ? "border-primary-600" : "border-neutral-300"}`}>
                {!perSpotPricing && <div className="h-2.5 w-2.5 rounded-full bg-primary-600" />}
              </div>
              <div className="flex-1">
                <div className="text-sm font-medium text-neutral-900">{t("priceSameTitle")}</div>
                <div className="text-xs text-neutral-500">{t("priceSameDesc")}</div>
              </div>
            </button>
            <button
              type="button"
              onClick={() => setPerSpotPricing(true)}
              className={`flex w-full items-start gap-3 rounded-lg border p-3 text-left transition ${perSpotPricing ? "border-primary-600 bg-primary-50" : "border-neutral-200 bg-white"}`}
            >
              <div className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 ${perSpotPricing ? "border-primary-600" : "border-neutral-300"}`}>
                {perSpotPricing && <div className="h-2.5 w-2.5 rounded-full bg-primary-600" />}
              </div>
              <div className="flex-1">
                <div className="text-sm font-medium text-neutral-900">{t("pricePerSpotTitle")}</div>
                <div className="text-xs text-neutral-500">{t("pricePerSpotDesc")}</div>
              </div>
            </button>
          </div>
        </div>
      )}

      {/* Velkomstmelding */}
      {(lat !== 0 || lng !== 0) && (
        <div className="space-y-4 rounded-xl border border-neutral-200 bg-white p-4">
          <div>
            <h3 className="text-base font-semibold text-neutral-900">{t("welcomeHeader")}</h3>
            <p className="mt-0.5 text-xs text-neutral-500">
              {t("welcomeHelp")}
            </p>
          </div>

          <div className="space-y-2">
            <button
              type="button"
              onClick={() => setPerSpotCheckinMessage(false)}
              className={`flex w-full items-start gap-3 rounded-lg border p-3 text-left transition ${!perSpotCheckinMessage ? "border-primary-600 bg-primary-50" : "border-neutral-200 bg-white"}`}
            >
              <div className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 ${!perSpotCheckinMessage ? "border-primary-600" : "border-neutral-300"}`}>
                {!perSpotCheckinMessage && <div className="h-2.5 w-2.5 rounded-full bg-primary-600" />}
              </div>
              <div className="flex-1">
                <div className="text-sm font-medium text-neutral-900">{t("welcomeSameTitle")}</div>
                <div className="text-xs text-neutral-500">{t("welcomeSameDesc")}</div>
              </div>
            </button>
            <button
              type="button"
              onClick={() => setPerSpotCheckinMessage(true)}
              className={`flex w-full items-start gap-3 rounded-lg border p-3 text-left transition ${perSpotCheckinMessage ? "border-primary-600 bg-primary-50" : "border-neutral-200 bg-white"}`}
            >
              <div className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 ${perSpotCheckinMessage ? "border-primary-600" : "border-neutral-300"}`}>
                {perSpotCheckinMessage && <div className="h-2.5 w-2.5 rounded-full bg-primary-600" />}
              </div>
              <div className="flex-1">
                <div className="text-sm font-medium text-neutral-900">{t("welcomePerSpotTitle")}</div>
                <div className="text-xs text-neutral-500">{t("welcomePerSpotDesc")}</div>
              </div>
            </button>
          </div>

          {!perSpotCheckinMessage && (
            <textarea
              value={checkinMessage ?? ""}
              onChange={(e) => onChange("checkinMessage", e.target.value)}
              placeholder={t("welcomePlaceholder")}
              rows={4}
              className="w-full rounded-lg border border-neutral-300 px-3 py-2 text-sm placeholder:text-neutral-400"
            />
          )}
          {perSpotCheckinMessage && (
            <p className="text-xs text-neutral-500">{t("welcomePerSpotNote")}</p>
          )}
        </div>
      )}

      {/* Plasser (utbrettet) */}
      {spotMarkers.length > 0 && (
        <div>
          <p className="text-sm font-medium text-neutral-700 mb-3">
            {spots > 0
              ? t("spotsHeaderOfTotal", { count: spotMarkers.length, total: spots })
              : t("spotsHeader", { count: spotMarkers.length })}
          </p>
          <div className="space-y-4">
            {spotMarkers.map((spot, i) => (
              <SpotInlineCard
                key={spot.id ?? i}
                index={i}
                spot={spot}
                category={category}
                defaultPrice={defaultPrice}
                showPrice={perSpotPricing}
                showCheckinMessage={perSpotCheckinMessage}
                onChange={(updated) => {
                  const next = [...spotMarkers];
                  next[i] = { ...updated, id: updated.id ?? crypto.randomUUID() };
                  onChange("spotMarkers", next);
                }}
                onRemove={() => removeSpot(i)}
              />
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
              label={t("hideAddressLabel")}
              description={t("hideAddressDesc")}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

interface SpotInlineCardProps {
  index: number;
  spot: SpotMarker;
  category: ListingCategory;
  defaultPrice: number;
  showPrice: boolean;
  showCheckinMessage: boolean;
  onChange: (updated: SpotMarker) => void;
  onRemove: () => void;
}

function SpotInlineCard({ index, spot, category, defaultPrice, showPrice, showCheckinMessage, onChange, onRemove }: SpotInlineCardProps) {
  const t = useTranslations("host.location");
  const [customName, setCustomName] = useState("");
  const [customPrice, setCustomPrice] = useState("");
  const [customPerNight, setCustomPerNight] = useState(false);

  const extras = spot.extras ?? [];
  const presetIds = new Set(AVAILABLE_EXTRAS.map((e) => e.id));
  const customExtras = extras.filter((e) => !presetIds.has(e.id as ExtraId));
  const sitePresets = AVAILABLE_EXTRAS.filter((e) => e.category.includes(category) && e.scope === "site");

  const setExtras = (next: ListingExtra[]) => {
    onChange({ ...spot, extras: next.length ? next : undefined });
  };

  const toggle = (id: ExtraId) => {
    if (extras.some((e) => e.id === id)) {
      setExtras(extras.filter((e) => e.id !== id));
    } else {
      const def = AVAILABLE_EXTRAS.find((e) => e.id === id)!;
      setExtras([...extras, { id, name: def.name, price: def.defaultPrice, perNight: def.perNight }]);
    }
  };

  const addCustom = () => {
    const name = customName.trim();
    const price = Number(customPrice);
    if (!name || !price || price <= 0) return;
    setExtras([...extras, { id: crypto.randomUUID(), name, price, perNight: customPerNight }]);
    setCustomName("");
    setCustomPrice("");
    setCustomPerNight(false);
  };

  return (
    <div className="rounded-xl border border-neutral-200 bg-white p-4 space-y-4">
      <div className="flex items-center gap-3">
        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary-600 text-sm font-bold text-white">
          {index + 1}
        </div>
        <input
          type="text"
          value={spot.label ?? ""}
          onChange={(e) => onChange({ ...spot, label: e.target.value || undefined })}
          placeholder={t("spotNamePlaceholder")}
          className="flex-1 rounded-lg border border-neutral-300 px-3 py-2 text-sm"
        />
        <button
          type="button"
          onClick={onRemove}
          className="text-neutral-400 hover:text-red-500 transition-colors"
        >
          <Trash2 className="h-4 w-4" />
        </button>
      </div>

      {showPrice && (
        <div className="flex items-center gap-2">
          <label className="text-sm font-medium text-neutral-700 w-16">{t("spotPriceLabel")}</label>
          <input
            type="number"
            value={spot.price ?? defaultPrice}
            onChange={(e) => onChange({ ...spot, price: Math.max(0, Number(e.target.value)) })}
            className="w-32 rounded-lg border border-neutral-300 px-3 py-2 text-sm"
          />
          <span className="text-xs text-neutral-500">{t("pricePerNight")}</span>
        </div>
      )}

      {sitePresets.length > 0 && (
        <div>
          <p className="text-sm font-medium text-neutral-700 mb-2">{t("spotExtrasHeader")}</p>
          <div className="space-y-2">
            {sitePresets.map((preset) => {
              const selected = extras.find((e) => e.id === preset.id);
              const isSel = !!selected;
              return (
                <div key={preset.id} className={`rounded-lg border ${isSel ? "border-primary-600 bg-primary-50" : "border-neutral-200"}`}>
                  <button
                    type="button"
                    onClick={() => toggle(preset.id)}
                    className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm"
                  >
                    <div className={`flex h-5 w-5 items-center justify-center rounded border-2 ${isSel ? "border-primary-600 bg-primary-600" : "border-neutral-300"}`}>
                      {isSel && <svg className="h-3 w-3 text-white" viewBox="0 0 12 12"><path d="M10 3L4.5 8.5L2 6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
                    </div>
                    <span className="flex-1">{preset.name}</span>
                    <span className="text-xs text-neutral-500">{preset.perNight ? t("perNight") : t("oneTime")}</span>
                  </button>
                  {isSel && selected && (
                    <div className="border-t border-primary-200 px-3 py-2 flex items-center gap-2">
                      <label className="text-xs text-neutral-500">{t("extraPriceLabel")}</label>
                      <input
                        type="number"
                        value={selected.price}
                        onChange={(e) => setExtras(extras.map((x) => x.id === preset.id ? { ...x, price: Math.max(0, Number(e.target.value)) } : x))}
                        className="w-20 rounded border border-neutral-300 px-2 py-1 text-sm"
                      />
                      <span className="text-xs text-neutral-500">{preset.perNight ? t("pricePerNight") : t("priceCurrency")}</span>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}

      <div className="space-y-2 pt-2 border-t border-neutral-100">
        <p className="text-xs font-semibold text-neutral-700">{t("customExtraHeader")}</p>
        {customExtras.map((extra) => (
          <div key={extra.id} className="flex items-center gap-2 rounded-lg bg-primary-50 px-3 py-2">
            <Sparkles className="h-3.5 w-3.5 text-primary-600" />
            <div className="flex-1 text-xs">
              <div className="font-medium">{extra.name}</div>
              <div className="text-neutral-500">{extra.price} {extra.perNight ? t("pricePerNight") : t("priceCurrency")}</div>
            </div>
            <button type="button" onClick={() => setExtras(extras.filter((e) => e.id !== extra.id))} className="text-neutral-400">
              <X className="h-3.5 w-3.5" />
            </button>
          </div>
        ))}
        <div className="flex gap-2">
          <input
            type="text"
            value={customName}
            onChange={(e) => setCustomName(e.target.value)}
            placeholder={t("customExtraName")}
            className="flex-1 rounded-lg border border-neutral-300 px-2 py-1.5 text-xs"
          />
          <input
            type="number"
            value={customPrice}
            onChange={(e) => setCustomPrice(e.target.value)}
            placeholder={t("customExtraPrice")}
            className="w-20 rounded-lg border border-neutral-300 px-2 py-1.5 text-xs"
          />
          <label className="flex items-center gap-1 text-xs text-neutral-600">
            <input type="checkbox" checked={customPerNight} onChange={(e) => setCustomPerNight(e.target.checked)} className="h-3.5 w-3.5 rounded border-neutral-300" />
            {t("customExtraPerNight")}
          </label>
          <button
            type="button"
            onClick={addCustom}
            disabled={!customName.trim() || Number(customPrice) <= 0}
            className="rounded-full bg-primary-600 px-3 py-1 text-xs font-semibold text-white disabled:bg-neutral-300"
          >
            +
          </button>
        </div>
      </div>

      {showCheckinMessage && (
        <div className="space-y-1 pt-2 border-t border-neutral-100">
          <label className="text-xs font-semibold text-neutral-700">{t("spotWelcomeLabel")}</label>
          <textarea
            value={spot.checkinMessage ?? ""}
            onChange={(e) => onChange({ ...spot, checkinMessage: e.target.value || undefined })}
            placeholder={t("spotWelcomePlaceholder")}
            rows={2}
            className="w-full rounded-lg border border-neutral-300 px-3 py-2 text-sm placeholder:text-neutral-400"
          />
        </div>
      )}

      <SpotBlockedDates
        blockedDates={spot.blockedDates ?? []}
        onChange={(dates) => onChange({ ...spot, blockedDates: dates.length ? dates : undefined })}
      />
    </div>
  );
}

interface SpotBlockedDatesProps {
  blockedDates: string[];
  onChange: (dates: string[]) => void;
}

function SpotBlockedDates({ blockedDates, onChange }: SpotBlockedDatesProps) {
  const t = useTranslations("host.location");
  const locale = useLocale();
  const dateLocale = bcpLocale(locale);
  const [expanded, setExpanded] = useState(false);
  const [displayedMonth, setDisplayedMonth] = useState(new Date());

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const formatDate = (d: Date) => {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return `${y}-${m}-${day}`;
  };

  const monthLabel = displayedMonth.toLocaleDateString(dateLocale, { month: "long", year: "numeric" });

  const moveMonth = (delta: number) => {
    const next = new Date(displayedMonth);
    next.setMonth(next.getMonth() + delta);
    setDisplayedMonth(next);
  };

  const daysInMonth = (): (Date | null)[] => {
    const year = displayedMonth.getFullYear();
    const month = displayedMonth.getMonth();
    const first = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0).getDate();
    let weekday = first.getDay();
    weekday = weekday === 0 ? 7 : weekday;
    const days: (Date | null)[] = Array(weekday - 1).fill(null);
    for (let d = 1; d <= lastDay; d++) days.push(new Date(year, month, d));
    return days;
  };

  const toggleDate = (d: Date) => {
    if (d < today) return;
    const str = formatDate(d);
    if (blockedDates.includes(str)) {
      onChange(blockedDates.filter((x) => x !== str));
    } else {
      onChange([...blockedDates, str]);
    }
  };

  const weekdayLabels = [
    t("weekdayMon"),
    t("weekdayTue"),
    t("weekdayWed"),
    t("weekdayThu"),
    t("weekdayFri"),
    t("weekdaySat"),
    t("weekdaySun"),
  ];

  return (
    <div className="pt-2 border-t border-neutral-100 space-y-2">
      <button
        type="button"
        onClick={() => setExpanded(!expanded)}
        className="flex w-full items-center gap-2 text-xs"
      >
        <svg className="h-3.5 w-3.5 text-neutral-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
        <span className="font-semibold text-neutral-700">{t("blockedDatesHeader")}</span>
        {blockedDates.length > 0 && (
          <span className="text-red-600">({blockedDates.length})</span>
        )}
        <span className="ml-auto text-neutral-400">{expanded ? "▾" : "▸"}</span>
      </button>

      {expanded && (
        <div>
          <div className="flex items-center justify-between text-xs mb-1">
            <button type="button" onClick={() => moveMonth(-1)} className="text-neutral-500 px-2">‹</button>
            <span className="font-medium capitalize">{monthLabel}</span>
            <button type="button" onClick={() => moveMonth(1)} className="text-neutral-500 px-2">›</button>
          </div>
          <div className="grid grid-cols-7 text-center text-[10px] text-neutral-500 mb-1">
            {weekdayLabels.map((d) => <div key={d}>{d}</div>)}
          </div>
          <div className="grid grid-cols-7 gap-0.5">
            {daysInMonth().map((d, i) => {
              if (!d) return <div key={i} />;
              const str = formatDate(d);
              const isBlocked = blockedDates.includes(str);
              const isPast = d < today;
              return (
                <button
                  key={i}
                  type="button"
                  disabled={isPast}
                  onClick={() => toggleDate(d)}
                  className={`h-7 rounded text-xs transition ${
                    isPast ? "text-neutral-300" : isBlocked ? "bg-red-100 text-red-700 font-bold" : "text-neutral-800 hover:bg-neutral-100"
                  }`}
                >
                  {d.getDate()}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
