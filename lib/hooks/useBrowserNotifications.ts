"use client";

import { useCallback, useEffect, useState } from "react";

type Permission = "default" | "granted" | "denied" | "unsupported";

/**
 * Hook for å håndtere browser Notification API opt-in.
 * Returnerer nåværende status + request-funksjon + show-funksjon.
 */
export function useBrowserNotifications() {
  const [permission, setPermission] = useState<Permission>("default");

  useEffect(() => {
    if (typeof window === "undefined" || !("Notification" in window)) {
      setPermission("unsupported");
      return;
    }
    setPermission(Notification.permission as Permission);
  }, []);

  const request = useCallback(async () => {
    if (typeof window === "undefined" || !("Notification" in window)) {
      setPermission("unsupported");
      return "unsupported" as Permission;
    }
    const res = await Notification.requestPermission();
    setPermission(res as Permission);
    return res as Permission;
  }, []);

  const show = useCallback(
    (title: string, options?: NotificationOptions & { onClick?: () => void }) => {
      if (typeof window === "undefined" || !("Notification" in window)) return;
      if (Notification.permission !== "granted") return;
      if (document.visibilityState === "visible") {
        // Ikke spam når brukeren allerede er aktiv på siden.
        return;
      }
      try {
        const n = new Notification(title, {
          icon: "/icons/icon-180.png",
          badge: "/icons/icon-180.png",
          ...options,
        });
        if (options?.onClick) {
          n.onclick = (e) => {
            e.preventDefault();
            window.focus();
            options.onClick?.();
            n.close();
          };
        }
      } catch {
        // noop — enkelte browsere throws hvis focus-tabet endrer seg
      }
    },
    [],
  );

  return { permission, request, show };
}
