import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { sendPushToAllAdmins, sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

/**
 * Pinger admins (hvis gjest har sendt) eller gjest (hvis admin har sendt).
 * Brukes fra iOS-klienten etter at en support-melding er insertet direkte
 * mot Supabase, og fra web-admin når admin svarer.
 *
 * Body: { conversationId: string, content: string }
 */
export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
    }
    const token = authHeader.slice(7);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return NextResponse.json({ error: "Ugyldig token" }, { status: 401 });
    }

    const body = await request.json();
    const { conversationId, content } = body as { conversationId: string; content: string };
    if (!conversationId || !content) {
      return NextResponse.json({ error: "Manglende felt" }, { status: 400 });
    }

    const { data: convo } = await supabase
      .from("conversations")
      .select("id, type, guest_id")
      .eq("id", conversationId)
      .single();

    if (!convo || convo.type !== "support") {
      return NextResponse.json({ error: "Ikke en support-samtale" }, { status: 400 });
    }

    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("is_admin, full_name")
      .eq("id", user.id)
      .single();

    const senderIsAdmin = senderProfile?.is_admin === true;
    const preview = content.slice(0, 120);

    if (senderIsAdmin) {
      // Admin svarer → push til gjest
      await sendPushToUser(
        convo.guest_id,
        "Tuno support svarte",
        preview,
        { conversationId, type: "support_reply" },
        { conversationId },
      );
    } else {
      // Gjest stiller spørsmål → push til alle admins
      const senderName = senderProfile?.full_name || "En bruker";
      await sendPushToAllAdmins(
        `Support: ${senderName}`,
        preview,
        { conversationId, type: "support_request" },
      );
    }

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("POST /api/messages/notify-support error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
