import Avatar from "@/components/ui/Avatar";
import { Host } from "@/types";
import { MessageCircle, Shield } from "lucide-react";

interface HostCardProps {
  host: Host;
}

export default function HostCard({ host }: HostCardProps) {
  return (
    <div className="rounded-xl border border-neutral-200 p-6">
      <div className="flex items-center gap-4">
        <Avatar src={host.avatar} alt={host.name} size="lg" />
        <div>
          <h3 className="font-semibold text-neutral-900">Hosted by {host.name}</h3>
          <p className="text-sm text-neutral-500">
            Member since {host.joinedYear} &middot; {host.listingsCount} listing
            {host.listingsCount !== 1 ? "s" : ""}
          </p>
        </div>
      </div>
      <div className="mt-4 grid grid-cols-2 gap-4">
        <div className="flex items-center gap-2 text-sm text-neutral-600">
          <MessageCircle className="h-4 w-4 text-primary-600" />
          {host.responseRate}% response rate
        </div>
        <div className="flex items-center gap-2 text-sm text-neutral-600">
          <Shield className="h-4 w-4 text-primary-600" />
          Responds {host.responseTime}
        </div>
      </div>
    </div>
  );
}
