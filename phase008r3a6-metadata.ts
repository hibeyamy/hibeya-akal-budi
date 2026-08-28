export const assetStatuses = [
  "legacy",
  "draft",
  "review",
  "approved",
  "retired"
] as const;

export type AssetStatus =
  (typeof assetStatuses)[number];

export const assetVisualFamilies = [
  "legacy",
  "hibeya-learning-v1"
] as const;

export type AssetVisualFamily =
  (typeof assetVisualFamilies)[number];

export interface AssetGovernanceMetadata {
  id: string;
  category: "fruit" | "flora" | "ui" | "other";
  status: AssetStatus;
  version: number;
  visualFamily: AssetVisualFamily;
  sourceFormat: "emoji" | "svg" | "png" | "webp" | "other";
  deliveryFormat: "emoji" | "svg" | "png" | "webp" | "other";
  richIllustration: boolean;
  sourcePath?: string;
  deliveryPath?: string;
  legacyPath?: string;
  notes?: string;
}

export const assetGovernanceMetadata:
  Readonly<Record<string, AssetGovernanceMetadata>> = {
    "apple-red": {
      id: "apple-red",
      category: "fruit",
      status: "approved",
      version: 1,
      visualFamily: "hibeya-learning-v1",
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true,
      sourcePath: "source/masters/fruit/apple-red.png",
      deliveryPath: "src/generated/apple-red.webp",
      legacyPath: "source/legacy/fruit/apple-red.svg"
    },
    "apple-green": {
      id: "apple-green",
      category: "fruit",
      status: "approved",
      version: 1,
      visualFamily: "hibeya-learning-v1",
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true,
      sourcePath: "source/masters/fruit/apple-green.png",
      deliveryPath: "src/generated/apple-green.webp",
      legacyPath: "source/legacy/fruit/apple-green.svg"
    },
    "banana-yellow": {
      id: "banana-yellow",
      category: "fruit",
      status: "approved",
      version: 1,
      visualFamily: "hibeya-learning-v1",
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true,
      sourcePath: "source/masters/fruit/banana-yellow.png",
      deliveryPath: "src/generated/banana-yellow.webp",
      legacyPath: "source/legacy/fruit/banana-yellow.svg"
    },
    "hibiscus-red": {
      id: "hibiscus-red",
      category: "flora",
      status: "approved",
      version: 1,
      visualFamily: "hibeya-learning-v1",
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true,
      sourcePath: "source/masters/flora/hibiscus-red.png",
      deliveryPath: "src/generated/hibiscus-red.webp",
      legacyPath: "source/legacy/flora/hibiscus-red.svg"
    },
    "hibiscus-yellow": {
      id: "hibiscus-yellow",
      category: "flora",
      status: "approved",
      version: 1,
      visualFamily: "hibeya-learning-v1",
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true,
      sourcePath: "source/masters/flora/hibiscus-yellow.png",
      deliveryPath: "src/generated/hibiscus-yellow.webp",
      legacyPath: "source/legacy/flora/hibiscus-yellow.svg"
    },
    "hibiscus-purple": {
      id: "hibiscus-purple",
      category: "flora",
      status: "approved",
      version: 1,
      visualFamily: "hibeya-learning-v1",
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true,
      sourcePath: "source/masters/flora/hibiscus-purple.png",
      deliveryPath: "src/generated/hibiscus-purple.webp",
      legacyPath: "source/legacy/flora/hibiscus-purple.svg"
    }
  };

export function getAssetMetadata(
  assetId: string
): AssetGovernanceMetadata {
  const metadata = assetGovernanceMetadata[assetId];
  if (!metadata) {
    throw new Error(`Unknown asset metadata: ${assetId}`);
  }
  return metadata;
}
