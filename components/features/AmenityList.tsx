import {
  Zap,
  Umbrella,
  Camera,
  Lock,
  Lightbulb,
  Bath,
  Droplets,
  Wifi,
  Flame,
  Waves,
  Mountain,
  PawPrint,
  Trash2,
  ShowerHead,
} from "lucide-react";
import { Amenity } from "@/types";

const amenityConfig: Record<Amenity, { label: string; icon: React.ElementType }> = {
  ev_charging: { label: "EV Charging", icon: Zap },
  covered: { label: "Covered", icon: Umbrella },
  security_camera: { label: "Security Camera", icon: Camera },
  gated: { label: "Gated Access", icon: Lock },
  lighting: { label: "Lighting", icon: Lightbulb },
  toilets: { label: "Toilets", icon: Bath },
  showers: { label: "Showers", icon: ShowerHead },
  electricity: { label: "Electricity", icon: Zap },
  water: { label: "Water", icon: Droplets },
  wifi: { label: "WiFi", icon: Wifi },
  campfire: { label: "Campfire", icon: Flame },
  lake_access: { label: "Lake/Fjord Access", icon: Waves },
  mountain_view: { label: "Mountain View", icon: Mountain },
  pets_allowed: { label: "Pets Allowed", icon: PawPrint },
  waste_disposal: { label: "Waste Disposal", icon: Trash2 },
};

interface AmenityListProps {
  amenities: Amenity[];
}

export default function AmenityList({ amenities }: AmenityListProps) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
      {amenities.map((amenity) => {
        const config = amenityConfig[amenity];
        const Icon = config.icon;
        return (
          <div
            key={amenity}
            className="flex items-center gap-2.5 rounded-lg border border-neutral-100 bg-neutral-50 px-3 py-2.5"
          >
            <Icon className="h-4 w-4 shrink-0 text-primary-600" />
            <span className="text-sm text-neutral-700">{config.label}</span>
          </div>
        );
      })}
    </div>
  );
}
