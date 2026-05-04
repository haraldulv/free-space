"use client";

import { useEffect, useRef } from "react";
import { createPortal } from "react-dom";
import { X } from "lucide-react";

interface SheetProps {
  open: boolean;
  onClose: () => void;
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  /** Footer-bar med handlinger (typisk Lagre-knapp). */
  footer?: React.ReactNode;
}

/**
 * Slide-in sheet fra høyre på desktop, full-screen på mobile. Lukkes ved klikk
 * på backdrop, ESC, eller X-knappen. Renderes i portal til body for å unngå
 * stacking-context-trøbbel med backdrop-filter på navbar.
 */
export default function Sheet({ open, onClose, title, subtitle, children, footer }: SheetProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!open) return;
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    document.addEventListener("keydown", handleKey);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleKey);
      document.body.style.overflow = "";
    };
  }, [open, onClose]);

  if (typeof window === "undefined") return null;
  if (!open) return null;

  return createPortal(
    <div className="fixed inset-0 z-[100] flex">
      <div
        className="absolute inset-0 bg-neutral-900/40 transition-opacity animate-fade-in"
        onClick={onClose}
        aria-hidden
      />
      <div
        ref={containerRef}
        className="relative ml-auto flex h-full w-full flex-col bg-white shadow-2xl sm:max-w-2xl animate-slide-in-right"
        role="dialog"
        aria-modal="true"
        aria-label={title}
      >
        <header className="flex items-start justify-between gap-4 border-b border-neutral-200 px-5 py-4">
          <div className="min-w-0">
            <h2 className="text-lg font-semibold text-neutral-900">{title}</h2>
            {subtitle && (
              <p className="mt-0.5 text-sm text-neutral-500">{subtitle}</p>
            )}
          </div>
          <button
            onClick={onClose}
            aria-label="Lukk"
            className="-mr-2 -mt-1 flex h-9 w-9 flex-none items-center justify-center rounded-full text-neutral-500 hover:bg-neutral-100 hover:text-neutral-900"
          >
            <X className="h-5 w-5" />
          </button>
        </header>

        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-5">{children}</div>

        {footer && (
          <footer className="border-t border-neutral-200 bg-white px-5 py-3">
            {footer}
          </footer>
        )}
      </div>
    </div>,
    document.body,
  );
}
