import {
  LearnerHome,
  LearnerShell
} from "../../learner-web/src/shell";

export default {
  title:
    "Learner/UX Shell"
};

export function Default() {
  return (
    <LearnerShell
      learnerName="Alya"
      progressPercent={35}
    >
      <LearnerHome />
    </LearnerShell>
  );
}

export function NewLearner() {
  return (
    <LearnerShell
      learnerName="Adam"
      progressPercent={0}
      title="Selamat datang!"
      subtitle="Mari mula dengan satu aktiviti ringkas."
    >
      <LearnerHome />
    </LearnerShell>
  );
}

export function ReturningLearner() {
  return (
    <LearnerShell
      learnerName="Sofia"
      progressPercent={72}
      title="Bagus, sambung bila bersedia."
      subtitle="Kemajuan disimpan. Tiada tekanan untuk habiskan semuanya hari ini."
    >
      <LearnerHome />
    </LearnerShell>
  );
}
