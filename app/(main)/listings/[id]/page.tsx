import { notFound } from "next/navigation";
import { MapPin, Users, Clock } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { getListingById, getAllListingIds, getFutureBookedDates } from "@/lib/supabase/listings";
import { getListingReviews } from "@/lib/supabase/reviews";
import Container from "@/components/ui/Container";
import Badge from "@/components/ui/Badge";
import ImageGallery from "@/components/features/ImageGallery";
import AmenityList from "@/components/features/AmenityList";
import ExtraList from "@/components/features/ExtraList";
import HostCard from "@/components/features/HostCard";
import BookingForm from "@/components/features/BookingForm";
import ListingFavoriteButton from "@/components/features/ListingFavoriteButton";
import ShareButton from "@/components/features/ShareButton";
import ListingMap from "@/components/features/ListingMap";
import ReviewList from "@/components/features/ReviewList";

export const dynamic = "force-dynamic";

export default async function ListingPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const [listing, reviews, bookedDates] = await Promise.all([
    getListingById(id),
    getListingReviews(id),
    getFutureBookedDates(id),
  ]);
  if (!listing) notFound();

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const isOwner = user?.id === listing.host.id;

  return (
    <Container className="py-8">
      <ImageGallery images={listing.images} alt={listing.title} />

      <div className="mt-8 grid grid-cols-1 gap-6 lg:gap-10 lg:grid-cols-3">
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
            <div className="flex items-center gap-2">
              <ShareButton title={listing.title} listingId={listing.id} />
              <ListingFavoriteButton listingId={listing.id} />
            </div>
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
            <div className="flex items-center gap-1">
              <Clock className="h-4 w-4" />
              Inn {listing.checkInTime || "15:00"} / Ut {listing.checkOutTime || "11:00"}
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

          {listing.amenities.length > 0 && (
            <div className="mt-6 border-t border-neutral-100 pt-6">
              <h2 className="mb-4 text-lg font-semibold text-neutral-900">
                Fasiliteter
              </h2>
              <AmenityList amenities={listing.amenities} />
            </div>
          )}

          {(() => {
            const listingExtras = listing.extras ?? [];
            const spotsWithExtras = (listing.spotMarkers ?? []).filter((s) => (s.extras ?? []).length > 0);
            if (listingExtras.length === 0 && spotsWithExtras.length === 0) return null;
            return (
              <div className="mt-6 border-t border-neutral-100 pt-6">
                <h2 className="mb-4 text-lg font-semibold text-neutral-900">Tillegg</h2>
                {listingExtras.length > 0 && (
                  <div className="mb-5">
                    <p className="mb-2 text-sm font-medium text-neutral-700">Felles tillegg</p>
                    <ExtraList extras={listingExtras} />
                  </div>
                )}
                {spotsWithExtras.length > 0 && (
                  <div className="space-y-3">
                    <p className="text-sm font-medium text-neutral-700">Per plass</p>
                    {spotsWithExtras.map((spot, idx) => (
                      <div key={spot.id ?? idx} className="rounded-lg border border-neutral-200 p-4">
                        <p className="mb-3 text-sm font-semibold text-neutral-900">
                          {spot.label?.trim() || `Plass ${idx + 1}`}
                        </p>
                        <ExtraList extras={spot.extras ?? []} />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })()}

          <div className="mt-6 border-t border-neutral-100 pt-6">
            <h2 className="mb-4 text-lg font-semibold text-neutral-900">
              {listing.hideExactLocation ? "Omtrentlig plassering" : "Plassering"}
            </h2>
            {!listing.hideExactLocation && (
              <div className="mb-3 flex items-center gap-1 text-sm text-neutral-500">
                <MapPin className="h-4 w-4" />
                {listing.location.address}
              </div>
            )}
            <ListingMap
              lat={listing.location.lat}
              lng={listing.location.lng}
              spotMarkers={listing.spotMarkers}
              hideExactLocation={listing.hideExactLocation}
            />
            {listing.hideExactLocation && (
              <p className="mt-2 text-xs text-neutral-400">
                Eksakt adresse deles etter bekreftet booking.
              </p>
            )}
          </div>

          <div className="mt-6 border-t border-neutral-100 pt-6">
            <HostCard host={listing.host} listingId={listing.id} />
          </div>

          <div className="mt-6 border-t border-neutral-100 pt-6">
            <ReviewList reviews={reviews} rating={listing.rating} reviewCount={listing.reviewCount} />
          </div>
        </div>

        <div className="lg:col-span-1">
          {isOwner ? (
            <div className="lg:sticky lg:top-24 rounded-xl border border-neutral-200 bg-neutral-50 p-6 text-sm text-neutral-600">
              Dette er din egen annonse. Bruk "Mine annonser" for å redigere den.
            </div>
          ) : (
            <BookingForm listing={listing} bookedDates={bookedDates} />
          )}
        </div>
      </div>
    </Container>
  );
}
