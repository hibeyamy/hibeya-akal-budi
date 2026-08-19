export interface AssetDefinition {
  id: string;
  type: "emoji" | "image";
  value: string;
  alt: {
    ms: string;
    en: string;
  };
}

const assets: Record<string, AssetDefinition> = {
  "apple-red": {
    id: "apple-red",
    type: "emoji",
    value: "🍎",
    alt: {
      ms: "Epal merah",
      en: "Red apple"
    }
  },

  "apple-green": {
    id: "apple-green",
    type: "emoji",
    value: "🍏",
    alt: {
      ms: "Epal hijau",
      en: "Green apple"
    }
  },

  "banana-yellow": {
    id: "banana-yellow",
    type: "emoji",
    value: "🍌",
    alt: {
      ms: "Pisang kuning",
      en: "Yellow banana"
    }
  }
};

export function getAsset(assetId: string): AssetDefinition {
  const asset = assets[assetId];

  if (!asset) {
    throw new Error(`Unknown asset: ${assetId}`);
  }

  return asset;
}
