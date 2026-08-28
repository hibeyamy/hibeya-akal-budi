import type {
  HTMLAttributes,
  PropsWithChildren
} from "react";

export type SurfaceElevation =
  | "flat"
  | "raised";

export interface SurfaceProps
  extends PropsWithChildren<HTMLAttributes<HTMLDivElement>> {
  elevation?: SurfaceElevation;
}

export function Surface({
  elevation = "raised",
  className = "",
  children,
  ...props
}: SurfaceProps) {
  return (
    <div
      {...props}
      data-elevation={elevation}
      className={[
        "ab-ui-surface",
        className
      ].filter(Boolean).join(" ")}
    >
      {children}
    </div>
  );
}
