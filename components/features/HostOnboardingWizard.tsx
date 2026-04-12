"use client";

import { useState } from "react";
import { CheckCircle2, ChevronRight, Loader2, ShieldCheck, UserCircle, MapPin, Building2, ArrowLeft } from "lucide-react";
import Input from "@/components/ui/Input";
import Button from "@/components/ui/Button";
import { createClient } from "@/lib/supabase/client";

type Step = "welcome" | "personal" | "address" | "bank" | "status";
const STEPS: Step[] = ["welcome", "personal", "address", "bank", "status"];

const stepLabels: Record<Step, string> = {
  welcome: "Velkommen",
  personal: "Personlig info",
  address: "Adresse",
  bank: "Bankkonto",
  status: "Ferdig",
};

interface HostOnboardingWizardProps {
  onComplete: () => void;
}

export default function HostOnboardingWizard({ onComplete }: HostOnboardingWizardProps) {
  const [step, setStep] = useState<Step>("welcome");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [dobDay, setDobDay] = useState("");
  const [dobMonth, setDobMonth] = useState("");
  const [dobYear, setDobYear] = useState("");
  const [idNumber, setIdNumber] = useState("");
  const [phone, setPhone] = useState("");

  const [street, setStreet] = useState("");
  const [postalCode, setPostalCode] = useState("");
  const [city, setCity] = useState("");

  const [iban, setIban] = useState("");
  const [accountHolder, setAccountHolder] = useState("");

  const [chargesEnabled, setChargesEnabled] = useState(false);
  const [payoutsEnabled, setPayoutsEnabled] = useState(false);

  const currentIndex = STEPS.indexOf(step);

  async function apiCall(url: string, body: unknown) {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const json = await res.json();
    if (!res.ok || json.error) throw new Error(json.error || "Noe gikk galt");
    return json;
  }

  const handleWelcome = async () => {
    setLoading(true);
    setError("");
    try {
      await apiCall("/api/stripe/connect", {});
      await apiCall("/api/stripe/account/update", { tos_acceptance: { accepted: true } });
      setStep("personal");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Noe gikk galt");
    }
    setLoading(false);
  };

  const handlePersonal = async () => {
    if (!firstName.trim() || !lastName.trim()) { setError("Fornavn og etternavn er påkrevd"); return; }
    if (!dobDay || !dobMonth || !dobYear) { setError("Fødselsdato er påkrevd"); return; }
    if (!/^\d{11}$/.test(idNumber)) { setError("Personnummer må være 11 siffer"); return; }
    if (phone.length < 8) { setError("Telefonnummer må være minst 8 tegn"); return; }

    setLoading(true);
    setError("");
    try {
      await apiCall("/api/stripe/account/update", {
        individual: {
          first_name: firstName.trim(),
          last_name: lastName.trim(),
          dob: { day: Number(dobDay), month: Number(dobMonth), year: Number(dobYear) },
          id_number: idNumber,
          phone: phone.startsWith("+") ? phone : `+47${phone.replace(/\s/g, "")}`,
        },
      });
      setStep("address");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Noe gikk galt");
    }
    setLoading(false);
  };

  const handleAddress = async () => {
    if (!street.trim()) { setError("Gateadresse er påkrevd"); return; }
    if (postalCode.length < 4) { setError("Postnummer må være minst 4 siffer"); return; }
    if (!city.trim()) { setError("Poststed er påkrevd"); return; }

    setLoading(true);
    setError("");
    try {
      await apiCall("/api/stripe/account/update", {
        individual: {
          address: { line1: street.trim(), postal_code: postalCode.trim(), city: city.trim(), country: "NO" },
        },
      });
      setStep("bank");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Noe gikk galt");
    }
    setLoading(false);
  };

  const handleBank = async () => {
    const cleanIban = iban.replace(/\s+/g, "").toUpperCase();
    if (!/^NO\d{13}$/.test(cleanIban)) { setError("Ugyldig norsk IBAN (NO + 13 siffer)"); return; }
    if (accountHolder.trim().length < 2) { setError("Kontoinnehavers navn er påkrevd"); return; }

    setLoading(true);
    setError("");
    try {
      const result = await apiCall("/api/stripe/account/bank", {
        iban: cleanIban,
        accountHolderName: accountHolder.trim(),
      });
      setChargesEnabled(result.charges_enabled);
      setPayoutsEnabled(result.payouts_enabled);
      setStep("status");

      if (result.charges_enabled && result.payouts_enabled) {
        const supabase = createClient();
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
          await supabase.from("profiles").update({ stripe_onboarding_complete: true }).eq("id", user.id);
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Noe gikk galt");
    }
    setLoading(false);
  };

  const handleRefreshStatus = async () => {
    setLoading(true);
    setError("");
    try {
      const result = await apiCall("/api/stripe/connect", {});
      setChargesEnabled(result.charges_enabled);
      setPayoutsEnabled(result.payouts_enabled);

      if (result.charges_enabled && result.payouts_enabled) {
        const supabase = createClient();
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
          await supabase.from("profiles").update({ stripe_onboarding_complete: true }).eq("id", user.id);
        }
        onComplete();
      } else {
        setError("Kontoen din er ikke helt klar ennå. Stripe behandler informasjonen din.");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Noe gikk galt");
    }
    setLoading(false);
  };

  const goBack = () => {
    const prev = STEPS[currentIndex - 1];
    if (prev) { setStep(prev); setError(""); }
  };

  return (
    <div className="mx-auto max-w-lg px-4 py-10">
      {/* Progress */}
      <div className="mb-8">
        <div className="flex items-center justify-between">
          {STEPS.map((s, i) => (
            <div key={s} className="flex items-center">
              <div className={`flex h-8 w-8 items-center justify-center rounded-full text-sm font-semibold transition-colors ${
                i < currentIndex ? "bg-primary-600 text-white"
                : i === currentIndex ? "bg-primary-600 text-white ring-4 ring-primary-100"
                : "bg-neutral-200 text-neutral-500"
              }`}>
                {i < currentIndex ? <CheckCircle2 className="h-5 w-5" /> : i + 1}
              </div>
              {i < STEPS.length - 1 && (
                <div className={`mx-1 h-0.5 w-6 sm:w-10 ${i < currentIndex ? "bg-primary-600" : "bg-neutral-200"}`} />
              )}
            </div>
          ))}
        </div>
        <p className="mt-3 text-center text-sm font-medium text-neutral-600">{stepLabels[step]}</p>
      </div>

      {/* Error */}
      {error && (
        <div className="mb-4 rounded-lg bg-red-50 border border-red-200 p-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Welcome */}
      {step === "welcome" && (
        <div className="text-center">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-primary-50">
            <ShieldCheck className="h-8 w-8 text-primary-600" />
          </div>
          <h1 className="mt-6 text-2xl font-bold text-neutral-900">Bli utleier på Tuno</h1>
          <p className="mt-3 text-neutral-600">
            For å motta utbetalinger trenger vi litt informasjon. Dette tar ca. 3 minutter.
          </p>
          <p className="mt-4 text-xs text-neutral-500">
            Ved å fortsette godtar du{" "}
            <a href="https://stripe.com/connect-account/legal/full" target="_blank" className="underline">Stripes tjenestevilkår</a>,
            Tunos{" "}
            <a href="/utleiervilkar" target="_blank" className="underline">utleiervilkår</a>{" "}
            og{" "}
            <a href="/retningslinjer" target="_blank" className="underline">retningslinjer for annonser</a>.
          </p>
          <Button className="mt-8 w-full" onClick={handleWelcome} disabled={loading}>
            {loading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
            Kom i gang
            <ChevronRight className="ml-1 h-4 w-4" />
          </Button>
        </div>
      )}

      {/* Personal */}
      {step === "personal" && (
        <div>
          <div className="flex items-center gap-3 mb-6">
            <UserCircle className="h-6 w-6 text-primary-600" />
            <h2 className="text-lg font-semibold text-neutral-900">Personlig informasjon</h2>
          </div>
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <Input id="firstName" label="Fornavn" value={firstName} onChange={(e) => setFirstName(e.target.value)} placeholder="Ola" />
              <Input id="lastName" label="Etternavn" value={lastName} onChange={(e) => setLastName(e.target.value)} placeholder="Nordmann" />
            </div>
            <div>
              <label className="mb-1.5 block text-sm font-medium text-neutral-700">Fødselsdato</label>
              <div className="grid grid-cols-3 gap-3">
                <Input id="dobDay" placeholder="Dag" value={dobDay} onChange={(e) => setDobDay(e.target.value)} type="number" />
                <Input id="dobMonth" placeholder="Måned" value={dobMonth} onChange={(e) => setDobMonth(e.target.value)} type="number" />
                <Input id="dobYear" placeholder="År" value={dobYear} onChange={(e) => setDobYear(e.target.value)} type="number" />
              </div>
            </div>
            <Input id="idNumber" label="Personnummer" value={idNumber} onChange={(e) => setIdNumber(e.target.value)} placeholder="11 siffer" maxLength={11} />
            <Input id="phone" label="Telefonnummer" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+47 123 45 678" type="tel" />
          </div>
          <div className="mt-6 flex gap-3">
            <Button variant="outline" onClick={goBack}><ArrowLeft className="mr-1 h-4 w-4" />Tilbake</Button>
            <Button className="flex-1" onClick={handlePersonal} disabled={loading}>
              {loading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
              Neste <ChevronRight className="ml-1 h-4 w-4" />
            </Button>
          </div>
        </div>
      )}

      {/* Address */}
      {step === "address" && (
        <div>
          <div className="flex items-center gap-3 mb-6">
            <MapPin className="h-6 w-6 text-primary-600" />
            <h2 className="text-lg font-semibold text-neutral-900">Adresse</h2>
          </div>
          <div className="space-y-4">
            <Input id="street" label="Gateadresse" value={street} onChange={(e) => setStreet(e.target.value)} placeholder="Storgata 1" />
            <div className="grid grid-cols-2 gap-4">
              <Input id="postalCode" label="Postnummer" value={postalCode} onChange={(e) => setPostalCode(e.target.value)} placeholder="0150" maxLength={4} />
              <Input id="city" label="Poststed" value={city} onChange={(e) => setCity(e.target.value)} placeholder="Oslo" />
            </div>
            <div className="rounded-lg bg-neutral-50 border border-neutral-200 px-3 py-2 text-sm text-neutral-500">
              Land: Norge
            </div>
          </div>
          <div className="mt-6 flex gap-3">
            <Button variant="outline" onClick={goBack}><ArrowLeft className="mr-1 h-4 w-4" />Tilbake</Button>
            <Button className="flex-1" onClick={handleAddress} disabled={loading}>
              {loading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
              Neste <ChevronRight className="ml-1 h-4 w-4" />
            </Button>
          </div>
        </div>
      )}

      {/* Bank */}
      {step === "bank" && (
        <div>
          <div className="flex items-center gap-3 mb-6">
            <Building2 className="h-6 w-6 text-primary-600" />
            <h2 className="text-lg font-semibold text-neutral-900">Bankkonto</h2>
          </div>
          <p className="mb-4 text-sm text-neutral-500">
            Oppgi din norske bankkonto for å motta utbetalinger. IBAN finner du i nettbanken din.
          </p>
          <div className="space-y-4">
            <Input id="iban" label="IBAN" value={iban} onChange={(e) => setIban(e.target.value)} placeholder="NO93 8601 1117 947" />
            <Input id="accountHolder" label="Kontoinnehaver" value={accountHolder} onChange={(e) => setAccountHolder(e.target.value)} placeholder="Ola Nordmann" />
          </div>
          <div className="mt-6 flex gap-3">
            <Button variant="outline" onClick={goBack}><ArrowLeft className="mr-1 h-4 w-4" />Tilbake</Button>
            <Button className="flex-1" onClick={handleBank} disabled={loading}>
              {loading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
              Fullfør
            </Button>
          </div>
        </div>
      )}

      {/* Status */}
      {step === "status" && (
        <div className="text-center">
          {chargesEnabled && payoutsEnabled ? (
            <>
              <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-green-50">
                <CheckCircle2 className="h-8 w-8 text-green-600" />
              </div>
              <h2 className="mt-6 text-2xl font-bold text-neutral-900">Du er klar!</h2>
              <p className="mt-3 text-neutral-600">
                Kontoen din er verifisert. Du kan nå opprette din første annonse.
              </p>
              <Button className="mt-8 w-full" onClick={onComplete}>
                Opprett annonse <ChevronRight className="ml-1 h-4 w-4" />
              </Button>
            </>
          ) : (
            <>
              <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-amber-50">
                <Loader2 className="h-8 w-8 text-amber-600 animate-spin" />
              </div>
              <h2 className="mt-6 text-2xl font-bold text-neutral-900">Verifisering pågår</h2>
              <p className="mt-3 text-neutral-600">
                Stripe behandler informasjonen din. Dette tar vanligvis noen sekunder.
              </p>
              <Button className="mt-8 w-full" onClick={handleRefreshStatus} disabled={loading}>
                {loading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                Sjekk status
              </Button>
            </>
          )}
        </div>
      )}
    </div>
  );
}
