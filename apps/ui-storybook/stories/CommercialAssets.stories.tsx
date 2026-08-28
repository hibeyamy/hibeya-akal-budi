import {
  getAsset
} from "@akal-budi/assets";

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow"
];

export default {
  title:
    "Assets/First Original Batch"
};

export function ReviewGallery() {
  return (
    <main
      style={{
        padding: "2rem",
        fontFamily: "system-ui, sans-serif"
      }}
    >
      <h1>
        HIBEYA First Original Asset Batch
      </h1>

      <p>
        Review silhouette clarity, child suitability,
        visual consistency and originality before approval.
      </p>

      <div
        style={{
          display: "grid",
          gridTemplateColumns:
            "repeat(auto-fit, minmax(180px, 1fr))",
          gap: "1.5rem",
          marginTop: "2rem"
        }}
      >
        {ids.map(
          id => {
            const asset =
              getAsset(
                id
              );

            return (
              <figure
                key={id}
                style={{
                  margin: 0,
                  padding: "1.5rem",
                  border: "1px solid #d7dee4",
                  borderRadius: "1rem",
                  background: "#fff"
                }}
              >
                <img
                  src={asset.value}
                  alt={asset.alt.en}
                  style={{
                    display: "block",
                    width: "160px",
                    height: "160px",
                    objectFit: "contain",
                    margin: "0 auto"
                  }}
                />

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
                    {id}
                  </small>
                </figcaption>
              </figure>
            );
          }
        )}
      </div>
    </main>
  );
}
