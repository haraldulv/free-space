import { SERVICE_FEE_RATE } from "@/lib/config";

export type CancelledBy = "guest" | "host";

export interface CancellationResult {
  refundAmount: number;
  refundAmountOre: number;
  serviceFee: number;
  basePrice: number;
  policy: "full" | "partial" | "none";
  policyLabel: string;
}

export function computeRefund(
  totalPrice: number,
  checkIn: string,
  cancelledBy: CancelledBy
): CancellationResult {
  const serviceFee = Math.round(
    totalPrice * SERVICE_FEE_RATE / (1 + SERVICE_FEE_RATE)
  );
  const basePrice = totalPrice - serviceFee;

  if (cancelledBy === "host") {
    return {
      refundAmount: totalPrice,
      refundAmountOre: totalPrice * 100,
      serviceFee,
      basePrice,
      policy: "full",
      policyLabel: "Full refusjon (utleier kansellerte)",
    };
  }

  const now = new Date();
  const checkInDate = new Date(checkIn + "T00:00:00");
  const hoursUntilCheckIn =
    (checkInDate.getTime() - now.getTime()) / (1000 * 60 * 60);

  if (hoursUntilCheckIn > 24) {
    return {
      refundAmount: basePrice,
      refundAmountOre: basePrice * 100,
      serviceFee,
      basePrice,
      policy: "full",
      policyLabel: "Full refusjon fratrukket servicetillegg",
    };
  }

  if (hoursUntilCheckIn > 0) {
    const partial = Math.round(basePrice * 0.5);
    return {
      refundAmount: partial,
      refundAmountOre: partial * 100,
      serviceFee,
      basePrice,
      policy: "partial",
      policyLabel: "50 % refusjon (under 24 timer til innsjekk)",
    };
  }

  return {
    refundAmount: 0,
    refundAmountOre: 0,
    serviceFee,
    basePrice,
    policy: "none",
    policyLabel: "Ingen refusjon (etter innsjekk)",
  };
}
