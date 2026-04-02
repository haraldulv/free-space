"use client";

import { useState, useEffect } from "react";
import { DayPicker, DateRange } from "react-day-picker";
import "react-day-picker/src/style.css";

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
    <div className="rdp-custom rounded-lg border border-neutral-200 bg-white p-3">
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
      `}</style>
      <DayPicker
        mode="range"
        selected={selected}
        onSelect={onSelect}
        disabled={[{ before: new Date() }, ...(disabled || [])]}
        numberOfMonths={isMobile ? 1 : numberOfMonths}
        weekStartsOn={1}
      />
    </div>
  );
}
