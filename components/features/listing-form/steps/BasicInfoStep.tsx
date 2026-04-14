"use client";

import Input from "@/components/ui/Input";
import Textarea from "@/components/ui/Textarea";
import Toggle from "@/components/ui/Toggle";
import type { ListingCategory } from "@/types";

interface BasicInfoStepProps {
  title: string;
  description: string;
  spots: number;
  maxVehicleLength?: number;
  category?: ListingCategory;
  checkInTime?: string;
  checkOutTime?: string;
  instantBooking: boolean;
  onChange: (field: string, value: string | number | boolean | undefined) => void;
  errors: Record<string, string>;
}

export default function BasicInfoStep({
  title,
  description,
  spots,
  maxVehicleLength,
  category,
  checkInTime,
  checkOutTime,
  instantBooking,
  onChange,
  errors,
}: BasicInfoStepProps) {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">Fortell om plassen din</h2>
        <p className="mt-1 text-sm text-neutral-500">Gi en god beskrivelse slik at gjester vet hva de kan forvente</p>
      </div>

      <Input
        id="title"
        label="Tittel"
        placeholder="F.eks. Sentral parkering ved Oslo S"
        value={title}
        onChange={(e) => onChange("title", e.target.value)}
        error={errors.title}
      />

      <Textarea
        id="description"
        label="Beskrivelse"
        placeholder="Beskriv plassen, tilgang, og hva som gjør den spesiell..."
        rows={4}
        value={description}
        onChange={(e) => onChange("description", e.target.value)}
        error={errors.description}
      />

      <div className="grid gap-4 sm:grid-cols-2">
        <Input
          id="spots"
          label="Antall plasser"
          type="number"
          min={1}
          max={100}
          value={spots || ""}
          onChange={(e) => onChange("spots", parseInt(e.target.value) || 0)}
          error={errors.spots}
        />

        {category === "camping" && (
          <Input
            id="maxVehicleLength"
            label="Maks kjøretøylengde (meter)"
            type="number"
            min={1}
            max={30}
            placeholder="F.eks. 10"
            value={maxVehicleLength || ""}
            onChange={(e) => {
              const val = e.target.value ? parseInt(e.target.value) : undefined;
              onChange("maxVehicleLength", val);
            }}
            error={errors.maxVehicleLength}
          />
        )}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Input
          id="checkInTime"
          label="Innsjekk fra"
          type="time"
          value={checkInTime || "15:00"}
          onChange={(e) => onChange("checkInTime", e.target.value)}
          error={errors.checkInTime}
        />
        <Input
          id="checkOutTime"
          label="Utsjekk innen"
          type="time"
          value={checkOutTime || "11:00"}
          onChange={(e) => onChange("checkOutTime", e.target.value)}
          error={errors.checkOutTime}
        />
      </div>

      <div className="rounded-xl border border-neutral-200 p-4">
        <Toggle
          checked={instantBooking}
          onChange={(v) => onChange("instantBooking", v)}
          label="Umiddelbar booking"
          description="Gjester kan reservere uten å vente på bekreftelse fra deg."
        />
      </div>
    </div>
  );
}
