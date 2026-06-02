"use client";

import { useMemo, useState } from "react";
import { X, Paperclip, FileText } from "lucide-react";
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
const MAX_FILE_SIZE = 4 * 1024 * 1024; // 4MB (Vercel payload limit)

interface Attachment {
  filename: string;
  content: string;
  contentType: string;
  size: number;
}

function substitute(text: string, name: string, contactPerson: string): string {
  return text
    .replaceAll("{name}", name)
    .replaceAll("{contact_person}", contactPerson)
    .replaceAll("{tuno_link}", TUNO_URL)
    .replaceAll("{app_store_link}", APP_STORE_URL);
}

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function EmailComposer({ target, templates, onClose, onSent }: Props) {
  const defaultTemplate = useMemo(
    () => templates.find((t) => t.isDefault) ?? templates[0] ?? null,
    [templates],
  );

  const [templateId, setTemplateId] = useState<string>(defaultTemplate?.id ?? "");
  const [sender, setSender] = useState<"kim" | "harald">("kim");
  const [language, setLanguage] = useState<"nb" | "en" | "de">("nb");
  const [subject, setSubject] = useState(defaultTemplate?.subject ?? "");
  const [body, setBody] = useState(defaultTemplate?.body ?? "");
  const [recipient, setRecipient] = useState(target.email ?? "");
  const [preview, setPreview] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [attachments, setAttachments] = useState<Attachment[]>([]);

  function loadTemplate(id: string) {
    setTemplateId(id);
    const t = templates.find((x) => x.id === id);
    if (t) {
      setSubject(t.subject);
      setBody(t.body);
    }
  }

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const files = e.target.files;
    if (!files) return;
    Array.from(files).forEach((file) => {
      if (file.size > MAX_FILE_SIZE) {
        setError(`«${file.name}» er for stor (maks ${formatSize(MAX_FILE_SIZE)}).`);
        return;
      }
      const reader = new FileReader();
      reader.onload = () => {
        const base64 = (reader.result as string).split(",")[1];
        setAttachments((prev) => [...prev, {
          filename: file.name,
          content: base64,
          contentType: file.type || "application/octet-stream",
          size: file.size,
        }]);
      };
      reader.readAsDataURL(file);
    });
    e.target.value = "";
  }

  function removeAttachment(index: number) {
    setAttachments((prev) => prev.filter((_, i) => i !== index));
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
      sender,
      language,
      attachments: attachments.length > 0
        ? attachments.map(({ filename, content, contentType }) => ({ filename, content, contentType }))
        : undefined,
    });
    setSending(false);
    if (res.error) {
      setError(res.error);
      return;
    }
    onSent();
  }

  const cp = target.contactPerson ?? "";

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
            <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Fra</label>
            <select
              value={sender}
              onChange={(e) => setSender(e.target.value as "kim" | "harald")}
              className="mt-1 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
            >
              <option value="kim">Kim fra Tuno (kim@tuno.no)</option>
              <option value="harald">Harald fra Tuno (harald@tuno.no)</option>
            </select>
          </div>

          <div>
            <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Språk</label>
            <select
              value={language}
              onChange={(e) => setLanguage(e.target.value as "nb" | "en" | "de")}
              className="mt-1 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
            >
              <option value="nb">🇳🇴 Norsk</option>
              <option value="en">🇬🇧 English</option>
              <option value="de">🇩🇪 Deutsch</option>
            </select>
            <p className="mt-1 text-[11px] text-neutral-400">
              Styrer boksene, knappen og lenken under meldingen. Meldingsteksten skriver du selv.
            </p>
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
                Innhold {!preview && <span className="text-neutral-400">(støtter {"{name}"}, {"{contact_person}"}, {"{tuno_link}"}, {"{app_store_link}"})</span>}
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
                {substitute(body, target.name, cp)}
              </pre>
            ) : (
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                className="mt-1 h-64 w-full rounded-md border border-neutral-200 px-2 py-2 font-mono text-sm"
              />
            )}
          </div>

          {/* Vedlegg */}
          <div>
            <label className="flex cursor-pointer items-center gap-1.5 text-sm text-neutral-600 hover:text-neutral-900">
              <Paperclip className="h-4 w-4" />
              <span>Legg til vedlegg</span>
              <input
                type="file"
                accept=".pdf,.doc,.docx,.jpg,.jpeg,.png"
                multiple
                onChange={handleFileSelect}
                className="hidden"
              />
            </label>
            {attachments.length > 0 && (
              <div className="mt-2 space-y-1.5">
                {attachments.map((a, i) => (
                  <div key={i} className="flex items-center gap-2 rounded-md bg-neutral-50 px-3 py-2 text-sm">
                    <FileText className="h-4 w-4 shrink-0 text-neutral-400" />
                    <span className="flex-1 truncate">{a.filename}</span>
                    <span className="shrink-0 text-xs text-neutral-400">{formatSize(a.size)}</span>
                    <button
                      onClick={() => removeAttachment(i)}
                      className="shrink-0 rounded p-0.5 hover:bg-neutral-200"
                    >
                      <X className="h-3.5 w-3.5 text-neutral-500" />
                    </button>
                  </div>
                ))}
              </div>
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
