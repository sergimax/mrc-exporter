import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Lua } from "wasmoon-lua5.1";

async function runScenario(scenario: string): Promise<void> {
  const lua = await Lua.create();
  try {
    assert.equal(lua.doStringSync("return _VERSION"), "Lua 5.1");
    for (const path of ["lua/wow-stubs.lua", "lua/scan-runtime.lua", "../Raidwise/InspectCoordinator.lua", "../Raidwise/GearCheckReport.lua", "../Raidwise/GearCheck.lua", "lua/scan-scenarios.lua"]) {
      lua.doStringSync((await readFile(new URL(path, import.meta.url), "utf8")).replace(/^\uFEFF/, ""));
    }
    lua.doStringSync(`RunScanScenario("${scenario}")`);
  } finally {
    lua.global.close();
  }
}

for (const scenario of ["repeated", "event-order", "missing", "deadline", "raid", "empty-confirmed", "empty-delayed", "empty-timeout"]) {
  test(`scan lifecycle: ${scenario}`, () => runScenario(scenario));
}

for (const scenario of ["identity", "spec-retry", "gem-retry", "cancel", "cancel-raid", "queued-identity", "retry-exhaustion"]) {
  test(`scan lifecycle: ${scenario}`, () => runScenario(scenario));
}
