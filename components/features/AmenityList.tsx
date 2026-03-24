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
  Accessibility,
} from "lucide-react";
import { Amenity } from "@/types";

export const amenityConfig: Record<Amenity, { label: string; icon: React.ElementType }> = {
  ev_charging: { label: "Elbil-lading", icon: Zap },
  covered: { label: "Under tak", icon: Umbrella },
  security_camera: { label: "Overvåkingskamera", icon: Camera },
  gated: { label: "Portadgang", icon: Lock },
  lighting: { label: "Belysning", icon: Lightbulb },
  toilets: { label: "Toalett", icon: Bath },
  showers: { label: "Dusj", icon: ShowerHead },
  electricity: { label: "Strøm (tilkobling)", icon: Zap },
  water: { label: "Vanntilkobling", icon: Droplets },
  wifi: { label: "WiFi", icon: Wifi },
  campfire: { label: "Bålplass", icon: Flame },
  lake_access: { label: "Sjø-/innsjøtilgang", icon: Waves },
  mountain_view: { label: "Fjellpanorama", icon: Mountain },
  pets_allowed: { label: "Dyrevennlig", icon: PawPrint },
  waste_disposal: { label: "Septiktømming", icon: Trash2 },
  handicap_accessible: { label: "Tilgjengelig for rullestol", icon: Accessibility },
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
