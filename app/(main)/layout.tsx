"use client";

import { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import Navbar from "@/components/features/Navbar";
import Footer from "@/components/features/Footer";
import { ListingCategory, VehicleType } from "@/types";

function MainLayoutInner({ children }: { children: React.ReactNode }) {
  const searchParams = useSearchParams();

  const rawCategory = searchParams.get("category");
  const category =
    rawCategory === "parking" || rawCategory === "camping"
      ? (rawCategory as ListingCategory)
      : undefined;

  const query = searchParams.get("query") || undefined;

  const rawVehicle = searchParams.get("vehicle");
  const vehicle =
    rawVehicle === "car" ||
    rawVehicle === "van" ||
    rawVehicle === "campervan" ||
    rawVehicle === "motorhome"
      ? (rawVehicle as VehicleType)
      : undefined;

  return (
    <>
      <Navbar
        selectedCategory={category}
        searchQuery={query}
        searchVehicle={vehicle}
      />
      <main className="flex-1">{children}</main>
      <Footer />
    </>
  );
}

export default function MainLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <Suspense>
      <MainLayoutInner>{children}</MainLayoutInner>
    </Suspense>
  );
}
