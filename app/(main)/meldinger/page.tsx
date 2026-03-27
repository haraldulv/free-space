"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { getConversations } from "@/lib/supabase/chat";
import Container from "@/components/ui/Container";
import ConversationList from "@/components/features/ConversationList";
import ChatView from "@/components/features/ChatView";
import type { Conversation } from "@/types";

export default function MeldingerPage() {
  const searchParams = useSearchParams();
  const conversationIdParam = searchParams.get("id");
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selected, setSelected] = useState<Conversation | null>(null);
  const [userId, setUserId] = useState<string | null>(null);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return;
      setUserId(data.user.id);
      const convos = await getConversations(data.user.id);
      setConversations(convos);

      // Auto-select conversation from URL param
      if (conversationIdParam) {
        const match = convos.find((c) => c.id === conversationIdParam);
        if (match) {
          setSelected(match);
        } else {
          // Conversation exists but not in list yet (just created) - fetch its details
          const { data: convoRow } = await supabase
            .from("conversations")
            .select(`
              *,
              guest:guest_id(full_name, avatar_url),
              host:host_id(full_name, avatar_url),
              listing:listing_id(title, images)
            `)
            .eq("id", conversationIdParam)
            .single();

          if (convoRow) {
            const isGuest = convoRow.guest_id === data.user.id;
            const otherUser = isGuest
              ? (convoRow.host as Record<string, unknown>)
              : (convoRow.guest as Record<string, unknown>);
            const listing = convoRow.listing as Record<string, unknown> | null;

            const newConvo: Conversation = {
              id: convoRow.id,
              listingId: convoRow.listing_id,
              guestId: convoRow.guest_id,
              hostId: convoRow.host_id,
              bookingId: convoRow.booking_id,
              lastMessageAt: convoRow.last_message_at,
              createdAt: convoRow.created_at,
              otherUserName: (otherUser?.full_name as string) || "Anonym",
              otherUserAvatar: (otherUser?.avatar_url as string) || "",
              listingTitle: (listing?.title as string) || "",
              listingImage: ((listing?.images as string[]) || [])[0] || "",
              lastMessageText: "",
              unreadCount: 0,
            };
            setConversations((prev) => [newConvo, ...prev]);
            setSelected(newConvo);
          }
        }
      }

      setLoaded(true);
    });
  }, [conversationIdParam]);

  if (!loaded) {
    return (
      <div className="min-h-screen bg-neutral-50">
        <Container className="py-10">
          <div className="animate-pulse space-y-4">
            <div className="h-8 w-48 rounded bg-neutral-200" />
            <div className="h-96 rounded-xl bg-neutral-200" />
          </div>
        </Container>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-neutral-50">
      <Container className="py-8">
        <h1 className="text-2xl font-semibold text-neutral-900">Meldinger</h1>

        <div className="mt-6 overflow-hidden rounded-xl border border-neutral-200 bg-white" style={{ height: "calc(100vh - 200px)" }}>
          <div className="flex h-full">
            {/* Conversation list */}
            <div className={`${selected ? "hidden lg:block" : ""} w-full lg:w-80 border-r border-neutral-200 overflow-y-auto`}>
              <ConversationList
                conversations={conversations}
                selectedId={selected?.id}
                onSelect={setSelected}
              />
            </div>

            {/* Chat view */}
            <div className={`${selected ? "" : "hidden lg:flex"} flex-1 flex flex-col`}>
              {selected && userId ? (
                <ChatView
                  conversationId={selected.id}
                  currentUserId={userId}
                  otherUserName={selected.otherUserName || "Anonym"}
                  listingTitle={selected.listingTitle || ""}
                  onBack={() => setSelected(null)}
                />
              ) : (
                <div className="flex flex-1 items-center justify-center text-sm text-neutral-400">
                  Velg en samtale
                </div>
              )}
            </div>
          </div>
        </div>
      </Container>
    </div>
  );
}
