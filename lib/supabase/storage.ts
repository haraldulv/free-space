import { createClient } from "./client";

export async function uploadListingImage(file: File, userId: string): Promise<string> {
  const supabase = createClient();
  const ext = file.name.split(".").pop() || "jpg";
  const path = `${userId}/${crypto.randomUUID()}.${ext}`;

  const { error } = await supabase.storage
    .from("listing-images")
    .upload(path, file, { contentType: file.type });

  if (error) throw new Error(error.message);

  const { data } = supabase.storage
    .from("listing-images")
    .getPublicUrl(path);

  return data.publicUrl;
}

export async function deleteListingImage(url: string): Promise<void> {
  const supabase = createClient();
  // Extract path from public URL
  const match = url.match(/listing-images\/(.+)$/);
  if (!match) return;

  await supabase.storage.from("listing-images").remove([match[1]]);
}
