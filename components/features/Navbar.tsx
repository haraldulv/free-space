"use client";

import { useState, useRef, useEffect } from "react";
import Link from "next/link";
import { useRouter, usePathname } from "next/navigation";
import {
  Menu,
  Languages,
  CalendarCheck,
  Heart,
  Megaphone,
  PlusCircle,
  Settings,
  LogOut,
  LogIn,
  UserPlus,
  Search,
} from "lucide-react";
import SearchBar from "./SearchBar";
import { ListingCategory, VehicleType } from "@/types";

interface NavbarProps {
  user?: { email: string; fullName?: string; avatar?: string } | null;
  isHost?: boolean;
  onSignOut?: () => void;
  selectedCategory?: ListingCategory;
  onCategoryChange?: (category?: ListingCategory) => void;
  searchQuery?: string;
  searchVehicle?: VehicleType;
  searchCheckIn?: string;
  searchCheckOut?: string;
}

const menuItemClass = "flex items-center gap-3 px-4 py-2.5 min-h-[44px] text-sm text-neutral-700 hover:bg-neutral-50";

export default function Navbar({
  user,
  isHost,
  onSignOut,
  selectedCategory,
  onCategoryChange,
  searchQuery,
  searchVehicle,
  searchCheckIn,
  searchCheckOut,
}: NavbarProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [avatarMenuOpen, setAvatarMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const avatarRef = useRef<HTMLDivElement>(null);
  const router = useRouter();
  const pathname = usePathname();
  const isSearchPage = pathname === "/search";

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
      if (avatarRef.current && !avatarRef.current.contains(e.target as Node)) {
        setAvatarMenuOpen(false);
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

  const initial = user?.fullName?.charAt(0)?.toUpperCase() || user?.email?.charAt(0)?.toUpperCase() || "?";

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
            <SearchBar initialQuery={searchQuery} initialVehicle={searchVehicle} initialCategory={selectedCategory} initialCheckIn={searchCheckIn} initialCheckOut={searchCheckOut} compact />
          </div>
        )}

        {!isSearchPage && <div className="flex-1" />}

        {/* Right: Actions */}
        <div className="flex items-center gap-2 shrink-0">
          {!(user && isHost) && (
            <Link
              href="/bli-utleier"
              className="hidden lg:block rounded-full px-4 py-2 text-sm font-medium text-neutral-700 transition-colors hover:bg-neutral-100"
            >
              Bli utleier
            </Link>
          )}

          <button
            className="flex items-center justify-center rounded-full border border-neutral-200 bg-white p-2 shadow-sm text-neutral-500 transition-all hover:shadow-md"
            aria-label="Endre språk"
          >
            <Languages className="h-4 w-4" />
          </button>

          {/* Hamburger — navigation menu */}
          <div className="relative" ref={menuRef}>
            <button
              onClick={() => { setMenuOpen(!menuOpen); setAvatarMenuOpen(false); }}
              className="flex items-center justify-center rounded-full border border-neutral-200 bg-white p-2 shadow-sm transition-all hover:shadow-md"
            >
              <Menu className="h-4 w-4 text-neutral-600" />
            </button>

            {menuOpen && (
              <div className="animate-fade-in absolute right-0 mt-2 w-56 rounded-xl border border-neutral-100 bg-white py-2 shadow-xl">
                {user ? (
                  <>
                    <Link href="/dashboard" className={menuItemClass} onClick={() => setMenuOpen(false)}>
                      <CalendarCheck className="h-4 w-4 text-neutral-400" />
                      Mine bestillinger
                    </Link>
                    <Link href="/dashboard?tab=favoritter" className={menuItemClass} onClick={() => setMenuOpen(false)}>
                      <Heart className="h-4 w-4 text-neutral-400" />
                      Favoritter
                    </Link>
                    {isHost ? (
                      <Link href="/dashboard?tab=annonser" className={menuItemClass} onClick={() => setMenuOpen(false)}>
                        <Megaphone className="h-4 w-4 text-neutral-400" />
                        Mine annonser
                      </Link>
                    ) : (
                      <Link href="/bli-utleier" className={menuItemClass} onClick={() => setMenuOpen(false)}>
                        <PlusCircle className="h-4 w-4 text-neutral-400" />
                        Bli utleier
                      </Link>
                    )}
                    <div className="my-1 border-t border-neutral-100" />
                    <Link href="/search" className={menuItemClass} onClick={() => setMenuOpen(false)}>
                      <Search className="h-4 w-4 text-neutral-400" />
                      Utforsk
                    </Link>
                  </>
                ) : (
                  <>
                    <Link href="/login" className={`${menuItemClass} font-medium`} onClick={() => setMenuOpen(false)}>
                      <LogIn className="h-4 w-4 text-neutral-400" />
                      Logg inn
                    </Link>
                    <Link href="/register" className={menuItemClass} onClick={() => setMenuOpen(false)}>
                      <UserPlus className="h-4 w-4 text-neutral-400" />
                      Registrer deg
                    </Link>
                    <div className="my-1 border-t border-neutral-100" />
                    <Link href="/bli-utleier" className={menuItemClass} onClick={() => setMenuOpen(false)}>
                      <PlusCircle className="h-4 w-4 text-neutral-400" />
                      Bli utleier
                    </Link>
                  </>
                )}
              </div>
            )}
          </div>

          {/* Avatar — account menu (only when logged in) */}
          {user && (
            <div className="relative" ref={avatarRef}>
              <button
                onClick={() => { setAvatarMenuOpen(!avatarMenuOpen); setMenuOpen(false); }}
                className="flex items-center justify-center rounded-full border-2 border-neutral-200 bg-neutral-100 overflow-hidden transition-all hover:border-primary-300 h-9 w-9"
              >
                {user.avatar ? (
                  <img src={user.avatar} alt={user.fullName || "Avatar"} className="h-full w-full object-cover" />
                ) : (
                  <span className="text-sm font-medium text-neutral-600">{initial}</span>
                )}
              </button>

              {avatarMenuOpen && (
                <div className="animate-fade-in absolute right-0 mt-2 w-56 rounded-xl border border-neutral-100 bg-white py-2 shadow-xl">
                  <div className="px-4 py-2.5 border-b border-neutral-100">
                    <p className="text-sm font-medium text-neutral-900">{user.fullName || "Min konto"}</p>
                    <p className="text-xs text-neutral-500 truncate">{user.email}</p>
                  </div>
                  <Link href="/settings" className={menuItemClass} onClick={() => setAvatarMenuOpen(false)}>
                    <Settings className="h-4 w-4 text-neutral-400" />
                    Innstillinger
                  </Link>
                  <button onClick={() => { setAvatarMenuOpen(false); onSignOut?.(); }} className={`${menuItemClass} w-full text-left`}>
                    <LogOut className="h-4 w-4 text-neutral-400" />
                    Logg ut
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Full search bar row — only on non-search pages */}
      {!isSearchPage && (
        <div className={`hidden md:flex justify-center pb-5 pt-2 ${padClass}`}>
          <div className="w-full max-w-2xl">
            <SearchBar initialQuery={searchQuery} initialVehicle={searchVehicle} initialCategory={selectedCategory} initialCheckIn={searchCheckIn} initialCheckOut={searchCheckOut} />
          </div>
        </div>
      )}

      {/* Mobile search bar — only on non-search pages */}
      {!isSearchPage && (
        <div className={`pb-3 md:hidden ${padClass}`}>
          <SearchBar initialQuery={searchQuery} initialVehicle={searchVehicle} initialCategory={selectedCategory} initialCheckIn={searchCheckIn} initialCheckOut={searchCheckOut} />
        </div>
      )}
    </header>
  );
}
