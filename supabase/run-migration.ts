/**
 * Run migration and seed data against Supabase using the Management API.
 * Usage: npx tsx supabase/run-migration.ts
 */

import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "fs";
import { join } from "path";

const SUPABASE_URL = "https://mqyeptwrfrhwxtysccnp.supabase.co";
const SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeWVwdHdyZnJod3h0eXNjY25wIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDI4NzM5MywiZXhwIjoyMDg5ODYzMzkzfQ.Mql-AjFXhYmvD6-_479ZRjLSZxVEUvihLVHd5iuDUFU";

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function runSQL(sql: string, label: string) {
  console.log(`\n--- ${label} ---`);

  // Split into individual statements
  const statements = sql
    .split(/;\s*$/m)
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !s.startsWith("--"));

  console.log(`Found ${statements.length} statements`);

  for (let i = 0; i < statements.length; i++) {
    const stmt = statements[i];
    const preview = stmt.substring(0, 80).replace(/\n/g, " ");
    try {
      const { error } = await supabase.rpc("exec_sql", { sql_string: stmt + ";" });
      if (error) {
        // Try via fetch directly to the Supabase postgres endpoint
        throw error;
      }
      console.log(`  [${i + 1}/${statements.length}] OK: ${preview}...`);
    } catch {
      console.log(`  [${i + 1}/${statements.length}] SKIP (will use REST API): ${preview}...`);
    }
  }
}

async function seedViaREST() {
  console.log("\n--- Seeding listings via REST API ---");

  // Import mock listings
  const { mockListings } = await import("../data/mock-listings");

  console.log(`Total listings to seed: ${mockListings.length}`);

  // Transform to DB format
  const rows = mockListings.map((l) => ({
    id: l.id,
    title: l.title,
    description: l.description,
    category: l.category,
    images: l.images,
    city: l.location.city,
    region: l.location.region,
    address: l.location.address,
    lat: l.location.lat,
    lng: l.location.lng,
    price: l.price,
    price_unit: l.priceUnit,
    rating: l.rating,
    review_count: l.reviewCount,
    amenities: l.amenities,
    max_vehicle_length: l.maxVehicleLength ?? null,
    spots: l.spots,
    tags: l.tags || [],
    host_name: l.host.name,
    host_avatar: l.host.avatar,
    host_response_rate: l.host.responseRate,
    host_response_time: l.host.responseTime,
    host_joined_year: l.host.joinedYear,
    host_listings_count: l.host.listingsCount,
  }));

  // Insert in batches of 100
  const BATCH = 100;
  for (let i = 0; i < rows.length; i += BATCH) {
    const batch = rows.slice(i, i + BATCH);
    const { error } = await supabase.from("listings").upsert(batch, { onConflict: "id" });
    if (error) {
      console.error(`  Batch ${i / BATCH + 1} error:`, error.message);
    } else {
      console.log(`  Batch ${i / BATCH + 1}: inserted ${batch.length} listings (${i + batch.length}/${rows.length})`);
    }
  }

  // Verify
  const { count } = await supabase.from("listings").select("*", { count: "exact", head: true });
  console.log(`\nTotal listings in DB: ${count}`);
}

async function main() {
  console.log("=== Free Space: Database Setup ===\n");

  // Step 1: We need to create tables via SQL Editor since REST API can't run DDL
  // Let's check if listings table exists
  const { error } = await supabase.from("listings").select("id", { count: "exact", head: true });

  if (error && error.code === "PGRST116" || error?.message?.includes("does not exist")) {
    console.log("Tables don't exist yet.");
    console.log("\nPlease run the migration SQL first:");
    console.log("1. Go to https://supabase.com/dashboard/project/mqyeptwrfrhwxtysccnp/sql/new");
    console.log("2. Paste contents of supabase/migration.sql");
    console.log("3. Click 'Run'");
    console.log("4. Then re-run this script to seed data");
    process.exit(1);
  }

  if (error) {
    console.log("Table check result:", error.message);
    console.log("Tables may not exist. Let's try to create them...");
    console.log("\nPlease run migration.sql in Supabase SQL Editor first.");
    process.exit(1);
  }

  console.log("Tables exist! Proceeding to seed...");

  // Step 2: Seed data via REST API (works with service role key, bypasses RLS)
  await seedViaREST();

  console.log("\n=== Done! ===");
}

main().catch(console.error);
