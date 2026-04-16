"use client";

import Avatar from "@/components/ui/Avatar";
import { Host } from "@/types";
import { MessageCircle, Shield } from "lucide-react";
import { useTranslations } from "next-intl";
import ContactHostButton from "./ContactHostButton";

interface HostCardProps {
  host: Host;
  listingId?: string;
}

export default function HostCard({ host, listingId }: HostCardProps) {
  const t = useTranslations("listing");
  return (
    <div className="rounded-xl border border-neutral-200 p-6">
      <div className="flex items-center gap-4">
        <Avatar src={host.avatar} alt={host.name} size="lg" />
        <div>
          <h3 className="font-semibold text-neutral-900">
            {t("hostedBy", { name: host.name || t("anonymousHost") })}
          </h3>
          {host.joinedYear ? (
            <p className="text-sm text-neutral-500">
              {t("memberSince", { year: host.joinedYear, count: host.listingsCount })}
            </p>
          ) : (
            <p className="text-sm text-neutral-500">{t("hostLabel")}</p>
          )}
        </div>
      </div>
      <div className="mt-4 grid grid-cols-2 gap-4">
        <div className="flex items-center gap-2 text-sm text-neutral-600">
          <MessageCircle className="h-4 w-4 text-primary-600" />
          {t("responseRate", { rate: host.responseRate })}
        </div>
        <div className="flex items-center gap-2 text-sm text-neutral-600">
          <Shield className="h-4 w-4 text-primary-600" />
          {t("respondsIn", { time: host.responseTime })}
        </div>
      </div>
      {listingId && (
        <ContactHostButton listingId={listingId} hostId={host.id} />
      )}
    </div>
  );
}
