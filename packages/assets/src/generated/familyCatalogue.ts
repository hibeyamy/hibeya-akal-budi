// GENERATED FILE. DO NOT EDIT.
// Source: assets/families/*.json

export const assetFamilyCatalogue = [
  {
    "id": "learner-core-fruit",
    "version": "1.0.0",
    "title": "Learner Core Fruit",
    "members": [
      {
        "id": "apple-red",
        "sha256": "e8349a44d90ddd54599cc81d17e94513c16f4a43ea89b744182da770d4e65da1"
      },
      {
        "id": "apple-green",
        "sha256": "c24534d1aafa4c7003ebc886b0e51e181b0eee9d795961772d35c67e920a6e8d"
      },
      {
        "id": "banana-yellow",
        "sha256": "e82e7ef6aa227d088ce3b9f9e629204d885adc12bb091359d7064f49f87e644f"
      }
    ]
  }
] as const;

export type AssetFamilyId = typeof assetFamilyCatalogue[number]["id"];
