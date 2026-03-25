import { notFound } from "next/navigation";
import { MapPin, Users } from "lucide-react";
import { getListingById, getAllListingIds } from "@/lib/supabase/listings";
import Container from "@/components/ui/Container";
import Badge from "@/components/ui/Badge";
import ImageGallery from "@/components/features/ImageGallery";
import AmenityList from "@/components/features/AmenityList";
import HostCard from "@/components/features/HostCard";
import BookingForm from "@/components/features/BookingForm";
import ListingFavoriteButton from "@/components/features/ListingFavoriteButton";

export const dynamic = "force-dynamic";

export default async function ListingPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const listing = await getListingById(id);
  if (!listing) notFound();

  return (
    <Container className="py-8">
      <ImageGallery images={listing.images} alt={listing.title} />

      <div className="mt-8 grid grid-cols-1 gap-10 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <div className="flex items-center gap-3">
            <Badge>
              {listing.category === "parking" ? "Parkering" : "Campingplass"}
            </Badge>
            {listing.maxVehicleLength && (
              <Badge variant="secondary">
                Max {listing.maxVehicleLength}m
              </Badge>
            )}
          </div>

          <div className="mt-3 flex items-start justify-between gap-4">
            <h1 className="text-3xl font-bold text-neutral-900">
              {listing.title}
            </h1>
            <ListingFavoriteButton listingId={listing.id} />
          </div>

          <div className="mt-2 flex items-center gap-4 text-neutral-500">
            <div className="flex items-center gap-1">
              <MapPin className="h-4 w-4" />
              {listing.location.address}, {listing.location.city}
            </div>
            <div className="flex items-center gap-1">
              <Users className="h-4 w-4" />
              {listing.spots} plasser
            </div>
          </div>

          <div className="mt-6 border-t border-neutral-100 pt-6">
            <h2 className="text-lg font-semibold text-neutral-900">
              Om denne plassen
            </h2>
            <p className="mt-2 leading-relaxed text-neutral-600">
              {listing.description}
            </p>
          </div>

          <div className="mt-6 border-t border-neutral-100 pt-6">
            <h2 className="mb-4 text-lg font-semibold text-neutral-900">
              Fasiliteter
            </h2>
            <AmenityList amenities={listing.amenities} />
          </div>

          <div className="mt-6 border-t border-neutral-100 pt-6">
            <HostCard host={listing.host} />
          </div>
        </div>

        <div className="lg:col-span-1">
          <BookingForm listing={listing} />
        </div>
      </div>
    </Container>
  );
}
