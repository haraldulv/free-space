import { Schibsted_Grotesk } from "next/font/google";

// /tjen ligger utenfor (main)-gruppen med vilje: plakat-landingssiden skal
// ikke ha bobil-navbar eller footer, bare sitt eget uttrykk. Schibsted
// Grotesk gjelder kun denne ruten; resten av siten beholder DM Sans.
const schibsted = Schibsted_Grotesk({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
});

export default function TjenLayout({ children }: { children: React.ReactNode }) {
  return <div className={schibsted.className}>{children}</div>;
}
