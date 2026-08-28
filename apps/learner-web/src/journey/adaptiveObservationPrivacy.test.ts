import fs from "node:fs";
import path from "node:path";

import {
  describe,
  expect,
  it
} from "vitest";


describe(
  "adaptive observation privacy and ingestion contract",
  () => {
    it(
      "persists no learner/device identity columns in the migration",
      () => {
        const migration =
          fs.readFileSync(
            path.resolve(
              process.cwd(),
              "../../supabase/migrations/20260827225222_adaptive_observation_ingestion.sql"
            ),
            "utf8"
          );

        const tableBlock =
          migration.slice(
            migration.indexOf(
              "create table if not exists"
            ),
            migration.indexOf(
              "alter table"
            )
          );

        for(
          const forbidden
          of [
            "child_id",
            "device_id",
            "device_token",
            "learner_key",
            "profile_id"
          ]
        ){
          expect(
            tableBlock
              .toLowerCase()
              .includes(
                forbidden
              )
          ).toBe(
            false
          );
        }

        expect(
          migration
            .toLowerCase()
            .includes(
              "on conflict"
            )
        ).toBe(
          true
        );
      }
    );
  }
);
