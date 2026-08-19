import {
  useEffect,
  useState
} from "react";

import {
  clearLearnerDevice,
  getLearnerDevice
} from "@akal-budi/offline";

import {
  DeviceActivation
} from "./features/activation/DeviceActivation";

import {
  ActivityPlayer
} from "./features/play/ActivityPlayer";

import {
  validateLearnerDevice
} from "./services/deviceActivationService";


type ActivationState =
  | "checking"
  | "active"
  | "inactive";


function App() {
  const [
    activationState,
    setActivationState
  ] =
    useState<ActivationState>(
      "checking"
    );


  useEffect(() => {
    void validateStoredDevice();
  }, []);


  async function validateStoredDevice() {
    const device =
      await getLearnerDevice();


    if (!device) {
      setActivationState(
        "inactive"
      );

      return;
    }


    try {
      const validation =
        await validateLearnerDevice(
          device.deviceId,
          device.deviceToken
        );


      if (
        !validation.valid ||
        validation.childId !==
          device.childId
      ) {
        await clearLearnerDevice();

        setActivationState(
          "inactive"
        );

        return;
      }


      setActivationState(
        "active"
      );
    } catch {
      /*
       * Offline-first behaviour:
       *
       * If the network is unavailable we keep the locally
       * activated learner experience available.
       *
       * A network error must not destroy the local identity.
       *
       * Remote sync will independently require token validation.
       */
      setActivationState(
        "active"
      );
    }
  }


  if (
    activationState ===
    "checking"
  ) {
    return (
      <main className="flex min-h-screen items-center justify-center px-5">
        <div className="text-center">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
            HIBEYA
          </p>

          <h1 className="mt-2 text-3xl font-bold text-slate-900">
            Akal Budi
          </h1>

          <p className="mt-4 text-slate-600">
            Memeriksa peranti...
          </p>
        </div>
      </main>
    );
  }


  if (
    activationState ===
    "inactive"
  ) {
    return (
      <DeviceActivation
        onActivated={
          () =>
            setActivationState(
              "active"
            )
        }
      />
    );
  }


  return (
    <ActivityPlayer />
  );
}


export default App;
