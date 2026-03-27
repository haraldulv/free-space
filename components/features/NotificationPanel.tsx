"use client";

import { useEffect, useState } from "react";
import { Bell, CalendarCheck, XCircle, CheckCircle, MessageCircle, Star } from "lucide-react";
import { getNotifications, markAllAsRead } from "@/lib/supabase/notifications";
import type { AppNotification } from "@/types";

interface NotificationPanelProps {
  userId: string;
  unreadCount: number;
  onUnreadChange: (count: number) => void;
}

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "Nå";
  if (minutes < 60) return `${minutes} min siden`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} t siden`;
  const days = Math.floor(hours / 24);
  return `${days} d siden`;
}

const typeIcons: Record<string, React.ElementType> = {
  booking_received: CalendarCheck,
  booking_confirmed: CheckCircle,
  booking_cancelled: XCircle,
  new_message: MessageCircle,
  new_review: Star,
};

export default function NotificationPanel({ userId, unreadCount, onUnreadChange }: NotificationPanelProps) {
  const [open, setOpen] = useState(false);
  const [notifications, setNotifications] = useState<AppNotification[]>([]);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    if (open && !loaded) {
      getNotifications(userId).then((data) => {
        setNotifications(data);
        setLoaded(true);
      });
    }
  }, [open, loaded, userId]);

  const handleMarkAllRead = async () => {
    await markAllAsRead(userId);
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    onUnreadChange(0);
  };

  return (
    <div className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="relative flex items-center justify-center rounded-full border border-neutral-200 bg-white p-2 shadow-sm transition-all hover:shadow-md"
        aria-label="Varsler"
      >
        <Bell className="h-4 w-4 text-neutral-600" />
        {unreadCount > 0 && (
          <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-red-500 text-[10px] font-bold text-white">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        )}
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="animate-fade-in absolute right-0 z-50 mt-2 w-80 rounded-xl border border-neutral-100 bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-neutral-100 px-4 py-3">
              <h3 className="text-sm font-semibold text-neutral-900">Varsler</h3>
              {unreadCount > 0 && (
                <button
                  onClick={handleMarkAllRead}
                  className="text-xs text-primary-600 hover:text-primary-700"
                >
                  Merk alle som lest
                </button>
              )}
            </div>

            <div className="max-h-80 overflow-y-auto">
              {!loaded ? (
                <div className="flex items-center justify-center py-8">
                  <div className="h-5 w-5 animate-spin rounded-full border-2 border-primary-600 border-t-transparent" />
                </div>
              ) : notifications.length === 0 ? (
                <div className="py-8 text-center">
                  <Bell className="mx-auto h-8 w-8 text-neutral-300" />
                  <p className="mt-2 text-sm text-neutral-500">Ingen varsler</p>
                </div>
              ) : (
                notifications.map((notification) => {
                  const Icon = typeIcons[notification.type] || Bell;
                  const href = notification.type === "new_message" && notification.metadata?.conversationId
                    ? `/dashboard?tab=messages&conversation=${notification.metadata.conversationId}`
                    : undefined;
                  const Wrapper = href ? "a" : "div";
                  return (
                    <Wrapper
                      key={notification.id}
                      {...(href ? { href, onClick: () => setOpen(false) } : {})}
                      className={`flex gap-3 px-4 py-3 border-b border-neutral-50 ${
                        !notification.read ? "bg-primary-50/50" : ""
                      } ${href ? "cursor-pointer hover:bg-neutral-50 transition-colors" : ""}`}
                    >
                      <div className={`mt-0.5 shrink-0 ${!notification.read ? "text-primary-600" : "text-neutral-400"}`}>
                        <Icon className="h-4 w-4" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <p className={`text-sm ${!notification.read ? "font-medium text-neutral-900" : "text-neutral-700"}`}>
                          {notification.title}
                        </p>
                        {notification.body && (
                          <p className="mt-0.5 text-xs text-neutral-500 line-clamp-2">{notification.body}</p>
                        )}
                        <p className="mt-1 text-xs text-neutral-400">{timeAgo(notification.createdAt)}</p>
                      </div>
                    </Wrapper>
                  );
                })
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
