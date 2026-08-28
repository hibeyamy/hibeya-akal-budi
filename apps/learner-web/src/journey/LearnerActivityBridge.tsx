import {
  ActivityPlayerAdapter
} from "../features/play/ActivityPlayer";

export interface LearnerActivityBridgeProps {
  activityId: string;
  onClose: () => void;
  onComplete?: () => void;
}

export function LearnerActivityBridge({
  activityId,
  onClose,
  onComplete
}: LearnerActivityBridgeProps) {
  return (
    <ActivityPlayerAdapter
      activityId={activityId}
      onComplete={onComplete}
      onExit={onClose}
    />
  );
}
