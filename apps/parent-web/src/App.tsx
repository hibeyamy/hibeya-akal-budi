import {
  useEffect,
  useMemo,
  useState
} from "react";

import type {
  Session,
  User
} from "@supabase/supabase-js";

import {
  supabase
} from "./lib/supabase";

import {
  getConsentState,
  getCurrentPrivacyNotice,
  saveInitialConsent,
  type ConsentState,
  type PrivacyNotice
} from "./services/consentService";

import {
  createActivationCode,
  getLearnerDevices,
  revokeLearnerDevice,
  type ActivationCode,
  type LearnerDevice
} from "./services/deviceActivationService";

import {
  getErrorMessage
} from "./utils/errorMessage";


interface ChildProfile {
  id: string;
  nickname: string;
  age_band: string;
  preferred_language: string;
}


function App() {
  const [session, setSession] =
    useState<Session | null>(null);

  const [user, setUser] =
    useState<User | null>(null);

  const [email, setEmail] =
    useState("");

  const [password, setPassword] =
    useState("");

  const [message, setMessage] =
    useState<string | null>(null);

  const [busy, setBusy] =
    useState(false);


  const [
    privacyNotice,
    setPrivacyNotice
  ] =
    useState<PrivacyNotice | null>(
      null
    );

  const [
    consentState,
    setConsentState
  ] =
    useState<ConsentState | null>(
      null
    );

  const [
    privacyAccepted,
    setPrivacyAccepted
  ] =
    useState(false);

  const [
    essentialAccepted,
    setEssentialAccepted
  ] =
    useState(false);

  const [
    analyticsAccepted,
    setAnalyticsAccepted
  ] =
    useState(false);


  const [children, setChildren] =
    useState<ChildProfile[]>([]);

  const [nickname, setNickname] =
    useState("");

  const [ageBand, setAgeBand] =
    useState("3-4");

  const [
    preferredLanguage,
    setPreferredLanguage
  ] =
    useState("ms");


  const [
    devices,
    setDevices
  ] =
    useState<LearnerDevice[]>([]);

  const [
    selectedChildId,
    setSelectedChildId
  ] =
    useState("");

  const [
    activation,
    setActivation
  ] =
    useState<ActivationCode | null>(
      null
    );


  useEffect(() => {
    void supabase.auth
      .getSession()
      .then(
        ({ data }) => {
          setSession(
            data.session
          );

          setUser(
            data.session?.user ??
              null
          );
        }
      );

    const {
      data: subscription
    } =
      supabase.auth
        .onAuthStateChange(
          (
            _event,
            nextSession
          ) => {
            setSession(
              nextSession
            );

            setUser(
              nextSession?.user ??
                null
            );
          }
        );

    return () => {
      subscription.subscription
        .unsubscribe();
    };
  }, []);


  useEffect(() => {
    if (!user) {
      setChildren([]);
      setDevices([]);
      setConsentState(null);
      setPrivacyNotice(null);
      setSelectedChildId("");
      setActivation(null);

      return;
    }

    void loadParentData();
  }, [user]);


  useEffect(() => {
    if (
      children.length > 0 &&
      !selectedChildId
    ) {
      setSelectedChildId(
        children[0].id
      );
    }
  }, [
    children,
    selectedChildId
  ]);


  const devicesByChild =
    useMemo(
      () => {
        const map =
          new Map<
            string,
            LearnerDevice[]
          >();

        for (
          const device of devices
        ) {
          const current =
            map.get(
              device.childId
            ) ?? [];

          current.push(
            device
          );

          map.set(
            device.childId,
            current
          );
        }

        return map;
      },
      [devices]
    );


  async function loadParentData() {
    setBusy(true);
    setMessage(null);

    try {
      const notice =
        await getCurrentPrivacyNotice();

      setPrivacyNotice(
        notice
      );

      if (!notice) {
        setConsentState(null);

        setMessage(
          "Tiada notis privasi aktif ditemui."
        );

        return;
      }

      const consent =
        await getConsentState(
          notice.id
        );

      setConsentState(
        consent
      );

      setAnalyticsAccepted(
        consent
          .productAnalyticsAccepted
      );

      if (
        consent
          .privacyNoticeAccepted &&
        consent
          .essentialProcessingAccepted
      ) {
        await Promise.all([
          loadChildren(),
          loadDevices()
        ]);
      } else {
        setChildren([]);
        setDevices([]);
      }
    } catch (error) {
      setMessage(
        getErrorMessage(error)
      );
    } finally {
      setBusy(false);
    }
  }


  async function loadChildren() {
    const {
      data,
      error
    } =
      await supabase
        .from("children")
        .select(
          "id,nickname,age_band,preferred_language"
        )
        .order(
          "created_at",
          {
            ascending: true
          }
        );

    if (error) {
      throw error;
    }

    setChildren(
      data ?? []
    );
  }


  async function loadDevices() {
    const result =
      await getLearnerDevices();

    setDevices(
      result
    );
  }


  async function signUp() {
    setBusy(true);
    setMessage(null);

    try {
      const {
        error
      } =
        await supabase.auth
          .signUp({
            email,
            password
          });

      if (error) {
        throw error;
      }

      setMessage(
        "Akaun berjaya didaftarkan. Semak e-mel jika pengesahan diperlukan."
      );
    } catch (error) {
      setMessage(
        getErrorMessage(error)
      );
    } finally {
      setBusy(false);
    }
  }


  async function signIn() {
    setBusy(true);
    setMessage(null);

    try {
      const {
        error
      } =
        await supabase.auth
          .signInWithPassword({
            email,
            password
          });

      if (error) {
        throw error;
      }

      setMessage(
        "Log masuk berjaya."
      );
    } catch (error) {
      setMessage(
        getErrorMessage(error)
      );
    } finally {
      setBusy(false);
    }
  }


  async function signOut() {
    setBusy(true);

    await supabase.auth
      .signOut();

    setMessage(null);
    setBusy(false);
  }


  async function submitConsent() {
    if (!privacyNotice) {
      return;
    }

    if (
      !privacyAccepted ||
      !essentialAccepted
    ) {
      setMessage(
        "Penerimaan Notis Privasi dan pemprosesan data penting diperlukan untuk menggunakan akaun Akal Budi."
      );

      return;
    }

    setBusy(true);
    setMessage(null);

    try {
      await saveInitialConsent(
        privacyNotice.id,
        analyticsAccepted
      );

      await loadParentData();

      setMessage(
        "Pilihan privasi berjaya direkodkan."
      );
    } catch (error) {
      setMessage(
        getErrorMessage(error)
      );
    } finally {
      setBusy(false);
    }
  }


  async function createChild() {
    if (!user) {
      return;
    }

    if (
      !consentState
        ?.privacyNoticeAccepted ||
      !consentState
        ?.essentialProcessingAccepted
    ) {
      setMessage(
        "Lengkapkan tetapan privasi terlebih dahulu."
      );

      return;
    }

    if (
      nickname.trim()
        .length === 0
    ) {
      setMessage(
        "Masukkan nama panggilan."
      );

      return;
    }

    setBusy(true);
    setMessage(null);

    try {
      const {
        error
      } =
        await supabase
          .from("children")
          .insert({
            parent_id:
              user.id,

            nickname:
              nickname.trim(),

            age_band:
              ageBand,

            preferred_language:
              preferredLanguage
          });

      if (error) {
        throw error;
      }

      setNickname("");

      await loadChildren();

      setMessage(
        "Profil anak berjaya dicipta."
      );
    } catch (error) {
      setMessage(
        getErrorMessage(error)
      );
    } finally {
      setBusy(false);
    }
  }


  async function generateActivation() {
    if (!selectedChildId) {
      setMessage(
        "Pilih profil anak terlebih dahulu."
      );

      return;
    }

    setBusy(true);
    setMessage(null);
    setActivation(null);

    try {
      const result =
        await createActivationCode(
          selectedChildId
        );

      setActivation(
        result
      );
    } catch (error) {
      setMessage(
        getErrorMessage(error)
      );
    } finally {
      setBusy(false);
    }
  }


  async function revokeDevice(
    deviceId: string
  ) {
    setBusy(true);
    setMessage(null);

    try {
      await revokeLearnerDevice(
        deviceId
      );

      await loadDevices();

      setMessage(
        "Peranti berjaya dinyahaktifkan."
      );
    } catch (error) {
      setMessage(
        getErrorMessage(error)
      );
    } finally {
      setBusy(false);
    }
  }


  if (!session) {
    return (
      <main className="mx-auto min-h-screen max-w-lg px-5 py-10">
        <BrandHeader />

        <section className="rounded-3xl bg-white p-6 shadow-sm">
          <h2 className="text-xl font-bold text-slate-900">
            Akaun Ibu Bapa / Penjaga
          </h2>

          <p className="mt-2 text-sm leading-6 text-slate-600">
            Akaun ini adalah untuk orang dewasa.
            Kanak-kanak tidak memerlukan akaun sendiri.
          </p>

          <label className="mt-5 block text-sm font-semibold text-slate-700">
            E-mel
          </label>

          <input
            type="email"
            autoComplete="email"
            value={email}
            onChange={
              (event) =>
                setEmail(
                  event.target.value
                )
            }
            className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3"
          />

          <label className="mt-4 block text-sm font-semibold text-slate-700">
            Kata laluan
          </label>

          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={
              (event) =>
                setPassword(
                  event.target.value
                )
            }
            className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3"
          />

          <div className="mt-6 flex flex-col gap-3 sm:flex-row">
            <button
              type="button"
              disabled={busy}
              onClick={
                () =>
                  void signUp()
              }
              className="rounded-2xl bg-slate-900 px-5 py-3 font-semibold text-white disabled:opacity-50"
            >
              Daftar
            </button>

            <button
              type="button"
              disabled={busy}
              onClick={
                () =>
                  void signIn()
              }
              className="rounded-2xl border border-slate-300 bg-white px-5 py-3 font-semibold text-slate-700 disabled:opacity-50"
            >
              Log masuk
            </button>
          </div>

          <StatusMessage
            message={message}
          />
        </section>
      </main>
    );
  }


  const mandatoryConsentComplete =
    Boolean(
      consentState
        ?.privacyNoticeAccepted &&
      consentState
        ?.essentialProcessingAccepted
    );


  if (
    !mandatoryConsentComplete
  ) {
    return (
      <main className="mx-auto min-h-screen max-w-2xl px-5 py-10">
        <ParentHeader
          email={user?.email}
          onSignOut={
            () =>
              void signOut()
          }
        />

        <section className="rounded-3xl bg-white p-6 shadow-sm sm:p-8">
          <p className="text-sm font-bold uppercase tracking-[0.15em] text-amber-700">
            Langkah Privasi
          </p>

          <h2 className="mt-2 text-2xl font-bold text-slate-900">
            Sebelum mencipta profil anak
          </h2>

          <p className="mt-3 leading-7 text-slate-600">
            Kami mahu hanya mengumpulkan data yang benar-benar diperlukan untuk menyediakan pengalaman Akal Budi.
          </p>

          {privacyNotice && (
            <div className="mt-6 rounded-2xl bg-slate-50 p-4">
              <p className="font-semibold text-slate-900">
                Notis Privasi
              </p>

              <p className="mt-1 text-sm text-slate-600">
                Versi{" "}
                {
                  privacyNotice.version
                }
              </p>

              {privacyNotice.noticeUrl ? (
                <a
                  href={
                    privacyNotice.noticeUrl
                  }
                  target="_blank"
                  rel="noreferrer"
                  className="mt-2 inline-block text-sm font-semibold text-amber-700 underline"
                >
                  Baca Notis Privasi
                </a>
              ) : (
                <p className="mt-2 text-sm text-amber-800">
                  Versi pembangunan — notis undang-undang produksi belum diterbitkan.
                </p>
              )}
            </div>
          )}

          <ConsentCheckbox
            checked={
              privacyAccepted
            }
            onChange={
              setPrivacyAccepted
            }
            title="Saya telah membaca dan memahami Notis Privasi."
            description="Diperlukan untuk meneruskan penggunaan akaun."
          />

          <ConsentCheckbox
            checked={
              essentialAccepted
            }
            onChange={
              setEssentialAccepted
            }
            title="Saya bersetuju dengan pemprosesan data penting."
            description="Ini merangkumi data minimum yang diperlukan untuk akaun ibu bapa, profil anak dan kemajuan pembelajaran."
          />

          <ConsentCheckbox
            checked={
              analyticsAccepted
            }
            onChange={
              setAnalyticsAccepted
            }
            title="Benarkan analitik produk."
            description="Pilihan. Tidak diperlukan untuk menggunakan Akal Budi."
            optional
          />

          <button
            type="button"
            disabled={
              busy ||
              !privacyAccepted ||
              !essentialAccepted
            }
            onClick={
              () =>
                void submitConsent()
            }
            className="mt-7 w-full rounded-2xl bg-slate-900 px-5 py-3 font-semibold text-white disabled:cursor-not-allowed disabled:opacity-40"
          >
            Simpan dan teruskan
          </button>

          <StatusMessage
            message={message}
          />
        </section>
      </main>
    );
  }


  return (
    <main className="mx-auto min-h-screen max-w-4xl px-5 py-10">
      <ParentHeader
        email={user?.email}
        onSignOut={
          () =>
            void signOut()
        }
      />

      <section className="rounded-3xl bg-white p-6 shadow-sm">
        <h2 className="text-xl font-bold text-slate-900">
          Tambah Profil Anak
        </h2>

        <p className="mt-1 text-sm leading-6 text-slate-600">
          Gunakan nama panggilan sahaja.
          Jangan masukkan nama penuh, nombor MyKid,
          sekolah atau maklumat pengenalan lain.
        </p>

        <label className="mt-5 block text-sm font-semibold text-slate-700">
          Nama panggilan
        </label>

        <input
          value={nickname}
          maxLength={40}
          onChange={
            (event) =>
              setNickname(
                event.target.value
              )
          }
          className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3"
        />

        <label className="mt-4 block text-sm font-semibold text-slate-700">
          Julat umur
        </label>

        <select
          value={ageBand}
          onChange={
            (event) =>
              setAgeBand(
                event.target.value
              )
          }
          className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3"
        >
          <option value="2-3">
            2–3 tahun
          </option>

          <option value="3-4">
            3–4 tahun
          </option>

          <option value="4-5">
            4–5 tahun
          </option>

          <option value="5-6">
            5–6 tahun
          </option>
        </select>

        <label className="mt-4 block text-sm font-semibold text-slate-700">
          Bahasa utama
        </label>

        <select
          value={
            preferredLanguage
          }
          onChange={
            (event) =>
              setPreferredLanguage(
                event.target.value
              )
          }
          className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3"
        >
          <option value="ms">
            Bahasa Melayu
          </option>

          <option value="en">
            English
          </option>
        </select>

        <button
          type="button"
          disabled={busy}
          onClick={
            () =>
              void createChild()
          }
          className="mt-6 rounded-2xl bg-slate-900 px-5 py-3 font-semibold text-white disabled:opacity-50"
        >
          Cipta profil anak
        </button>

        <StatusMessage
          message={message}
        />
      </section>


      <section className="mt-6 rounded-3xl bg-white p-6 shadow-sm">
        <h2 className="text-xl font-bold text-slate-900">
          Profil Anak
        </h2>

        {children.length === 0 ? (
          <p className="mt-3 text-slate-600">
            Belum ada profil anak.
          </p>
        ) : (
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            {children.map(
              (child) => (
                <article
                  key={child.id}
                  className="rounded-2xl border border-slate-200 bg-slate-50 p-4"
                >
                  <p className="text-lg font-bold text-slate-900">
                    {
                      child.nickname
                    }
                  </p>

                  <p className="mt-1 text-sm text-slate-600">
                    Umur:{" "}
                    {
                      child.age_band
                    }
                  </p>

                  <p className="text-sm text-slate-600">
                    Bahasa:{" "}
                    {
                      child.preferred_language ===
                      "ms"
                        ? "Bahasa Melayu"
                        : "English"
                    }
                  </p>

                  <p className="mt-2 text-xs text-slate-500">
                    Peranti aktif:{" "}
                    {
                      (
                        devicesByChild
                          .get(
                            child.id
                          ) ?? []
                      ).filter(
                        (device) =>
                          !device.revokedAt
                      ).length
                    }
                  </p>
                </article>
              )
            )}
          </div>
        )}
      </section>


      <section className="mt-6 rounded-3xl bg-white p-6 shadow-sm">
        <p className="text-sm font-bold uppercase tracking-[0.15em] text-amber-700">
          Learner Mode
        </p>

        <h2 className="mt-2 text-xl font-bold text-slate-900">
          Aktifkan Peranti
        </h2>

        <p className="mt-2 text-sm leading-6 text-slate-600">
          Pilih profil anak dan jana kod 6 digit.
          Masukkan kod tersebut pada peranti yang akan digunakan oleh anak.
        </p>

        {children.length === 0 ? (
          <p className="mt-5 rounded-2xl bg-slate-100 px-4 py-3 text-sm text-slate-700">
            Cipta sekurang-kurangnya satu profil anak terlebih dahulu.
          </p>
        ) : (
          <>
            <label className="mt-5 block text-sm font-semibold text-slate-700">
              Profil anak
            </label>

            <select
              value={
                selectedChildId
              }
              onChange={
                (event) => {
                  setSelectedChildId(
                    event.target.value
                  );

                  setActivation(
                    null
                  );
                }
              }
              className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3"
            >
              {children.map(
                (child) => (
                  <option
                    key={
                      child.id
                    }
                    value={
                      child.id
                    }
                  >
                    {
                      child.nickname
                    }
                  </option>
                )
              )}
            </select>

            <button
              type="button"
              disabled={
                busy ||
                !selectedChildId
              }
              onClick={
                () =>
                  void generateActivation()
              }
              className="mt-5 rounded-2xl bg-slate-900 px-5 py-3 font-semibold text-white disabled:opacity-50"
            >
              Jana Kod Pengaktifan
            </button>
          </>
        )}

        {activation && (
          <div className="mt-6 rounded-3xl border-2 border-amber-200 bg-amber-50 p-6 text-center">
            <p className="text-sm font-semibold text-amber-800">
              Kod Pengaktifan
            </p>

            <p className="mt-3 text-5xl font-black tracking-[0.3em] text-slate-900">
              {
                activation.code
              }
            </p>

            <p className="mt-4 text-sm text-slate-600">
              Sah sehingga{" "}
              {
                new Date(
                  activation.expiresAt
                ).toLocaleTimeString(
                  "ms-MY",
                  {
                    hour:
                      "2-digit",
                    minute:
                      "2-digit"
                  }
                )
              }
            </p>

            <p className="mt-2 text-xs leading-5 text-slate-500">
              Kod ini hanya boleh digunakan sekali dan akan luput secara automatik.
            </p>
          </div>
        )}
      </section>


      <section className="mt-6 rounded-3xl bg-white p-6 shadow-sm">
        <h2 className="text-xl font-bold text-slate-900">
          Peranti Keluarga
        </h2>

        <p className="mt-2 text-sm leading-6 text-slate-600">
          Peranti yang telah diaktifkan untuk Learner Mode.
        </p>

        {devices.length === 0 ? (
          <p className="mt-4 text-slate-600">
            Belum ada peranti yang diaktifkan.
          </p>
        ) : (
          <div className="mt-5 space-y-4">
            {devices.map(
              (device) => {
                const child =
                  children.find(
                    (item) =>
                      item.id ===
                      device.childId
                  );

                const revoked =
                  Boolean(
                    device.revokedAt
                  );

                return (
                  <article
                    key={
                      device.id
                    }
                    className="rounded-2xl border border-slate-200 bg-slate-50 p-4"
                  >
                    <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
                      <div>
                        <p className="font-bold text-slate-900">
                          {
                            device.deviceName ??
                            "Peranti Akal Budi"
                          }
                        </p>

                        <p className="mt-1 text-sm text-slate-600">
                          Profil:{" "}
                          {
                            child
                              ?.nickname ??
                            "Tidak diketahui"
                          }
                        </p>

                        <p className="text-sm text-slate-600">
                          Diaktifkan:{" "}
                          {
                            new Date(
                              device.activatedAt
                            ).toLocaleString(
                              "ms-MY"
                            )
                          }
                        </p>

                        <p className="mt-1 text-xs font-semibold">
                          {revoked
                            ? "Dinyahaktifkan"
                            : "Aktif"}
                        </p>
                      </div>

                      {!revoked && (
                        <button
                          type="button"
                          disabled={busy}
                          onClick={
                            () =>
                              void revokeDevice(
                                device.id
                              )
                          }
                          className="rounded-2xl border border-red-200 bg-white px-4 py-2 text-sm font-semibold text-red-700 disabled:opacity-50"
                        >
                          Nyahaktifkan
                        </button>
                      )}
                    </div>
                  </article>
                );
              }
            )}
          </div>
        )}
      </section>
    </main>
  );
}


interface ConsentCheckboxProps {
  checked: boolean;

  onChange:
    (value: boolean) => void;

  title: string;

  description: string;

  optional?: boolean;
}


function ConsentCheckbox({
  checked,
  onChange,
  title,
  description,
  optional = false
}: ConsentCheckboxProps) {
  return (
    <label className="mt-5 flex cursor-pointer gap-4 rounded-2xl border border-slate-200 p-4">
      <input
        type="checkbox"
        checked={
          checked
        }
        onChange={
          (event) =>
            onChange(
              event.target.checked
            )
        }
        className="mt-1 h-5 w-5"
      />

      <span>
        <span className="font-semibold text-slate-900">
          {title}

          {optional && (
            <span className="ml-2 text-xs font-normal text-slate-500">
              Pilihan
            </span>
          )}
        </span>

        <span className="mt-1 block text-sm leading-6 text-slate-600">
          {
            description
          }
        </span>
      </span>
    </label>
  );
}


function BrandHeader() {
  return (
    <header className="mb-8">
      <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
        HIBEYA
      </p>

      <h1 className="mt-1 text-3xl font-bold text-slate-900">
        Akal Budi
      </h1>

      <p className="mt-1 text-slate-600">
        Parent Portal
      </p>
    </header>
  );
}


interface ParentHeaderProps {
  email:
    string | undefined;

  onSignOut:
    () => void;
}


function ParentHeader({
  email,
  onSignOut
}: ParentHeaderProps) {
  return (
    <header className="mb-8 flex items-start justify-between gap-4">
      <div>
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
          HIBEYA
        </p>

        <h1 className="mt-1 text-3xl font-bold text-slate-900">
          Akal Budi
        </h1>

        <p className="mt-1 text-sm text-slate-600">
          {email}
        </p>
      </div>

      <button
        type="button"
        onClick={
          onSignOut
        }
        className="rounded-2xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-700"
      >
        Log keluar
      </button>
    </header>
  );
}


function StatusMessage({
  message
}: {
  message:
    string | null;
}) {
  if (!message) {
    return null;
  }

  return (
    <p className="mt-5 rounded-2xl bg-slate-100 px-4 py-3 text-sm leading-6 text-slate-700">
      {message}
    </p>
  );
}


export default App;
