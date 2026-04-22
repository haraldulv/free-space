"use client";

import { useState } from "react";
import { ArrowLeft, ArrowRight, Loader2 } from "lucide-react";
import { useTranslations } from "next-intl";
import Button from "@/components/ui/Button";
import StepIndicator from "./StepIndicator";
import CategoryStep from "./steps/CategoryStep";
import BasicInfoStep from "./steps/BasicInfoStep";
import LocationStep from "./steps/LocationStep";
import ImageUploadStep from "./steps/ImageUploadStep";
import AmenitiesStep from "./steps/AmenitiesStep";
import ExtrasStep from "./steps/ExtrasStep";
import ReviewStep from "./steps/ReviewStep";
import AvailabilityEditor from "./AvailabilityEditor";
import { listingStepSchemas } from "@/lib/utils/validation";
import type { CreateListingData } from "@/lib/supabase/listings";
import type { Amenity, ListingCategory, ListingExtra, VehicleType } from "@/types";

interface ListingFormWizardProps {
  userId: string;
  mode?: "create" | "edit";
  listingId?: string;
  initialData?: Partial<CreateListingData>;
  onSubmit: (data: CreateListingData) => Promise<string | void>;
}

const TOTAL_STEPS = 8;

export default function ListingFormWizard({
  userId,
  mode = "create",
  listingId,
  initialData,
  onSubmit,
}: ListingFormWizardProps) {
  const t = useTranslations("host");
  const tCommon = useTranslations("common");
  const [step, setStep] = useState(0);
  const [submitting, setSubmitting] = useState(false);
  const [globalError, setGlobalError] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});

  const [formData, setFormData] = useState<Partial<CreateListingData>>({
    category: "camping",
    vehicleType: "motorhome",
    title: "",
    internalName: "",
    description: "",
    spots: 1,
    maxVehicleLength: undefined,
    address: "",
    city: "",
    region: "",
    lat: 0,
    lng: 0,
    images: [],
    amenities: [],
    price: 0,
    priceUnit: "time",
    instantBooking: false,
    spotMarkers: [],
    hideExactLocation: false,
    perSpotPricing: false,
    perSpotCheckinMessage: false,
    blockedDates: [],
    extras: [],
    ...initialData,
  });

  const updateField = (field: string, value: unknown) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    setErrors((prev) => {
      const next = { ...prev };
      delete next[field];
      return next;
    });
  };

  const validateStep = (): boolean => {
    const schema = listingStepSchemas[step];
    if (!schema) return true;

    const result = schema.safeParse(formData);
    if (result.success) {
      setErrors({});
      return true;
    }

    const newErrors: Record<string, string> = {};
    result.error.issues.forEach((issue) => {
      const field = issue.path[0] as string;
      if (!newErrors[field]) newErrors[field] = issue.message;
    });
    setErrors(newErrors);
    return false;
  };

  const next = () => {
    if (!validateStep()) return;
    setStep((s) => Math.min(s + 1, TOTAL_STEPS - 1));
  };

  const back = () => {
    setErrors({});
    setStep((s) => Math.max(s - 1, 0));
  };

  const submit = async () => {
    if (submitting) return;
    setSubmitting(true);
    setGlobalError("");
    try {
      await onSubmit(formData as CreateListingData);
      window.location.href = "/dashboard?tab=annonser";
    } catch (err) {
      setGlobalError(err instanceof Error ? err.message : t("somethingWentWrong"));
      setSubmitting(false);
    }
  };

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <StepIndicator currentStep={step} />

      <div className="mt-8">
        {globalError && (
          <div className="mb-6 rounded-lg bg-red-50 p-3 text-sm text-red-700">{globalError}</div>
        )}

        {step === 0 && (
          <CategoryStep
            value={formData.category}
            vehicleType={formData.vehicleType as VehicleType | undefined}
            onChange={(cat) => {
              updateField("category", cat);
              updateField("priceUnit", cat === "parking" ? "time" : "natt");
              updateField("amenities", []);
            }}
            onVehicleChange={(vt) => updateField("vehicleType", vt)}
            error={errors.category}
            vehicleError={errors.vehicleType}
          />
        )}

        {step === 1 && (
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
        )}

        {step === 2 && (
          <LocationStep
            address={formData.address || ""}
            city={formData.city || ""}
            region={formData.region || ""}
            lat={formData.lat || 0}
            lng={formData.lng || 0}
            spotMarkers={formData.spotMarkers || []}
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
        )}

        {step === 3 && (
          <ImageUploadStep
            images={formData.images || []}
            userId={userId}
            onChange={(imgs) => updateField("images", imgs)}
            error={errors.images}
          />
        )}

        {step === 4 && formData.category && (
          <AmenitiesStep
            category={formData.category}
            selected={(formData.amenities || []) as Amenity[]}
            onChange={(amenities) => updateField("amenities", amenities)}
          />
        )}

        {step === 5 && formData.category && (
          <ExtrasStep
            category={formData.category}
            extras={(formData.extras || []) as ListingExtra[]}
            onChange={(extras) => updateField("extras", extras)}
          />
        )}

        {step === 6 && (
          <AvailabilityEditor
            blockedDates={(formData.blockedDates || []) as string[]}
            onChange={(dates) => updateField("blockedDates", dates)}
          />
        )}

        {step === 7 && <ReviewStep data={formData} />}
      </div>

      {/* Navigation */}
      <div className="mt-8 flex items-center justify-between">
        {step > 0 ? (
          <Button variant="ghost" onClick={back}>
            <ArrowLeft className="mr-1.5 h-4 w-4" />
            {tCommon("back")}
          </Button>
        ) : (
          <div />
        )}

        {step < TOTAL_STEPS - 1 ? (
          <Button onClick={next}>
            {tCommon("next")}
            <ArrowRight className="ml-1.5 h-4 w-4" />
          </Button>
        ) : (
          <Button onClick={submit} disabled={submitting}>
            {submitting ? (
              <>
                <Loader2 className="mr-1.5 h-4 w-4 animate-spin" />
                {t("publishing")}
              </>
            ) : mode === "edit" ? (
              t("saveChanges")
            ) : (
              t("publishListing")
            )}
          </Button>
        )}
      </div>
    </div>
  );
}
