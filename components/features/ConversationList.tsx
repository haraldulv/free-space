"use client";

import { useMemo, useState } from "react";
import { formatDistanceToNow } from "date-fns";
import { MessageCircle, Search, X } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { dateFnsLocale } from "@/lib/i18n-helpers";
import type { Conversation } from "@/types";

interface ConversationListProps {
  conversations: Conversation[];
  selectedId?: string;
  onSelect: (conversation: Conversation) => void;
  /** Tap-handler for "Kontakt support"-pinned-rad. Når denne er definert, renderes raden alltid øverst. */
  onOpenSupport?: () => void;
}

export default function ConversationList({
  conversations,
  selectedId,
  onSelect,
  onOpenSupport,
}: ConversationListProps) {
  const t = useTranslations("messages");
  const locale = useLocale();
  const dateLocale = dateFnsLocale(locale);
  const [query, setQuery] = useState("");
  const [unreadOnly, setUnreadOnly] = useState(false);

  // Filtrer ut eksisterende support-conversation fra hovedlisten — den vises alltid pinnet øverst.
  const supportConvo = useMemo(
    () => conversations.find((c) => c.type === "support"),
    [conversations],
  );
  const nonSupportConversations = useMemo(
    () => conversations.filter((c) => c.type !== "support"),
    [conversations],
  );

  const totalUnread = nonSupportConversations.reduce((sum, c) => sum + (c.unreadCount || 0), 0);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return nonSupportConversations.filter((c) => {
      if (unreadOnly && !(c.unreadCount && c.unreadCount > 0)) return false;
      if (!q) return true;
      const hay = `${c.otherUserName ?? ""} ${c.listingTitle ?? ""} ${c.lastMessageText ?? ""}`.toLowerCase();
      return hay.includes(q);
    });
  }, [nonSupportConversations, query, unreadOnly]);

  const showSupportPin = !!onOpenSupport && !query && !unreadOnly;

  const renderSupportRow = () => {
    if (!showSupportPin) return null;
    const isSelected = supportConvo && selectedId === supportConvo.id;
    return (
      <button
        type="button"
        onClick={() => {
          if (supportConvo) {
            onSelect(supportConvo);
          } else {
            onOpenSupport?.();
          }
        }}
        className={`flex w-full items-start gap-3 px-4 py-3 text-left transition-colors hover:bg-neutral-50 ${
          isSelected ? "bg-primary-50" : ""
        }`}
      >
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/tuno-pin.png" alt="Tuno" className="h-9 w-9 object-contain" />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-2">
            <p className="text-sm font-semibold text-neutral-900 truncate">Tuno support</p>
            {supportConvo?.lastMessageAt && (
              <span className="shrink-0 text-[10px] text-neutral-400">
                {formatDistanceToNow(new Date(supportConvo.lastMessageAt), { addSuffix: true, locale: dateLocale })}
              </span>
            )}
          </div>
          <p className="text-xs text-neutral-500 truncate">Kundeservice</p>
          <p className="mt-0.5 text-xs text-neutral-400 truncate">
            {supportConvo?.lastMessageText || "Spør oss om hva som helst — vi svarer fortløpende."}
          </p>
        </div>
        {(supportConvo?.unreadCount || 0) > 0 && (
          <span className="mt-1 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-primary-600 px-1.5 text-[10px] font-bold text-white">
            {supportConvo!.unreadCount}
          </span>
        )}
      </button>
    );
  };

  if (conversations.length === 0 && !onOpenSupport) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-neutral-100">
          <MessageCircle className="h-8 w-8 text-neutral-400" />
        </div>
        <h2 className="mt-4 text-lg font-semibold text-neutral-700">{t("noConversations")}</h2>
        <p className="mt-1 text-sm text-neutral-500">
          {t("noConversationsDescription")}
        </p>
      </div>
    );
  }

  return (
    <div>
      <div className="sticky top-0 z-10 space-y-2 border-b border-neutral-100 bg-white p-3">
        <div className="relative">
          <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-neutral-400" />
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t("searchPlaceholder")}
            className="w-full rounded-full border border-neutral-200 bg-neutral-50 py-1.5 pl-8 pr-8 text-xs focus:border-primary-500 focus:bg-white focus:outline-none"
          />
          {query && (
            <button
              type="button"
              onClick={() => setQuery("")}
              className="absolute right-2 top-1/2 -translate-y-1/2 text-neutral-400 hover:text-neutral-600"
              aria-label={t("clearSearch")}
            >
              <X className="h-3.5 w-3.5" />
            </button>
          )}
        </div>
        <div className="flex items-center gap-1.5">
          <button
            type="button"
            onClick={() => setUnreadOnly(false)}
            className={`rounded-full px-2.5 py-1 text-[11px] font-medium transition ${
              !unreadOnly ? "bg-neutral-900 text-white" : "bg-neutral-100 text-neutral-600 hover:bg-neutral-200"
            }`}
          >
            {t("filterAll")}
          </button>
          <button
            type="button"
            onClick={() => setUnreadOnly(true)}
            className={`inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-[11px] font-medium transition ${
              unreadOnly ? "bg-neutral-900 text-white" : "bg-neutral-100 text-neutral-600 hover:bg-neutral-200"
            }`}
          >
            {t("filterUnread")}
            {totalUnread > 0 && (
              <span className={`inline-flex h-4 min-w-[16px] items-center justify-center rounded-full px-1 text-[10px] font-bold ${
                unreadOnly ? "bg-white text-neutral-900" : "bg-primary-600 text-white"
              }`}>
                {totalUnread}
              </span>
            )}
          </button>
        </div>
      </div>

      <div className="divide-y divide-neutral-100">
        {renderSupportRow()}
      </div>

      {filtered.length === 0 && nonSupportConversations.length > 0 ? (
        <p className="px-4 py-8 text-center text-xs text-neutral-400">{t("noFilterMatches")}</p>
      ) : filtered.length === 0 ? null : (
      <div className="divide-y divide-neutral-100">
      {filtered.map((convo) => (
        <button
          key={convo.id}
          onClick={() => onSelect(convo)}
          className={`flex w-full items-start gap-3 px-4 py-3 text-left transition-colors hover:bg-neutral-50 ${
            selectedId === convo.id ? "bg-primary-50" : ""
          }`}
        >
          {convo.otherUserAvatar ? (
            <img
              src={convo.otherUserAvatar}
              alt={convo.otherUserName || ""}
              className="h-10 w-10 shrink-0 rounded-full object-cover"
            />
          ) : (
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-neutral-200 text-sm font-medium text-neutral-600">
              {(convo.otherUserName || "A").charAt(0).toUpperCase()}
            </div>
          )}
          <div className="min-w-0 flex-1">
            <div className="flex items-center justify-between gap-2">
              <p className="text-sm font-medium text-neutral-900 truncate">{convo.otherUserName}</p>
              <span className="shrink-0 text-[10px] text-neutral-400">
                {formatDistanceToNow(new Date(convo.lastMessageAt), { addSuffix: true, locale: dateLocale })}
              </span>
            </div>
            <p className="text-xs text-neutral-500 truncate">{convo.listingTitle}</p>
            <p className="mt-0.5 text-xs text-neutral-400 truncate">{convo.lastMessageText || t("noMessages")}</p>
          </div>
          {(convo.unreadCount || 0) > 0 && (
            <span className="mt-1 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-primary-600 px-1.5 text-[10px] font-bold text-white">
              {convo.unreadCount}
            </span>
          )}
        </button>
      ))}
      </div>
      )}
    </div>
  );
}
