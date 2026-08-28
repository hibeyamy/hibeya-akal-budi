import {
  describe,
  expect,
  it
} from "vitest";

import {
  getEvidenceAdjustedLearningNeed,
  getMasteryEvidenceConfidence
} from "../masteryConfidence";


describe(
  "mastery evidence confidence",
  () => {
    it(
      "returns zero confidence without observations",
      () => {
        expect(
          getMasteryEvidenceConfidence(
            0
          )
        ).toBe(
          0
        );
      }
    );


    it(
      "returns partial confidence before the mastery minimum observation count",
      () => {
        expect(
          getMasteryEvidenceConfidence(
            1
          )
        ).toBe(
          0.5
        );
      }
    );


    it(
      "reaches full confidence at the existing mastery observation minimum",
      () => {
        expect(
          getMasteryEvidenceConfidence(
            2
          )
        ).toBe(
          1
        );
      }
    );


    it(
      "caps confidence for repeated observations",
      () => {
        expect(
          getMasteryEvidenceConfidence(
            12
          )
        ).toBe(
          1
        );
      }
    );


    it(
      "shrinks sparse weak evidence toward neutral need",
      () => {
        expect(
          getEvidenceAdjustedLearningNeed({
            masteryScore:
              0.1,
            observationCount:
              1,
            mastered:
              false
          })
        ).toBeCloseTo(
          0.7
        );
      }
    );


    it(
      "uses full raw learning need once evidence is sufficient",
      () => {
        expect(
          getEvidenceAdjustedLearningNeed({
            masteryScore:
              0.1,
            observationCount:
              2,
            mastered:
              false
          })
        ).toBeCloseTo(
          0.9
        );
      }
    );


    it(
      "keeps mastered skills at zero need",
      () => {
        expect(
          getEvidenceAdjustedLearningNeed({
            masteryScore:
              0.75,
            observationCount:
              2,
            mastered:
              true
          })
        ).toBe(
          0
        );
      }
    );
  }
);
