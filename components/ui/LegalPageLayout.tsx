import Container from "@/components/ui/Container";

interface LegalPageLayoutProps {
  title: string;
  lastUpdated: string;
  children: React.ReactNode;
}

export default function LegalPageLayout({
  title,
  lastUpdated,
  children,
}: LegalPageLayoutProps) {
  return (
    <Container className="py-12">
      <div className="mx-auto max-w-3xl">
        <h1 className="text-3xl font-bold text-neutral-900">{title}</h1>
        <p className="mt-2 text-sm text-neutral-400">
          Sist oppdatert: {lastUpdated}
        </p>
        <div className="mt-8 space-y-8">{children}</div>
      </div>
    </Container>
  );
}

export function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section>
      <h2 className="text-lg font-semibold text-neutral-900">{title}</h2>
      <div className="mt-3 space-y-3 text-sm leading-relaxed text-neutral-600">
        {children}
      </div>
    </section>
  );
}
