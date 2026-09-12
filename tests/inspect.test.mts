import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Lua } from "wasmoon-lua5.1";

test("real roster queue releases timeouts, validates identity, and hands off to gear", async () => {
  const lua = await Lua.create();
  try {
    assert.equal(lua.doStringSync("return _VERSION"), "Lua 5.1");
    for (const path of ["lua/wow-stubs.lua", "lua/scan-runtime.lua", "../Raidwise/InspectCoordinator.lua", "../Raidwise/PartyRoster.lua", "../Raidwise/RosterRefresh.lua", "../Raidwise/GearCheckReport.lua", "../Raidwise/GearCheck.lua"]) {
      lua.doStringSync(await readFile(new URL(path, import.meta.url), "utf8"));
    }
    lua.doStringSync(`
      function GetNumRaidMembers() return 2 end
      function UnitIsVisible() return true end
      function CanInspect() return true end
      function GetInventorySlotInfo() return nil end
      function GetTalentTabInfo(tab) return "Spec" .. tab, "icon", tab end
      function time() return 100 end
      local runtime = ScanRuntime
      Raidwise:QueuePartyInspects()
      assert(#runtime.notifications == 1 and runtime.notifications[1].unit == "raid1")
      runtime:Tick(4)
      assert(#runtime.notifications == 2 and runtime.notifications[2].unit == "raid2")
      runtime:Ready("raid2")
      assert(Raidwise:GetCachedSpecForUnit("raid2") == "Spec3")
      Raidwise:ClearCachedSpecForUnit("raid1")
      Raidwise:QueuePartyInspects()
      runtime.identities.raid1 = "C"
      runtime:Ready()
      assert(Raidwise:GetCachedSpecForUnit("raid1") == "", "Cached a changed identity")
      runtime:Ready("raid2")
      Raidwise:QueuePartyInspects()
      local calls = 0
      Raidwise.EvaluateGearCheck = function() end
      Raidwise.CollectGearCheck = function(_, unit)
        return {character={guid=UnitGUID(unit),specKnown=true},inspect={canInspect=true},
          collection={counts={filledCheckedSlots=1}},equipment={}}
      end
      assert(Raidwise:StartGearCheckUnitScan("target", function(report,status)
        calls=calls+1; assert(status=="ok" and report.character.guid=="A")
      end))
      local count = #runtime.notifications
      assert(runtime.notifications[count].unit == "target")
      runtime:Ready("raid2")
      assert(calls == 0 and #runtime.notifications == count)
      runtime:Ready("target")
      assert(calls == 1 and runtime.notifications[#runtime.notifications].unit == "raid1")
      runtime:Ready("raid1"); runtime:Ready("raid2")
      assert(not Raidwise:IsGearCheckScanBusy())
    `);
  } finally {
    lua.global.close();
  }
});
