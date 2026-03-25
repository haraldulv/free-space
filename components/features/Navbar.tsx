"use client";

import { useState, useRef, useEffect } from "react";
import Link from "next/link";
import { useRouter, usePathname } from "next/navigation";
import { Menu, Languages } from "lucide-react";
import SearchBar from "./SearchBar";
import { ListingCategory, VehicleType } from "@/types";

interface NavbarProps {
  user?: { email: string; fullName?: string } | null;
  isHost?: boolean;
  onSignOut?: () => void;
  selectedCategory?: ListingCategory;
  onCategoryChange?: (category?: ListingCategory) => void;
  searchQuery?: string;
  searchVehicle?: VehicleType;
}

export default function Navbar({
  user,
  isHost,
  onSignOut,
  selectedCategory,
  onCategoryChange,
  searchQuery,
  searchVehicle,
}: NavbarProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const router = useRouter();
  const pathname = usePathname();
  const isSearchPage = pathname === "/search";

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  // On homepage: match Container padding (px-6 sm:px-10 lg:px-20)
  // On search page: tighter padding (px-5 sm:px-6 lg:px-8)
  const padClass = isSearchPage
    ? "px-5 sm:px-6 lg:px-8"
    : "px-6 sm:px-10 lg:px-20 mx-auto max-w-[1760px]";

  const isHome = pathname === "/";

  return (
    <header className={`sticky top-0 z-50 border-b border-neutral-200/60 ${isHome ? "glass-navbar" : "bg-white"}`}>
      <div className={`flex items-center justify-between gap-4 ${padClass} ${isSearchPage ? "py-3" : "pt-4 pb-2"}`}>
        {/* Logo */}
        <Link href="/" className="shrink-0 group">
          <span className="text-[22px] text-neutral-900 transition-opacity group-hover:opacity-70 lowercase">
            <span className="font-extralight tracking-tighter">free</span>
            <span className="font-bold italic tracking-tight">space</span>
          </span>
        </Link>

        {/* Compact search bar — centered in row 1 on search page */}
        {isSearchPage && (
          <div className="flex-1 flex justify-center">
            <SearchBar initialQuery={searchQuery} initialVehicle={searchVehicle} initialCategory={selectedCategory} compact />
          </div>
        )}

        {!isSearchPage && <div className="flex-1" />}

        {/* Right: Actions */}
        <div className="flex items-center gap-1 shrink-0">
          <Link
            href={user && isHost ? "/dashboard?tab=annonser" : "/bli-utleier"}
            className="hidden lg:block rounded-full px-4 py-2 text-sm font-medium text-neutral-700 transition-colors hover:bg-neutral-100"
          >
            {user && isHost ? "Mine annonser" : "Bli utleier"}
          </Link>

          <button
            className="flex items-center justify-center rounded-full border border-neutral-200 bg-white p-2 shadow-sm text-neutral-500 transition-all hover:shadow-md"
            aria-label="Endre språk"
          >
            <Languages className="h-4 w-4" />
          </button>

          <div className="relative" ref={menuRef}>
            <button
              onClick={() => setMenuOpen(!menuOpen)}
              className="flex items-center justify-center rounded-full border border-neutral-200 bg-white p-2 shadow-sm transition-all hover:shadow-md"
            >
              <Menu className="h-4 w-4 text-neutral-600" />
            </button>

            {menuOpen && (
              <div className="animate-fade-in absolute right-0 mt-2 w-56 rounded-xl border border-neutral-100 bg-white py-2 shadow-xl">
                {user ? (
                  <>
                    <div className="px-4 py-2 text-sm text-neutral-500 border-b border-neutral-100">
                      {user.fullName || user.email}
                    </div>
                    <Link href="/dashboard" className="block px-4 py-2.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50" onClick={() => setMenuOpen(false)}>
                      Kontrollpanel
                    </Link>
                    <Link href="/dashboard" className="block px-4 py-2.5 text-sm text-neutral-700 hover:bg-neutral-50" onClick={() => setMenuOpen(false)}>
                      Mine bestillinger
                    </Link>
                    {isHost ? (
                      <Link href="/dashboard?tab=annonser" className="block px-4 py-2.5 text-sm text-neutral-700 hover:bg-neutral-50" onClick={() => setMenuOpen(false)}>
                        Mine annonser
                      </Link>
                    ) : (
                      <Link href="/bli-utleier" className="block px-4 py-2.5 text-sm text-neutral-700 hover:bg-neutral-50" onClick={() => setMenuOpen(false)}>
                        Bli utleier
                      </Link>
                    )}
                    <div className="my-1 border-t border-neutral-100" />
                    <button onClick={() => { setMenuOpen(false); onSignOut?.(); }} className="w-full px-4 py-2.5 text-left text-sm text-neutral-700 hover:bg-neutral-50">
                      Logg ut
                    </button>
                  </>
                ) : (
                  <>
                    <Link href="/login" className="block px-4 py-2.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50" onClick={() => setMenuOpen(false)}>
                      Logg inn
                    </Link>
                    <Link href="/register" className="block px-4 py-2.5 text-sm text-neutral-700 hover:bg-neutral-50" onClick={() => setMenuOpen(false)}>
                      Registrer deg
                    </Link>
                    <div className="my-1 border-t border-neutral-100" />
                    <Link href="/bli-utleier" className="block px-4 py-2.5 text-sm text-neutral-700 hover:bg-neutral-50" onClick={() => setMenuOpen(false)}>
                      Bli utleier
                    </Link>
                  </>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Full search bar row — only on non-search pages */}
      {!isSearchPage && (
        <div className={`hidden md:flex justify-center pb-5 pt-2 ${padClass}`}>
          <div className="w-full max-w-2xl">
            <SearchBar initialQuery={searchQuery} initialVehicle={searchVehicle} initialCategory={selectedCategory} />
          </div>
        </div>
      )}

      {/* Mobile search bar — only on non-search pages */}
      {!isSearchPage && (
        <div className={`pb-3 md:hidden ${padClass}`}>
          <SearchBar initialQuery={searchQuery} initialVehicle={searchVehicle} initialCategory={selectedCategory} />
        </div>
      )}
    </header>
  );
}
