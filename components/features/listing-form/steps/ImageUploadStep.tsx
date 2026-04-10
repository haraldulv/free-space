"use client";

import { useCallback, useRef, useState } from "react";
import { Upload, X, GripVertical } from "lucide-react";
import Image from "next/image";
import { uploadListingImage, deleteListingImage } from "@/lib/supabase/storage";

async function moderateImage(imageUrl: string): Promise<{ approved: boolean; reason?: string }> {
  const res = await fetch("/api/moderate-image", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ imageUrl }),
  });
  return res.json();
}

interface ImageUploadStepProps {
  images: string[];
  userId: string;
  onChange: (images: string[]) => void;
  error?: string;
}

export default function ImageUploadStep({ images, userId, onChange, error }: ImageUploadStepProps) {
  const [uploading, setUploading] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [moderationError, setModerationError] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [dragIndex, setDragIndex] = useState<number | null>(null);

  const handleFiles = useCallback(
    async (files: FileList) => {
      const remaining = 10 - images.length;
      const toUpload = Array.from(files).slice(0, remaining);
      if (toUpload.length === 0) return;

      setUploading(true);
      setModerationError("");
      try {
        const approvedUrls: string[] = [];

        for (const file of toUpload) {
          const url = await uploadListingImage(file, userId);

          const result = await moderateImage(url);
          if (!result.approved) {
            await deleteListingImage(url);
            setModerationError(result.reason || "Bildet ble blokkert av innholdsfilter.");
            continue;
          }

          approvedUrls.push(url);
        }

        if (approvedUrls.length > 0) {
          onChange([...images, ...approvedUrls]);
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error("Upload error:", msg);
        alert(`Feil ved opplasting: ${msg}`);
      } finally {
        setUploading(false);
      }
    },
    [images, userId, onChange],
  );

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setDragOver(false);
      if (e.dataTransfer.files.length > 0) {
        handleFiles(e.dataTransfer.files);
      }
    },
    [handleFiles],
  );

  const removeImage = (index: number) => {
    onChange(images.filter((_, i) => i !== index));
  };

  const handleReorderDrop = (targetIndex: number) => {
    if (dragIndex === null || dragIndex === targetIndex) return;
    const updated = [...images];
    const [moved] = updated.splice(dragIndex, 1);
    updated.splice(targetIndex, 0, moved);
    onChange(updated);
    setDragIndex(null);
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">Legg til bilder</h2>
        <p className="mt-1 text-sm text-neutral-500">
          Last opp opptil 10 bilder. Første bilde blir forsidebildet.
        </p>
      </div>

      {error && <p className="text-sm text-red-500">{error}</p>}

      {moderationError && (
        <div className="rounded-lg bg-red-50 border border-red-200 p-3 text-sm text-red-700">
          {moderationError}
        </div>
      )}

      {/* Drop zone */}
      <div
        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current?.click()}
        className={`flex cursor-pointer flex-col items-center justify-center rounded-xl border-2 border-dashed p-8 transition-colors ${
          dragOver
            ? "border-primary-500 bg-primary-50"
            : "border-neutral-300 hover:border-neutral-400"
        }`}
      >
        <Upload className={`h-8 w-8 ${dragOver ? "text-primary-500" : "text-neutral-400"}`} />
        <p className="mt-2 text-sm font-medium text-neutral-700">
          {uploading ? "Laster opp..." : "Dra bilder hit eller klikk for å velge"}
        </p>
        <p className="mt-1 text-xs text-neutral-400">JPG, PNG, WebP — maks 10 bilder</p>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          multiple
          className="hidden"
          onChange={(e) => e.target.files && handleFiles(e.target.files)}
        />
      </div>

      {/* Image grid */}
      {images.length > 0 && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {images.map((url, i) => (
            <div
              key={url}
              draggable
              onDragStart={() => setDragIndex(i)}
              onDragOver={(e) => e.preventDefault()}
              onDrop={() => handleReorderDrop(i)}
              className="group relative aspect-square overflow-hidden rounded-lg border border-neutral-200"
            >
              <Image
                src={url}
                alt={`Bilde ${i + 1}`}
                fill
                className="object-cover"
                sizes="150px"
              />
              {i === 0 && (
                <span className="absolute top-1.5 left-1.5 rounded bg-neutral-900/70 px-1.5 py-0.5 text-[10px] font-medium text-white">
                  Forsidebilde
                </span>
              )}
              <div className="absolute inset-0 flex items-center justify-center gap-1 bg-black/0 opacity-0 transition-all group-hover:bg-black/20 group-hover:opacity-100">
                <button
                  type="button"
                  onClick={() => removeImage(i)}
                  className="flex h-7 w-7 items-center justify-center rounded-full bg-white/90 text-neutral-700 hover:bg-white"
                >
                  <X className="h-3.5 w-3.5" />
                </button>
                <div className="flex h-7 w-7 cursor-grab items-center justify-center rounded-full bg-white/90 text-neutral-700">
                  <GripVertical className="h-3.5 w-3.5" />
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
