"use server";

import { createListing, updateListing, deleteListing, type CreateListingData } from "@/lib/supabase/listings";
import { createClient } from "@/lib/supabase/server";

async function getAuthUserId(): Promise<string> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return user.id;
}

export async function createListingAction(data: CreateListingData): Promise<string> {
  const userId = await getAuthUserId();
  return createListing(data, userId);
}

export async function updateListingAction(id: string, data: Partial<CreateListingData>): Promise<void> {
  const userId = await getAuthUserId();
  return updateListing(id, data, userId);
}

export async function deleteListingAction(id: string): Promise<void> {
  const userId = await getAuthUserId();
  return deleteListing(id, userId);
}
