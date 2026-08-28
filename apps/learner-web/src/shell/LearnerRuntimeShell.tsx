import type {
  ReactNode
} from "react";

import {
  LearnerShell
} from "./LearnerShell";

export interface LearnerRuntimeShellProps {
  children:
    ReactNode;

  learnerName?:
    string;

  progressPercent?:
    number;

  progressAvailable?:
    boolean;
}

export function LearnerRuntimeShell({
  children,
  learnerName,
  progressPercent,
  progressAvailable
}: LearnerRuntimeShellProps) {
  return (
    <LearnerShell
      learnerName={learnerName}
      progressPercent={progressPercent}
      progressAvailable={progressAvailable}
      title="Jom belajar!"
      subtitle="Pilih satu aktiviti dan belajar mengikut rentak sendiri."
    >
      {children}
    </LearnerShell>
  );
}
