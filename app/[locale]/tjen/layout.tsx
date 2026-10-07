import { Quicksand } from "next/font/google";

// /tjen ligger utenfor (main)-gruppen med vilje: plakat-landingssiden skal
// ikke ha bobil-navbar eller footer, bare sitt eget uttrykk. Quicksand
// gjelder kun denne ruten; resten av siten beholder DM Sans.
const quicksand = Quicksand({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
});

export default function TjenLayout({ children }: { children: React.ReactNode }) {
  return <div className={quicksand.className}>{children}</div>;
}
