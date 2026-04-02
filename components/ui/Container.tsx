interface ContainerProps {
  children: React.ReactNode;
  className?: string;
}

export default function Container({ children, className = "" }: ContainerProps) {
  return (
    <div className={`mx-auto w-full max-w-[1760px] px-4 sm:px-10 lg:px-20 ${className}`}>
      {children}
    </div>
  );
}
