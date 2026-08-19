import {
  getDatabase,
  type LearnerDeviceIdentity
} from "./database";

export interface SaveLearnerDeviceInput {
  deviceId: string;
  childId: string;
  deviceToken: string;
  deviceName:
    string | null;
}

export async function saveLearnerDevice(
  input: SaveLearnerDeviceInput
): Promise<void> {
  const database =
    await getDatabase();

  const identity:
    LearnerDeviceIdentity = {
      id:
        "active-device",

      deviceId:
        input.deviceId,

      childId:
        input.childId,

      deviceToken:
        input.deviceToken,

      deviceName:
        input.deviceName,

      activatedAt:
        Date.now()
    };

  await database.put(
    "learnerDevice",
    identity
  );
}

export async function getLearnerDevice():
  Promise<
    LearnerDeviceIdentity |
    undefined
  > {
  const database =
    await getDatabase();

  return database.get(
    "learnerDevice",
    "active-device"
  );
}

export async function clearLearnerDevice():
  Promise<void> {
  const database =
    await getDatabase();

  await database.delete(
    "learnerDevice",
    "active-device"
  );
}
