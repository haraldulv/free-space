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
    Tuno AS · <a href="https://tuno.no" style="color:#a3a3a3;">tuno.no</a> · <a href="mailto:support@tuno.no" style="color:#a3a3a3;">support@tuno.no</a>
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
