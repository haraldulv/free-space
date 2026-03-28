"use client";

import Image from "next/image";
import { Zap, MapPin, Bus, Caravan, Car, CalendarX2, Clock } from "lucide-react";
import { amenityConfig } from "@/components/features/AmenityList";
import type { Amenity, ListingCategory, VehicleType } from "@/types";
import { vehicleLabels } from "@/types";
import Badge from "@/components/ui/Badge";

const vehicleIcons: Record<VehicleType, React.ElementType> = {
  motorhome: Bus,
  campervan: Caravan,
  car: Car,
};

interface ReviewStepProps {
  data: {
    category?: ListingCategory;
    vehicleType?: VehicleType;
    title?: string;
    description?: string;
    spots?: number;
    maxVehicleLength?: number;
    address?: string;
    city?: string;
    region?: string;
    images?: string[];
    amenities?: Amenity[];
    price?: number;
    priceUnit?: "time" | "natt";
    instantBooking?: boolean;
    blockedDates?: string[];
    checkInTime?: string;
    checkOutTime?: string;
  };
}

export default function ReviewStep({ data }: ReviewStepProps) {
  const unit = data.priceUnit === "time" ? "time" : "natt";
  const VIcon = data.vehicleType ? vehicleIcons[data.vehicleType] : Bus;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">Se over annonsen din</h2>
        <p className="mt-1 text-sm text-neutral-500">Kontroller at alt ser riktig ut før du publiserer</p>
      </div>

      <div className="space-y-5 rounded-xl border border-neutral-200 p-5">
        {/* Header */}
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="flex items-center gap-2 mb-1 flex-wrap">
              <Badge variant="secondary">
                {data.category === "parking" ? "Parkering" : "Camping / Bobil"}
              </Badge>
              {data.vehicleType && (
                <Badge variant="secondary">
                  <VIcon className="mr-1 h-3 w-3" />
                  {vehicleLabels[data.vehicleType]}
                </Badge>
              )}
              {data.instantBooking && (
                <Badge variant="primary">
                  <Zap className="mr-1 h-3 w-3" />
                  Direktebooking
                </Badge>
              )}
            </div>
            <h3 className="text-lg font-bold text-neutral-900">{data.title}</h3>
          </div>
          <div className="text-right shrink-0">
            <p className="text-lg font-bold text-neutral-900">{data.price} kr</p>
            <p className="text-xs text-neutral-500">per {unit}</p>
          </div>
        </div>

        {/* Images */}
        {data.images && data.images.length > 0 && (
          <div className="flex gap-2 overflow-x-auto">
            {data.images.map((url, i) => (
              <div key={url} className="relative h-24 w-32 shrink-0 overflow-hidden rounded-lg">
                <Image src={url} alt={`Bilde ${i + 1}`} fill className="object-cover" sizes="128px" />
              </div>
            ))}
          </div>
        )}

        {/* Description */}
        <p className="text-sm text-neutral-600 whitespace-pre-line">{data.description}</p>

        {/* Location */}
        <div className="flex items-center gap-1.5 text-sm text-neutral-500">
          <MapPin className="h-4 w-4" />
          {data.address}, {data.city}, {data.region}
        </div>

        {/* Details */}
        <div className="flex flex-wrap gap-4 text-sm text-neutral-600">
          <span>{data.spots} {data.spots === 1 ? "plass" : "plasser"}</span>
          {data.maxVehicleLength && <span>Maks {data.maxVehicleLength}m</span>}
          <span className="flex items-center gap-1">
            <Clock className="h-3.5 w-3.5 text-neutral-400" />
            Inn {data.checkInTime || "15:00"} / Ut {data.checkOutTime || "11:00"}
          </span>
        </div>

        {/* Amenities */}
        {data.amenities && data.amenities.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {data.amenities.map((amenity) => {
              const config = amenityConfig[amenity];
              const Icon = config.icon;
              return (
                <span
                  key={amenity}
                  className="flex items-center gap-1.5 rounded-full border border-neutral-200 bg-neutral-50 px-2.5 py-1 text-xs text-neutral-600"
                >
                  <Icon className="h-3 w-3 text-primary-600" />
                  {config.label}
                </span>
              );
            })}
          </div>
        )}

        {/* Blocked dates */}
        {data.blockedDates && data.blockedDates.length > 0 && (
          <div className="flex items-center gap-2 text-sm text-neutral-500">
            <CalendarX2 className="h-4 w-4 text-red-400" />
            {data.blockedDates.length} {data.blockedDates.length === 1 ? "dato" : "datoer"} blokkert
          </div>
        )}
      </div>
    </div>
  );
}
