"use client";

import { formatDistanceToNow } from "date-fns";
import { nb } from "date-fns/locale";
import { MessageCircle } from "lucide-react";
import type { Conversation } from "@/types";

interface ConversationListProps {
  conversations: Conversation[];
  selectedId?: string;
  onSelect: (conversation: Conversation) => void;
}

export default function ConversationList({
  conversations,
  selectedId,
  onSelect,
}: ConversationListProps) {
  if (conversations.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-neutral-100">
          <MessageCircle className="h-8 w-8 text-neutral-400" />
        </div>
        <h2 className="mt-4 text-lg font-semibold text-neutral-700">Ingen meldinger ennå</h2>
        <p className="mt-1 text-sm text-neutral-500">
          Start en samtale fra en annonse.
        </p>
      </div>
    );
  }

  return (
    <div className="divide-y divide-neutral-100">
      {conversations.map((convo) => (
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
                {formatDistanceToNow(new Date(convo.lastMessageAt), { addSuffix: true, locale: nb })}
              </span>
            </div>
            <p className="text-xs text-neutral-500 truncate">{convo.listingTitle}</p>
            <p className="mt-0.5 text-xs text-neutral-400 truncate">{convo.lastMessageText || "Ingen meldinger"}</p>
          </div>
          {(convo.unreadCount || 0) > 0 && (
            <span className="mt-1 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-primary-600 px-1.5 text-[10px] font-bold text-white">
              {convo.unreadCount}
            </span>
          )}
        </button>
      ))}
    </div>
  );
}
