import Image from "next/image";

interface AvatarProps {
  src: string;
  alt: string;
  size?: "sm" | "md" | "lg";
  className?: string;
}

const sizeClasses = {
  sm: "h-8 w-8",
  md: "h-10 w-10",
  lg: "h-14 w-14",
};

const sizePx = { sm: 32, md: 40, lg: 56 };

export default function Avatar({
  src,
  alt,
  size = "md",
  className = "",
}: AvatarProps) {
  return (
    <div
      className={`relative overflow-hidden rounded-full bg-neutral-200 ${sizeClasses[size]} ${className}`}
    >
      <Image
        src={src}
        alt={alt}
        width={sizePx[size]}
        height={sizePx[size]}
        className="h-full w-full object-cover"
      />
    </div>
  );
}
