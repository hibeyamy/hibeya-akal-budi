import {
  supabase
} from "../lib/supabase";

export type ConsentType =
  | "privacy-notice"
  | "essential-data-processing"
  | "product-analytics"
  | "research-participation"
  | "marketing";

export interface ConsentState {
  privacyNoticeAccepted: boolean;
  essentialProcessingAccepted: boolean;
  productAnalyticsAccepted: boolean;
}

export interface PrivacyNotice {
  id: string;
  version: string;
  effectiveAt: string;
  noticeUrl: string | null;
}

export async function getCurrentPrivacyNotice():
  Promise<PrivacyNotice | null> {
  const {
    data,
    error
  } =
    await supabase
      .from(
        "privacy_notice_versions"
      )
      .select(
        "id,version,effective_at,notice_url"
      )
      .lte(
        "effective_at",
        new Date().toISOString()
      )
      .order(
        "effective_at",
        {
          ascending: false
        }
      )
      .limit(1)
      .maybeSingle();

  if (error) {
    throw error;
  }

  if (!data) {
    return null;
  }

  return {
    id:
      data.id,

    version:
      data.version,

    effectiveAt:
      data.effective_at,

    noticeUrl:
      data.notice_url
  };
}


export async function getConsentState(
  privacyNoticeId: string
): Promise<ConsentState> {
  const {
    data,
    error
  } =
    await supabase
      .from("consents")
      .select(
        "consent_type,granted,recorded_at,privacy_notice_version_id"
      )
      .order(
        "recorded_at",
        {
          ascending: false
        }
      );

  if (error) {
    throw error;
  }

  let privacyNoticeAccepted =
    false;

  let essentialProcessingAccepted =
    false;

  let productAnalyticsAccepted =
    false;

  let privacyFound =
    false;

  let essentialFound =
    false;

  let analyticsFound =
    false;

  for (
    const consent of data ?? []
  ) {
    if (
      consent.consent_type ===
        "privacy-notice" &&
      !privacyFound
    ) {
      privacyFound = true;

      privacyNoticeAccepted =
        consent.granted &&
        consent.privacy_notice_version_id ===
          privacyNoticeId;
    }

    if (
      consent.consent_type ===
        "essential-data-processing" &&
      !essentialFound
    ) {
      essentialFound = true;

      essentialProcessingAccepted =
        consent.granted;
    }

    if (
      consent.consent_type ===
        "product-analytics" &&
      !analyticsFound
    ) {
      analyticsFound = true;

      productAnalyticsAccepted =
        consent.granted;
    }
  }

  return {
    privacyNoticeAccepted,
    essentialProcessingAccepted,
    productAnalyticsAccepted
  };
}


export async function recordConsent(
  privacyNoticeId: string,
  consentType: ConsentType,
  granted: boolean
): Promise<void> {
  const {
    error
  } =
    await supabase.rpc(
      "record_consent",
      {
        p_privacy_notice_version_id:
          privacyNoticeId,

        p_consent_type:
          consentType,

        p_granted:
          granted
      }
    );

  if (error) {
    throw error;
  }
}


export async function saveInitialConsent(
  privacyNoticeId: string,
  analyticsAccepted: boolean
): Promise<void> {
  await recordConsent(
    privacyNoticeId,
    "privacy-notice",
    true
  );

  await recordConsent(
    privacyNoticeId,
    "essential-data-processing",
    true
  );

  await recordConsent(
    privacyNoticeId,
    "product-analytics",
    analyticsAccepted
  );
}
