"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import ListingFormWizard from "@/components/features/listing-form/ListingFormWizard";
import { updateListingAction } from "../../actions";
import type { CreateListingData } from "@/lib/supabase/listings";
import type { Listing } from "@/types";

function listingToFormData(listing: Listing): Partial<CreateListingData> {
  return {
    category: listing.category,
    title: listing.title,
    description: listing.description,
    spots: listing.spots,
    maxVehicleLength: listing.maxVehicleLength,
    address: listing.location.address,
    city: listing.location.city,
    region: listing.location.region,
    lat: listing.location.lat,
    lng: listing.location.lng,
    images: listing.images,
    amenities: listing.amenities,
    price: listing.price,
    priceUnit: listing.priceUnit,
    instantBooking: listing.instantBooking || false,
    spotMarkers: listing.spotMarkers || [],
    hideExactLocation: listing.hideExactLocation || false,
  };
}

export default function EditListingPage() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;
  const [userId, setUserId] = useState<string | null>(null);
  const [initialData, setInitialData] = useState<Partial<CreateListingData> | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (!user) {
        router.push("/login");
        return;
      }
      setUserId(user.id);

      const { data: row } = await supabase
        .from("listings")
        .select("*")
        .eq("id", id)
        .single();

      if (!row || row.host_id !== user.id) {
        router.push("/dashboard?tab=listings");
        return;
      }

      const listing: Listing = {
        id: row.id,
        title: row.title,
        description: row.description,
        category: row.category,
        images: row.images,
        location: { city: row.city, region: row.region, address: row.address, lat: row.lat, lng: row.lng },
        price: row.price,
        priceUnit: row.price_unit,
        rating: row.rating,
        reviewCount: row.review_count,
        amenities: row.amenities,
        host: { id: row.host_id, name: row.host_name, avatar: row.host_avatar, responseRate: row.host_response_rate, responseTime: row.host_response_time, joinedYear: row.host_joined_year, listingsCount: row.host_listings_count },
        spots: row.spots,
        maxVehicleLength: row.max_vehicle_length,
        tags: row.tags,
        instantBooking: row.instant_booking,
        spotMarkers: row.spot_markers,
        hideExactLocation: row.hide_exact_location,
      };

      setInitialData(listingToFormData(listing));
      setLoading(false);
    });
  }, [router, id]);

  if (loading || !userId || !initialData) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <p className="text-sm text-neutral-400">Laster annonse...</p>
      </div>
    );
  }

  return (
    <ListingFormWizard
      userId={userId}
      mode="edit"
      listingId={id}
      initialData={initialData}
      onSubmit={async (data) => {
        const result = await updateListingAction(id, data);
        if (result.error) throw new Error(result.error);
      }}
    />
  );
}
