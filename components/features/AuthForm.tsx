"use client";

import { useState, type FormEvent, type ReactNode } from "react";
import Button from "@/components/ui/Button";
import Input from "@/components/ui/Input";

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
  onSubmit: (values: Record<string, string>) => Promise<void>;
}

export default function AuthForm({
  title,
  subtitle,
  fields,
  submitLabel,
  footer,
  extraContent,
  onSubmit,
}: AuthFormProps) {
  const [values, setValues] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [globalError, setGlobalError] = useState("");

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setErrors({});
    setGlobalError("");
    setLoading(true);
    try {
      await onSubmit(values);
    } catch (err) {
      if (err instanceof Error) {
        setGlobalError(err.message);
      }
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

      <Button type="submit" size="lg" className="w-full" disabled={loading}>
        {loading ? "Vennligst vent..." : submitLabel}
      </Button>

      {footer && (
        <div className="text-center text-sm text-neutral-500">{footer}</div>
      )}
    </form>
  );
}
