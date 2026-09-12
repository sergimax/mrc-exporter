import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Lua } from "wasmoon-lua5.1";

test("dump output, frame progress, cancellation, restart, and export routing", async () => {
  const lua = await Lua.create();
  try {
    assert.equal(lua.doStringSync("return _VERSION"), "Lua 5.1");
    for (const path of ["lua/wow-stubs.lua", "lua/scan-runtime.lua", "../Raidwise/InspectCoordinator.lua", "../Raidwise/GearCheckReport.lua", "../Raidwise/GearCheck.lua", "../Raidwise/GearCheckDump.lua"]) {
      lua.doStringSync(await readFile(new URL(path, import.meta.url), "utf8"));
    }
    lua.doStringSync(`
      local report = {
        schemaVersion=3, character={name="Tester", gaps={{code="SPEC_UNKNOWN"}}},
        equipment={{key="head",slotName="HeadSlot",policy="CHECKED",verdict="B",item={
          itemId=123, name="Test helm", stats={strength=10,agility=5},
          enchant={enchantId=1,name="Test enchant",present=true,known=true},
          gems={{itemId=2,name="Test gem",color="red",socketIndex=1,state="known"}},
          gaps={{code="ITEM_GAP",detail="test"}}
        }}}, findings={{code="TEST",severity="info",category="item",slot="head",message="Test finding"}}
      }
      local target = Raidwise:FormatGearCheckDump(report)
      assert(target:find("stats: agility=5, strength=10",1,true))
      assert(target:find("name=Test enchant",1,true) and target:find("name=Test gem",1,true))
      assert(target:find("ITEM_GAP(test)",1,true) and target:find("TEST @head",1,true))
      assert(Raidwise:FormatGearCheckPhase1Dump(report) == target)
      assert(Raidwise:FormatGearCheckDump(nil) == "No Gear Check data.")
      local results = {{report=report,member={name="Tester"}}, {member={name="Offline"},status="skipped"}}
      local expected = Raidwise:FormatGearCheckRaidDump(results)
      assert(expected:find("2 players, 1 reports, 1 failed/skipped",1,true))
      assert(expected:find(target,1,true) and expected:find("Player: Offline",1,true))
      local progress, callbacks, output = 0, 0, nil
      local function done(text)
        callbacks=callbacks+1; output=text
        assert(not Raidwise:IsGearCheckRaidDumpBusy(), "Busy state not cleared before callback")
      end
      assert(Raidwise:BuildGearCheckRaidDumpAsync(results,function(index,total,member)
        progress=progress+1; assert(index==progress and total==2 and member.name)
      end,done))
      assert(not Raidwise:BuildGearCheckRaidDumpAsync(results,nil,function() error("Rejected job callback") end))
      ScanRuntime:Tick(0.01); assert(progress==1 and callbacks==0)
      ScanRuntime:Tick(0.01); assert(progress==2 and callbacks==0)
      ScanRuntime:Tick(0.01); assert(callbacks==1 and output==expected)
      ScanRuntime:Tick(1); assert(callbacks==1)
      assert(Raidwise:BuildGearCheckRaidDumpAsync(results,nil,done))
      ScanRuntime:Tick(0.01)
      Raidwise:CancelGearCheckRaidDump()
      assert(callbacks==2 and output==nil)
      Raidwise:CancelGearCheckRaidDump(); ScanRuntime:Tick(1); assert(callbacks==2)
      assert(Raidwise:BuildGearCheckRaidDumpAsync(results,nil,done))
      for index=1,3 do ScanRuntime:Tick(0.01) end
      assert(callbacks==3 and output==expected)
      assert(not Raidwise:BuildGearCheckRaidDumpAsync({},nil,done))
      assert(callbacks==4 and output=="" and Raidwise:FormatGearCheckRaidDump({})=="")
      local displayed, printed
      Raidwise.Print=function(_,message) printed=message end
      Raidwise.ShowRaidGearCheckExportText=function(_,text) displayed=text end
      assert(Raidwise:ShowGearCheckRaidDump(results) and displayed==expected)
      Raidwise.ShowRaidGearCheckExportText=nil
      Raidwise.ShowGearCheckDumpText=function(_,text) displayed=text end
      displayed=nil
      assert(Raidwise:ShowGearCheckRaidDump(results) and displayed==expected)
      assert(not Raidwise:ShowGearCheckRaidDump({}) and printed=="GEAR_CHECK_RAID_EXPORT_EMPTY")
    `);
  } finally {
    lua.global.close();
  }
});
