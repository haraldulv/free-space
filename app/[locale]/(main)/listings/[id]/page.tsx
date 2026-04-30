import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { MapPin, Users, Clock } from "lucide-react";
import { getTranslations } from "next-intl/server";
import { createClient } from "@/lib/supabase/server";
import { getListingById, getFutureBookedDates } from "@/lib/supabase/listings";
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
import ListingDistanceBadge from "@/components/features/ListingDistanceBadge";
import ReviewList from "@/components/features/ReviewList";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string; locale: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const listing = await getListingById(id);
  if (!listing) return {};

  const description = listing.description.length > 160
    ? `${listing.description.slice(0, 157)}...`
    : listing.description;
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";
  const url = `${siteUrl}/listings/${listing.id}`;

  return {
    title: `${listing.title} — Tuno`,
    description,
    alternates: { canonical: url },
    openGraph: {
      title: listing.title,
      description,
      url,
      siteName: "Tuno",
      type: "website",
      locale: "nb_NO",
      images: listing.images.length > 0
        ? [{ url: listing.images[0], alt: listing.title }]
        : undefined,
    },
    twitter: {
      card: "summary_large_image",
      title: listing.title,
      description,
      images: listing.images[0] ? [listing.images[0]] : undefined,
    },
  };
}

export default async function ListingPage({
  params,
}: {
  params: Promise<{ id: string; locale: string }>;
}) {
  const { id } = await params;
  const [listing, reviews, bookedDates, tListing, tCategory] = await Promise.all([
    getListingById(id),
    getListingReviews(id),
    getFutureBookedDates(id),
    getTranslations("listing"),
    getTranslations("category"),
  ]);
  if (!listing) notFound();

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const isOwner = user?.id === listing.host.id;

  const listingTypeMap = {
    parking: "ParkingFacility",
    camping: "Campground",
  } as const;
  const jsonLd: Record<string, unknown> = {
    "@context": "https://schema.org",
    "@type": listingTypeMap[listing.category] ?? "LodgingBusiness",
    name: listing.title,
    description: listing.description,
    image: listing.images,
    address: {
      "@type": "PostalAddress",
      addressLocality: listing.location.city,
      addressRegion: listing.location.region,
      addressCountry: "NO",
      ...(listing.hideExactLocation ? {} : { streetAddress: listing.location.address }),
    },
    ...(listing.hideExactLocation
      ? {}
      : {
          geo: {
            "@type": "GeoCoordinates",
            latitude: listing.location.lat,
            longitude: listing.location.lng,
          },
        }),
    priceRange: `${listing.price} NOK / ${listing.priceUnit === "hour" ? "hour" : "night"}`,
    ...(listing.reviewCount > 0
      ? {
          aggregateRating: {
            "@type": "AggregateRating",
            ratingValue: listing.rating,
            reviewCount: listing.reviewCount,
          },
        }
      : {}),
    url: `https://tuno.no/listings/${listing.id}`,
  };

  return (
    <Container className="py-8">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <ImageGallery images={listing.images} alt={listing.title} />

      <div className="mt-8 grid grid-cols-1 gap-6 lg:gap-10 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <div className="flex items-center gap-3">
            <Badge>
              {listing.category === "parking" ? tCategory("parking") : tCategory("camping")}
            </Badge>
            {listing.maxVehicleLength && (
              <Badge variant="secondary">
                {tListing("maxLength", { length: listing.maxVehicleLength })}
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

          <div className="mt-2 flex items-center gap-4 text-neutral-500 flex-wrap">
            <div className="flex items-center gap-1">
              <MapPin className="h-4 w-4" />
              {listing.hideExactLocation
                ? `${listing.location.city}, ${listing.location.region}`
                : `${listing.location.address}, ${listing.location.city}`}
            </div>
            <ListingDistanceBadge lat={listing.location.lat} lng={listing.location.lng} />
            <div className="flex items-center gap-1">
              <Users className="h-4 w-4" />
              {tListing("spotsAvailable", { count: listing.spots })}
            </div>
            <div className="flex items-center gap-1">
              <Clock className="h-4 w-4" />
              {tListing("checkInOutTimes", {
                checkIn: listing.checkInTime || "15:00",
                checkOut: listing.checkOutTime || "11:00",
              })}
            </div>
          </div>

          <div className="mt-6 border-t border-neutral-100 pt-6">
            <h2 className="text-lg font-semibold text-neutral-900">
              {tListing("description")}
            </h2>
            <p className="mt-2 leading-relaxed text-neutral-600">
              {listing.description}
            </p>
          </div>

          {listing.amenities.length > 0 && (
            <div className="mt-6 border-t border-neutral-100 pt-6">
              <h2 className="mb-4 text-lg font-semibold text-neutral-900">
                {tListing("amenities")}
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
                <h2 className="mb-4 text-lg font-semibold text-neutral-900">{tListing("extras")}</h2>
                {listingExtras.length > 0 && (
                  <div className="mb-5">
                    <p className="mb-2 text-sm font-medium text-neutral-700">{tListing("extrasShared")}</p>
                    <ExtraList extras={listingExtras} />
                  </div>
                )}
                {spotsWithExtras.length > 0 && (
                  <div className="space-y-3">
                    <p className="text-sm font-medium text-neutral-700">{tListing("extrasPerSpot")}</p>
                    {spotsWithExtras.map((spot, idx) => (
                      <div key={spot.id ?? idx} className="rounded-lg border border-neutral-200 p-4">
                        <p className="mb-3 text-sm font-semibold text-neutral-900">
                          {spot.label?.trim() || tListing("spotLabel", { number: idx + 1 })}
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
              {listing.hideExactLocation ? tListing("approximateLocation") : tListing("location")}
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
                {tListing("exactLocationSharedAfterBooking")}
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
              {tListing("ownerNotice")}
            </div>
          ) : (
            <BookingForm listing={listing} bookedDates={bookedDates} />
          )}
        </div>
      </div>
    </Container>
  );
}
