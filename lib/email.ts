import { Resend } from "resend";

const resend = new Resend(process.env.RESEND_API_KEY);
const FROM = "Tuno <noreply@tuno.no>";
const LOGO_URL = "https://tuno.no/tuno-logo.png";

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

export async function sendBookingConfirmation(to: string, data: {
  guestName: string;
  listingTitle: string;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
  bookingId: string;
}) {
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Booking bekreftet: ${data.listingTitle}`,
    html: wrap("Booking bekreftet!", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.guestName}, din booking er bekreftet!
      </p>
      <div style="background:#f5f5f5;border-radius:8px;padding:16px;margin:16px 0;">
        <p style="margin:0;font-size:14px;color:#525252;"><strong>${data.listingTitle}</strong></p>
        <p style="margin:4px 0 0;font-size:14px;color:#737373;">Innsjekk: ${data.checkIn}</p>
        <p style="margin:4px 0 0;font-size:14px;color:#737373;">Utsjekk: ${data.checkOut}</p>
        <p style="margin:8px 0 0;font-size:16px;font-weight:700;color:#171717;">${data.totalPrice} kr</p>
      </div>
      ${btn("Se bestillingen", `https://tuno.no/dashboard?tab=bookings`)}
    `),
  });
}

export async function sendBookingNotificationToHost(to: string, data: {
  hostName: string;
  guestName: string;
  listingTitle: string;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
}) {
  const hostAmount = Math.round(data.totalPrice * 0.9);
  await resend.emails.send({
    from: FROM,
    to,
    subject: `Ny booking: ${data.listingTitle}`,
    html: wrap("Du har en ny booking!", `
      <p style="color:#525252;font-size:14px;line-height:1.6;">
        Hei ${data.hostName}, ${data.guestName} har booket plassen din.
      </p>
      <div style="background:#f5f5f5;border-radius:8px;padding:16px;margin:16px 0;">
        <p style="margin:0;font-size:14px;color:#525252;"><strong>${data.listingTitle}</strong></p>
        <p style="margin:4px 0 0;font-size:14px;color:#737373;">Innsjekk: ${data.checkIn}</p>
        <p style="margin:4px 0 0;font-size:14px;color:#737373;">Utsjekk: ${data.checkOut}</p>
        <p style="margin:8px 0 0;font-size:16px;font-weight:700;color:#171717;">Din utbetaling: ${hostAmount} kr</p>
      </div>
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
