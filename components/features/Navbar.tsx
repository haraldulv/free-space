"use client";

import { useState, useRef, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Menu, Globe, CircleUserRound } from "lucide-react";
import Container from "@/components/ui/Container";
import SearchBar from "./SearchBar";
import { ListingCategory, VehicleType } from "@/types";

interface NavbarProps {
  user?: { email: string; fullName?: string } | null;
  onSignOut?: () => void;
  selectedCategory?: ListingCategory;
  onCategoryChange?: (category?: ListingCategory) => void;
  searchQuery?: string;
  searchVehicle?: VehicleType;
}

export default function Navbar({
  user,
  onSignOut,
  selectedCategory,
  onCategoryChange,
  searchQuery,
  searchVehicle,
}: NavbarProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const router = useRouter();

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <header className="sticky top-0 z-50 bg-neutral-100 border-b border-neutral-200">
      {/* Row 1: Logo + Search + Actions */}
      <Container>
        <div className="flex items-center justify-between gap-4 pt-4 pb-2">
          {/* Logo */}
          <Link href="/" className="shrink-0">
            <span className="text-xl font-bold text-primary-600">
              Free Space
            </span>
          </Link>

          <div className="flex-1" />

          {/* Right: Actions */}
          <div className="flex items-center gap-1 shrink-0">
            <Link
              href="#"
              className="hidden lg:block rounded-full px-4 py-2 text-sm font-medium text-neutral-700 transition-colors hover:bg-neutral-100"
            >
              Bli utleier
            </Link>

            <button
              className="rounded-full p-2.5 text-neutral-700 transition-colors hover:bg-neutral-100"
              aria-label="Endre språk"
            >
              <Globe className="h-5 w-5" />
            </button>

            <div className="relative" ref={menuRef}>
              <button
                onClick={() => setMenuOpen(!menuOpen)}
                className="flex items-center gap-2 rounded-full border border-neutral-300 py-1.5 pl-3 pr-1.5 transition-shadow hover:shadow-md"
              >
                <Menu className="h-4 w-4 text-neutral-700" />
                <CircleUserRound className="h-8 w-8 text-neutral-500" />
              </button>

              {menuOpen && (
                <div className="absolute right-0 mt-2 w-56 rounded-xl border border-neutral-200 bg-white py-2 shadow-lg">
                  {user ? (
                    <>
                      <div className="px-4 py-2 text-sm text-neutral-500 border-b border-neutral-100">
                        {user.fullName || user.email}
                      </div>
                      <Link
                        href="/dashboard"
                        className="block px-4 py-2.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
                        onClick={() => setMenuOpen(false)}
                      >
                        Kontrollpanel
                      </Link>
                      <Link
                        href="/dashboard"
                        className="block px-4 py-2.5 text-sm text-neutral-700 hover:bg-neutral-50"
                        onClick={() => setMenuOpen(false)}
                      >
                        Mine bestillinger
                      </Link>
                      <div className="my-1 border-t border-neutral-100" />
                      <button
                        onClick={() => {
                          setMenuOpen(false);
                          onSignOut?.();
                        }}
                        className="w-full px-4 py-2.5 text-left text-sm text-neutral-700 hover:bg-neutral-50"
                      >
                        Logg ut
                      </button>
                    </>
                  ) : (
                    <>
                      <Link
                        href="/login"
                        className="block px-4 py-2.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
                        onClick={() => setMenuOpen(false)}
                      >
                        Logg inn
                      </Link>
                      <Link
                        href="/register"
                        className="block px-4 py-2.5 text-sm text-neutral-700 hover:bg-neutral-50"
                        onClick={() => setMenuOpen(false)}
                      >
                        Registrer deg
                      </Link>
                      <div className="my-1 border-t border-neutral-100" />
                      <Link
                        href="#"
                        className="block px-4 py-2.5 text-sm text-neutral-700 hover:bg-neutral-50"
                        onClick={() => setMenuOpen(false)}
                      >
                        Bli utleier
                      </Link>
                    </>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Search bar row — centered, below logo */}
        <div className="hidden md:flex justify-center pb-5 pt-2">
          <div className="w-full max-w-2xl">
            <SearchBar initialQuery={searchQuery} initialVehicle={searchVehicle} initialCategory={selectedCategory} />
          </div>
        </div>

        {/* Mobile search bar */}
        <div className="pb-3 md:hidden">
          <SearchBar initialQuery={searchQuery} initialVehicle={searchVehicle} initialCategory={selectedCategory} />
        </div>
      </Container>

    </header>
  );
}
