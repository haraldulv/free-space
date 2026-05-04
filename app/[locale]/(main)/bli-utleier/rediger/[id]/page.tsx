"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import Image from "next/image";
import {
  Loader2,
  FileText,
  MapPin,
  Image as ImageIcon,
  Sparkles,
  CalendarDays,
  CalendarClock,
  ChevronRight,
  ExternalLink,
  Eye,
  EyeOff,
  Loader,
} from "lucide-react";
import { useTranslations } from "next-intl";
import { createClient } from "@/lib/supabase/client";
import {
  updateListingAction,
  updateBlockedDatesAction,
  toggleListingActiveAction,
} from "../../actions";
import BasicInfoStep from "@/components/features/listing-form/steps/BasicInfoStep";
import LocationStep from "@/components/features/listing-form/steps/LocationStep";
import ImageUploadStep from "@/components/features/listing-form/steps/ImageUploadStep";
import AmenitiesStep from "@/components/features/listing-form/steps/AmenitiesStep";
import DiscountsStep from "@/components/features/listing-form/steps/DiscountsStep";
import AvailabilityEditor from "@/components/features/listing-form/AvailabilityEditor";
import Button from "@/components/ui/Button";
import Sheet from "@/components/ui/Sheet";
import type { CreateListingData } from "@/lib/supabase/listings";
import type { Amenity, SpotMarker } from "@/types";

type SectionId =
  | "info"
  | "location"
  | "images"
  | "amenities"
  | "discounts"
  | "availability";

export default function EditListingPage() {
  const t = useTranslations("host.edit");
  const tHost = useTranslations("host");
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");
  const [openSheet, setOpenSheet] = useState<SectionId | null>(null);
  const [activeToggling, setActiveToggling] = useState(false);

  const [formData, setFormData] = useState<Partial<CreateListingData>>({});
  const [blockedDates, setBlockedDates] = useState<string[]>([]);
  const [isActive, setIsActive] = useState<boolean>(true);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (!user) {
        router.push("/login");
        return;
      }
      setUserId(user.id);

      const { data: row } = await supabase
        .from("listings")
        .select("*")
        .eq("id", id)
        .single();

      if (!row || row.host_id !== user.id) {
        router.push("/dashboard?tab=annonser");
        return;
      }

      setFormData({
        category: row.category,
        vehicleType: row.vehicle_type || "motorhome",
        title: row.title,
        internalName: row.internal_name || "",
        description: row.description,
        spots: row.spots,
        maxVehicleLength: row.max_vehicle_length,
        address: row.address,
        city: row.city,
        region: row.region,
        lat: row.lat,
        lng: row.lng,
        images: row.images,
        amenities: row.amenities,
        price: row.price,
        priceUnit: row.price_unit,
        instantBooking: row.instant_booking || false,
        spotMarkers: row.spot_markers || [],
        hideExactLocation: row.hide_exact_location || false,
        checkInTime: row.check_in_time || "15:00",
        checkOutTime: row.check_out_time || "11:00",
        checkinMessage: row.checkin_message || "",
        checkoutMessage: row.checkout_message || "",
        checkoutMessageSendHoursBefore: row.checkout_message_send_hours_before ?? 2,
        extras: row.extras || [],
        perSpotPricing: Array.isArray(row.spot_markers) && (row.spot_markers as SpotMarker[]).some((s) => s.price != null),
        perSpotCheckinMessage: Array.isArray(row.spot_markers) && (row.spot_markers as SpotMarker[]).some((s) => s.checkinMessage),
      });
      setBlockedDates(row.blocked_dates || []);
      setIsActive(row.is_active !== false);
      setLoading(false);
    });
  }, [router, id]);

  const updateField = (field: string, value: unknown) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    setSaved(false);
  };

  const handleSave = async (closeAfter = true) => {
    if (saving) return false;
    setSaving(true);
    setError("");
    setSaved(false);
    try {
      const result = await updateListingAction(id, formData as Partial<CreateListingData>);
      if (result.error) {
        setError(result.error);
        setSaving(false);
        return false;
      }
      const datesResult = await updateBlockedDatesAction(id, blockedDates);
      if (datesResult.error) {
        setError(datesResult.error);
        setSaving(false);
        return false;
      }
      setSaved(true);
      setSaving(false);
      if (closeAfter) setOpenSheet(null);
      return true;
    } catch (err) {
      setError(err instanceof Error ? err.message : tHost("somethingWentWrong"));
      setSaving(false);
      return false;
    }
  };

  const handleToggleActive = async () => {
    if (activeToggling) return;
    setActiveToggling(true);
    setError("");
    const next = !isActive;
    const result = await toggleListingActiveAction(id, next);
    if (result.error) {
      setError(result.error);
    } else {
      setIsActive(next);
    }
    setActiveToggling(false);
  };

  if (loading || !userId) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <p className="text-sm text-neutral-400">{t("loadingListing")}</p>
      </div>
    );
  }

  const errors: Record<string, string> = {};

  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      {/* Header */}
      <div className="mb-6">
        <button
          type="button"
          onClick={() => router.push("/dashboard?tab=annonser")}
          className="mb-3 text-sm text-neutral-500 hover:text-neutral-900"
        >
          ← {t("backToListings")}
        </button>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <h1 className="text-2xl font-bold text-neutral-900 sm:text-3xl">
              {formData.title || t("untitledListing")}
            </h1>
            {formData.address && (
              <p className="mt-1 text-sm text-neutral-500">
                {formData.address}{formData.city ? `, ${formData.city}` : ""}
              </p>
            )}
          </div>
          <a
            href={`/listings/${id}`}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 rounded-full border border-neutral-200 px-3 py-1.5 text-xs font-medium text-neutral-700 hover:bg-neutral-50"
          >
            <ExternalLink className="h-3.5 w-3.5" />
            {t("viewListing")}
          </a>
        </div>
      </div>

      {/* Status banner */}
      <div className={`mb-6 flex items-center justify-between rounded-2xl border px-4 py-3 ${isActive ? "border-primary-200 bg-primary-50" : "border-neutral-200 bg-neutral-50"}`}>
        <div className="flex items-center gap-3">
          {isActive ? (
            <Eye className="h-5 w-5 text-primary-600" />
          ) : (
            <EyeOff className="h-5 w-5 text-neutral-500" />
          )}
          <div>
            <p className="text-sm font-semibold text-neutral-900">
              {isActive ? t("listingActiveTitle") : t("listingHiddenTitle")}
            </p>
            <p className="text-xs text-neutral-500">
              {isActive ? t("listingActiveDesc") : t("listingHiddenDesc")}
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={handleToggleActive}
          disabled={activeToggling}
          className="inline-flex items-center gap-1.5 rounded-full border border-neutral-300 bg-white px-4 py-1.5 text-sm font-medium text-neutral-800 transition-colors hover:bg-neutral-100 disabled:opacity-60"
        >
          {activeToggling ? <Loader className="h-3.5 w-3.5 animate-spin" /> : null}
          {isActive ? t("hideListingButton") : t("activateListingButton")}
        </button>
      </div>

      {error && (
        <div className="mb-6 rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</div>
      )}

      {/* Section cards */}
      <div className="space-y-3">
        <SectionCard
          icon={ImageIcon}
          title={t("sectionImagesTitle")}
          preview={
            (formData.images || []).length > 0
              ? t("sectionImagesPreview", { count: (formData.images || []).length })
              : t("sectionImagesEmpty")
          }
          coverImage={formData.images?.[0]}
          onClick={() => setOpenSheet("images")}
        />

        <SectionCard
          icon={FileText}
          title={t("sectionInfoTitle")}
          preview={infoPreview(formData, t)}
          onClick={() => setOpenSheet("info")}
        />

        <SectionCard
          icon={MapPin}
          title={t("sectionLocationTitle")}
          preview={locationPreview(formData, t)}
          onClick={() => setOpenSheet("location")}
        />

        <SectionCard
          icon={CalendarClock}
          title={t("sectionDiscountsTitle")}
          preview={discountsPreview(formData, t)}
          onClick={() => setOpenSheet("discounts")}
        />

        <SectionCard
          icon={Sparkles}
          title={t("sectionAmenitiesTitle")}
          preview={
            (formData.amenities || []).length > 0
              ? t("sectionAmenitiesPreview", { count: (formData.amenities || []).length })
              : t("sectionAmenitiesEmpty")
          }
          onClick={() => setOpenSheet("amenities")}
        />

        {/* Tilgjengelighet vises inline — kalender er stor og naturlig på siden */}
        <div className="rounded-2xl border border-neutral-200 bg-white p-5">
          <div className="mb-4 flex items-center gap-3">
            <div className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-neutral-100">
              <CalendarDays className="h-5 w-5 text-neutral-700" />
            </div>
            <div>
              <h2 className="text-base font-semibold text-neutral-900">
                {t("sectionAvailabilityTitle")}
              </h2>
              <p className="text-xs text-neutral-500">{t("sectionAvailabilitySubtitle")}</p>
            </div>
          </div>
          <AvailabilityEditor
            blockedDates={blockedDates}
            onChange={(dates) => {
              setBlockedDates(dates);
              setSaved(false);
            }}
          />
          <div className="mt-4 flex items-center gap-3">
            <Button onClick={() => handleSave(false)} disabled={saving}>
              {saving ? (
                <>
                  <Loader2 className="mr-1.5 h-4 w-4 animate-spin" />
                  {t("saving")}
                </>
              ) : (
                t("saveAvailability")
              )}
            </Button>
            {saved && (
              <span className="text-sm font-medium text-green-600">{t("saved")}</span>
            )}
          </div>
        </div>
      </div>

      {/* Sheets */}
      <Sheet
        open={openSheet === "info"}
        onClose={() => setOpenSheet(null)}
        title={t("sectionInfoTitle")}
        footer={<SaveBar onSave={() => handleSave()} saving={saving} saved={saved} t={t} />}
      >
        <BasicInfoStep
          title={formData.title || ""}
          internalName={formData.internalName || ""}
          description={formData.description || ""}
          spots={formData.spots || 1}
          maxVehicleLength={formData.maxVehicleLength}
          category={formData.category}
          checkInTime={formData.checkInTime}
          checkOutTime={formData.checkOutTime}
          instantBooking={formData.instantBooking ?? false}
          onChange={updateField}
          errors={errors}
        />
      </Sheet>

      <Sheet
        open={openSheet === "location"}
        onClose={() => setOpenSheet(null)}
        title={t("sectionLocationTitle")}
        footer={<SaveBar onSave={() => handleSave()} saving={saving} saved={saved} t={t} />}
      >
        <LocationStep
          address={formData.address || ""}
          city={formData.city || ""}
          region={formData.region || ""}
          lat={formData.lat || 0}
          lng={formData.lng || 0}
          spotMarkers={(formData.spotMarkers || []) as SpotMarker[]}
          hideExactLocation={formData.hideExactLocation || false}
          spots={formData.spots || 1}
          category={formData.category || "camping"}
          defaultPrice={formData.price || 0}
          perSpotPricing={formData.perSpotPricing || false}
          priceUnit={formData.priceUnit || "natt"}
          checkinMessage={formData.checkinMessage}
          perSpotCheckinMessage={formData.perSpotCheckinMessage || false}
          checkoutMessage={formData.checkoutMessage}
          checkoutMessageSendHoursBefore={formData.checkoutMessageSendHoursBefore}
          onChange={updateField}
          errors={errors}
        />
      </Sheet>

      <Sheet
        open={openSheet === "images"}
        onClose={() => setOpenSheet(null)}
        title={t("sectionImagesTitle")}
        footer={<SaveBar onSave={() => handleSave()} saving={saving} saved={saved} t={t} />}
      >
        <ImageUploadStep
          images={formData.images || []}
          userId={userId}
          onChange={(imgs) => updateField("images", imgs)}
          error={errors.images}
        />
      </Sheet>

      <Sheet
        open={openSheet === "amenities"}
        onClose={() => setOpenSheet(null)}
        title={t("sectionAmenitiesTitle")}
        footer={<SaveBar onSave={() => handleSave()} saving={saving} saved={saved} t={t} />}
      >
        {formData.category && (
          <AmenitiesStep
            category={formData.category}
            selected={(formData.amenities || []) as Amenity[]}
            onChange={(amenities) => updateField("amenities", amenities)}
          />
        )}
      </Sheet>

      <Sheet
        open={openSheet === "discounts"}
        onClose={() => setOpenSheet(null)}
        title={t("sectionDiscountsTitle")}
        footer={<SaveBar onSave={() => handleSave()} saving={saving} saved={saved} t={t} />}
      >
        <DiscountsStep
          spotMarkers={(formData.spotMarkers || []) as SpotMarker[]}
          defaultPrice={formData.price || 0}
          priceUnit={formData.priceUnit || "natt"}
          onChange={updateField}
        />
      </Sheet>
    </div>
  );
}

interface SectionCardProps {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  preview: string;
  coverImage?: string;
  onClick: () => void;
}

function SectionCard({ icon: Icon, title, preview, coverImage, onClick }: SectionCardProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="group flex w-full items-center gap-4 rounded-2xl border border-neutral-200 bg-white p-4 text-left transition-colors hover:border-neutral-300 hover:bg-neutral-50"
    >
      {coverImage ? (
        <div className="relative h-14 w-14 flex-none overflow-hidden rounded-xl bg-neutral-100">
          <Image src={coverImage} alt="" fill className="object-cover" sizes="56px" unoptimized />
        </div>
      ) : (
        <div className="flex h-14 w-14 flex-none items-center justify-center rounded-xl bg-neutral-100">
          <Icon className="h-6 w-6 text-neutral-700" />
        </div>
      )}
      <div className="min-w-0 flex-1">
        <p className="text-base font-semibold text-neutral-900">{title}</p>
        <p className="truncate text-sm text-neutral-500">{preview}</p>
      </div>
      <ChevronRight className="h-5 w-5 flex-none text-neutral-400 transition-transform group-hover:translate-x-0.5" />
    </button>
  );
}

interface SaveBarProps {
  onSave: () => Promise<boolean>;
  saving: boolean;
  saved: boolean;
  t: (key: string) => string;
}

function SaveBar({ onSave, saving, saved, t }: SaveBarProps) {
  return (
    <div className="flex items-center justify-end gap-3">
      {saved && !saving && (
        <span className="text-sm font-medium text-green-600">{t("saved")}</span>
      )}
      <Button onClick={onSave} disabled={saving}>
        {saving ? (
          <>
            <Loader2 className="mr-1.5 h-4 w-4 animate-spin" />
            {t("saving")}
          </>
        ) : (
          t("save")
        )}
      </Button>
    </div>
  );
}

// MARK: - Preview-helpers

function infoPreview(d: Partial<CreateListingData>, t: (key: string, args?: Record<string, string | number | Date>) => string): string {
  const parts: string[] = [];
  if (d.spots) parts.push(t("spotsCount", { count: d.spots }));
  if (d.instantBooking) parts.push(t("instantBookingShort"));
  if (d.description) {
    const trimmed = d.description.trim();
    if (trimmed.length > 0) {
      parts.push(trimmed.length > 60 ? trimmed.slice(0, 60) + "…" : trimmed);
    }
  }
  return parts.length > 0 ? parts.join(" · ") : t("infoEmpty");
}

function locationPreview(d: Partial<CreateListingData>, t: (key: string, args?: Record<string, string | number | Date>) => string): string {
  const markers = d.spotMarkers || [];
  const prices = markers
    .map((m) => m.price ?? m.pricePerHour ?? m.pricePerNight)
    .filter((p): p is number => p != null && p > 0);
  if (prices.length > 0) {
    const min = Math.min(...prices);
    const max = Math.max(...prices);
    const unit = d.priceUnit === "hour" ? "kr/time" : "kr/natt";
    if (min === max) return t("locationPricePreview", { price: `${min}`, unit });
    return t("locationPricePreview", { price: `${min}–${max}`, unit });
  }
  if (d.price && d.price > 0) {
    const unit = d.priceUnit === "hour" ? "kr/time" : "kr/natt";
    return t("locationPricePreview", { price: `${d.price}`, unit });
  }
  return d.address ? d.address : t("locationEmpty");
}

function discountsPreview(d: Partial<CreateListingData>, t: (key: string) => string): string {
  const markers = d.spotMarkers || [];
  const hasAny = markers.some(
    (m) =>
      (m.dailyPrice ?? 0) > 0 ||
      (m.weeklyPrice ?? 0) > 0 ||
      (m.monthlyPrice ?? 0) > 0 ||
      (m.discountDayPct ?? 0) > 0 ||
      (m.discountWeekPct ?? 0) > 0 ||
      (m.discountMonthPct ?? 0) > 0,
  );
  return hasAny ? t("discountsActive") : t("discountsInactive");
}
