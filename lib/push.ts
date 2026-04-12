import http2 from "http2";
import { SignJWT, importPKCS8 } from "jose";

const APNS_HOST = process.env.APNS_PRODUCTION === "true"
  ? "api.push.apple.com"
  : "api.sandbox.push.apple.com";
const BUNDLE_ID = "no.tuno.app";

let cachedToken: { token: string; expires: number } | null = null;

async function getApnsToken(): Promise<string> {
  if (cachedToken && Date.now() < cachedToken.expires) return cachedToken.token;

  const key = process.env.APNS_KEY_P8;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;

  if (!key || !keyId || !teamId) throw new Error("APNs not configured");

  const privateKey = await importPKCS8(key.replace(/\\n/g, "\n"), "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(privateKey);

  cachedToken = { token, expires: Date.now() + 50 * 60 * 1000 };
  return token;
}

function sendApns(deviceToken: string, payload: object): Promise<boolean> {
  return new Promise(async (resolve) => {
    try {
      const token = await getApnsToken();
      const client = http2.connect(`https://${APNS_HOST}`);

      const body = JSON.stringify(payload);
      const req = client.request({
        ":method": "POST",
        ":path": `/3/device/${deviceToken}`,
        "authorization": `bearer ${token}`,
        "apns-topic": BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
        "content-length": Buffer.byteLength(body),
      });

      req.on("response", (headers) => {
        const status = headers[":status"];
        if (status !== 200) {
          console.error(`APNs error ${status} for ${deviceToken.slice(0, 8)}...`);
        }
        resolve(status === 200);
      });

      req.on("error", (err) => {
        console.error("APNs request error:", err);
        resolve(false);
      });

      req.end(body);

      setTimeout(() => {
        client.close();
      }, 5000);
    } catch (err) {
      console.error("APNs send error:", err);
      resolve(false);
    }
  });
}

export async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>,
) {
  const { createClient } = await import("@supabase/supabase-js");
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", userId);

  if (!tokens || tokens.length === 0) return;

  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
      badge: 1,
    },
    ...data,
  };

  await Promise.all(tokens.map((t) => sendApns(t.token, payload)));
}

export async function sendPushToUser(userId: string, title: string, body: string) {
  try {
    await sendPushNotification(userId, title, body);
  } catch {
    // Push errors should not block other operations
  }
}
