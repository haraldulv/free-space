"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "@/i18n/navigation";
import { formatDistanceToNow } from "date-fns";
import { Send, ArrowLeft, Bell, ChevronRight, CreditCard, Hourglass } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { dateFnsLocale } from "@/lib/i18n-helpers";
import { getMessages, subscribeToMessages } from "@/lib/supabase/chat";
import { sendMessageAction, markMessagesReadAction } from "@/app/[locale]/(main)/meldinger/actions";
import { createClient as createSupabaseClient } from "@/lib/supabase/client";
import OfferMessageBubble from "./OfferMessageBubble";
import CounterOfferModal from "./CounterOfferModal";
import type { Message, OfferMessageMetadata } from "@/types";

interface ChatViewProps {
  conversationId: string;
  currentUserId: string;
  otherUserName: string;
  listingTitle: string;
  listingId?: string;
  listingImage?: string;
  isSupport?: boolean;
  onBack?: () => void;
}

export default function ChatView({
  conversationId,
  currentUserId,
  otherUserName,
  listingTitle,
  listingId,
  listingImage,
  isSupport = false,
  onBack,
}: ChatViewProps) {
  const t = useTranslations("messages");
  const locale = useLocale();
  const dateLocale = dateFnsLocale(locale);
  const router = useRouter();
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [bookingState, setBookingState] = useState<NegotiationState | null>(null);
  const [counterContext, setCounterContext] = useState<{
    bookingId: string;
    currentOfferPrice: number;
    currentOfferLabel: string;
  } | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

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

  const reloadMessages = async () => {
    const fresh = await getMessages(conversationId);
    setMessages(fresh);
  };

  const reloadBookingState = async () => {
    if (!listingId) return;
    try {
      const supabase = createSupabaseClient();
      const { data, error } = await supabase
        .from("bookings")
        .select("id, user_id, host_id, status, current_offer_id, total_price")
        .eq("listing_id", listingId)
        .or(`user_id.eq.${currentUserId},host_id.eq.${currentUserId}`)
        .in("status", ["awaiting_host", "awaiting_guest", "awaiting_payment", "requested", "confirmed", "expired", "declined", "cancelled"])
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (error || !data) {
        setBookingState(null);
        return;
      }
      setBookingState({
        bookingId: data.id,
        status: data.status,
        currentOfferId: data.current_offer_id,
        userId: data.user_id,
        hostId: data.host_id,
        totalPrice: data.total_price,
        isNegotiating: ["awaiting_host", "awaiting_guest", "awaiting_payment", "requested"].includes(data.status),
      });
    } catch (err) {
      console.warn("reloadBookingState:", err);
    }
  };

  useEffect(() => {
    reloadBookingState();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [listingId, currentUserId]);

  const acceptOffer = async (metadata: OfferMessageMetadata) => {
    if (!metadata.bookingId || !metadata.offerId) return;
    setActionError(null);
    try {
      const supabase = createSupabaseClient();
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        setActionError("Du må være innlogget");
        return;
      }
      const res = await fetch("/api/bookings/accept", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${session.access_token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ bookingId: metadata.bookingId, offerId: metadata.offerId }),
      });
      const json = await res.json();
      if (!res.ok || json.error) {
        setActionError(json.error || "Kunne ikke godta tilbudet");
        return;
      }
      // Hvis gjest godtok, har vi clientSecret + skal redirecte til betalings-side.
      // Hvis host godtok, returneres bare status — gjest får push og må fullføre selv.
      if (json.acceptorRole === "guest" && json.clientSecret && json.bookingId) {
        const params = new URLSearchParams({
          bookingId: json.bookingId,
          clientSecret: json.clientSecret,
          publishableKey: json.publishableKey,
        });
        router.push(`/book/payment?${params.toString()}`);
        return;
      }
      await Promise.all([reloadMessages(), reloadBookingState()]);
    } catch (err) {
      setActionError(err instanceof Error ? err.message : "Noe gikk galt");
    }
  };

  const declineOffer = async () => {
    if (!bookingState?.bookingId) return;
    setActionError(null);
    try {
      const supabase = createSupabaseClient();
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        setActionError("Du må være innlogget");
        return;
      }
      const res = await fetch("/api/bookings/decline", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${session.access_token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ bookingId: bookingState.bookingId }),
      });
      const json = await res.json();
      if (!res.ok || json.error) {
        setActionError(json.error || "Kunne ikke avslå");
        return;
      }
      await Promise.all([reloadMessages(), reloadBookingState()]);
    } catch (err) {
      setActionError(err instanceof Error ? err.message : "Noe gikk galt");
    }
  };

  const openCounter = (metadata: OfferMessageMetadata) => {
    if (!metadata.bookingId || metadata.totalPrice == null) return;
    const role = metadata.proposedByRole === "host" ? "utleier" : "gjest";
    setCounterContext({
      bookingId: metadata.bookingId,
      currentOfferPrice: metadata.totalPrice,
      currentOfferLabel: `${metadata.totalPrice.toLocaleString("nb-NO")} kr fra ${role}`,
    });
  };

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
            {isSupport ? (
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white">
                <img
                  src="/tuno-pin.png"
                  alt="Tuno"
                  className="h-9 w-9 object-contain"
                />
              </div>
            ) : listingImage ? (
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

      {bookingState && bookingState.isNegotiating && (
        <NegotiationBanner state={bookingState} userId={currentUserId} />
      )}

      <div ref={messagesContainerRef} className="flex-1 overflow-y-auto p-4 space-y-3">
        {messages.length === 0 && (
          <p className="text-center text-sm text-neutral-400 mt-8">{t("startConversation")}</p>
        )}
        {messages.map((msg) => {
          const isOwn = msg.senderId === currentUserId;
          if (msg.kind === "offer" && msg.metadata) {
            const isActive =
              !!msg.metadata.offerId &&
              bookingState?.currentOfferId === msg.metadata.offerId;
            return (
              <div key={msg.id} className={`flex ${isOwn ? "justify-end" : "justify-start"}`}>
                <OfferMessageBubble
                  metadata={msg.metadata}
                  isFromMe={isOwn}
                  isActive={isActive}
                  onAccept={isActive && !isOwn ? () => acceptOffer(msg.metadata!) : undefined}
                  onCounter={isActive && !isOwn ? () => openCounter(msg.metadata!) : undefined}
                  onDecline={isActive && !isOwn ? () => declineOffer() : undefined}
                />
              </div>
            );
          }
          if (msg.kind === "offer_accepted" || msg.kind === "offer_declined" || msg.kind === "system") {
            return (
              <div key={msg.id} className="flex justify-center">
                <span className="rounded-full bg-neutral-100 px-3 py-1.5 text-xs text-neutral-500 max-w-md text-center">
                  {msg.content}
                </span>
              </div>
            );
          }
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
        {actionError && (
          <p className="text-center text-sm text-red-600">{actionError}</p>
        )}
      </div>

      {counterContext && (
        <CounterOfferModal
          bookingId={counterContext.bookingId}
          currentOfferPrice={counterContext.currentOfferPrice}
          currentOfferLabel={counterContext.currentOfferLabel}
          onClose={() => setCounterContext(null)}
          onSent={async () => {
            await Promise.all([reloadMessages(), reloadBookingState()]);
          }}
        />
      )}

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

interface NegotiationState {
  bookingId: string;
  status: string;
  currentOfferId: string | null;
  userId: string;
  hostId: string | null;
  totalPrice: number;
  isNegotiating: boolean;
}

function NegotiationBanner({ state, userId }: { state: NegotiationState; userId: string }) {
  const isMyTurn = (() => {
    switch (state.status) {
      case "awaiting_host":
      case "requested":
        return state.hostId === userId;
      case "awaiting_guest":
      case "awaiting_payment":
        return state.userId === userId;
      default:
        return false;
    }
  })();

  const text = (() => {
    switch (state.status) {
      case "awaiting_host":
      case "requested":
        return isMyTurn ? "Din tur å svare på forespørselen" : "Venter på utleier";
      case "awaiting_guest":
        return isMyTurn ? "Din tur å svare på motbudet" : "Venter på gjest";
      case "awaiting_payment":
        return isMyTurn ? "Fullfør betalingen" : "Venter på at gjest betaler";
      default:
        return "";
    }
  })();

  const isPaymentPending = state.status === "awaiting_payment";
  const Icon = isPaymentPending ? CreditCard : isMyTurn ? Bell : Hourglass;
  const colorClasses = isPaymentPending
    ? "bg-amber-50 border-b-amber-200 text-amber-900"
    : isMyTurn
      ? "bg-primary-50 border-b-primary-200 text-primary-900"
      : "bg-neutral-50 border-b-neutral-200 text-neutral-700";

  return (
    <div className={`flex items-center gap-2.5 border-b px-4 py-2.5 ${colorClasses}`}>
      <Icon className="h-4 w-4 shrink-0" />
      <span className="flex-1 text-sm font-semibold">{text}</span>
      <span className="text-sm font-bold">{state.totalPrice.toLocaleString("nb-NO")} kr</span>
    </div>
  );
}
