"use client";

import { useMemo, useState, useTransition, useRef } from "react";
import { X, Check, Loader2 } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { bcpLocale } from "@/lib/i18n-helpers";
import Button from "@/components/ui/Button";
import {
  bulkSetOverridesAction,
  bulkClearOverridesAction,
  bulkBlockDatesAction,
  bulkUnblockDatesAction,
} from "@/app/[locale]/(main)/dashboard/kalender/actions";

export type PriceSource = "base" | "weekend" | "season" | "override";

export type CalendarCell =
  | { kind: "available"; price: number; source: PriceSource }
  | { kind: "booked"; requested?: boolean; guestName?: string }
  | { kind: "blocked" };

export interface CalendarListing {
  id: string;
  title: string;
  thumbnail?: string;
  basePrice: number;
}

interface Props {
  listings: CalendarListing[];
  dates: string[];
  cells: Record<string, CalendarCell>;
}

type SelectionKey = string; // `${listingId}:${date}`

export function HostCalendarGrid({ listings, dates, cells: initialCells }: Props) {
  const t = useTranslations("hostCalendar");
  const locale = useLocale();
  const dfLocale = bcpLocale(locale);
  const [pending, startTransition] = useTransition();
  const [cells, setCells] = useState(initialCells);
  const [selection, setSelection] = useState<Set<SelectionKey>>(new Set());
  const [dragAnchor, setDragAnchor] = useState<{ listingId: string; date: string } | null>(null);
  const [dragging, setDragging] = useState(false);
  const [showPriceModal, setShowPriceModal] = useState(false);
  const [priceInput, setPriceInput] = useState<string>("");
  const [error, setError] = useState<string | null>(null);
  const gridRef = useRef<HTMLDivElement>(null);

  const listingIndex = useMemo(() => {
    const map = new Map<string, number>();
    listings.forEach((l, i) => map.set(l.id, i));
    return map;
  }, [listings]);

  const dateIndex = useMemo(() => {
    const map = new Map<string, number>();
    dates.forEach((d, i) => map.set(d, i));
    return map;
  }, [dates]);

  const expandSelection = (anchor: { listingId: string; date: string }, head: { listingId: string; date: string }) => {
    const anchorL = listingIndex.get(anchor.listingId) ?? 0;
    const headL = listingIndex.get(head.listingId) ?? 0;
    const anchorD = dateIndex.get(anchor.date) ?? 0;
    const headD = dateIndex.get(head.date) ?? 0;
    const lMin = Math.min(anchorL, headL);
    const lMax = Math.max(anchorL, headL);
    const dMin = Math.min(anchorD, headD);
    const dMax = Math.max(anchorD, headD);

    const next = new Set<SelectionKey>();
    for (let li = lMin; li <= lMax; li++) {
      for (let di = dMin; di <= dMax; di++) {
        const key = `${listings[li].id}:${dates[di]}`;
        // Hopp over celler som ikke kan velges (booket)
        const cell = cells[key];
        if (cell?.kind === "booked") continue;
        next.add(key);
      }
    }
    return next;
  };

  const handleCellMouseDown = (e: React.MouseEvent, listingId: string, date: string) => {
    e.preventDefault();
    const cell = cells[`${listingId}:${date}`];
    if (cell?.kind === "booked") return;

    if (e.shiftKey && dragAnchor) {
      setSelection(expandSelection(dragAnchor, { listingId, date }));
      return;
    }
    if (e.metaKey || e.ctrlKey) {
      const key = `${listingId}:${date}`;
      const next = new Set(selection);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      setSelection(next);
      setDragAnchor({ listingId, date });
      return;
    }
    setDragAnchor({ listingId, date });
    setDragging(true);
    setSelection(new Set([`${listingId}:${date}`]));
  };

  const handleCellMouseEnter = (listingId: string, date: string) => {
    if (!dragging || !dragAnchor) return;
    setSelection(expandSelection(dragAnchor, { listingId, date }));
  };

  const handleMouseUp = () => setDragging(false);

  const clearSelection = () => {
    setSelection(new Set());
    setDragAnchor(null);
  };

  const selectionItems = useMemo(
    () => Array.from(selection).map((k) => {
      const [listingId, date] = k.split(":");
      return { listingId, date };
    }),
    [selection],
  );

  const anyBlocked = selectionItems.some((i) => cells[`${i.listingId}:${i.date}`]?.kind === "blocked");
  const anyAvailable = selectionItems.some((i) => cells[`${i.listingId}:${i.date}`]?.kind === "available");

  const applyOptimistic = (items: SelectionKey[], update: (key: SelectionKey) => CalendarCell) => {
    const next = { ...cells };
    for (const key of items) next[key] = update(key);
    setCells(next);
  };

  const handleBlock = () => {
    setError(null);
    const items = selectionItems.filter((i) => cells[`${i.listingId}:${i.date}`]?.kind === "available");
    if (items.length === 0) return;
    const keys = items.map((i) => `${i.listingId}:${i.date}`);
    applyOptimistic(keys, () => ({ kind: "blocked" }));
    startTransition(async () => {
      const res = await bulkBlockDatesAction(items);
      if (res.error) {
        setError(res.error);
        setCells(initialCells);  // rollback
      } else {
        clearSelection();
      }
    });
  };

  const handleUnblock = () => {
    setError(null);
    const items = selectionItems.filter((i) => cells[`${i.listingId}:${i.date}`]?.kind === "blocked");
    if (items.length === 0) return;
    const keys = items.map((i) => `${i.listingId}:${i.date}`);
    applyOptimistic(keys, (key) => {
      const [listingId] = key.split(":");
      const listing = listings.find((l) => l.id === listingId);
      return { kind: "available", price: listing?.basePrice ?? 0, source: "base" };
    });
    startTransition(async () => {
      const res = await bulkUnblockDatesAction(items);
      if (res.error) {
        setError(res.error);
        setCells(initialCells);
      } else {
        clearSelection();
      }
    });
  };

  const handleSetPrice = () => {
    setError(null);
    const price = Number(priceInput);
    if (!price || price <= 0) {
      setError(t("invalidPrice"));
      return;
    }
    const items = selectionItems.filter((i) => cells[`${i.listingId}:${i.date}`]?.kind === "available");
    if (items.length === 0) return;
    const keys = items.map((i) => `${i.listingId}:${i.date}`);
    applyOptimistic(keys, () => ({ kind: "available", price, source: "override" }));
    startTransition(async () => {
      const res = await bulkSetOverridesAction(items.map((i) => ({ ...i, price })));
      if (res.error) {
        setError(res.error);
        setCells(initialCells);
      } else {
        setShowPriceModal(false);
        setPriceInput("");
        clearSelection();
      }
    });
  };

  const handleClearPrice = () => {
    setError(null);
    const items = selectionItems.filter((i) => {
      const c = cells[`${i.listingId}:${i.date}`];
      return c?.kind === "available" && c.source === "override";
    });
    if (items.length === 0) return;
    const keys = items.map((i) => `${i.listingId}:${i.date}`);
    applyOptimistic(keys, (key) => {
      const [listingId] = key.split(":");
      const listing = listings.find((l) => l.id === listingId);
      return { kind: "available", price: listing?.basePrice ?? 0, source: "base" };
    });
    startTransition(async () => {
      const res = await bulkClearOverridesAction(items);
      if (res.error) {
        setError(res.error);
        setCells(initialCells);
      } else {
        clearSelection();
      }
    });
  };

  const monthLabels = useMemo(() => {
    const result: { label: string; colStart: number; colEnd: number }[] = [];
    let current: { month: number; year: number; colStart: number } | null = null;
    dates.forEach((d, i) => {
      const dt = new Date(d + "T00:00:00");
      const month = dt.getMonth();
      const year = dt.getFullYear();
      if (!current || current.month !== month || current.year !== year) {
        if (current) {
          const label = new Date(current.year, current.month, 1).toLocaleDateString(dfLocale, { month: "long", year: "numeric" });
          result.push({ label, colStart: current.colStart, colEnd: i - 1 });
        }
        current = { month, year, colStart: i };
      }
    });
    if (current !== null) {
      const c = current as { month: number; year: number; colStart: number };
      const label = new Date(c.year, c.month, 1).toLocaleDateString(dfLocale, { month: "long", year: "numeric" });
      result.push({ label, colStart: c.colStart, colEnd: dates.length - 1 });
    }
    return result;
  }, [dates, dfLocale]);

  return (
    <div onMouseUp={handleMouseUp} onMouseLeave={handleMouseUp}>
      {/* Legende */}
      <div className="mb-3 flex flex-wrap items-center gap-4 text-xs text-neutral-500">
        <div className="flex items-center gap-1.5">
          <span className="h-3 w-3 rounded border border-neutral-300 bg-white" />
          {t("legendAvailable")}
        </div>
        <div className="flex items-center gap-1.5">
          <span className="h-3 w-3 rounded bg-primary-100 border border-primary-300" />
          {t("legendOverride")}
        </div>
        <div className="flex items-center gap-1.5">
          <span className="h-3 w-3 rounded bg-amber-100 border border-amber-300" />
          {t("legendRule")}
        </div>
        <div className="flex items-center gap-1.5">
          <span className="h-3 w-3 rounded bg-green-600" />
          {t("legendBooked")}
        </div>
        <div className="flex items-center gap-1.5">
          <span className="h-3 w-3 rounded bg-neutral-300" style={{ backgroundImage: "repeating-linear-gradient(45deg, #a3a3a3 0, #a3a3a3 2px, #d4d4d4 2px, #d4d4d4 4px)" }} />
          {t("legendBlocked")}
        </div>
      </div>

      {/* Grid */}
      <div
        ref={gridRef}
        className="overflow-auto rounded-lg border border-neutral-200 bg-white"
        style={{ maxHeight: "calc(100vh - 280px)" }}
      >
        <div
          className="inline-grid"
          style={{
            gridTemplateColumns: `200px repeat(${dates.length}, 44px)`,
          }}
        >
          {/* Måned-header */}
          <div className="sticky top-0 left-0 z-20 bg-white border-b border-r border-neutral-200 h-8" />
          {monthLabels.map((m, i) => (
            <div
              key={i}
              className="sticky top-0 z-10 bg-white border-b border-neutral-200 px-2 text-xs font-semibold capitalize text-neutral-700 flex items-center h-8"
              style={{ gridColumn: `${m.colStart + 2} / ${m.colEnd + 3}` }}
            >
              {m.label}
            </div>
          ))}

          {/* Dato-header */}
          <div className="sticky top-8 left-0 z-20 bg-white border-b border-r border-neutral-200 h-10" />
          {dates.map((d) => {
            const dt = new Date(d + "T00:00:00");
            const weekday = dt.toLocaleDateString(dfLocale, { weekday: "narrow" });
            const isWeekend = dt.getDay() === 0 || dt.getDay() === 6 || dt.getDay() === 5;
            return (
              <div
                key={d}
                className={`sticky top-8 z-10 border-b border-neutral-200 px-1 py-1 text-center text-[10px] leading-tight ${
                  isWeekend ? "bg-neutral-50 text-neutral-600" : "bg-white text-neutral-500"
                }`}
              >
                <div className="font-semibold">{dt.getDate()}</div>
                <div className="uppercase">{weekday}</div>
              </div>
            );
          })}

          {/* Rader per listing */}
          {listings.map((listing) => (
            <RowForListing
              key={listing.id}
              listing={listing}
              dates={dates}
              cells={cells}
              selection={selection}
              onCellMouseDown={handleCellMouseDown}
              onCellMouseEnter={handleCellMouseEnter}
            />
          ))}
        </div>
      </div>

      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}

      {/* Bulk-action bar */}
      {selection.size > 0 && (
        <div className="fixed inset-x-0 bottom-0 z-40 border-t border-neutral-200 bg-white shadow-lg">
          <div className="mx-auto flex max-w-screen-xl flex-wrap items-center gap-3 px-4 py-3 sm:px-6">
            <span className="text-sm font-medium text-neutral-900">
              {t("selected", { count: selection.size })}
            </span>
            {anyAvailable && (
              <>
                <Button size="sm" onClick={() => setShowPriceModal(true)} disabled={pending}>
                  {t("setPrice")}
                </Button>
                <Button size="sm" variant="outline" onClick={handleBlock} disabled={pending}>
                  {t("block")}
                </Button>
                <button
                  type="button"
                  onClick={handleClearPrice}
                  disabled={pending}
                  className="text-sm text-neutral-600 hover:text-neutral-900 disabled:opacity-50"
                >
                  {t("clearOverride")}
                </button>
              </>
            )}
            {anyBlocked && (
              <Button size="sm" variant="outline" onClick={handleUnblock} disabled={pending}>
                {t("unblock")}
              </Button>
            )}
            {pending && <Loader2 className="h-4 w-4 animate-spin text-neutral-500" />}
            <div className="ml-auto">
              <button
                type="button"
                onClick={clearSelection}
                className="flex items-center gap-1 text-sm text-neutral-500 hover:text-neutral-900"
              >
                <X className="h-4 w-4" />
                {t("cancel")}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Pris-modal */}
      {showPriceModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-sm rounded-xl bg-white p-5 shadow-xl">
            <h3 className="text-lg font-semibold text-neutral-900">{t("setPriceTitle")}</h3>
            <p className="mt-1 text-sm text-neutral-500">
              {t("setPriceDescription", { count: selectionItems.filter((i) => cells[`${i.listingId}:${i.date}`]?.kind === "available").length })}
            </p>
            <input
              type="number"
              value={priceInput}
              onChange={(e) => setPriceInput(e.target.value)}
              placeholder={t("pricePlaceholder")}
              autoFocus
              className="mt-4 w-full rounded-lg border border-neutral-300 px-3 py-2 text-sm"
            />
            <div className="mt-4 flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => { setShowPriceModal(false); setPriceInput(""); }}
                className="rounded-lg px-3 py-2 text-sm text-neutral-600 hover:text-neutral-900"
                disabled={pending}
              >
                {t("cancel")}
              </button>
              <Button size="sm" onClick={handleSetPrice} disabled={pending}>
                {pending ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Check className="h-3.5 w-3.5 mr-1" />}
                {t("apply")}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

interface RowProps {
  listing: CalendarListing;
  dates: string[];
  cells: Record<string, CalendarCell>;
  selection: Set<SelectionKey>;
  onCellMouseDown: (e: React.MouseEvent, listingId: string, date: string) => void;
  onCellMouseEnter: (listingId: string, date: string) => void;
}

function RowForListing({ listing, dates, cells, selection, onCellMouseDown, onCellMouseEnter }: RowProps) {
  return (
    <>
      <div className="sticky left-0 z-10 border-b border-r border-neutral-200 bg-white px-3 py-2 flex items-center gap-2">
        {listing.thumbnail && (
          <div
            className="h-8 w-8 shrink-0 rounded bg-cover bg-center"
            style={{ backgroundImage: `url(${listing.thumbnail})` }}
          />
        )}
        <div className="min-w-0">
          <div className="truncate text-sm font-medium text-neutral-900">{listing.title}</div>
          <div className="text-[11px] text-neutral-500">{listing.basePrice} kr</div>
        </div>
      </div>
      {dates.map((d) => {
        const key = `${listing.id}:${d}`;
        const cell = cells[key];
        const isSelected = selection.has(key);
        return (
          <CellView
            key={key}
            cell={cell}
            isSelected={isSelected}
            onMouseDown={(e) => onCellMouseDown(e, listing.id, d)}
            onMouseEnter={() => onCellMouseEnter(listing.id, d)}
          />
        );
      })}
    </>
  );
}

function CellView({
  cell,
  isSelected,
  onMouseDown,
  onMouseEnter,
}: {
  cell: CalendarCell | undefined;
  isSelected: boolean;
  onMouseDown: (e: React.MouseEvent) => void;
  onMouseEnter: () => void;
}) {
  if (!cell) return <div className="border-b border-r border-neutral-100 bg-neutral-50" />;

  const baseClass = "border-b border-r border-neutral-100 text-center text-[10px] leading-tight cursor-pointer select-none flex flex-col items-center justify-center h-11 relative";
  const selectedRing = isSelected ? "ring-2 ring-inset ring-primary-600" : "";

  if (cell.kind === "booked") {
    return (
      <div
        className={`${baseClass} bg-green-600 text-white cursor-not-allowed`}
        title={cell.guestName || ""}
      >
        <span className="text-[9px] font-semibold uppercase tracking-wider opacity-90">
          {cell.requested ? "?" : "●"}
        </span>
      </div>
    );
  }

  if (cell.kind === "blocked") {
    return (
      <div
        className={`${baseClass} bg-neutral-100 ${selectedRing}`}
        style={{ backgroundImage: "repeating-linear-gradient(45deg, #a3a3a3 0, #a3a3a3 2px, #e5e5e5 2px, #e5e5e5 6px)" }}
        onMouseDown={onMouseDown}
        onMouseEnter={onMouseEnter}
      />
    );
  }

  // available
  let bgClass = "bg-white";
  if (cell.source === "override") bgClass = "bg-primary-50";
  else if (cell.source === "weekend" || cell.source === "season") bgClass = "bg-amber-50";

  return (
    <div
      className={`${baseClass} ${bgClass} ${selectedRing} text-neutral-700`}
      onMouseDown={onMouseDown}
      onMouseEnter={onMouseEnter}
    >
      <span className="font-medium">{cell.price}</span>
    </div>
  );
}
