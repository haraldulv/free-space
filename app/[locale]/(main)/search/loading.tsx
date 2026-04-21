import Skeleton from "@/components/ui/Skeleton";

export default function SearchLoading() {
  return (
    <div className="relative overflow-hidden" style={{ height: "calc(100dvh - 64px)" }}>
      <div className="absolute top-0 left-0 bottom-0 overflow-hidden lg:w-1/2">
        <div className="px-5 py-3 sm:px-6">
          <Skeleton className="h-5 w-40" />
          <div className="mt-4 grid grid-cols-1 gap-x-4 gap-y-5 sm:grid-cols-2 lg:grid-cols-3">
            {Array.from({ length: 9 }).map((_, i) => (
              <div key={i} className="space-y-2">
                <Skeleton className="aspect-square w-full rounded-t-lg" />
                <div className="px-2.5 py-2 space-y-1.5">
                  <Skeleton className="h-4 w-3/4" />
                  <Skeleton className="h-3 w-1/2" />
                  <Skeleton className="h-4 w-2/3" />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
      <div className="absolute top-0 right-0 bottom-0 hidden lg:block lg:left-1/2 bg-neutral-100" />
    </div>
  );
}
