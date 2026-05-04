"use client";

import { useState, useEffect } from "react";
import type { DateRange } from "react-day-picker";
import TunoCalendar from "./TunoCalendar";

interface DatePickerProps {
  selected?: DateRange;
  onSelect: (range: DateRange | undefined) => void;
  disabled?: Date[];
  numberOfMonths?: number;
}

export default function DatePicker({
  selected,
  onSelect,
  disabled,
  numberOfMonths = 2,
}: DatePickerProps) {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < 768);
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3">
      <TunoCalendar
        mode="range"
        selected={selected}
        onSelect={onSelect}
        disabled={[{ before: new Date() }, ...(disabled || [])]}
        numberOfMonths={isMobile ? 1 : numberOfMonths}
      />
    </div>
  );
}
