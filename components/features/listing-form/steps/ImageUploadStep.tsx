"use client";

import { useCallback, useRef, useState } from "react";
import { Upload, X, Star, ArrowLeft, ArrowRight } from "lucide-react";
import Image from "next/image";
import { useTranslations } from "next-intl";
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
  const t = useTranslations("host.images");
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
            setModerationError(result.reason || t("moderationBlocked"));
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
        alert(`${t("uploadErrorPrefix")} ${msg}`);
      } finally {
        setUploading(false);
      }
    },
    [images, userId, onChange, t],
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

  const moveImage = (fromIndex: number, toIndex: number) => {
    if (toIndex < 0 || toIndex >= images.length) return;
    const updated = [...images];
    const [moved] = updated.splice(fromIndex, 1);
    updated.splice(toIndex, 0, moved);
    onChange(updated);
  };

  const setAsCover = (index: number) => moveImage(index, 0);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">{t("title")}</h2>
        <p className="mt-1 text-sm text-neutral-500">
          {t("subtitle")}
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
          {uploading ? t("uploading") : t("dropHint")}
        </p>
        <p className="mt-1 text-xs text-neutral-400">{t("fileTypes")}</p>
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
        <>
          <p className="text-xs text-neutral-500">{t("reorderHint")}</p>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
            {images.map((url, i) => (
              <div
                key={url}
                draggable
                onDragStart={() => setDragIndex(i)}
                onDragOver={(e) => e.preventDefault()}
                onDrop={() => handleReorderDrop(i)}
                className={`group relative aspect-square overflow-hidden rounded-lg border bg-white ${
                  i === 0 ? "border-primary-500 ring-2 ring-primary-500/30" : "border-neutral-200"
                }`}
              >
                <Image
                  src={url}
                  alt={t("imageAlt", { number: i + 1 })}
                  fill
                  className="object-cover"
                  sizes="150px"
                />
                {i === 0 && (
                  <span className="absolute top-1.5 left-1.5 inline-flex items-center gap-1 rounded bg-primary-600 px-1.5 py-0.5 text-[10px] font-semibold text-white shadow-sm">
                    <Star className="h-2.5 w-2.5 fill-white" />
                    {t("coverBadge")}
                  </span>
                )}
                <button
                  type="button"
                  onClick={() => removeImage(i)}
                  className="absolute top-1.5 right-1.5 flex h-7 w-7 items-center justify-center rounded-full bg-white/95 text-neutral-700 shadow-sm hover:bg-white"
                  aria-label={t("removeImage")}
                >
                  <X className="h-3.5 w-3.5" />
                </button>

                <div className="absolute inset-x-0 bottom-0 flex items-center justify-between gap-1 bg-gradient-to-t from-black/60 to-transparent p-1.5 opacity-100 sm:opacity-0 sm:transition-opacity sm:group-hover:opacity-100">
                  <button
                    type="button"
                    onClick={() => moveImage(i, i - 1)}
                    disabled={i === 0}
                    className="flex h-7 w-7 items-center justify-center rounded-full bg-white/95 text-neutral-700 shadow-sm hover:bg-white disabled:opacity-30"
                    aria-label={t("moveLeft")}
                  >
                    <ArrowLeft className="h-3.5 w-3.5" />
                  </button>
                  {i !== 0 && (
                    <button
                      type="button"
                      onClick={() => setAsCover(i)}
                      className="flex-1 rounded-full bg-white/95 px-2 py-1 text-[10px] font-semibold text-neutral-700 shadow-sm hover:bg-white"
                    >
                      {t("setAsCover")}
                    </button>
                  )}
                  <button
                    type="button"
                    onClick={() => moveImage(i, i + 1)}
                    disabled={i === images.length - 1}
                    className="flex h-7 w-7 items-center justify-center rounded-full bg-white/95 text-neutral-700 shadow-sm hover:bg-white disabled:opacity-30"
                    aria-label={t("moveRight")}
                  >
                    <ArrowRight className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
