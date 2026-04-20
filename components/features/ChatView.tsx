"use client";

import { useEffect, useRef, useState } from "react";
import { formatDistanceToNow } from "date-fns";
import { Send, ArrowLeft, ChevronRight } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { dateFnsLocale } from "@/lib/i18n-helpers";
import { getMessages, subscribeToMessages } from "@/lib/supabase/chat";
import { sendMessageAction, markMessagesReadAction } from "@/app/[locale]/(main)/meldinger/actions";
import type { Message } from "@/types";

interface ChatViewProps {
  conversationId: string;
  currentUserId: string;
  otherUserName: string;
  listingTitle: string;
  listingId?: string;
  listingImage?: string;
  onBack?: () => void;
}

export default function ChatView({
  conversationId,
  currentUserId,
  otherUserName,
  listingTitle,
  listingId,
  listingImage,
  onBack,
}: ChatViewProps) {
  const t = useTranslations("messages");
  const locale = useLocale();
  const dateLocale = dateFnsLocale(locale);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);

  useEffect(() => {
    getMessages(conversationId).then((msgs) => {
      setMessages(msgs);
      markMessagesReadAction(conversationId);
    });

    const channel = subscribeToMessages(conversationId, (msg) => {
      setMessages((prev) => {
        if (prev.some((m) => m.content === msg.content && m.senderId === msg.senderId && Math.abs(new Date(m.createdAt).getTime() - new Date(msg.createdAt).getTime()) < 5000)) {
          return prev;
        }
        return [...prev, msg];
      });
      markMessagesReadAction(conversationId);
    });

    return () => {
      channel.unsubscribe();
    };
  }, [conversationId]);

  const messagesContainerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (messagesContainerRef.current) {
      messagesContainerRef.current.scrollTop = messagesContainerRef.current.scrollHeight;
    }
  }, [messages]);

  const handleSend = async () => {
    const content = input.trim();
    if (!content) return;

    setInput("");
    setSending(true);

    const optimistic: Message = {
      id: crypto.randomUUID(),
      conversationId,
      senderId: currentUserId,
      content,
      read: false,
      createdAt: new Date().toISOString(),
    };
    setMessages((prev) => [...prev, optimistic]);

    await sendMessageAction({ conversationId, content });
    setSending(false);
  };

  const inputRef = useRef<HTMLTextAreaElement>(null);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      e.stopPropagation();
      handleSend();
      requestAnimationFrame(() => inputRef.current?.focus());
    }
  };

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-3 border-b border-neutral-200 px-4 py-3">
        {onBack && (
          <button onClick={onBack} className="text-neutral-500 hover:text-neutral-700 lg:hidden">
            <ArrowLeft className="h-5 w-5" />
          </button>
        )}
        {listingId ? (
          <Link
            href={`/listings/${listingId}`}
            className="flex flex-1 items-center gap-3 min-w-0 transition-opacity hover:opacity-80"
          >
            {listingImage ? (
              <img
                src={listingImage}
                alt=""
                className="h-10 w-10 shrink-0 rounded-lg object-cover"
              />
            ) : (
              <div className="h-10 w-10 shrink-0 rounded-lg bg-neutral-100" />
            )}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-neutral-900">{otherUserName}</p>
              <p className="truncate text-xs text-neutral-500">{listingTitle}</p>
            </div>
            <ChevronRight className="h-4 w-4 shrink-0 text-neutral-400" />
          </Link>
        ) : (
          <div className="flex flex-1 items-center gap-3 min-w-0">
            {listingImage ? (
              <img
                src={listingImage}
                alt=""
                className="h-10 w-10 shrink-0 rounded-lg object-cover"
              />
            ) : (
              <div className="h-10 w-10 shrink-0 rounded-lg bg-neutral-100" />
            )}
            <div className="min-w-0">
              <p className="truncate text-sm font-semibold text-neutral-900">{otherUserName}</p>
              <p className="truncate text-xs text-neutral-500">{listingTitle}</p>
            </div>
          </div>
        )}
      </div>

      <div ref={messagesContainerRef} className="flex-1 overflow-y-auto p-4 space-y-3">
        {messages.length === 0 && (
          <p className="text-center text-sm text-neutral-400 mt-8">{t("startConversation")}</p>
        )}
        {messages.map((msg) => {
          const isOwn = msg.senderId === currentUserId;
          return (
            <div key={msg.id} className={`flex ${isOwn ? "justify-end" : "justify-start"}`}>
              <div
                className={`max-w-[75%] rounded-2xl px-4 py-2 ${
                  isOwn
                    ? "bg-primary-600 text-white"
                    : "bg-neutral-100 text-neutral-900"
                }`}
              >
                <p className="text-sm whitespace-pre-wrap">{msg.content}</p>
                <p className={`mt-1 text-[10px] ${isOwn ? "text-white/60" : "text-neutral-400"}`}>
                  {formatDistanceToNow(new Date(msg.createdAt), { addSuffix: true, locale: dateLocale })}
                </p>
              </div>
            </div>
          );
        })}
      </div>

      <div className="border-t border-neutral-200 p-3">
        <div className="flex items-end gap-2">
          <textarea
            ref={inputRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={t("typeMessage")}
            rows={1}
            className="flex-1 resize-none rounded-lg border border-neutral-300 px-3 py-2 text-sm text-neutral-900 placeholder:text-neutral-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
          />
          <button
            onClick={handleSend}
            disabled={!input.trim() || sending}
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary-600 text-white transition-colors hover:bg-primary-700 disabled:opacity-50"
          >
            <Send className="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
