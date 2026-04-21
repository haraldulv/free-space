import Container from "@/components/ui/Container";
import Skeleton from "@/components/ui/Skeleton";

export default function ListingLoading() {
  return (
    <Container className="py-8">
      <Skeleton className="h-[400px] w-full" />
      <div className="mt-8 grid grid-cols-1 gap-6 lg:gap-10 lg:grid-cols-3">
        <div className="lg:col-span-2 space-y-4">
          <div className="flex gap-3">
            <Skeleton className="h-6 w-20" />
            <Skeleton className="h-6 w-24" />
          </div>
          <Skeleton className="h-10 w-3/4" />
          <Skeleton className="h-5 w-1/2" />
          <div className="border-t border-neutral-100 pt-6 space-y-2">
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-2/3" />
          </div>
          <Skeleton className="h-[350px] w-full" />
        </div>
        <div className="lg:col-span-1">
          <Skeleton className="h-[420px] w-full" />
        </div>
      </div>
    </Container>
  );
}
