"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { MessageCircle } from "lucide-react";
import { getOrCreateConversationAction } from "@/app/(main)/meldinger/actions";
import Button from "@/components/ui/Button";

interface ContactHostButtonProps {
  listingId: string;
  hostId: string;
}

export default function ContactHostButton({ listingId, hostId }: ContactHostButtonProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  const handleClick = async () => {
    setLoading(true);
    const result = await getOrCreateConversationAction({ listingId, hostId });
    setLoading(false);

    if (result.error) {
      alert(result.error);
      return;
    }

    window.location.href = `/meldinger?id=${result.conversationId}`;
  };

  return (
    <Button variant="ghost" size="sm" onClick={handleClick} disabled={loading} className="mt-4 w-full border border-neutral-300">
      <MessageCircle className="mr-2 h-4 w-4" />
      {loading ? "Åpner..." : "Kontakt utleier"}
    </Button>
  );
}
