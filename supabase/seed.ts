/**
 * Seed script: generates SQL INSERT statements for all mock listings.
 * Run with: npx tsx supabase/seed.ts > supabase/seed.sql
 */

// We import the data directly
import { mockListings } from "../data/mock-listings";

function escapeSQL(str: string): string {
  return str.replace(/'/g, "''");
}

function toSQLArray(arr: string[]): string {
  if (arr.length === 0) return "'{}'";
  return `'{${arr.map((s) => `"${escapeSQL(s)}"`).join(",")}}'`;
}

console.log("-- Free Space: Seed data");
console.log(`-- Generated: ${new Date().toISOString()}`);
console.log(`-- Total listings: ${mockListings.length}`);
console.log("");
console.log("-- Temporarily allow inserts without auth for seeding");
console.log("alter table public.listings disable row level security;");
console.log("");

// Batch insert in chunks of 50
const CHUNK = 50;
for (let i = 0; i < mockListings.length; i += CHUNK) {
  const chunk = mockListings.slice(i, i + CHUNK);

  console.log(
    "insert into public.listings (id, title, description, category, images, city, region, address, lat, lng, price, price_unit, rating, review_count, amenities, max_vehicle_length, spots, tags, host_name, host_avatar, host_response_rate, host_response_time, host_joined_year, host_listings_count) values"
  );

  const rows = chunk.map((l) => {
    const values = [
      `'${escapeSQL(l.id)}'`,
      `'${escapeSQL(l.title)}'`,
      `'${escapeSQL(l.description)}'`,
      `'${l.category}'`,
      toSQLArray(l.images),
      `'${escapeSQL(l.location.city)}'`,
      `'${escapeSQL(l.location.region)}'`,
      `'${escapeSQL(l.location.address)}'`,
      l.location.lat,
      l.location.lng,
      l.price,
      `'${l.priceUnit}'`,
      l.rating,
      l.reviewCount,
      toSQLArray(l.amenities),
      l.maxVehicleLength ?? "null",
      l.spots,
      toSQLArray(l.tags || []),
      `'${escapeSQL(l.host.name)}'`,
      `'${escapeSQL(l.host.avatar)}'`,
      l.host.responseRate,
      `'${escapeSQL(l.host.responseTime)}'`,
      l.host.joinedYear,
      l.host.listingsCount,
    ];
    return `(${values.join(", ")})`;
  });

  console.log(rows.join(",\n") + ";");
  console.log("");
}

console.log("-- Re-enable RLS");
console.log("alter table public.listings enable row level security;");
