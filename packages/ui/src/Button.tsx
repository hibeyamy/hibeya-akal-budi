import type {
  ButtonHTMLAttributes
} from "react";

export type ButtonVariant =
  | "primary"
  | "secondary"
  | "gentle";

export interface ButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
}

export function Button({
  variant = "primary",
  type = "button",
  className = "",
  ...props
}: ButtonProps) {
  return (
    <button
      {...props}
      type={type}
      data-variant={variant}
      className={[
        "ab-ui-button",
        className
      ].filter(Boolean).join(" ")}
    />
  );
}
