import type { GameMechanicRuntime } from "@akal-budi/game-runtime";

import { TapChoiceMechanic } from "./tap-choice";

const mechanics = new Map<string, GameMechanicRuntime>();

const tapChoice = new TapChoiceMechanic();

mechanics.set(tapChoice.mechanicId, tapChoice);

export function getGameMechanic(
  mechanicId: string
): GameMechanicRuntime {
  const mechanic = mechanics.get(mechanicId);

  if (!mechanic) {
    throw new Error(`Unsupported game mechanic: ${mechanicId}`);
  }

  return mechanic;
}
