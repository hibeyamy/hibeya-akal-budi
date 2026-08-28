import {
  getAsset,
  getAssetMetadata
} from "@akal-budi/assets";

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
] as const;

export default {
  title: "Assets/Malaysian Garden Hibiscus"
};

export function ReviewGallery() {
  const assets = ids.map(id => ({
    asset: getAsset(id),
    metadata: getAssetMetadata(id)
  }));

  return (
    <main
      style={{
        padding: "2rem",
        fontFamily: "system-ui, sans-serif"
      }}
    >
      <h1>
        HIBEYA Malaysian Garden — Hibiscus Review
      </h1>

      <p>
        These review visuals resolve through getAsset(); Storybook
        does not reference generated SVG, PNG or WebP files directly.
      </p>

      <div
        style={{
          display: "grid",
          gridTemplateColumns:
            "repeat(auto-fit, minmax(200px, 1fr))",
          gap: "1.5rem",
          marginTop: "2rem"
        }}
      >
        {assets.map(({ asset, metadata }) => (
          <figure
            key={asset.id}
            style={{
              margin: 0,
              padding: "1.5rem",
              border: "1px solid #d7dee4",
              borderRadius: "1rem",
              background: "#fff"
            }}
          >
            {asset.type === "image" ? (
              <img
                src={asset.value}
                alt={asset.alt.en}
                style={{
                  display: "block",
                  width: "180px",
                  height: "180px",
                  objectFit: "contain",
                  margin: "0 auto"
                }}
              />
            ) : (
              <div
                role="img"
                aria-label={asset.alt.en}
                style={{
                  width: "180px",
                  height: "180px",
                  display: "grid",
                  placeItems: "center",
                  margin: "0 auto",
                  fontSize: "7rem"
                }}
              >
                {asset.value}
              </div>
            )}

            <figcaption
              style={{
                marginTop: "1rem",
                textAlign: "center",
                fontWeight: 600
              }}
            >
              {asset.alt.ms}
              <br />
              <small>
                {asset.id}
                {" · "}
                {metadata.deliveryFormat}
              </small>
            </figcaption>
          </figure>
        ))}
      </div>
    </main>
  );
}