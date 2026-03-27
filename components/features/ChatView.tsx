"use client";

import { useEffect, useRef, useState } from "react";
import { formatDistanceToNow } from "date-fns";
import { nb } from "date-fns/locale";
import { Send, ArrowLeft } from "lucide-react";
import { getMessages, subscribeToMessages } from "@/lib/supabase/chat";
import { sendMessageAction, markMessagesReadAction } from "@/app/(main)/meldinger/actions";
import type { Message } from "@/types";

interface ChatViewProps {
  conversationId: string;
  currentUserId: string;
  otherUserName: string;
  listingTitle: string;
  onBack?: () => void;
}

export default function ChatView({
  conversationId,
  currentUserId,
  otherUserName,
  listingTitle,
  onBack,
}: ChatViewProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    getMessages(conversationId).then((msgs) => {
      setMessages(msgs);
      markMessagesReadAction(conversationId);
    });

    const channel = subscribeToMessages(conversationId, (msg) => {
      setMessages((prev) => [...prev, msg]);
      markMessagesReadAction(conversationId);
    });

    return () => {
      channel.unsubscribe();
    };
  }, [conversationId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSend = async () => {
    const content = input.trim();
    if (!content) return;

    setInput("");
    setSending(true);

    // Optimistic update
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

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="flex h-full flex-col">
      {/* Header */}
      <div className="flex items-center gap-3 border-b border-neutral-200 px-4 py-3">
        {onBack && (
          <button onClick={onBack} className="text-neutral-500 hover:text-neutral-700 lg:hidden">
            <ArrowLeft className="h-5 w-5" />
          </button>
        )}
        <div>
          <p className="text-sm font-semibold text-neutral-900">{otherUserName}</p>
          <p className="text-xs text-neutral-500">{listingTitle}</p>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-3">
        {messages.length === 0 && (
          <p className="text-center text-sm text-neutral-400 mt-8">Ingen meldinger ennå. Start samtalen!</p>
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
                  {formatDistanceToNow(new Date(msg.createdAt), { addSuffix: true, locale: nb })}
                </p>
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="border-t border-neutral-200 p-3">
        <div className="flex items-end gap-2">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Skriv en melding..."
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
