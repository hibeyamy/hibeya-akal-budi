import {
  useState
} from "react";

import {
  saveLearnerDevice
} from "@akal-budi/offline";

import {
  exchangeActivationCode
} from "../../services/deviceActivationService";

interface DeviceActivationProps {
  onActivated:
    () => void;
}

export function DeviceActivation({
  onActivated
}: DeviceActivationProps) {
  const [
    code,
    setCode
  ] =
    useState("");

  const [
    deviceName,
    setDeviceName
  ] =
    useState(
      "Peranti Akal Budi"
    );

  const [
    message,
    setMessage
  ] =
    useState<
      string | null
    >(null);

  const [
    busy,
    setBusy
  ] =
    useState(false);


  async function activate() {
    setBusy(true);
    setMessage(null);

    try {
      const result =
        await exchangeActivationCode(
          code,
          deviceName.trim() ||
            null
        );

      await saveLearnerDevice({
        deviceId:
          result.deviceId,

        childId:
          result.childId,

        deviceToken:
          result.deviceToken,

        deviceName:
          deviceName.trim() ||
          null
      });

      onActivated();
    } catch (error) {
      if (
        typeof error ===
          "object" &&
        error !== null &&
        "message" in error &&
        typeof error.message ===
          "string"
      ) {
        setMessage(
          error.message
        );
      } else {
        setMessage(
          "Pengaktifan peranti gagal."
        );
      }
    } finally {
      setBusy(false);
    }
  }


  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col justify-center px-5 py-10">
      <header className="mb-8 text-center">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
          HIBEYA
        </p>

        <h1 className="mt-2 text-4xl font-bold text-slate-900">
          Akal Budi
        </h1>

        <p className="mt-3 text-slate-600">
          Aktifkan peranti ini bersama ibu bapa atau penjaga.
        </p>
      </header>


      <section className="rounded-[2rem] bg-white p-6 shadow-sm sm:p-8">
        <h2 className="text-center text-xl font-bold text-slate-900">
          Kod Pengaktifan
        </h2>

        <p className="mt-2 text-center text-sm leading-6 text-slate-600">
          Masukkan kod 6 digit daripada Parent Portal.
        </p>


        <input
          type="text"
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={6}
          value={code}
          onChange={
            (event) =>
              setCode(
                event.target
                  .value
                  .replace(
                    /\D/g,
                    ""
                  )
                  .slice(
                    0,
                    6
                  )
              )
          }
          placeholder="000000"
          aria-label="Kod pengaktifan 6 digit"
          className="mt-7 w-full rounded-3xl border-2 border-slate-200 px-5 py-5 text-center text-4xl font-bold tracking-[0.35em] text-slate-900"
        />


        <label className="mt-6 block text-sm font-semibold text-slate-700">
          Nama peranti
        </label>

        <input
          type="text"
          maxLength={80}
          value={
            deviceName
          }
          onChange={
            (event) =>
              setDeviceName(
                event.target.value
              )
          }
          className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3"
        />


        <button
          type="button"
          disabled={
            busy ||
            code.length !== 6
          }
          onClick={
            () =>
              void activate()
          }
          className="mt-7 w-full rounded-2xl bg-slate-900 px-5 py-4 font-bold text-white disabled:cursor-not-allowed disabled:opacity-40"
        >
          {busy
            ? "Mengaktifkan..."
            : "Aktifkan Peranti"}
        </button>


        {message && (
          <p className="mt-5 rounded-2xl bg-amber-50 px-4 py-3 text-center text-sm leading-6 text-amber-900">
            {message}
          </p>
        )}
      </section>
    </main>
  );
}
