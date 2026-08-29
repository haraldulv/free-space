import { Resend } from "resend";
import { splitHostAndFee } from "@/lib/config";
import type { SelectedExtras } from "@/types";

const resend = new Resend(process.env.RESEND_API_KEY);
const FROM = "Tuno <noreply@tuno.no>";
const LOGO_URL = "https://tuno.no/tuno-logo.png";

function extrasBlock(extras: SelectedExtras | null | undefined, nights: number): string {
  if (!extras) return "";
  const listingEntries = extras.listing ?? [];
  const spotEntries = Object.values(extras.spots ?? {}).flat();
  const all = [...listingEntries, ...spotEntries];
  if (all.length === 0) return "";

  const rows = all.map((extra) => {
    const amount = extra.price * (extra.perNight ? nights : 1) * extra.quantity;
    const qty = extra.quantity > 1 ? ` × ${extra.quantity}` : "";
    const nightly = extra.perNight ? ` × ${nights}n` : "";
    return `
      <tr>
        <td style="padding:4px 0;font-size:13px;color:#525252;">${extra.name}<span style="color:#a3a3a3;">${qty}${nightly}</span></td>
        <td style="padding:4px 0;font-size:13px;color:#525252;text-align:right;">${amount} kr</td>
      </tr>`;
  }).join("");

  return `
    <div style="margin:12px 0 0;padding:12px 16px;background:#fafafa;border:1px solid #e5e5e5;border-radius:8px;">
      <p style="margin:0 0 4px;font-size:11px;font-weight:700;color:#737373;text-transform:uppercase;letter-spacing:0.06em;">Tilleggstjenester</p>
      <table style="width:100%;border-collapse:collapse;">${rows}</table>
    </div>`;
}

function wrap(title: string, content: string) {
  return `<!DOCTYPE html>
<html lang="nb">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<div style="max-width:560px;margin:0 auto;padding:32px 16px;">
  <div style="text-align:center;margin-bottom:24px;">
    <img src="${LOGO_URL}" alt="Tuno" height="28" style="height:28px;" />
  </div>
  <div style="background:#fff;border-radius:12px;padding:32px 24px;border:1px solid #e5e5e5;">
    <h1 style="margin:0 0 16px;font-size:20px;color:#171717;">${title}</h1>
    ${content}
  </div>
  <p style="text-align:center;margin-top:24px;font-size:12px;color:#a3a3a3;">
    Tuno · <a href="https://tuno.no" style="color:#a3a3a3;">tuno.no</a> · <a href="mailto:support@tuno.no" style="color:#a3a3a3;">support@tuno.no</a>
  </p>
</div>
</body>
</html>`;
}

function btn(text: string, url: string) {
  return `<a href="${url}" style="display:inline-block;margin-top:16px;padding:12px 24px;background:#46C185;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">${text}</a>`;
}

function listingCard(opts: {
  listingId: string | null;
  listingTitle: string;
  listingImage: string | null;
  checkIn: string;
  checkOut: string;
  bottomLine: string;
}) {
  const url = opts.listingId ? `https://tuno.no/listings/${opts.listingId}` : null;
  const title = url
    ? `<a href="${url}" style="color:#171717;text-decoration:none;"><strong>${opts.listingTitle}</strong></a>`
    : `<strong>${opts.listingTitle}</strong>`;
  const image = opts.listingImage
    ? `<a href="${url ?? "#"}" style="display:block;text-decoration:none;">
         <img src="${opts.listingImage}" alt="${opts.listingTitle}" width="512" style="display:block;width:100%;max-width:512px;height:auto;border-radius:8px;margin-bottom:12px;" />
       </a>`
    : "";
  return `
    <div style="margin:16px 0;">
      ${image}
      <div style="background:#f5f5f5;border-radius:8px;padding:16px;">
        <p style="margin:0;font-size:14px;color:#525252;">${title}</p>
        <p style="margin:4px 0 0;font-size:14px;color:#737373;">Innsjekk: ${opts.checkIn}</p>
        <p style="margin:4px 0 0;font-size:14px;color:#737373;">Utsjekk: ${opts.checkOut}</p>
        <p style="margin:8px 0 0;font-size:16px;font-weight:700;color:#171717;">${opts.bottomLine}</p>
      </div>
    </div>`;
}

function nightsBetween(checkIn: string, checkOut: string): number {
  const a = new Date(checkIn);
  const b = new Date(checkOut);
  return Math.max(1, Math.round((b.getTime() - a.getTime()) / 86400000));
}

export async function sendBookingConfirmation(to: string, data: {
  guestName: string;
  listingTitle: string;
  listingId?: string | null;
  listingImage?: string | null;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
  bookingId: string;
  selectedExtras?: SelectedExtras | null;
}) {
  const nights = nightsBetween(data.checkIn, data.checkOut);
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Booking bekreftet: ${data.listingTitle}`,
    html: wrap("Booking bekreftet!", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.guestName}, din booking er bekreftet!
      </p>
      ${listingCard({
        listingId: data.listingId ?? null,
        listingTitle: data.listingTitle,
        listingImage: data.listingImage ?? null,
        checkIn: data.checkIn,
        checkOut: data.checkOut,
        bottomLine: `${data.totalPrice} kr`,
      })}
      ${extrasBlock(data.selectedExtras, nights)}
      ${btn("Se bestillingen", `https://tuno.no/dashboard?tab=bookings`)}
    `),
  });
}

export async function sendBookingNotificationToHost(to: string, data: {
  hostName: string;
  guestName: string;
  listingTitle: string;
  listingId?: string | null;
  listingImage?: string | null;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
  selectedExtras?: SelectedExtras | null;
}) {
  const hostAmount = splitHostAndFee(data.totalPrice).hostShareNok;
  const nights = nightsBetween(data.checkIn, data.checkOut);
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Ny booking: ${data.listingTitle}`,
    html: wrap("Du har en ny booking!", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.hostName}, ${data.guestName} har booket plassen din.
      </p>
      ${listingCard({
        listingId: data.listingId ?? null,
        listingTitle: data.listingTitle,
        listingImage: data.listingImage ?? null,
        checkIn: data.checkIn,
        checkOut: data.checkOut,
        bottomLine: `Din utbetaling: ${hostAmount} kr`,
      })}
      ${extrasBlock(data.selectedExtras, nights)}
      ${btn("Se utleien", `https://tuno.no/dashboard?tab=rentals`)}
    `),
  });
}

export async function sendCancellationEmail(to: string, data: {
  name: string;
  listingTitle: string;
  checkIn: string;
  checkOut: string;
  refundAmount: number;
  cancelledBy: "guest" | "host";
}) {
  const who = data.cancelledBy === "host" ? "Utleier" : "Du";
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Booking kansellert: ${data.listingTitle}`,
    html: wrap("Booking kansellert", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.name}, ${who.toLowerCase()} har kansellert bookingen.
      </p>
      <div style="background:#f5f5f5;border-radius:8px;padding:16px;margin:16px 0;">
        <p style="margin:0;font-size:14px;color:#525252;"><strong>${data.listingTitle}</strong></p>
        <p style="margin:4px 0 0;font-size:14px;color:#737373;">${data.checkIn} – ${data.checkOut}</p>
        ${data.refundAmount > 0 ? `<p style="margin:8px 0 0;font-size:14px;color:#46C185;font-weight:600;">Refusjon: ${data.refundAmount} kr</p>` : ""}
      </div>
      ${btn("Se mine bestillinger", `https://tuno.no/dashboard?tab=bookings`)}
    `),
  });
}

export async function sendPayoutEmail(to: string, data: {
  hostName: string;
  amount: number;
  listingTitle: string;
}) {
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Utbetaling: ${data.amount} kr`,
    html: wrap("Utbetaling sendt!", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.hostName}, vi har sendt en utbetaling til kontoen din.
      </p>
      <div style="background:#f5f5f5;border-radius:8px;padding:16px;margin:16px 0;">
        <p style="margin:0;font-size:14px;color:#525252;"><strong>${data.listingTitle}</strong></p>
        <p style="margin:8px 0 0;font-size:20px;font-weight:700;color:#46C185;">${data.amount} kr</p>
      </div>
      ${btn("Se inntekter", `https://tuno.no/dashboard?tab=earnings`)}
    `),
  });
}

export async function sendPayoutFailedEmail(to: string, data: {
  hostName: string;
  amount: number;
  listingTitle: string;
  reason?: string;
}) {
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Utbetaling feilet: ${data.amount} kr`,
    html: wrap("Utbetalingen feilet", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.hostName}, vi klarte ikke å sende utbetalingen for ${data.listingTitle}.
      </p>
      <div style="background:#fef3c7;border-left:4px solid #f59e0b;border-radius:8px;padding:16px;margin:16px 0;">
        <p style="margin:0;font-size:14px;color:#525252;"><strong>${data.listingTitle}</strong></p>
        <p style="margin:8px 0;font-size:20px;font-weight:700;color:#92400e;">${data.amount} kr</p>
        ${data.reason ? `<p style="margin:8px 0 0;font-size:13px;color:#92400e;">${data.reason}</p>` : ""}
      </div>
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Vanligste årsaker: bankkonto mangler eller har feil format, identifikasjon må verifiseres,
        eller Stripe-onboardingen er ikke fullført. Gå inn på Mine inntekter for å sjekke statusen din.
      </p>
      ${btn("Sjekk utbetalingsstatus", `https://tuno.no/dashboard?tab=earnings`)}
    `),
  });
}

export async function sendBookingRequestToHost(to: string, data: {
  hostName: string;
  guestName: string;
  listingTitle: string;
  listingId?: string | null;
  listingImage?: string | null;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
  approvalDeadline?: string | null;
  selectedExtras?: SelectedExtras | null;
}) {
  const hostAmount = splitHostAndFee(data.totalPrice).hostShareNok;
  const nights = nightsBetween(data.checkIn, data.checkOut);
  const deadlineLine = data.approvalDeadline
    ? `<p style="color:#d97706;font-size:14px;font-weight:600;margin:16px 0 0;">⏱ Du har 24 timer på å svare — ellers blir forespørselen automatisk avvist.</p>`
    : "";
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Ny forespørsel: ${data.listingTitle}`,
    html: wrap("Du har en ny forespørsel", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.hostName}, ${data.guestName} ønsker å booke plassen din.
      </p>
      ${listingCard({
        listingId: data.listingId ?? null,
        listingTitle: data.listingTitle,
        listingImage: data.listingImage ?? null,
        checkIn: data.checkIn,
        checkOut: data.checkOut,
        bottomLine: `Din utbetaling: ${hostAmount} kr`,
      })}
      ${extrasBlock(data.selectedExtras, nights)}
      ${deadlineLine}
      ${btn("Godkjenn eller avvis", `https://tuno.no/dashboard?tab=rentals`)}
    `),
  });
}

export async function sendBookingRequestPendingToGuest(to: string, data: {
  guestName: string;
  listingTitle: string;
  listingId?: string | null;
  listingImage?: string | null;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
  selectedExtras?: SelectedExtras | null;
}) {
  const nights = nightsBetween(data.checkIn, data.checkOut);
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Forespørsel sendt: ${data.listingTitle}`,
    html: wrap("Vi venter på utleier", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.guestName}, vi har autorisert betalingen din og sendt forespørselen til utleier.
        Du belastes først hvis utleier godkjenner — ellers frigjøres beløpet automatisk.
      </p>
      ${listingCard({
        listingId: data.listingId ?? null,
        listingTitle: data.listingTitle,
        listingImage: data.listingImage ?? null,
        checkIn: data.checkIn,
        checkOut: data.checkOut,
        bottomLine: `${data.totalPrice} kr`,
      })}
      ${extrasBlock(data.selectedExtras, nights)}
      <p style="color:#737373;font-size:13px;margin-top:16px;">
        Utleier har 24 timer på å svare. Vi varsler deg så snart vi hører noe.
      </p>
      ${btn("Se bestillingen", `https://tuno.no/dashboard?tab=bookings`)}
    `),
  });
}

export async function sendBookingApprovedToGuest(to: string, data: {
  guestName: string;
  listingTitle: string;
  listingId?: string | null;
  listingImage?: string | null;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
  selectedExtras?: SelectedExtras | null;
}) {
  const nights = nightsBetween(data.checkIn, data.checkOut);
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Bekreftet: ${data.listingTitle}`,
    html: wrap("Forespørselen din er godkjent!", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.guestName}, utleier har godkjent forespørselen og bookingen er bekreftet.
      </p>
      ${listingCard({
        listingId: data.listingId ?? null,
        listingTitle: data.listingTitle,
        listingImage: data.listingImage ?? null,
        checkIn: data.checkIn,
        checkOut: data.checkOut,
        bottomLine: `${data.totalPrice} kr`,
      })}
      ${extrasBlock(data.selectedExtras, nights)}
      ${btn("Se bestillingen", `https://tuno.no/dashboard?tab=bookings`)}
    `),
  });
}

export async function sendBookingDeclinedToGuest(to: string, data: {
  guestName: string;
  listingTitle: string;
  checkIn: string;
  checkOut: string;
  autoDeclined: boolean;
}) {
  const reason = data.autoDeclined
    ? "Utleier rakk dessverre ikke å svare innen 24 timer, så forespørselen ble automatisk avvist."
    : "Utleier kunne dessverre ikke ta imot deg denne gangen.";
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Forespørselen ble ikke godkjent`,
    html: wrap("Forespørselen ble avvist", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.guestName}, ${reason} Beløpet er frigjort og du belastes ikke.
      </p>
      <div style="background:#f5f5f5;border-radius:8px;padding:16px;margin:16px 0;">
        <p style="margin:0;font-size:14px;color:#525252;"><strong>${data.listingTitle}</strong></p>
        <p style="margin:4px 0 0;font-size:14px;color:#737373;">${data.checkIn} – ${data.checkOut}</p>
      </div>
      ${btn("Finn en annen plass", `https://tuno.no/search`)}
    `),
  });
}

export async function sendReviewReminderEmail(to: string, data: {
  guestName: string;
  listingTitle: string;
  bookingId: string;
}) {
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Hvordan var oppholdet ditt?`,
    html: wrap("Legg igjen en anmeldelse", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.guestName}, takk for at du brukte Tuno!
      </p>
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hvordan var oppholdet ditt på <strong>${data.listingTitle}</strong>?
        Din tilbakemelding hjelper andre gjester og utleieren.
      </p>
      ${btn("Skriv anmeldelse", `https://tuno.no/dashboard?tab=bookings`)}
    `),
  });
}

const APP_STORE_URL_EMAIL = "https://apps.apple.com/no/app/tuno-motorhome-and-parking/id6761529990";
export type OutreachLocale = "nb" | "en" | "de";

interface OutreachShellCopy {
  lang: string;
  usp: readonly (readonly [icon: string, title: string, desc: string])[];
  cta: string;
  appStoreAlt: string;
  madeIn: string;
  utleierUrl: string;
}

/**
 * Lokalisert tekst for outreach-mailens "skall" (de tre USP-boksene, knappen,
 * App Store-merket og bunnteksten). Selve meldingen + emnet skrives av avsenderen
 * i komposeren; denne mappen styrer kun det Tuno auto-genererer under meldingen,
 * samt hvilken språkversjon av landingssiden knappen peker til.
 */
const OUTREACH_COPY: Record<OutreachLocale, OutreachShellCopy> = {
  nb: {
    lang: "nb",
    usp: [
      ["📸", "Klar på 5 min", "Lag annonsen din på et blunk"],
      ["📱", "QR-kode", "Gjester scanner og booker selv"],
      ["💰", "Helt gratis", "Kun avgift fra leieren"],
    ],
    cta: "Se hvordan det fungerer →",
    appStoreAlt: "Last ned fra App Store",
    madeIn: "🇳🇴 Utviklet i Norge",
    utleierUrl: "https://tuno.no/utleier",
  },
  en: {
    lang: "en",
    usp: [
      ["📸", "Ready in 5 min", "Create your listing in a flash"],
      ["📱", "QR code", "Guests scan and book themselves"],
      ["💰", "Completely free", "Only the guest pays a fee"],
    ],
    cta: "See how it works →",
    appStoreAlt: "Download on the App Store",
    madeIn: "🇳🇴 Made in Norway",
    utleierUrl: "https://tuno.no/en/utleier",
  },
  de: {
    lang: "de",
    usp: [
      ["📸", "In 5 Min. fertig", "Erstellen Sie Ihre Anzeige im Nu"],
      ["📱", "QR-Code", "Gäste scannen und buchen selbst"],
      ["💰", "Völlig kostenlos", "Nur der Gast zahlt eine Gebühr"],
    ],
    cta: "So funktioniert es →",
    appStoreAlt: "Im App Store laden",
    madeIn: "🇳🇴 Entwickelt in Norwegen",
    utleierUrl: "https://tuno.no/de/utleier",
  },
};

function wrapOutreach(body: string, locale: OutreachLocale = "nb") {
  const copy = OUTREACH_COPY[locale];
  const usp = (icon: string, title: string, desc: string) =>
    `<td style="padding:0 4px;vertical-align:top;width:33%;">
      <div style="text-align:center;padding:14px 8px 16px;background:#f9fafb;border-radius:10px;border:1px solid #f0f0f0;min-height:95px;">
        <div style="font-size:22px;line-height:1;">${icon}</div>
        <div style="margin-top:6px;font-size:12px;font-weight:600;color:#171717;">${title}</div>
        <div style="margin-top:3px;font-size:11px;color:#737373;line-height:1.3;">${desc}</div>
      </div>
    </td>`;

  return `<!DOCTYPE html>
<html lang="${copy.lang}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<div style="max-width:560px;margin:0 auto;padding:32px 16px;">
  <div style="text-align:center;margin-bottom:24px;">
    <img src="${LOGO_URL}" alt="Tuno" height="28" style="height:28px;" />
  </div>
  <div style="background:#fff;border-radius:12px;padding:32px 24px;border:1px solid #e5e5e5;">
    <div style="color:#404040;font-size:15px;line-height:1.7;">${body}</div>
  </div>

  <div style="margin-top:16px;background:#fff;border-radius:12px;padding:20px 12px 24px;border:1px solid #e5e5e5;">
    <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;">
      <tr>
        ${copy.usp.map(([icon, title, desc]) => usp(icon, title, desc)).join("")}
      </tr>
    </table>
    <div style="text-align:center;margin-top:20px;">
      <a href="${copy.utleierUrl}" style="display:inline-block;padding:14px 32px;background:#46C185;color:#fff;border-radius:24px;text-decoration:none;font-weight:600;font-size:15px;">${copy.cta}</a>
    </div>
    <div style="text-align:center;margin-top:14px;">
      <a href="${APP_STORE_URL_EMAIL}" style="display:inline-block;">
        <img src="https://tuno.no/app-store-badge-nb.png" alt="${copy.appStoreAlt}" width="150" style="width:150px;height:auto;" />
      </a>
    </div>
    <div style="text-align:center;margin-top:14px;">
      <span style="display:inline-block;font-size:11px;color:#737373;">${copy.madeIn}</span>
    </div>
  </div>

  <p style="text-align:center;margin-top:20px;font-size:12px;color:#a3a3a3;">
    Tuno · <a href="https://tuno.no" style="color:#a3a3a3;">tuno.no</a> · <a href="mailto:support@tuno.no" style="color:#a3a3a3;">support@tuno.no</a>
  </p>
</div>
</body>
</html>`;
}

/**
 * Outreach-mail til potensielle utleiere. Bruker kim@tuno.no som from + reply-to
 * slik at mottakeren kan svare direkte. Body sendes inn som ren tekst og konverteres
 * til HTML (linjeskift → <br>, lenker auto-detekteres).
 */
const SENDERS = {
  kim: { from: "Kim fra Tuno <kim@tuno.no>", replyTo: "kim@tuno.no" },
  harald: { from: "Harald fra Tuno <harald@tuno.no>", replyTo: "harald@tuno.no" },
} as const;

export async function sendHostOutreachEmail(opts: {
  to: string;
  subject: string;
  body: string;
  sender?: "kim" | "harald";
  locale?: OutreachLocale;
  replyTo?: string;
  attachments?: { filename: string; content: string; contentType?: string }[];
}) {
  const escapeHtml = (s: string) =>
    s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

  const html = escapeHtml(opts.body)
    .replaceAll(/(https?:\/\/\S+)/g, (url) => `<a href="${url}" style="color:#46C185;">${url}</a>`)
    .replaceAll("\n", "<br>");

  const s = SENDERS[opts.sender ?? "kim"];

  await resend.emails.send({
    from: s.from,
    replyTo: opts.replyTo ?? s.replyTo,
    to: opts.to,
    subject: opts.subject,
    html: wrapOutreach(html, opts.locale ?? "nb"),
    attachments: opts.attachments?.map((a) => ({
      filename: a.filename,
      content: Buffer.from(a.content, "base64"),
      content_type: a.contentType,
    })),
  });
}

// ---------------------------------------------------------------------
// Moderering av annonser
// ---------------------------------------------------------------------

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
}

export async function sendListingModerationAdminEmail(to: string[], data: {
  status: "approved" | "flagged";
  listingId: string;
  listingTitle: string;
  hostName: string;
  hostEmail: string | null;
  city: string | null;
  images: string[];
  result: { verdict: string; confidence: string; reasons: string[]; text_quality: string; images: Array<{ index: number; category: string; note: string }> };
  adminUrl: string;
  stripeReady: boolean;
}) {
  const flagged = data.status === "flagged";
  const subject = flagged
    ? `⚠️ Annonse flagget: ${data.listingTitle}`
    : `Ny annonse: ${data.listingTitle}`;

  const thumbs = data.images.slice(0, 6).map((url, i) => {
    const v = data.result.images.find((x) => x.index === i + 1 || x.index === i);
    const bad = v && v.category !== "ok" && v.category !== "unclear";
    return `<td style="padding:4px;vertical-align:top;">
      <a href="${url}"><img src="${url}" width="150" style="width:150px;height:100px;object-fit:cover;border-radius:8px;border:${bad ? "3px solid #dc2626" : "1px solid #e5e5e5"};" /></a>
      ${v ? `<p style="margin:4px 0 0;font-size:11px;color:${bad ? "#dc2626" : "#737373"};max-width:150px;">${escapeHtml(v.category)}${v.note ? ": " + escapeHtml(v.note) : ""}</p>` : ""}
    </td>`;
  }).join("");

  const reasons = data.result.reasons.length
    ? `<ul style="margin:8px 0 0;padding-left:18px;color:#525252;font-size:14px;line-height:1.6;">${data.result.reasons.map((r) => `<li>${escapeHtml(r)}</li>`).join("")}</ul>`
    : "";

  const statusLine = flagged
    ? `<p style="margin:0 0 12px;padding:10px 12px;background:#fef2f2;border:1px solid #fecaca;border-radius:8px;color:#991b1b;font-size:14px;font-weight:600;">Flagget av AI (${escapeHtml(data.result.confidence)} sikkerhet). Annonsen er skjult til du tar stilling.</p>`
    : `<p style="margin:0 0 12px;padding:10px 12px;background:#f0fdf4;border:1px solid #bbf7d0;border-radius:8px;color:#166534;font-size:14px;font-weight:600;">Godkjent automatisk av AI (${escapeHtml(data.result.confidence)} sikkerhet).${data.stripeReady ? "" : " Hosten er ikke Stripe-verifisert ennå, så annonsen er fortsatt skjult."}</p>`;

  await resend.emails.send({
    from: FROM,
    to,
    subject,
    html: wrap(flagged ? "Annonse trenger gjennomgang" : "Ny annonse publisert", `
      ${statusLine}
      <p style="margin:0;color:#171717;font-size:16px;font-weight:600;">${escapeHtml(data.listingTitle)}</p>
      <p style="margin:4px 0 0;color:#525252;font-size:14px;">${escapeHtml(data.hostName)}${data.hostEmail ? ` · ${escapeHtml(data.hostEmail)}` : ""}${data.city ? ` · ${escapeHtml(data.city)}` : ""}</p>
      <p style="margin:4px 0 0;color:#737373;font-size:12px;">Tekstkvalitet: ${escapeHtml(data.result.text_quality)}</p>
      ${reasons}
      <table style="border-collapse:collapse;margin-top:12px;"><tr>${thumbs}</tr></table>
      ${btn(flagged ? "Åpne moderering" : "Se i admin", data.adminUrl)}
    `),
  });
}

export async function sendListingApprovedToHost(to: string, data: {
  hostName: string;
  listingTitle: string;
  listingId: string;
  stripeReady: boolean;
}) {
  await resend.emails.send({
    from: FROM,
    to,
    subject: "Annonsen din er godkjent",
    html: wrap("Annonsen din er godkjent 🎉", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">Hei ${escapeHtml(data.hostName)}!</p>
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        «${escapeHtml(data.listingTitle)}» er gjennomgått og godkjent.
        ${data.stripeReady
          ? "Den er nå synlig for leietakere på tuno.no og i appen."
          : "Den blir synlig for leietakere så snart Stripe har verifisert utleierkontoen din. Sjekk Innstillinger i appen om noe mangler."}
      </p>
      ${btn("Se annonsen", `https://tuno.no/listings/${data.listingId}`)}
    `),
  });
}

export async function sendListingRejectedToHost(to: string, data: {
  hostName: string;
  listingTitle: string;
  reason: string | null;
}) {
  await resend.emails.send({
    from: FROM,
    to,
    subject: "Annonsen din ble ikke godkjent",
    html: wrap("Annonsen din ble ikke godkjent", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">Hei ${escapeHtml(data.hostName)},</p>
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Vi har gjennomgått «${escapeHtml(data.listingTitle)}» og kan dessverre ikke publisere den.
      </p>
      ${data.reason ? `<p style="margin:12px 0;padding:12px 16px;background:#fafafa;border:1px solid #e5e5e5;border-radius:8px;color:#525252;font-size:14px;line-height:1.6;">${escapeHtml(data.reason)}</p>` : ""}
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Annonser på Tuno skal vise selve plassen som leies ut, med ekte bilder og en forståelig beskrivelse.
        Mener du dette er feil, svar på denne e-posten eller kontakt support@tuno.no.
      </p>
    `),
  });
}

/** Generisk admin-varsel (innholdsflagg, rapporter). Kun til ADMIN_EMAILS-lista. */
export async function sendAdminAlertEmail(subject: string, bodyHtml: string, url: string) {
  const { ADMIN_EMAILS } = await import("@/lib/config");
  await resend.emails.send({
    from: FROM,
    to: ADMIN_EMAILS,
    subject,
    html: wrap(subject, `${bodyHtml}${btn("Åpne i admin", url)}`),
  });
}
