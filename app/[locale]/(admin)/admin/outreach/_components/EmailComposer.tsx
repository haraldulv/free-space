"use client";

import { useMemo, useState } from "react";
import { X } from "lucide-react";
import type { OutreachEmailTemplate, OutreachTarget } from "@/types";
import { sendOutreachEmailAction } from "../actions";

interface Props {
  target: OutreachTarget;
  templates: OutreachEmailTemplate[];
  onClose: () => void;
  onSent: () => void;
}

const APP_STORE_URL = "https://apps.apple.com/no/app/tuno-motorhome-and-parking/id6761529990";
const TUNO_URL = "https://tuno.no";

function substitute(text: string, name: string): string {
  return text
    .replaceAll("{name}", name)
    .replaceAll("{tuno_link}", TUNO_URL)
    .replaceAll("{app_store_link}", APP_STORE_URL);
}

export default function EmailComposer({ target, templates, onClose, onSent }: Props) {
  const defaultTemplate = useMemo(
    () => templates.find((t) => t.isDefault) ?? templates[0] ?? null,
    [templates],
  );

  const [templateId, setTemplateId] = useState<string>(defaultTemplate?.id ?? "");
  const [subject, setSubject] = useState(defaultTemplate?.subject ?? "");
  const [body, setBody] = useState(defaultTemplate?.body ?? "");
  const [recipient, setRecipient] = useState(target.email ?? "");
  const [preview, setPreview] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function loadTemplate(id: string) {
    setTemplateId(id);
    const t = templates.find((x) => x.id === id);
    if (t) {
      setSubject(t.subject);
      setBody(t.body);
    }
  }

  async function send() {
    if (!recipient || !subject || !body) {
      setError("Mottaker, emne og innhold må fylles ut.");
      return;
    }
    setError(null);
    setSending(true);
    const res = await sendOutreachEmailAction(target.id, {
      subject,
      body,
      recipientEmail: recipient,
      templateId: templateId || undefined,
    });
    setSending(false);
    if (res.error) {
      setError(res.error);
      return;
    }
    onSent();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="flex max-h-[90vh] w-full max-w-2xl flex-col rounded-lg bg-white shadow-xl">
        <div className="flex items-center justify-between border-b border-neutral-200 px-4 py-3">
          <h2 className="text-base font-semibold">Send e-post til {target.name}</h2>
          <button onClick={onClose} className="rounded p-1 hover:bg-neutral-100">
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="flex-1 space-y-3 overflow-y-auto px-4 py-4">
          <div>
            <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Mal</label>
            <select
              value={templateId}
              onChange={(e) => loadTemplate(e.target.value)}
              className="mt-1 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
            >
              {templates.length === 0 && <option value="">Ingen maler</option>}
              {templates.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}{t.isDefault ? " (standard)" : ""}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Til</label>
            <input
              type="email"
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              placeholder="kontakt@bedrift.no"
              className="mt-1 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
            />
          </div>

          <div>
            <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Emne</label>
            <input
              type="text"
              value={subject}
              onChange={(e) => setSubject(e.target.value)}
              className="mt-1 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
            />
          </div>

          <div>
            <div className="flex items-center justify-between">
              <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">
                Innhold {!preview && <span className="text-neutral-400">(støtter {"{name}"}, {"{tuno_link}"}, {"{app_store_link}"})</span>}
              </label>
              <button
                type="button"
                onClick={() => setPreview(!preview)}
                className="text-xs text-primary-600 hover:underline"
              >
                {preview ? "Rediger" : "Forhåndsvis"}
              </button>
            </div>
            {preview ? (
              <pre className="mt-1 h-64 overflow-y-auto whitespace-pre-wrap rounded-md border border-neutral-200 bg-neutral-50 p-3 font-sans text-sm">
                {substitute(body, target.name)}
              </pre>
            ) : (
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                className="mt-1 h-64 w-full rounded-md border border-neutral-200 px-2 py-2 font-mono text-sm"
              />
            )}
          </div>

          {error && (
            <div className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div>
          )}
        </div>

        <div className="flex items-center justify-end gap-2 border-t border-neutral-200 px-4 py-3">
          <button
            onClick={onClose}
            className="rounded-md border border-neutral-200 px-3 py-2 text-sm hover:bg-neutral-50"
          >
            Avbryt
          </button>
          <button
            onClick={send}
            disabled={sending || !recipient || !subject || !body}
            className="rounded-md bg-primary-600 px-4 py-2 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
          >
            {sending ? "Sender..." : "Send"}
          </button>
        </div>
      </div>
    </div>
  );
}
