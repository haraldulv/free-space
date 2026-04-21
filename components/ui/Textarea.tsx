import { forwardRef, type TextareaHTMLAttributes } from "react";

interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
  showCount?: boolean;
}

const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ label, error, id, className = "", showCount, maxLength, value, ...props }, ref) => {
    const count = typeof value === "string" ? value.length : 0;
    const showCounter = showCount && typeof maxLength === "number";
    const nearLimit = showCounter && count > (maxLength as number) * 0.9;

    return (
      <div className="space-y-1">
        {label && (
          <label htmlFor={id} className="block text-sm font-medium text-neutral-700">
            {label}
          </label>
        )}
        <textarea
          ref={ref}
          id={id}
          value={value}
          maxLength={maxLength}
          className={`w-full rounded-lg border px-3 py-2 text-sm transition-colors placeholder:text-neutral-400 focus:outline-none focus:ring-2 ${
            error
              ? "border-red-500 focus:ring-red-500/20"
              : "border-neutral-300 focus:border-primary-500 focus:ring-primary-500/20"
          } ${className}`}
          {...props}
        />
        <div className="flex items-center justify-between">
          {error ? (
            <p className="text-xs text-red-500">{error}</p>
          ) : (
            <span />
          )}
          {showCounter && (
            <p className={`text-xs tabular-nums ${nearLimit ? "text-amber-600" : "text-neutral-400"}`}>
              {count} / {maxLength}
            </p>
          )}
        </div>
      </div>
    );
  },
);

Textarea.displayName = "Textarea";
export default Textarea;
