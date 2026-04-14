import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().email("Skriv inn en gyldig e-postadresse"),
  password: z.string().min(6, "Passord må ha minst 6 tegn"),
});

export const registerSchema = z
  .object({
    fullName: z.string().min(2, "Navn må ha minst 2 tegn"),
    email: z.string().email("Skriv inn en gyldig e-postadresse"),
    password: z.string().min(6, "Passord må ha minst 6 tegn"),
    confirmPassword: z.string(),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passordene stemmer ikke overens",
    path: ["confirmPassword"],
  });

export const forgotPasswordSchema = z.object({
  email: z.string().email("Skriv inn en gyldig e-postadresse"),
});

export const resetPasswordSchema = z
  .object({
    password: z.string().min(6, "Passord må ha minst 6 tegn"),
    confirmPassword: z.string(),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passordene stemmer ikke overens",
    path: ["confirmPassword"],
  });

export type LoginInput = z.infer<typeof loginSchema>;
export type RegisterInput = z.infer<typeof registerSchema>;
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;

// Listing form — per-step schemas
export const listingStep1Schema = z.object({
  category: z.enum(["parking", "camping"], { message: "Velg en kategori" }),
  vehicleType: z.enum(["car", "campervan", "motorhome"], { message: "Velg kjøretøystype" }),
});

export const listingStep2Schema = z.object({
  title: z.string().min(3, "Tittel må ha minst 3 tegn").max(100, "Maks 100 tegn"),
  description: z.string().min(10, "Beskrivelse må ha minst 10 tegn").max(2000, "Maks 2000 tegn"),
  spots: z.number().int().min(1, "Minst 1 plass").max(100),
  maxVehicleLength: z.number().int().min(1).max(30).optional(),
  checkInTime: z.string().regex(/^\d{2}:\d{2}$/, "Ugyldig format (HH:MM)").optional(),
  checkOutTime: z.string().regex(/^\d{2}:\d{2}$/, "Ugyldig format (HH:MM)").optional(),
});

const listingStep3ObjectSchema = z.object({
  address: z.string().min(3, "Skriv inn en adresse"),
  city: z.string().min(1, "By er påkrevd"),
  region: z.string().min(1, "Region er påkrevd"),
  lat: z.number(),
  lng: z.number(),
  price: z.number().int().optional(),
  perSpotPricing: z.boolean().optional(),
  spotMarkers: z.array(z.object({
    id: z.string().optional(),
    price: z.number().optional(),
  }).passthrough()).optional(),
});

export const listingStep3Schema = listingStep3ObjectSchema.superRefine((data, ctx) => {
  if (data.perSpotPricing) {
    if (!data.spotMarkers || data.spotMarkers.length === 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Marker minst én plass på kartet",
        path: ["spotMarkers"],
      });
      return;
    }
    data.spotMarkers.forEach((spot, i) => {
      if (spot.price == null || spot.price < 1) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: `Plass ${i + 1}: sett pris`,
          path: ["price"],
        });
      }
    });
  } else {
    if (data.price == null || data.price < 1) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Pris må være minst 1 kr",
        path: ["price"],
      });
    }
  }
});

export const listingStep4Schema = z.object({
  images: z.array(z.string().url()).min(1, "Last opp minst ett bilde").max(10, "Maks 10 bilder"),
});

export const listingStep5Schema = z.object({
  amenities: z.array(z.string()),
});

export const listingStep6Schema = z.object({
  price: z.number().int().min(1, "Pris må være minst 1 kr"),
  priceUnit: z.enum(["time", "natt"]),
  instantBooking: z.boolean(),
});

export const listingStep7Schema = z.object({
  blockedDates: z.array(z.string()).optional(),
});

export const createListingSchema = listingStep1Schema
  .merge(listingStep2Schema)
  .merge(listingStep3ObjectSchema)
  .merge(listingStep4Schema)
  .merge(listingStep5Schema)
  .merge(listingStep7Schema);

export type CreateListingInput = z.infer<typeof createListingSchema>;

export const listingStepSchemas = [
  listingStep1Schema,   // 0 Kategori
  listingStep2Schema,   // 1 Detaljer
  listingStep3Schema,   // 2 Lokasjon + pris
  listingStep4Schema,   // 3 Bilder
  listingStep5Schema,   // 4 Fasiliteter
  null,                  // 5 Felles tillegg
  null,                  // 6 Kalender
  null,                  // 7 Publiser
];
