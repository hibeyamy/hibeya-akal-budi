import {
  afterAll,
  beforeAll,
  describe,
  expect,
  it
} from "vitest";

import {
  createClient,
  type SupabaseClient
} from "@supabase/supabase-js";


const supabaseUrl =
  process.env.SUPABASE_URL;

const publishableKey =
  process.env.SUPABASE_PUBLISHABLE_KEY;

const secretKey =
  process.env.SUPABASE_SECRET_KEY;


if (!supabaseUrl) {
  throw new Error(
    "Missing SUPABASE_URL"
  );
}

if (!publishableKey) {
  throw new Error(
    "Missing SUPABASE_PUBLISHABLE_KEY"
  );
}

if (!secretKey) {
  throw new Error(
    "Missing SUPABASE_SECRET_KEY"
  );
}


const admin =
  createClient(
    supabaseUrl,
    secretKey,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false
      }
    }
  );


function createPublicClient() {
  return createClient(
    supabaseUrl!,
    publishableKey!,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false
      }
    }
  );
}


function uniqueEmail(
  label: string
) {
  return (
    `akal-budi-${label}-` +
    `${Date.now()}-` +
    `${crypto.randomUUID()}` +
    "@example.test"
  );
}


const password =
  `Ab!${crypto.randomUUID()}9z`;


let parentAEmail = "";
let parentBEmail = "";

let parentAId = "";
let parentBId = "";

let childAId = "";
let childBId = "";

let sessionAId = "";

let privacyNoticeId = "";


let parentA:
  SupabaseClient;

let parentB:
  SupabaseClient;

let anonymous:
  SupabaseClient;


beforeAll(
  async () => {
    parentAEmail =
      uniqueEmail(
        "parent-a"
      );

    parentBEmail =
      uniqueEmail(
        "parent-b"
      );


    const {
      data: createdA,
      error: createAError
    } =
      await admin.auth.admin
        .createUser({
          email:
            parentAEmail,

          password,

          email_confirm:
            true
        });


    if (
      createAError ||
      !createdA.user
    ) {
      throw new Error(
        `Unable to create Parent A: ${
          createAError?.message ??
          "Unknown error"
        }`
      );
    }


    parentAId =
      createdA.user.id;


    const {
      data: createdB,
      error: createBError
    } =
      await admin.auth.admin
        .createUser({
          email:
            parentBEmail,

          password,

          email_confirm:
            true
        });


    if (
      createBError ||
      !createdB.user
    ) {
      throw new Error(
        `Unable to create Parent B: ${
          createBError?.message ??
          "Unknown error"
        }`
      );
    }


    parentBId =
      createdB.user.id;


    parentA =
      createPublicClient();

    parentB =
      createPublicClient();

    anonymous =
      createPublicClient();


    const {
      error: signInAError
    } =
      await parentA.auth
        .signInWithPassword({
          email:
            parentAEmail,

          password
        });


    if (signInAError) {
      throw new Error(
        `Unable to sign in Parent A: ${signInAError.message}`
      );
    }


    const {
      error: signInBError
    } =
      await parentB.auth
        .signInWithPassword({
          email:
            parentBEmail,

          password
        });


    if (signInBError) {
      throw new Error(
        `Unable to sign in Parent B: ${signInBError.message}`
      );
    }


    const {
      data: notice,
      error: noticeError
    } =
      await admin
        .from(
          "privacy_notice_versions"
        )
        .select("id")
        .order(
          "effective_at",
          {
            ascending:
              false
          }
        )
        .limit(1)
        .single();


    if (
      noticeError ||
      !notice
    ) {
      throw new Error(
        `Unable to load privacy notice: ${
          noticeError?.message ??
          "No notice available"
        }`
      );
    }


    privacyNoticeId =
      notice.id;


    const {
      data: childA,
      error: childAError
    } =
      await parentA
        .from("children")
        .insert({
          parent_id:
            parentAId,

          nickname:
            "Security Test A",

          age_band:
            "3-4",

          preferred_language:
            "ms"
        })
        .select("id")
        .single();


    if (
      childAError ||
      !childA
    ) {
      throw new Error(
        `Unable to create Parent A child: ${
          childAError?.message ??
          "Unknown error"
        }`
      );
    }


    childAId =
      childA.id;


    const {
      data: childB,
      error: childBError
    } =
      await parentB
        .from("children")
        .insert({
          parent_id:
            parentBId,

          nickname:
            "Security Test B",

          age_band:
            "4-5",

          preferred_language:
            "en"
        })
        .select("id")
        .single();


    if (
      childBError ||
      !childB
    ) {
      throw new Error(
        `Unable to create Parent B child: ${
          childBError?.message ??
          "Unknown error"
        }`
      );
    }


    childBId =
      childB.id;
  },
  30_000
);


afterAll(
  async () => {
    if (parentA) {
      await parentA.auth
        .signOut();
    }

    if (parentB) {
      await parentB.auth
        .signOut();
    }

    if (parentAId) {
      await admin.auth.admin
        .deleteUser(
          parentAId
        );
    }

    if (parentBId) {
      await admin.auth.admin
        .deleteUser(
          parentBId
        );
    }
  },
  30_000
);


describe(
  "Akal Budi RLS security boundary",
  () => {
    it(
      "Parent A can read own child",
      async () => {
        const {
          data,
          error
        } =
          await parentA
            .from("children")
            .select(
              "id,parent_id"
            )
            .eq(
              "id",
              childAId
            );

        expect(error)
          .toBeNull();

        expect(data)
          .toHaveLength(1);
      }
    );


    it(
      "Parent A cannot read Parent B child",
      async () => {
        const {
          data,
          error
        } =
          await parentA
            .from("children")
            .select("id")
            .eq(
              "id",
              childBId
            );

        expect(error)
          .toBeNull();

        expect(data)
          .toEqual([]);
      }
    );


    it(
      "Parent B can read own child",
      async () => {
        const {
          data,
          error
        } =
          await parentB
            .from("children")
            .select("id")
            .eq(
              "id",
              childBId
            );

        expect(error)
          .toBeNull();

        expect(data)
          .toHaveLength(1);
      }
    );


    it(
      "Parent B cannot read Parent A child",
      async () => {
        const {
          data,
          error
        } =
          await parentB
            .from("children")
            .select("id")
            .eq(
              "id",
              childAId
            );

        expect(error)
          .toBeNull();

        expect(data)
          .toEqual([]);
      }
    );


    it(
      "anonymous cannot read children",
      async () => {
        const {
          data
        } =
          await anonymous
            .from("children")
            .select("id");

        expect(
          data ?? []
        ).toHaveLength(0);
      }
    );


    it(
      "anonymous can read privacy notice",
      async () => {
        const {
          data,
          error
        } =
          await anonymous
            .from(
              "privacy_notice_versions"
            )
            .select(
              "id,version"
            )
            .eq(
              "id",
              privacyNoticeId
            );

        expect(error)
          .toBeNull();

        expect(data)
          .toHaveLength(1);
      }
    );


    it(
      "Parent A cannot directly insert consent",
      async () => {
        const {
          error
        } =
          await parentA
            .from("consents")
            .insert({
              parent_id:
                parentAId,

              privacy_notice_version_id:
                privacyNoticeId,

              consent_type:
                "product-analytics",

              granted:
                true
            });

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "Parent A can record consent through RPC",
      async () => {
        const {
          error
        } =
          await parentA.rpc(
            "record_consent",
            {
              p_privacy_notice_version_id:
                privacyNoticeId,

              p_consent_type:
                "privacy-notice",

              p_granted:
                true
            }
          );

        expect(error)
          .toBeNull();
      }
    );


    it(
      "anonymous cannot call record_consent",
      async () => {
        const {
          error
        } =
          await anonymous.rpc(
            "record_consent",
            {
              p_privacy_notice_version_id:
                privacyNoticeId,

              p_consent_type:
                "privacy-notice",

              p_granted:
                true
            }
          );

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "Parent A can read own consent",
      async () => {
        const {
          data,
          error
        } =
          await parentA
            .from("consents")
            .select(
              "parent_id"
            )
            .eq(
              "parent_id",
              parentAId
            );

        expect(error)
          .toBeNull();

        expect(
          data?.length
        ).toBeGreaterThan(0);
      }
    );


    it(
      "Parent B cannot read Parent A consent",
      async () => {
        const {
          data,
          error
        } =
          await parentB
            .from("consents")
            .select(
              "parent_id"
            )
            .eq(
              "parent_id",
              parentAId
            );

        expect(error)
          .toBeNull();

        expect(data)
          .toEqual([]);
      }
    );


    it(
      "Parent A can create learning session for own child",
      async () => {
        sessionAId =
          crypto.randomUUID();

        const {
          error
        } =
          await parentA
            .from(
              "learning_sessions"
            )
            .insert({
              id:
                sessionAId,

              child_id:
                childAId,

              activity_id:
                "warna-merah-test-001",

              activity_version:
                1,

              started_at:
                "2026-08-20T00:00:00.000Z",

              completed_at:
                "2026-08-20T00:00:05.000Z",

              correct_count:
                1,

              incorrect_count:
                1,

              attempts:
                2,

              duration_seconds:
                5
            });

        expect(error)
          .toBeNull();
      }
    );


    it(
      "Parent A cannot create learning session for Parent B child",
      async () => {
        const {
          error
        } =
          await parentA
            .from(
              "learning_sessions"
            )
            .insert({
              id:
                crypto.randomUUID(),

              child_id:
                childBId,

              activity_id:
                "unauthorised-test",

              activity_version:
                1,

              started_at:
                "2026-08-20T00:00:00.000Z",

              completed_at:
                "2026-08-20T00:00:05.000Z",

              correct_count:
                1,

              incorrect_count:
                0,

              attempts:
                1,

              duration_seconds:
                5
            });

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "Parent B cannot read Parent A learning session",
      async () => {
        const {
          data,
          error
        } =
          await parentB
            .from(
              "learning_sessions"
            )
            .select("id")
            .eq(
              "id",
              sessionAId
            );

        expect(error)
          .toBeNull();

        expect(data)
          .toEqual([]);
      }
    );


    it(
      "anonymous cannot read learning sessions",
      async () => {
        const {
          data
        } =
          await anonymous
            .from(
              "learning_sessions"
            )
            .select("id");

        expect(
          data ?? []
        ).toHaveLength(0);
      }
    );


    it(
      "Parent A cannot modify completed learning session",
      async () => {
        const {
          error
        } =
          await parentA
            .from(
              "learning_sessions"
            )
            .update({
              correct_count:
                999
            })
            .eq(
              "id",
              sessionAId
            );

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "Parent A cannot delete completed learning session",
      async () => {
        const {
          error
        } =
          await parentA
            .from(
              "learning_sessions"
            )
            .delete()
            .eq(
              "id",
              sessionAId
            );

        expect(error)
          .not.toBeNull();
      }
    );
  }
);
