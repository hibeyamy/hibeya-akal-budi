import {
  renderToStaticMarkup
} from "react-dom/server";

import {
  describe,
  expect,
  it
} from "vitest";

import {
  LearnerHome,
  LearnerShell
} from "./index";

describe(
  "LearnerShell",
  () => {
    it(
      "shows learner identity and calm progress context",
      () => {
        const html =
          renderToStaticMarkup(
            <LearnerShell
              learnerName="Alya"
              progressPercent={35}
            >
              <LearnerHome />
            </LearnerShell>
          );

        expect(
          html
        ).toContain(
          "Hai, Alya"
        );

        expect(
          html
        ).toContain(
          'aria-label="Kemajuan 35 peratus"'
        );
      }
    );

    it(
      "keeps primary learner actions at least 56px high",
      () => {
        const html =
          renderToStaticMarkup(
            <LearnerHome />
          );

        expect(
          html
        ).toContain(
          "Sambung belajar"
        );

        expect(
          html
        ).toContain(
          "min-h-14"
        );
      }
    );

    it(
      "includes an accessible skip link",
      () => {
        const html =
          renderToStaticMarkup(
            <LearnerShell>
              <LearnerHome />
            </LearnerShell>
          );

        expect(
          html
        ).toContain(
          'href="#learner-main"'
        );

        expect(
          html
        ).toContain(
          'id="learner-main"'
        );
      }
    );
  }
);
