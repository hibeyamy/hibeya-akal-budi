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


function completedSessionTimes(
  durationSeconds = 10
) {
  const completedAt =
    new Date(
      Date.now() - 60_000
    );

  const startedAt =
    new Date(
      completedAt.getTime() -
      durationSeconds * 1000
    );

  return {
    startedAt:
      startedAt.toISOString(),

    completedAt:
      completedAt.toISOString()
  };
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

let activationCode = "";
let activatedDeviceId = "";
let activatedDeviceToken = "";


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
            ascending: false
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

    // ========================================================
    // CHILD PROFILE SECURITY
    // ========================================================

    it(
      "Parent A can read own child",
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


    // ========================================================
    // PRIVACY + CONSENT SECURITY
    // ========================================================

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
            .select("id")
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


    // ========================================================
    // PARENT LEARNING SESSION SECURITY
    // ========================================================

    it(
      "Parent A can create learning session for own child",
      async () => {
        const {
          startedAt,
          completedAt
        } =
          completedSessionTimes(5);

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
                startedAt,

              completed_at:
                completedAt,

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
          startedAt,
          completedAt
        } =
          completedSessionTimes(5);

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
                startedAt,

              completed_at:
                completedAt,

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


    // ========================================================
    // DEVICE ACTIVATION SECURITY
    // ========================================================

    it(
      "Parent A can create activation for own child",
      async () => {
        const {
          data,
          error
        } =
          await parentA.rpc(
            "create_learner_device_activation",
            {
              p_child_id:
                childAId
            }
          );

        expect(error)
          .toBeNull();

        expect(data)
          .toHaveLength(1);

        activationCode =
          data?.[0]
            ?.activation_code ??
          "";

        expect(
          activationCode
        ).toMatch(
          /^[0-9]{6}$/
        );
      }
    );


    it(
      "Parent A cannot create activation for Parent B child",
      async () => {
        const {
          error
        } =
          await parentA.rpc(
            "create_learner_device_activation",
            {
              p_child_id:
                childBId
            }
          );

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "anonymous cannot create activation codes",
      async () => {
        const {
          error
        } =
          await anonymous.rpc(
            "create_learner_device_activation",
            {
              p_child_id:
                childAId
            }
          );

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "activation table does not expose raw activation code",
      async () => {
        const {
          data,
          error
        } =
          await admin
            .from(
              "learner_device_activations"
            )
            .select(
              "code_hash"
            )
            .eq(
              "child_id",
              childAId
            )
            .order(
              "created_at",
              {
                ascending:
                  false
              }
            )
            .limit(1)
            .single();

        expect(error)
          .toBeNull();

        expect(
          data?.code_hash
        ).not.toBe(
          activationCode
        );

        expect(
          data?.code_hash
        ).toMatch(
          /^[a-f0-9]{64}$/
        );
      }
    );


    it(
      "anonymous learner can exchange valid activation code",
      async () => {
        const {
          data,
          error
        } =
          await anonymous.rpc(
            "exchange_learner_device_activation",
            {
              p_activation_code:
                activationCode,

              p_device_name:
                "Security Test Tablet"
            }
          );

        expect(error)
          .toBeNull();

        expect(data)
          .toHaveLength(1);

        activatedDeviceId =
          data?.[0]
            ?.device_id ??
          "";

        activatedDeviceToken =
          data?.[0]
            ?.device_token ??
          "";

        expect(
          activatedDeviceId
        ).not.toBe("");

        expect(
          activatedDeviceToken
        ).toMatch(
          /^[a-f0-9]{64}$/
        );

        expect(
          data?.[0]?.child_id
        ).toBe(
          childAId
        );
      }
    );


    it(
      "activation code is single-use",
      async () => {
        const {
          error
        } =
          await anonymous.rpc(
            "exchange_learner_device_activation",
            {
              p_activation_code:
                activationCode,

              p_device_name:
                "Replay Device"
            }
          );

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "invalid activation code is rejected",
      async () => {
        const {
          error
        } =
          await anonymous.rpc(
            "exchange_learner_device_activation",
            {
              p_activation_code:
                "999999",

              p_device_name:
                "Invalid Device"
            }
          );

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "malformed activation code is rejected",
      async () => {
        const {
          error
        } =
          await anonymous.rpc(
            "exchange_learner_device_activation",
            {
              p_activation_code:
                "ABC123",

              p_device_name:
                "Malformed Device"
            }
          );

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "raw learner device token is not stored",
      async () => {
        const {
          data,
          error
        } =
          await admin
            .from(
              "learner_devices"
            )
            .select(
              "token_hash"
            )
            .eq(
              "id",
              activatedDeviceId
            )
            .single();

        expect(error)
          .toBeNull();

        expect(
          data?.token_hash
        ).not.toBe(
          activatedDeviceToken
        );

        expect(
          data?.token_hash
        ).toMatch(
          /^[a-f0-9]{64}$/
        );
      }
    );


    it(
      "Parent B cannot see Parent A learner device",
      async () => {
        const {
          data,
          error
        } =
          await parentB
            .from(
              "learner_devices"
            )
            .select("id")
            .eq(
              "id",
              activatedDeviceId
            );

        expect(error)
          .toBeNull();

        expect(data)
          .toEqual([]);
      }
    );


    it(
      "anonymous cannot read learner devices",
      async () => {
        const {
          data
        } =
          await anonymous
            .from(
              "learner_devices"
            )
            .select("id");

        expect(
          data ?? []
        ).toHaveLength(0);
      }
    );


    it(
      "Parent B cannot revoke Parent A learner device",
      async () => {
        const {
          error
        } =
          await parentB.rpc(
            "revoke_learner_device",
            {
              p_device_id:
                activatedDeviceId
            }
          );

        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "anonymous cannot revoke learner device",
      async () => {
        const {
          error
        } =
          await anonymous.rpc(
            "revoke_learner_device",
            {
              p_device_id:
                activatedDeviceId
            }
          );

        expect(error)
          .not.toBeNull();
      }
    );


    // ========================================================
    // DEVICE-AUTHENTICATED PROGRESS SYNC
    // ========================================================

    it(
      "valid learner device can sync own progress",
      async () => {
        const sessionId =
          crypto.randomUUID();

        const {
          startedAt,
          completedAt
        } =
          completedSessionTimes(10);


        const {
          data,
          error
        } =
          await anonymous.rpc(
            "sync_learner_session",
            {
              p_device_id:
                activatedDeviceId,

              p_device_token:
                activatedDeviceToken,

              p_session_id:
                sessionId,

              p_activity_id:
                "security-progress-001",

              p_activity_version:
                1,

              p_started_at:
                startedAt,

              p_completed_at:
                completedAt,

              p_correct_count:
                2,

              p_incorrect_count:
                1,

              p_attempts:
                3,

              p_duration_seconds:
                10
            }
          );


        expect(error)
          .toBeNull();

        expect(data)
          .toBe(
            sessionId
          );


        const {
          data: stored,
          error: readError
        } =
          await admin
            .from(
              "learning_sessions"
            )
            .select(
              "id,child_id"
            )
            .eq(
              "id",
              sessionId
            )
            .single();


        expect(readError)
          .toBeNull();

        expect(
          stored?.child_id
        ).toBe(
          childAId
        );
      }
    );


    it(
      "wrong learner device token cannot sync progress",
      async () => {
        const {
          startedAt,
          completedAt
        } =
          completedSessionTimes(10);


        const {
          error
        } =
          await anonymous.rpc(
            "sync_learner_session",
            {
              p_device_id:
                activatedDeviceId,

              p_device_token:
                "0".repeat(64),

              p_session_id:
                crypto.randomUUID(),

              p_activity_id:
                "security-invalid-token",

              p_activity_version:
                1,

              p_started_at:
                startedAt,

              p_completed_at:
                completedAt,

              p_correct_count:
                1,

              p_incorrect_count:
                0,

              p_attempts:
                1,

              p_duration_seconds:
                10
            }
          );


        expect(error)
          .not.toBeNull();

        expect(
          error?.message
        ).toContain(
          "Device not authorised"
        );
      }
    );


    it(
      "anonymous cannot directly insert learner progress",
      async () => {
        const {
          startedAt,
          completedAt
        } =
          completedSessionTimes(10);


        const {
          error
        } =
          await anonymous
            .from(
              "learning_sessions"
            )
            .insert({
              id:
                crypto.randomUUID(),

              child_id:
                childAId,

              activity_id:
                "direct-anon-insert",

              activity_version:
                1,

              started_at:
                startedAt,

              completed_at:
                completedAt,

              correct_count:
                1,

              incorrect_count:
                0,

              attempts:
                1,

              duration_seconds:
                10
            });


        expect(error)
          .not.toBeNull();
      }
    );


    it(
      "learner progress retry is idempotent",
      async () => {
        const sessionId =
          crypto.randomUUID();

        const {
          startedAt,
          completedAt
        } =
          completedSessionTimes(15);


        const payload = {
          p_device_id:
            activatedDeviceId,

          p_device_token:
            activatedDeviceToken,

          p_session_id:
            sessionId,

          p_activity_id:
            "security-idempotent",

          p_activity_version:
            1,

          p_started_at:
            startedAt,

          p_completed_at:
            completedAt,

          p_correct_count:
            2,

          p_incorrect_count:
            0,

          p_attempts:
            2,

          p_duration_seconds:
            15
        };


        const first =
          await anonymous.rpc(
            "sync_learner_session",
            payload
          );


        expect(first.error)
          .toBeNull();


        const second =
          await anonymous.rpc(
            "sync_learner_session",
            payload
          );


        expect(second.error)
          .toBeNull();


        const {
          count,
          error
        } =
          await admin
            .from(
              "learning_sessions"
            )
            .select(
              "*",
              {
                count:
                  "exact",

                head:
                  true
              }
            )
            .eq(
              "id",
              sessionId
            );


        expect(error)
          .toBeNull();

        expect(count)
          .toBe(1);
      }
    );


    it(
      "Parent B cannot read device-synchronised Parent A progress",
      async () => {
        const sessionId =
          crypto.randomUUID();

        const {
          startedAt,
          completedAt
        } =
          completedSessionTimes(10);


        const {
          error: syncError
        } =
          await anonymous.rpc(
            "sync_learner_session",
            {
              p_device_id:
                activatedDeviceId,

              p_device_token:
                activatedDeviceToken,

              p_session_id:
                sessionId,

              p_activity_id:
                "security-parent-isolation",

              p_activity_version:
                1,

              p_started_at:
                startedAt,

              p_completed_at:
                completedAt,

              p_correct_count:
                1,

              p_incorrect_count:
                1,

              p_attempts:
                2,

              p_duration_seconds:
                10
            }
          );


        expect(syncError)
          .toBeNull();


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
              sessionId
            );


        expect(error)
          .toBeNull();

        expect(data)
          .toEqual([]);
      }
    );


    // ========================================================
    // DEVICE REVOCATION
    // ========================================================

    it(
      "Parent A can revoke own learner device",
      async () => {
        const {
          error
        } =
          await parentA.rpc(
            "revoke_learner_device",
            {
              p_device_id:
                activatedDeviceId
            }
          );


        expect(error)
          .toBeNull();


        const {
          data,
          error:
            readError
        } =
          await parentA
            .from(
              "learner_devices"
            )
            .select(
              "revoked_at"
            )
            .eq(
              "id",
              activatedDeviceId
            )
            .single();


        expect(readError)
          .toBeNull();

        expect(
          data?.revoked_at
        ).not.toBeNull();
      }
    );


    it(
      "revoked learner device cannot sync progress",
      async () => {
        const {
          startedAt,
          completedAt
        } =
          completedSessionTimes(10);


        const {
          error
        } =
          await anonymous.rpc(
            "sync_learner_session",
            {
              p_device_id:
                activatedDeviceId,

              p_device_token:
                activatedDeviceToken,

              p_session_id:
                crypto.randomUUID(),

              p_activity_id:
                "security-revoked-device",

              p_activity_version:
                1,

              p_started_at:
                startedAt,

              p_completed_at:
                completedAt,

              p_correct_count:
                1,

              p_incorrect_count:
                0,

              p_attempts:
                1,

              p_duration_seconds:
                10
            }
          );


        expect(error)
          .not.toBeNull();

        expect(
          error?.message
        ).toContain(
          "Device not authorised"
        );
      }
    );
  }
);
