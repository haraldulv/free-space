"use client";

import { useEffect, useState, useRef } from "react";
import { Camera, LogOut, Trash2, User, Mail, Calendar, Check } from "lucide-react";
import Container from "@/components/ui/Container";
import Input from "@/components/ui/Input";
import Button from "@/components/ui/Button";
import { createClient } from "@/lib/supabase/client";
import { uploadAvatar, deleteAvatar } from "@/lib/supabase/storage";
import {
  getProfileAction,
  updateProfileAction,
  updateAvatarAction,
  deleteAccountAction,
} from "./actions";

interface ProfileData {
  id: string;
  email: string;
  fullName: string;
  avatar: string;
  responseRate: number;
  responseTime: string;
  joinedYear: number;
}

export default function SettingsPage() {
  const [profile, setProfile] = useState<ProfileData | null>(null);
  const [fullName, setFullName] = useState("");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    getProfileAction().then((result) => {
      if (result.profile) {
        setProfile(result.profile);
        setFullName(result.profile.fullName);
      }
    });
  }, []);

  const handleSave = async () => {
    if (!fullName.trim()) return;
    setSaving(true);
    setError("");
    setSaved(false);

    const result = await updateProfileAction({ fullName: fullName.trim() });
    if (result.error) {
      setError(result.error);
    } else {
      setSaved(true);
      setProfile((prev) => prev ? { ...prev, fullName: fullName.trim() } : null);
      setTimeout(() => setSaved(false), 2000);
    }
    setSaving(false);
  };

  const handleAvatarChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !profile) return;

    if (file.size > 5 * 1024 * 1024) {
      setError("Bildet kan ikke være større enn 5 MB");
      return;
    }

    setUploadingAvatar(true);
    setError("");

    try {
      // Delete old avatar if exists
      if (profile.avatar) {
        await deleteAvatar(profile.avatar).catch(() => {});
      }

      const url = await uploadAvatar(file, profile.id);
      const result = await updateAvatarAction(url);

      if (result.error) {
        setError(result.error);
      } else {
        setProfile((prev) => prev ? { ...prev, avatar: url } : null);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Kunne ikke laste opp bilde");
    }
    setUploadingAvatar(false);
  };

  const handleSignOut = async () => {
    const supabase = createClient();
    await supabase.auth.signOut();
    window.location.href = "/";
  };

  const handleDeleteAccount = async () => {
    setDeleting(true);
    const result = await deleteAccountAction();
    if (result.error) {
      setError(result.error);
      setDeleting(false);
    } else {
      window.location.href = "/";
    }
  };

  if (!profile) {
    return (
      <Container className="py-10 min-h-screen bg-neutral-50">
        <div className="mx-auto max-w-xl animate-pulse space-y-6">
          <div className="h-8 w-48 rounded bg-neutral-200" />
          <div className="h-20 w-20 rounded-full bg-neutral-200" />
          <div className="h-10 rounded bg-neutral-200" />
          <div className="h-10 rounded bg-neutral-200" />
        </div>
      </Container>
    );
  }

  return (
    <Container className="py-10 min-h-screen bg-neutral-50">
      <div className="mx-auto max-w-xl">
        <h1 className="text-2xl font-semibold text-neutral-900">Innstillinger</h1>

        {/* Profile section */}
        <section className="mt-8">
          <h2 className="text-base font-medium text-neutral-700">Profil</h2>

          {/* Avatar */}
          <div className="mt-4 flex items-center gap-5">
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploadingAvatar}
              className="group relative h-20 w-20 shrink-0 overflow-hidden rounded-full bg-neutral-200 transition-opacity hover:opacity-90 disabled:opacity-60"
            >
              {profile.avatar ? (
                <img
                  src={profile.avatar}
                  alt={profile.fullName}
                  className="h-full w-full object-cover"
                />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-2xl font-medium text-neutral-400">
                  {profile.fullName?.charAt(0)?.toUpperCase() || profile.email.charAt(0).toUpperCase()}
                </div>
              )}
              <div className="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 transition-opacity group-hover:opacity-100">
                <Camera className="h-5 w-5 text-white" />
              </div>
              {uploadingAvatar && (
                <div className="absolute inset-0 flex items-center justify-center bg-white/70">
                  <div className="h-5 w-5 animate-spin rounded-full border-2 border-primary-600 border-t-transparent" />
                </div>
              )}
            </button>
            <div>
              <p className="text-sm font-medium text-neutral-700">Profilbilde</p>
              <p className="text-xs text-neutral-500">Klikk for å endre. Maks 5 MB.</p>
            </div>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/jpeg,image/png,image/webp"
              className="hidden"
              onChange={handleAvatarChange}
            />
          </div>

          {/* Name */}
          <div className="mt-6 space-y-4">
            <Input
              id="fullName"
              label="Fullt navn"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="Ditt navn"
            />

            {/* Email (read-only) */}
            <div className="w-full">
              <label className="mb-1.5 block text-sm font-medium text-neutral-700">
                E-post
              </label>
              <div className="flex items-center gap-2 rounded-lg border border-neutral-200 bg-neutral-50 px-3 py-2 text-sm text-neutral-500">
                <Mail className="h-4 w-4 shrink-0" />
                {profile.email}
              </div>
            </div>
          </div>

          {error && (
            <p className="mt-3 text-sm text-red-600">{error}</p>
          )}

          <Button
            className="mt-5"
            onClick={handleSave}
            disabled={saving || fullName.trim() === profile.fullName}
          >
            {saving ? (
              "Lagrer..."
            ) : saved ? (
              <span className="inline-flex items-center gap-1.5">
                <Check className="h-4 w-4" /> Lagret
              </span>
            ) : (
              "Lagre endringer"
            )}
          </Button>
        </section>

        {/* Account info */}
        <section className="mt-10 border-t border-neutral-200 pt-8">
          <h2 className="text-base font-medium text-neutral-700">Kontoinformasjon</h2>
          <div className="mt-4 space-y-3">
            <div className="flex items-center gap-3 text-sm text-neutral-600">
              <Calendar className="h-4 w-4 text-neutral-400" />
              Medlem siden {profile.joinedYear}
            </div>
            <div className="flex items-center gap-3 text-sm text-neutral-600">
              <User className="h-4 w-4 text-neutral-400" />
              Svartid: {profile.responseTime}
            </div>
          </div>
        </section>

        {/* Account actions */}
        <section className="mt-10 border-t border-neutral-200 pt-8 pb-16">
          <h2 className="text-base font-medium text-neutral-700">Konto</h2>
          <div className="mt-4 flex flex-col gap-3 sm:flex-row">
            <Button variant="outline" onClick={handleSignOut}>
              <LogOut className="mr-2 h-4 w-4" />
              Logg ut
            </Button>

            {!showDeleteConfirm ? (
              <Button
                variant="ghost"
                className="text-red-600 hover:bg-red-50 hover:text-red-700"
                onClick={() => setShowDeleteConfirm(true)}
              >
                <Trash2 className="mr-2 h-4 w-4" />
                Slett konto
              </Button>
            ) : (
              <div className="flex items-center gap-2">
                <Button
                  variant="ghost"
                  className="bg-red-600 text-white hover:bg-red-700 hover:text-white"
                  onClick={handleDeleteAccount}
                  disabled={deleting}
                >
                  {deleting ? "Sletter..." : "Bekreft sletting"}
                </Button>
                <Button
                  variant="ghost"
                  onClick={() => setShowDeleteConfirm(false)}
                  disabled={deleting}
                >
                  Avbryt
                </Button>
              </div>
            )}
          </div>
        </section>
      </div>
    </Container>
  );
}
