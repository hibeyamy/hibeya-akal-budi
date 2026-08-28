export {
  assetGovernanceMetadata,
  assetStatuses,
  assetVisualFamilies,
  getAssetMetadata,
  type AssetGovernanceMetadata,
  type AssetStatus,
  type AssetVisualFamily
} from "./metadata";
import { commercialAssetOverrides } from "./commercial";

export interface AssetDefinition {
  id: string;

  type:
    | "emoji"
    | "image"
    | "quantity";

  value: string;

  itemAsset?: string;
  count?: number;

  alt: {
    ms: string;
    en: string;
  };
}


const assets:
  Record<
    string,
    AssetDefinition
  > = {

    // ========================================================
    // LEGACY / EXISTING ASSETS
    // ========================================================

    "apple-red": {
      id:
        "apple-red",

      type:
        "emoji",

      value:
        "ðŸŽ",

      alt: {
        ms:
          "Epal merah",

        en:
          "Red apple"
      }
    },


    "apple-green": {
      id:
        "apple-green",

      type:
        "emoji",

      value:
        "ðŸ",

      alt: {
        ms:
          "Epal hijau",

        en:
          "Green apple"
      }
    },


    "banana-yellow": {
      id:
        "banana-yellow",

      type:
        "emoji",

      value:
        "ðŸŒ",

      alt: {
        ms:
          "Pisang kuning",

        en:
          "Yellow banana"
      }
    },


    // ========================================================
    // AKAL BUDI â€” MALAYSIAN GARDEN PROTOTYPE ASSETS
    //
    // These are temporary Unicode prototype representations.
    //
    // They are NOT intended to be the final commercial artwork.
    // Final production assets should be original HIBEYA artwork
    // with documented provenance.
    // ========================================================

    "hibiscus-red": {
      id:
        "hibiscus-red",

      type:
        "emoji",

      value:
        "ðŸ”´ðŸŒº",

      alt: {
        ms:
          "Bunga raya merah",

        en:
          "Red hibiscus"
      }
    },


    "hibiscus-yellow": {
      id:
        "hibiscus-yellow",

      type:
        "emoji",

      value:
        "ðŸŸ¡ðŸŒº",

      alt: {
        ms:
          "Bunga raya kuning",

        en:
          "Yellow hibiscus"
      }
    },


    "hibiscus-purple": {
      id:
        "hibiscus-purple",

      type:
        "emoji",

      value:
        "ðŸŸ£ðŸŒº",

      alt: {
        ms:
          "Bunga raya ungu",

        en:
          "Purple hibiscus"
      }
    },
    "quantity-apple-1": {
      id: "quantity-apple-1", type: "quantity", value: "", itemAsset: "apple-red", count: 1,
      alt: { ms: "Satu epal", en: "One apple" }
    },
    "quantity-apple-2": {
      id: "quantity-apple-2", type: "quantity", value: "", itemAsset: "apple-red", count: 2,
      alt: { ms: "Dua epal", en: "Two apples" }
    },
    "quantity-apple-3": {
      id: "quantity-apple-3", type: "quantity", value: "", itemAsset: "apple-red", count: 3,
      alt: { ms: "Tiga epal", en: "Three apples" }
    },
  };


export function getAsset(assetId: string): AssetDefinition {
  const asset =
    commercialAssetOverrides[assetId] ??
    assets[assetId];

  if (!asset) {
    throw new Error(`Unknown asset: ${assetId}`);
  }

  return asset;
}
