"use server";

import { createListing, updateListing, deleteListing, type CreateListingData } from "@/lib/supabase/listings";
import { createClient } from "@/lib/supabase/server";

async function getAuthUserId(): Promise<string> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return user.id;
}

export async function createListingAction(data: CreateListingData): Promise<{ id?: string; error?: string }> {
  try {
    const userId = await getAuthUserId();
    const id = await createListing(data, userId);
    return { id };
  } catch (err) {
    console.error("createListingAction error:", err);
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function updateListingAction(id: string, data: Partial<CreateListingData>): Promise<{ error?: string }> {
  try {
    const userId = await getAuthUserId();
    await updateListing(id, data, userId);
    return {};
  } catch (err) {
    console.error("updateListingAction error:", err);
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function deleteListingAction(id: string): Promise<void> {
  const userId = await getAuthUserId();
  return deleteListing(id, userId);
}
