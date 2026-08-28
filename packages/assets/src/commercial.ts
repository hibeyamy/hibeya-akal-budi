import {
  generatedCommercialAssetOverrides
} from "./generated/commercialRegistry.generated";

export interface CommercialAssetOverride {
  id: string;

  type:
    "image";

  value:
    string;

  alt: {
    ms:
      string;

    en:
      string;
  };
}

export const commercialAssetOverrides:
  Record<
    string,
    CommercialAssetOverride
  > =
    generatedCommercialAssetOverrides;
