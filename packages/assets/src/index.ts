export interface AssetDefinition {
  id: string;

  type:
    | "emoji"
    | "image";

  value: string;

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
        "🍎",

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
        "🍏",

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
        "🍌",

      alt: {
        ms:
          "Pisang kuning",

        en:
          "Yellow banana"
      }
    },


    // ========================================================
    // AKAL BUDI — MALAYSIAN GARDEN PROTOTYPE ASSETS
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
        "🔴🌺",

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
        "🟡🌺",

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
        "🟣🌺",

      alt: {
        ms:
          "Bunga raya ungu",

        en:
          "Purple hibiscus"
      }
    }
  };


export function getAsset(
  assetId: string
): AssetDefinition {
  const asset =
    assets[
      assetId
    ];


  if (!asset) {
    throw new Error(
      `Unknown asset: ${assetId}`
    );
  }


  return asset;
}
