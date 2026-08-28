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
}

export function LearnerRuntimeShell({
  children,
  learnerName,
  progressPercent
}: LearnerRuntimeShellProps) {
  return (
    <LearnerShell
      learnerName={learnerName}
      progressPercent={progressPercent}
      title="Jom belajar!"
      subtitle="Pilih satu aktiviti dan belajar mengikut rentak sendiri."
    >
      {children}
    </LearnerShell>
  );
}
