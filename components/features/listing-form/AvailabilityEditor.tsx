"use client";

import { useState } from "react";
import { DayPicker } from "react-day-picker";
import "react-day-picker/src/style.css";
import { CalendarX2, Check } from "lucide-react";
import Button from "@/components/ui/Button";

interface AvailabilityEditorProps {
  blockedDates: string[];
  onChange: (dates: string[]) => void;
  saving?: boolean;
}

export default function AvailabilityEditor({ blockedDates, onChange, saving }: AvailabilityEditorProps) {
  const blocked = new Set(blockedDates);

  const blockedDateObjects = blockedDates.map((d) => new Date(d + "T00:00:00"));

  const handleDayClick = (day: Date) => {
    const key = `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, "0")}-${String(day.getDate()).padStart(2, "0")}`;
    const next = new Set(blocked);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    onChange(Array.from(next).sort());
  };

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-neutral-900">Tilgjengelighet</h3>
        <p className="mt-1 text-sm text-neutral-500">
          Klikk på datoer for å blokkere eller åpne dem. Blokkerte datoer vises i rødt.
        </p>
      </div>

      <div className="rdp-custom inline-block rounded-lg border border-neutral-200 p-3">
        <style>{`
          .rdp-custom .rdp-root {
            --rdp-accent-color: #1a3268;
            --rdp-accent-background-color: #d9e2f5;
            --rdp-day-height: 40px;
            --rdp-day-width: 40px;
            --rdp-day_button-height: 38px;
            --rdp-day_button-width: 38px;
            --rdp-day_button-border-radius: 8px;
            font-size: 0.875rem;
          }
          .rdp-custom .rdp-today:not(.rdp-selected) {
            font-weight: 700;
            color: var(--rdp-accent-color);
          }
          .rdp-custom .rdp-blocked {
            background-color: #fee2e2 !important;
            color: #dc2626 !important;
            border-radius: 8px;
          }
          .rdp-custom .rdp-blocked .rdp-day_button {
            color: #dc2626;
            font-weight: 600;
          }
        `}</style>
        <DayPicker
          onDayClick={handleDayClick}
          disabled={{ before: new Date() }}
          numberOfMonths={2}
          weekStartsOn={1}
          modifiers={{ blocked: blockedDateObjects }}
          modifiersClassNames={{ blocked: "rdp-blocked" }}
        />
      </div>

      {blocked.size > 0 && (
        <div className="flex items-start gap-2 rounded-lg bg-red-50 p-3">
          <CalendarX2 className="h-4 w-4 text-red-500 mt-0.5 shrink-0" />
          <p className="text-sm text-red-700">
            {blocked.size} {blocked.size === 1 ? "dato" : "datoer"} blokkert
          </p>
        </div>
      )}
    </div>
  );
}
