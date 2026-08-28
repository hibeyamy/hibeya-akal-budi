import type {
  HTMLAttributes,
  PropsWithChildren
} from "react";

export type FeedbackTone =
  | "success"
  | "gentle"
  | "error";

export interface FeedbackPanelProps
  extends PropsWithChildren<HTMLAttributes<HTMLDivElement>> {
  tone?: FeedbackTone;
}

export function FeedbackPanel({
  tone = "gentle",
  className = "",
  children,
  ...props
}: FeedbackPanelProps) {
  return (
    <div
      {...props}
      data-tone={tone}
      className={[
        "ab-ui-feedback",
        className
      ].filter(Boolean).join(" ")}
      aria-live={props["aria-live"] ?? "polite"}
    >
      {children}
    </div>
  );
}
