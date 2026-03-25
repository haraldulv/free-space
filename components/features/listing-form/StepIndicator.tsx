const STEP_LABELS = [
  "Kategori",
  "Detaljer",
  "Lokasjon",
  "Bilder",
  "Fasiliteter",
  "Pris",
  "Kalender",
  "Publiser",
];

interface StepIndicatorProps {
  currentStep: number;
}

export default function StepIndicator({ currentStep }: StepIndicatorProps) {
  return (
    <div className="flex items-center gap-1">
      {STEP_LABELS.map((label, i) => (
        <div key={label} className="flex items-center gap-1 flex-1">
          <div className="flex flex-col items-center flex-1">
            <div
              className={`h-1.5 w-full rounded-full transition-colors ${
                i <= currentStep ? "bg-primary-600" : "bg-neutral-200"
              }`}
            />
            <span
              className={`mt-1.5 text-[10px] font-medium hidden sm:block ${
                i === currentStep ? "text-primary-600" : i < currentStep ? "text-neutral-500" : "text-neutral-300"
              }`}
            >
              {label}
            </span>
          </div>
        </div>
      ))}
    </div>
  );
}
