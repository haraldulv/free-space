"use client";

import { DayPicker, type DayPickerProps } from "react-day-picker";
import "react-day-picker/src/style.css";

/**
 * Felles kalender-komponent for hele Tuno-web. Innkapsler stiler og
 * defaults så alle kalendrene (booking, wizard, rediger, dashboard) deler
 * samme aksentfarge (#46c185), avrundete dager, og uke-start på mandag.
 *
 * Konsumenter kan fortsatt sette `mode`, `selected`, `modifiers` osv. via
 * props. Kun det visuelle og accessibility-grunnlaget er felles.
 */
export default function TunoCalendar(props: DayPickerProps) {
  const { className, ...rest } = props;
  return (
    <div className={`tuno-calendar ${className ?? ""}`}>
      <style>{`
        .tuno-calendar .rdp-root {
          --rdp-accent-color: #46c185;
          --rdp-accent-background-color: #d6f0e3;
          --rdp-day-height: 40px;
          --rdp-day-width: 40px;
          --rdp-day_button-height: 38px;
          --rdp-day_button-width: 38px;
          --rdp-day_button-border-radius: 8px;
          font-size: 0.875rem;
        }
        .tuno-calendar .rdp-today:not(.rdp-selected) {
          font-weight: 700;
          color: var(--rdp-accent-color);
        }
        .tuno-calendar .rdp-blocked {
          background-color: #fee2e2 !important;
          color: #dc2626 !important;
          border-radius: 8px;
        }
        .tuno-calendar .rdp-blocked .rdp-day_button {
          color: #dc2626;
          font-weight: 600;
        }
        .tuno-calendar .rdp-booked {
          background-color: #fef3c7 !important;
          color: #92400e !important;
          border-radius: 8px;
          cursor: not-allowed;
        }
      `}</style>
      <DayPicker weekStartsOn={1} {...rest} />
    </div>
  );
}
