import type {
  HTMLAttributes,
  PropsWithChildren
} from "react";

export type Audience =
  | "learner"
  | "parent";

export interface AudienceShellProps
  extends PropsWithChildren<HTMLAttributes<HTMLDivElement>> {
  audience: Audience;
}

export function AudienceShell({
  audience,
  className = "",
  children,
  ...props
}: AudienceShellProps) {
  return (
    <div
      {...props}
      data-ab-audience={audience}
      className={[
        "ab-ui-audience-shell",
        className
      ].filter(Boolean).join(" ")}
    >
      {children}
    </div>
  );
}
