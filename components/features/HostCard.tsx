import Avatar from "@/components/ui/Avatar";
import { Host } from "@/types";
import { MessageCircle, Shield } from "lucide-react";
import ContactHostButton from "./ContactHostButton";

interface HostCardProps {
  host: Host;
  listingId?: string;
}

export default function HostCard({ host, listingId }: HostCardProps) {
  return (
    <div className="rounded-xl border border-neutral-200 p-6">
      <div className="flex items-center gap-4">
        <Avatar src={host.avatar} alt={host.name} size="lg" />
        <div>
          <h3 className="font-semibold text-neutral-900">Utleid av {host.name}</h3>
          <p className="text-sm text-neutral-500">
            Medlem siden {host.joinedYear} &middot; {host.listingsCount} annonse{host.listingsCount !== 1 ? "r" : ""}
          </p>
        </div>
      </div>
      <div className="mt-4 grid grid-cols-2 gap-4">
        <div className="flex items-center gap-2 text-sm text-neutral-600">
          <MessageCircle className="h-4 w-4 text-primary-600" />
          {host.responseRate}% svarprosent
        </div>
        <div className="flex items-center gap-2 text-sm text-neutral-600">
          <Shield className="h-4 w-4 text-primary-600" />
          Svarer {host.responseTime}
        </div>
      </div>
      {listingId && (
        <ContactHostButton listingId={listingId} hostId={host.id} />
      )}
    </div>
  );
}
