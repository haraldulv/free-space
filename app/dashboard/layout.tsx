import Navbar from "@/components/features/Navbar";
import Footer from "@/components/features/Footer";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <>
      <Navbar />
      <main className="flex-1 bg-neutral-50">{children}</main>
      <Footer />
    </>
  );
}
