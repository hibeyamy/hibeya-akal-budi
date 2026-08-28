interface ImportMetaEnv {
  readonly BASE_URL:
    string;

  readonly MODE:
    string;

  readonly DEV:
    boolean;

  readonly PROD:
    boolean;

  readonly SSR:
    boolean;

  readonly VITE_SUPABASE_URL?:
    string;

  readonly VITE_SUPABASE_ANON_KEY?:
    string;

  readonly [key: `VITE_${string}`]:
    string |
    undefined;
}

interface ImportMeta {
  readonly env:
    ImportMetaEnv;
}
