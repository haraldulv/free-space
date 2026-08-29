"use client";

import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { useTranslations } from "next-intl";
import Button from "@/components/ui/Button";
import Input from "@/components/ui/Input";
import Turnstile, { TURNSTILE_ENABLED, type TurnstileHandle } from "@/components/features/Turnstile";

interface AuthFormProps {
  title?: string;
  subtitle?: ReactNode;
  fields: {
    name: string;
    label: string;
    type: string;
    placeholder?: string;
    autoComplete?: string;
  }[];
  submitLabel: string;
  footer?: ReactNode;
  extraContent?: ReactNode;
  /** Vis Turnstile-captcha. Tokenet leveres som `values.captchaToken`. */
  captcha?: boolean;
  onSubmit: (values: Record<string, string>) => Promise<void>;
}

export default function AuthForm({
  title,
  subtitle,
  fields,
  submitLabel,
  footer,
  extraContent,
  captcha = false,
  onSubmit,
}: AuthFormProps) {
  const t = useTranslations("auth");
  const [values, setValues] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [globalError, setGlobalError] = useState("");
  const [captchaToken, setCaptchaToken] = useState<string | null>(null);
  const captchaHandle = useRef<TurnstileHandle | null>(null);

  const needsCaptcha = captcha && TURNSTILE_ENABLED;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setErrors({});
    setGlobalError("");
    if (needsCaptcha && !captchaToken) {
      setGlobalError(t("captchaRequired"));
      return;
    }
    setLoading(true);
    try {
      await onSubmit(captchaToken ? { ...values, captchaToken } : values);
    } catch (err) {
      if (err instanceof Error) {
        const msg = /captcha/i.test(err.message) ? t("captchaFailed") : err.message;
        setGlobalError(msg);
      }
      // Turnstile-tokens er engangs; nullstill så neste forsøk får nytt token.
      captchaHandle.current?.reset();
      setCaptchaToken(null);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      <div className="text-center">
        <h1 className="text-2xl font-bold text-neutral-900">{title}</h1>
        {subtitle && (
          <p className="mt-1 text-sm text-neutral-500">{subtitle}</p>
        )}
      </div>

      {globalError && (
        <div className="rounded-lg bg-red-50 p-3 text-sm text-red-700">
          {globalError}
        </div>
      )}

      {fields.map((field) => (
        <Input
          key={field.name}
          id={field.name}
          label={field.label}
          type={field.type}
          placeholder={field.placeholder}
          autoComplete={field.autoComplete}
          value={values[field.name] || ""}
          onChange={(e) =>
            setValues({ ...values, [field.name]: e.target.value })
          }
          error={errors[field.name]}
        />
      ))}

      {extraContent}

      {captcha && (
        <Turnstile
          onToken={setCaptchaToken}
          onReady={(h) => { captchaHandle.current = h; }}
        />
      )}

      <Button type="submit" size="lg" className="w-full" disabled={loading}>
        {loading ? "Vennligst vent..." : submitLabel}
      </Button>

      {footer && (
        <div className="text-center text-sm text-neutral-500">{footer}</div>
      )}
    </form>
  );
}
