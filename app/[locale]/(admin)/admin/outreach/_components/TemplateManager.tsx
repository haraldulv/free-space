"use client";

import { useState } from "react";
import { Plus, Trash2, X } from "lucide-react";
import type { OutreachEmailTemplate } from "@/types";
import { deleteTemplateAction, loadOutreachAction, saveTemplateAction } from "../actions";

interface Props {
  templates: OutreachEmailTemplate[];
  onClose: () => void;
  onChanged: (next: OutreachEmailTemplate[]) => void;
}

interface DraftTemplate {
  id?: string;
  name: string;
  subject: string;
  body: string;
  isDefault: boolean;
}

const EMPTY_DRAFT: DraftTemplate = { name: "", subject: "", body: "", isDefault: false };

export default function TemplateManager({ templates, onClose, onChanged }: Props) {
  const [selectedId, setSelectedId] = useState<string | "new" | null>(
    templates[0]?.id ?? "new",
  );
  const [draft, setDraft] = useState<DraftTemplate>(() => {
    const t = templates[0];
    return t ? { id: t.id, name: t.name, subject: t.subject, body: t.body, isDefault: t.isDefault } : EMPTY_DRAFT;
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function selectTemplate(id: string) {
    const t = templates.find((x) => x.id === id);
    if (!t) return;
    setSelectedId(id);
    setDraft({ id: t.id, name: t.name, subject: t.subject, body: t.body, isDefault: t.isDefault });
  }

  function selectNew() {
    setSelectedId("new");
    setDraft(EMPTY_DRAFT);
  }

  async function refresh() {
    const res = await loadOutreachAction({ area: "lofoten" });
    if (res.templates) onChanged(res.templates);
  }

  async function save() {
    if (!draft.name || !draft.subject || !draft.body) {
      setError("Navn, emne og innhold må fylles ut.");
      return;
    }
    setSaving(true);
    setError(null);
    const res = await saveTemplateAction(draft);
    setSaving(false);
    if (res.error) {
      setError(res.error);
      return;
    }
    await refresh();
    if (res.template) {
      setSelectedId(res.template.id);
      setDraft({ ...res.template });
    }
  }

  async function remove() {
    if (!draft.id) return;
    if (!confirm(`Slette malen "${draft.name}"?`)) return;
    const res = await deleteTemplateAction(draft.id);
    if (res.error) {
      setError(res.error);
      return;
    }
    await refresh();
    selectNew();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="flex h-[80vh] w-full max-w-4xl rounded-lg bg-white shadow-xl">
        <div className="w-60 border-r border-neutral-200 bg-neutral-50">
          <div className="flex items-center justify-between border-b border-neutral-200 px-3 py-2">
            <h2 className="text-sm font-semibold">Maler</h2>
            <button onClick={onClose} className="rounded p-1 hover:bg-neutral-200">
              <X className="h-4 w-4" />
            </button>
          </div>
          <button
            onClick={selectNew}
            className="flex w-full items-center gap-1.5 border-b border-neutral-200 px-3 py-2 text-left text-xs text-primary-600 hover:bg-white"
          >
            <Plus className="h-3.5 w-3.5" /> Ny mal
          </button>
          <ul>
            {templates.map((t) => (
              <li
                key={t.id}
                onClick={() => selectTemplate(t.id)}
                className={`cursor-pointer border-b border-neutral-100 px-3 py-2 text-sm ${
                  selectedId === t.id ? "bg-white font-medium" : "hover:bg-white"
                }`}
              >
                {t.name}{t.isDefault && <span className="ml-1 text-[10px] text-primary-600">★</span>}
              </li>
            ))}
          </ul>
        </div>

        <div className="flex flex-1 flex-col">
          <div className="flex-1 space-y-3 overflow-y-auto px-4 py-4">
            <div>
              <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Navn</label>
              <input
                type="text"
                value={draft.name}
                onChange={(e) => setDraft({ ...draft, name: e.target.value })}
                placeholder="F.eks. Oppfølging etter telefonsamtale"
                className="mt-1 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
              />
            </div>
            <div>
              <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Emne</label>
              <input
                type="text"
                value={draft.subject}
                onChange={(e) => setDraft({ ...draft, subject: e.target.value })}
                className="mt-1 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
              />
            </div>
            <div>
              <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">
                Innhold (støtter {"{name}"}, {"{tuno_link}"}, {"{app_store_link}"})
              </label>
              <textarea
                value={draft.body}
                onChange={(e) => setDraft({ ...draft, body: e.target.value })}
                className="mt-1 h-80 w-full rounded-md border border-neutral-200 px-2 py-2 font-mono text-sm"
              />
            </div>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={draft.isDefault}
                onChange={(e) => setDraft({ ...draft, isDefault: e.target.checked })}
              />
              Bruk som standard-mal
            </label>
            {error && (
              <div className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div>
            )}
          </div>
          <div className="flex items-center justify-between border-t border-neutral-200 px-4 py-3">
            {draft.id ? (
              <button
                onClick={remove}
                className="flex items-center gap-1.5 text-sm text-red-600 hover:underline"
              >
                <Trash2 className="h-4 w-4" /> Slett
              </button>
            ) : <span />}
            <button
              onClick={save}
              disabled={saving}
              className="rounded-md bg-primary-600 px-4 py-2 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
            >
              {saving ? "Lagrer..." : draft.id ? "Lagre" : "Opprett mal"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
