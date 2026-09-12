import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Lua } from "wasmoon-lua5.1";

test("saved report revisions are independent of release version and preserve legacy entries", async () => {
  const lua = await Lua.create();
  try {
    assert.equal(lua.doStringSync("return _VERSION"), "Lua 5.1");
    lua.doStringSync("Raidwise={db={},version='1.21.0'}; function time() return 100 end");
    for (const module of ["GearCheckCatalog", "GearCheckReport", "GearCheckRules", "GearCheckSavedReports"]) {
      lua.doStringSync(await readFile(new URL(`../Raidwise/${module}.lua`, import.meta.url), "utf8"));
    }
    lua.doStringSync(`
      local report={schemaVersion=3,character={guid="A",name="Tester",unit="target"},equipment={}}
      local first=Raidwise:SaveGearCheckReport(report)
      local entry=Raidwise:GetGearCheckSavedReport(first)
      local rules,data=entry.rulesetVersion,entry.dataVersion
      assert(rules==Raidwise.GEAR_CHECK_RULESET_VERSION and data==Raidwise.GEAR_CHECK_DATA_VERSION)
      Raidwise.version="9.0.0"
      local second=Raidwise:GetGearCheckSavedReport(Raidwise:SaveGearCheckReport(report))
      assert(second.rulesetVersion==rules and second.dataVersion==data)
      assert(entry.report.schemaVersion==3 and entry.report.character.unit==nil)
      assert(report.character.unit=="target", "Saving mutated the source")
      entry.rulesetVersion="wotlk-3.3.5a-1.20.0"
      entry.dataVersion="legacy-catalog"
      assert(Raidwise:GetGearCheckSavedReport(first)==entry)
      assert(#Raidwise:ListGearCheckSavedReports("A")==2)
      assert(entry.rulesetVersion=="wotlk-3.3.5a-1.20.0" and entry.dataVersion=="legacy-catalog")
      Raidwise.GEAR_CHECK_RULESET_VERSION="test-next-revision"
      assert(Raidwise:GetGearCheckRulesetVersion()~=rules and Raidwise:GetGearCheckDataVersion()==data)
      Raidwise.GEAR_CHECK_DATA_VERSION="catalog-next"
      assert(Raidwise:GetGearCheckRulesetVersion()=="test-next-revision")
      Raidwise.GEAR_CHECK_RULESET_VERSION=nil; Raidwise.GEAR_CHECK_DATA_VERSION=nil
      assert(Raidwise:GetGearCheckRulesetVersion()=="unknown" and Raidwise:GetGearCheckDataVersion()=="unknown")
      assert(entry.rulesetVersion=="wotlk-3.3.5a-1.20.0")
    `);
  } finally { lua.global.close(); }
});
