import {
  useEffect,
  useState
} from "react";

import type {
  Session,
  User
} from "@supabase/supabase-js";

import {
  supabase
} from "./lib/supabase";

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

  const [children, setChildren] =
    useState<ChildProfile[]>([]);

  const [nickname, setNickname] =
    useState("");

  const [ageBand, setAgeBand] =
    useState("3-4");

  const [
    preferredLanguage,
    setPreferredLanguage
  ] = useState("ms");

  useEffect(() => {
    void supabase.auth
      .getSession()
      .then(({ data }) => {
        setSession(
          data.session
        );

        setUser(
          data.session?.user ??
            null
        );
      });

    const {
      data: subscription
    } =
      supabase.auth
        .onAuthStateChange(
          (_event, nextSession) => {
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
      return;
    }

    void loadChildren();
  }, [user]);

  async function loadChildren() {
    if (!user) {
      return;
    }

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
      setMessage(
        error.message
      );

      return;
    }

    setChildren(
      data ?? []
    );
  }

  async function signUp() {
    setMessage(null);

    const {
      error
    } =
      await supabase.auth
        .signUp({
          email,
          password
        });

    if (error) {
      setMessage(
        error.message
      );

      return;
    }

    setMessage(
      "Akaun berjaya didaftarkan. Semak e-mel jika pengesahan diperlukan."
    );
  }

  async function signIn() {
    setMessage(null);

    const {
      error
    } =
      await supabase.auth
        .signInWithPassword({
          email,
          password
        });

    if (error) {
      setMessage(
        error.message
      );

      return;
    }

    setMessage(
      "Log masuk berjaya."
    );
  }

  async function signOut() {
    await supabase.auth
      .signOut();

    setMessage(null);
  }

  async function createChild() {
    if (!user) {
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

    setMessage(null);

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
      setMessage(
        error.message
      );

      return;
    }

    setNickname("");

    await loadChildren();

    setMessage(
      "Profil anak berjaya dicipta."
    );
  }

  if (!session) {
    return (
      <main className="mx-auto min-h-screen max-w-lg px-5 py-10">
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

        <section className="rounded-3xl bg-white p-6 shadow-sm">
          <h2 className="text-xl font-bold text-slate-900">
            Akaun Ibu Bapa / Penjaga
          </h2>

          <label className="mt-5 block text-sm font-semibold text-slate-700">
            E-mel
          </label>

          <input
            type="email"
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
              onClick={
                () =>
                  void signUp()
              }
              className="rounded-2xl bg-slate-900 px-5 py-3 font-semibold text-white"
            >
              Daftar
            </button>

            <button
              type="button"
              onClick={
                () =>
                  void signIn()
              }
              className="rounded-2xl border border-slate-300 bg-white px-5 py-3 font-semibold text-slate-700"
            >
              Log masuk
            </button>
          </div>

          {message && (
            <p className="mt-5 rounded-2xl bg-slate-100 px-4 py-3 text-sm text-slate-700">
              {message}
            </p>
          )}
        </section>
      </main>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-3xl px-5 py-10">
      <header className="mb-8 flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">
            HIBEYA
          </p>

          <h1 className="mt-1 text-3xl font-bold text-slate-900">
            Akal Budi
          </h1>

          <p className="mt-1 text-sm text-slate-600">
            {user?.email}
          </p>
        </div>

        <button
          type="button"
          onClick={
            () =>
              void signOut()
          }
          className="rounded-2xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-700"
        >
          Log keluar
        </button>
      </header>

      <section className="rounded-3xl bg-white p-6 shadow-sm">
        <h2 className="text-xl font-bold text-slate-900">
          Tambah Profil Anak
        </h2>

        <p className="mt-1 text-sm text-slate-600">
          Gunakan nama panggilan sahaja.
        </p>

        <label className="mt-5 block text-sm font-semibold text-slate-700">
          Nama panggilan
        </label>

        <input
          value={nickname}
          onChange={
            (event) =>
              setNickname(
                event.target.value
              )
          }
          maxLength={40}
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
          onClick={
            () =>
              void createChild()
          }
          className="mt-6 rounded-2xl bg-slate-900 px-5 py-3 font-semibold text-white"
        >
          Cipta profil anak
        </button>

        {message && (
          <p className="mt-5 rounded-2xl bg-slate-100 px-4 py-3 text-sm text-slate-700">
            {message}
          </p>
        )}
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
                    {child.nickname}
                  </p>

                  <p className="mt-1 text-sm text-slate-600">
                    Umur:{" "}
                    {child.age_band}
                  </p>

                  <p className="text-sm text-slate-600">
                    Bahasa:{" "}
                    {
                      child.preferred_language
                    }
                  </p>
                </article>
              )
            )}
          </div>
        )}
      </section>
    </main>
  );
}

export default App;
