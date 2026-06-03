"use client";

import { useState } from "react";
import { Link2, Loader2, X } from "lucide-react";
import { OUTREACH_CATEGORY_LABELS, type OutreachCategory } from "@/types";
import { createManualTargetAction, resolveGoogleMapsUrlAction } from "../actions";

interface Props {
  onClose: () => void;
  onCreated: () => void;
}

const CATEGORIES: OutreachCategory[] = ["rorbu", "hotell", "restaurant", "camping", "overnatting", "gård", "other"];

export default function AddTargetModal({ onClose, onCreated }: Props) {
  const [mode, setMode] = useState<"url" | "manual">("url");
  const [url, setUrl] = useState("");
  const [resolving, setResolving] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resolved, setResolved] = useState(false);

  const [name, setName] = useState("");
  const [category, setCategory] = useState<OutreachCategory>("overnatting");
  const [area, setArea] = useState("lofoten");
  const [address, setAddress] = useState("");
  const [phone, setPhone] = useState("");
  const [website, setWebsite] = useState("");
  const [email, setEmail] = useState("");
  const [placeId, setPlaceId] = useState<string | null>(null);
  const [lat, setLat] = useState<number | null>(null);
  const [lng, setLng] = useState<number | null>(null);
  const [rating, setRating] = useState<number | null>(null);
  const [userRatingsTotal, setUserRatingsTotal] = useState<number | null>(null);

  async function handleResolve() {
    if (!url.trim()) return;
    setResolving(true);
    setError(null);
    const res = await resolveGoogleMapsUrlAction(url);
    setResolving(false);
    if (res.error) {
      setError(res.error);
      return;
    }
    if (res.name) setName(res.name);
    if (res.address) setAddress(res.address);
    if (res.phone) setPhone(res.phone);
    if (res.website) setWebsite(res.website);
    if (res.placeId) setPlaceId(res.placeId);
    if (res.lat != null) setLat(res.lat);
    if (res.lng != null) setLng(res.lng);
    if (res.rating != null) setRating(res.rating);
    if (res.userRatingsTotal != null) setUserRatingsTotal(res.userRatingsTotal);
    setResolved(true);
  }

  async function handleSave() {
    if (!name.trim()) {
      setError("Navn er påkrevd");
      return;
    }
    setSaving(true);
    setError(null);
    const res = await createManualTargetAction({
      name: name.trim(),
      category,
      area,
      address: address || undefined,
      phone: phone || undefined,
      website: website || undefined,
      email: email || undefined,
      placeId: placeId || undefined,
      lat: lat ?? undefined,
      lng: lng ?? undefined,
      rating: rating ?? undefined,
      userRatingsTotal: userRatingsTotal ?? undefined,
    });
    setSaving(false);
    if (res.error) {
      setError(res.error);
      return;
    }
    onCreated();
  }

  const inputCls = "w-full rounded-lg border border-neutral-300 px-3 py-2 text-sm focus:border-[#46C185] focus:ring-1 focus:ring-[#46C185] focus:outline-none";
  const labelCls = "block text-xs font-medium text-neutral-600 mb-1";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="relative mx-4 w-full max-w-lg rounded-xl bg-white p-6 shadow-xl">
        <button onClick={onClose} className="absolute right-4 top-4 text-neutral-400 hover:text-neutral-700">
          <X className="h-5 w-5" />
        </button>

        <h2 className="text-lg font-semibold text-neutral-900">Legg til aktør</h2>

        {/* Tabs */}
        <div className="mt-4 flex gap-1 rounded-lg bg-neutral-100 p-1">
          <button
            onClick={() => { setMode("url"); setError(null); }}
            className={`flex-1 rounded-md px-3 py-1.5 text-sm font-medium transition ${mode === "url" ? "bg-white text-neutral-900 shadow-sm" : "text-neutral-500"}`}
          >
            <Link2 className="mr-1.5 inline h-4 w-4" />
            Google Maps-lenke
          </button>
          <button
            onClick={() => { setMode("manual"); setError(null); }}
            className={`flex-1 rounded-md px-3 py-1.5 text-sm font-medium transition ${mode === "manual" ? "bg-white text-neutral-900 shadow-sm" : "text-neutral-500"}`}
          >
            Manuelt
          </button>
        </div>

        {/* URL input */}
        {mode === "url" && (
          <div className="mt-4">
            <label className={labelCls}>Lim inn Google Maps-lenke</label>
            <div className="flex gap-2">
              <input
                type="url"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                placeholder="https://www.google.com/maps/place/..."
                className={`${inputCls} flex-1`}
              />
              <button
                onClick={handleResolve}
                disabled={resolving || !url.trim()}
                className="rounded-lg bg-[#46C185] px-4 py-2 text-sm font-medium text-white transition hover:bg-[#3baa73] disabled:opacity-50"
              >
                {resolving ? <Loader2 className="h-4 w-4 animate-spin" /> : "Hent"}
              </button>
            </div>
            {resolved && <p className="mt-1 text-xs text-[#46C185]">Sted funnet. Rediger feltene under om nødvendig.</p>}
          </div>
        )}

        {/* Form fields */}
        <div className="mt-4 grid grid-cols-2 gap-3">
          <div className="col-span-2">
            <label className={labelCls}>Navn *</label>
            <input value={name} onChange={(e) => setName(e.target.value)} className={inputCls} />
          </div>
          <div>
            <label className={labelCls}>Kategori *</label>
            <select value={category} onChange={(e) => setCategory(e.target.value as OutreachCategory)} className={inputCls}>
              {CATEGORIES.map((c) => <option key={c} value={c}>{OUTREACH_CATEGORY_LABELS[c]}</option>)}
            </select>
          </div>
          <div>
            <label className={labelCls}>Område</label>
            <input value={area} onChange={(e) => setArea(e.target.value)} className={inputCls} />
          </div>
          <div className="col-span-2">
            <label className={labelCls}>Adresse</label>
            <input value={address} onChange={(e) => setAddress(e.target.value)} className={inputCls} />
          </div>
          <div>
            <label className={labelCls}>Telefon</label>
            <input value={phone} onChange={(e) => setPhone(e.target.value)} className={inputCls} />
          </div>
          <div>
            <label className={labelCls}>Nettside</label>
            <input value={website} onChange={(e) => setWebsite(e.target.value)} className={inputCls} />
          </div>
          <div className="col-span-2">
            <label className={labelCls}>E-post</label>
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} className={inputCls} />
          </div>
        </div>

        {error && <p className="mt-3 text-sm text-red-600">{error}</p>}

        <div className="mt-6 flex justify-end gap-3">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-600 hover:bg-neutral-100">
            Avbryt
          </button>
          <button
            onClick={handleSave}
            disabled={saving || !name.trim()}
            className="rounded-lg bg-[#46C185] px-5 py-2 text-sm font-medium text-white transition hover:bg-[#3baa73] disabled:opacity-50"
          >
            {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : "Lagre"}
          </button>
        </div>
      </div>
    </div>
  );
}
