import { createClient } from "./client";
import type { AppNotification } from "@/types";

export async function getNotifications(userId: string): Promise<AppNotification[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("notifications")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(20);

  if (!data) return [];

  return data.map((row) => ({
    id: row.id,
    userId: row.user_id,
    type: row.type,
    title: row.title,
    body: row.body,
    metadata: row.metadata,
    read: row.read,
    createdAt: row.created_at,
  }));
}

export async function getUnreadCount(userId: string): Promise<number> {
  const supabase = createClient();
  const { count } = await supabase
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("read", false);

  return count ?? 0;
}

export async function markAsRead(notificationId: string): Promise<void> {
  const supabase = createClient();
  await supabase
    .from("notifications")
    .update({ read: true })
    .eq("id", notificationId);
}

export async function markAllAsRead(userId: string): Promise<void> {
  const supabase = createClient();
  await supabase
    .from("notifications")
    .update({ read: true })
    .eq("user_id", userId)
    .eq("read", false);
}
