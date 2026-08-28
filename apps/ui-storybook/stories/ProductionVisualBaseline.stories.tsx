import {
  getAsset,
  getAssetMetadata,
  type AssetDefinition
} from "@akal-budi/assets";

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow",
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
] as const;

function AssetVisual({ asset }: { asset: AssetDefinition }) {
  if (asset.type === "image") {
    return (
      <img
        src={asset.value}
        alt={asset.alt.en}
        data-production-asset={asset.id}
        style={{
          display: "block",
          width: "180px",
          height: "180px",
          objectFit: "contain",
          margin: "0 auto"
        }}
      />
    );
  }

  return (
    <div role="img" aria-label={asset.alt.en}>
      {asset.value}
    </div>
  );
}

export default {
  title: "Assets/Production Visual Baseline"
};

export function SixAssetAudit() {
  const assets = ids.map(id => ({
    asset: getAsset(id),
    metadata: getAssetMetadata(id)
  }));

  return (
    <main
      data-testid="production-visual-baseline"
      style={{
        padding: "2rem",
        fontFamily: "system-ui, sans-serif",
        background: "#faf8f2",
        minHeight: "100vh"
      }}
    >
      <h1>HIBEYA Akal Budi — Production Visual Baseline</h1>
      <p>
        All visuals on this page resolve through the same semantic
        getAsset() boundary used by the learner application.
      </p>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit,minmax(220px,1fr))",
          gap: "1.25rem",
          marginTop: "2rem"
        }}
      >
        {assets.map(({ asset, metadata }) => (
          <figure
            key={asset.id}
            data-asset-card={asset.id}
            data-status={metadata.status}
            data-delivery-format={metadata.deliveryFormat}
            style={{
              margin: 0,
              padding: "1.5rem",
              border: "1px solid #e5dfd2",
              borderRadius: "20px",
              background: "#fff",
              boxShadow: "0 8px 24px rgba(35,51,63,.08)"
            }}
          >
            <AssetVisual asset={asset} />
            <figcaption
              style={{
                textAlign: "center",
                marginTop: "1rem",
                fontWeight: 700
              }}
            >
              {asset.alt.ms}
              <br />
              <small style={{ fontWeight: 500 }}>
                {asset.id}
                {" · "}
                {metadata.status}
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
