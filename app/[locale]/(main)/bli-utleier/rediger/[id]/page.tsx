"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { Loader2, FileText, MapPin, Image as ImageIcon, Sparkles, CalendarDays } from "lucide-react";
import { useTranslations } from "next-intl";
import { createClient } from "@/lib/supabase/client";
import { updateListingAction, updateBlockedDatesAction } from "../../actions";
import BasicInfoStep from "@/components/features/listing-form/steps/BasicInfoStep";
import LocationStep from "@/components/features/listing-form/steps/LocationStep";
import ImageUploadStep from "@/components/features/listing-form/steps/ImageUploadStep";
import AmenitiesStep from "@/components/features/listing-form/steps/AmenitiesStep";
import ExtrasStep from "@/components/features/listing-form/steps/ExtrasStep";
import AvailabilityEditor from "@/components/features/listing-form/AvailabilityEditor";
import Button from "@/components/ui/Button";
import type { CreateListingData } from "@/lib/supabase/listings";
import type { Amenity, SpotMarker, ListingExtra } from "@/types";

const TAB_META = [
  { id: "info", labelKey: "tabInfo", icon: FileText },
  { id: "location", labelKey: "tabLocation", icon: MapPin },
  { id: "images", labelKey: "tabImages", icon: ImageIcon },
  { id: "amenities", labelKey: "tabAmenities", icon: Sparkles },
  { id: "extras", labelKey: "tabExtras", icon: Sparkles },
  { id: "availability", labelKey: "tabAvailability", icon: CalendarDays },
] as const;

type TabId = (typeof TAB_META)[number]["id"];

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
  const [tab, setTab] = useState<TabId>("info");

  const [formData, setFormData] = useState<Partial<CreateListingData>>({});
  const [blockedDates, setBlockedDates] = useState<string[]>([]);

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
        extras: row.extras || [],
        perSpotPricing: Array.isArray(row.spot_markers) && (row.spot_markers as SpotMarker[]).some((s) => s.price != null),
        perSpotCheckinMessage: Array.isArray(row.spot_markers) && (row.spot_markers as SpotMarker[]).some((s) => s.checkinMessage),
      });
      setBlockedDates(row.blocked_dates || []);
      setLoading(false);
    });
  }, [router, id]);

  const updateField = (field: string, value: unknown) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    setSaved(false);
  };

  const handleSave = async () => {
    if (saving) return;
    setSaving(true);
    setError("");
    setSaved(false);
    try {
      const result = await updateListingAction(id, formData as Partial<CreateListingData>);
      if (result.error) {
        setError(result.error);
        setSaving(false);
        return;
      }
      const datesResult = await updateBlockedDatesAction(id, blockedDates);
      if (datesResult.error) {
        setError(datesResult.error);
        setSaving(false);
        return;
      }
      setSaved(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : tHost("somethingWentWrong"));
    } finally {
      setSaving(false);
    }
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
    <div className="mx-auto max-w-4xl px-4 py-8">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-neutral-900">{t("title")}</h1>
        <div className="flex items-center gap-3">
          {saved && (
            <span className="text-sm text-green-600 font-medium">{t("saved")}</span>
          )}
          <Button variant="ghost" onClick={() => router.push("/dashboard?tab=annonser")}>
            {t("cancel")}
          </Button>
          <Button onClick={handleSave} disabled={saving}>
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
      </div>

      {error && (
        <div className="mb-6 rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 border-b border-neutral-200 mb-8 overflow-x-auto">
        {TAB_META.map((meta) => {
          const Icon = meta.icon;
          return (
            <button
              key={meta.id}
              onClick={() => setTab(meta.id)}
              className={`flex items-center gap-2 whitespace-nowrap px-4 py-2.5 text-sm font-medium transition-colors ${
                tab === meta.id
                  ? "border-b-2 border-primary-600 text-primary-600"
                  : "text-neutral-500 hover:text-neutral-700"
              }`}
            >
              <Icon className="h-4 w-4" />
              {t(meta.labelKey)}
            </button>
          );
        })}
      </div>

      {/* Tab content */}
      <div className="max-w-2xl">
        {tab === "info" && (
          <BasicInfoStep
            title={formData.title || ""}
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
        )}

        {tab === "location" && (
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
            onChange={updateField}
            errors={errors}
          />
        )}

        {tab === "images" && (
          <ImageUploadStep
            images={formData.images || []}
            userId={userId}
            onChange={(imgs) => updateField("images", imgs)}
            error={errors.images}
          />
        )}

        {tab === "amenities" && formData.category && (
          <AmenitiesStep
            category={formData.category}
            selected={(formData.amenities || []) as Amenity[]}
            onChange={(amenities) => updateField("amenities", amenities)}
          />
        )}

        {tab === "extras" && formData.category && (
          <ExtrasStep
            category={formData.category}
            extras={(formData.extras || []) as ListingExtra[]}
            onChange={(extras) => updateField("extras", extras)}
          />
        )}

        {tab === "availability" && (
          <AvailabilityEditor
            blockedDates={blockedDates}
            onChange={(dates) => {
              setBlockedDates(dates);
              setSaved(false);
            }}
            saving={saving}
          />
        )}
      </div>

      {/* Bottom save bar */}
      <div className="mt-10 flex items-center justify-end gap-3 border-t border-neutral-200 pt-6">
        {saved && (
          <span className="text-sm text-green-600 font-medium">{t("savedBottom")}</span>
        )}
        <Button onClick={handleSave} disabled={saving}>
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
    </div>
  );
}
