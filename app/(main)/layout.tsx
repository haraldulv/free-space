"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams, usePathname, useRouter } from "next/navigation";
import Navbar from "@/components/features/Navbar";
import Footer from "@/components/features/Footer";
import { createClient } from "@/lib/supabase/client";
import { ListingCategory, VehicleType } from "@/types";

function MainLayoutInner({ children }: { children: React.ReactNode }) {
  const searchParams = useSearchParams();
  const pathname = usePathname();
  const router = useRouter();
  const isSearchPage = pathname === "/search";

  const [user, setUser] = useState<{ email: string; fullName?: string } | null>(null);
  const [isHost, setIsHost] = useState(false);

  useEffect(() => {
    const supabase = createClient();

    async function checkHost(userId: string) {
      const { count } = await supabase
        .from("listings")
        .select("id", { count: "exact", head: true })
        .eq("host_id", userId)
        .limit(1);
      setIsHost((count ?? 0) > 0);
    }

    // Get initial session
    supabase.auth.getUser().then(({ data }) => {
      if (data.user) {
        setUser({
          email: data.user.email || "",
          fullName: data.user.user_metadata?.full_name,
        });
        checkHost(data.user.id);
      }
    });

    // Listen for auth changes (login/logout)
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        setUser({
          email: session.user.email || "",
          fullName: session.user.user_metadata?.full_name,
        });
        checkHost(session.user.id);
      } else {
        setUser(null);
        setIsHost(false);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const handleSignOut = async () => {
    const supabase = createClient();
    await supabase.auth.signOut();
    setUser(null);
    router.push("/");
  };

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

  const checkIn = searchParams.get("checkIn") || undefined;
  const checkOut = searchParams.get("checkOut") || undefined;

  return (
    <>
      <Navbar
        user={user}
        isHost={isHost}
        onSignOut={handleSignOut}
        selectedCategory={category}
        searchQuery={query}
        searchVehicle={vehicle}
        searchCheckIn={checkIn}
        searchCheckOut={checkOut}
      />
      <main className={`flex-1 ${isSearchPage ? "flex flex-col overflow-hidden" : ""}`}>
        {children}
      </main>
      {!isSearchPage && <Footer />}
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
