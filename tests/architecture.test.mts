import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Lua } from "wasmoon-lua5.1";

async function run(modules: string[], setup: string, scenario: string): Promise<void> {
  const lua = await Lua.create();
  try {
    lua.doStringSync(await readFile(new URL("lua/wow-stubs.lua", import.meta.url), "utf8"));
    lua.doStringSync(setup);
    for (const name of modules) {
      lua.doStringSync((await readFile(new URL(`../Raidwise/${name}.lua`, import.meta.url), "utf8")).replace(/^\uFEFF/, ""));
    }
    lua.doStringSync(scenario);
  } finally { lua.global.close(); }
}

test("canonical reports preserve legacy inputs and separate grades from completeness", async () => {
  await run(["GearCheckReport"], "", `
    local legacy = {name="Tester",slots={{policy="CHECKED",item={sockets={}}}},
      inspect={needed=true,complete=true},stats={filledCheckedSlots=1,gearScore=6000}}
    local report = Raidwise:NormalizeGearCheckReport(legacy)
    assert(report.character.name=="Tester" and report.character.gearScore==6000)
    assert(report.equipment==report.slots and report.inspect==report.collection.inspect)
    assert(Raidwise:GetGearCheckScanState(report)=="complete")
    report.overall={status="S"}
    report.equipment[1].item.sockets.gemDataUncertain=true
    local state,reason=Raidwise:GetGearCheckScanState(report)
    assert(state=="incomplete" and reason=="gems_pending" and report.overall.status=="S")
    report.collection.counts.filledCheckedSlots=0
    assert(Raidwise:GetGearCheckScanState(report)=="unavailable")
    report.inspect={complete=true} -- stale legacy alias cannot override canonical data
    report.collection.inspect={needed=true,complete=false,canInspect=false}
    Raidwise:NormalizeGearCheckReport(report)
    assert(report.inspect==report.collection.inspect and report.stats.filledCheckedSlots==0)
    report.collection.counts.filledCheckedSlots=1
    state,reason=Raidwise:GetGearCheckScanState(report)
    assert(state=="unavailable" and reason=="cannot_inspect")
  `);
});

test("rating getters do not migrate or initialize SavedVariables", async () => {
  await run(["PlayerHistory", "PlayerHistoryStore"], "Raidwise.db={}; function time() return 100 end", `
    assert(Raidwise:GetHistoryEntry("absent")==nil and Raidwise.db.history==nil)
    assert(#Raidwise:BuildHistoryRoster()==0 and Raidwise.db.history==nil)
    local entry={guid="A",rating={personal={opinion="positive",tags={"late"},updatedAt=10}}}
    Raidwise.db.history={A=entry}
    Raidwise:GetPersonalRating(entry)
    Raidwise:GetCommunityRating(entry)
    Raidwise:GetHistoryEvents(entry)
    Raidwise:BuildHistoryRoster()
    assert(entry.events==nil and entry.notes==nil and not entry.rating.personal.reputationV2)
    assert(entry.rating.personal.tags[1]=="late")
    Raidwise:InitializeHistoryStore()
    assert(entry.rating.personal.reputationV2 and entry.events[1].type=="late_arrival")
    Raidwise:InitializeHistoryStore()
    assert(#entry.events==1)
    local personal=Raidwise:GetPersonalRating(entry)
    personal.tags[1]="changed"
    assert(entry.rating.personal.tags[1]==nil)
  `);
});

test("shell dispatches page lifecycle without knowing page controls", async () => {
  await run(["ExporterWindow"], "Raidwise.Widgets={}; Raidwise.UITheme={}; Raidwise.Pages={}", `
    local calls={}
    local function page() return {Show=function() end,Hide=function() end} end
    local frame={pages={settings=page(),history=page()},menuButtons={}}
    Raidwise.mainFrame=frame
    Raidwise.Pages.Settings={Refresh=function(host,entering)
      assert(host==frame.pages.settings); calls.entering=entering; calls.refresh=(calls.refresh or 0)+1
    end,ApplyLocale=function(host) assert(host==frame.pages.settings);calls.locale=true end}
    Raidwise:SelectTab("settings")
    assert(calls.entering and calls.refresh==1)
    Raidwise:RefreshLocalizedUI()
    assert(calls.locale and calls.refresh==2 and not calls.entering)
  `);
});

test("party and raid collection share identity fields and retain raid role", async () => {
  await run(["PartyRoster"], `
    function UnitName() return "Tester","Realm" end
    function UnitClass() return "Druid","DRUID" end
    function UnitGUID() return "A" end
    function UnitRace() return "Elf","NightElf" end
    function UnitFactionGroup() return "Alliance" end
    function UnitSex() return 3 end
    function UnitExists() return true end
    function UnitIsUnit() return true end
    function GetGuildInfo() return "Guild","Member" end
    function GetInventorySlotInfo() return nil end
    function GetRaidRosterInfo() return nil,nil,nil,nil,nil,nil,nil,nil,nil,"MAINTANK" end
    Raidwise.CollectPrimarySpec=function() return "Feral","icon",2 end
    Raidwise.RoleForRaidMember=function(_,class,tab,tank)
      assert(class=="DRUID" and tab==2); return tank and "tank" or "melee"
    end
    Raidwise.MergeRatingIntoMember=function(_,member) member.rating="merged" end
  `, `
    local party=Raidwise:CollectPartyMember("player",false)
    local raid=Raidwise:CollectRaidMember("player",false,1)
    for _,key in ipairs({"guid","name","realm","class","spec","specTab","race","faction","gender","rating"}) do
      assert(party[key]==raid[key],key)
    end
    assert(party.role==nil and raid.role=="tank")
    assert(Raidwise:CollectRaidMember("player",false).role=="melee")
  `);
});

test("profile panel construction and history rendering survive extraction", async () => {
  await run(["ProfilePanels"], `
    function widget()
      return setmetatable({}, {__index=function(_,key)
        if key=="GetFrameLevel" then return function() return 1 end end
        if key=="GetWidth" then return function() return 400 end end
        if key=="CreateTexture" then return widget end
        return function() end
      end})
    end
    CreateFrame=function() return widget() end
    Raidwise.Widgets={T=function(key) return key end,CreateFontString=widget,
      CreatePlainButton=widget,ApplyPlainPanel=function() end,SetFontColor=function() end}
  `, `
    local controls={UI={ACTION_BTN_GAP=8,ACTION_BTN_H=28},
      GetRatingTagGroups=function() return {} end,
      CreateOpinionRadio=function() return {host=widget()} end,
      CreateProfileNotesBox=function() return widget(),widget() end}
    for _,key in ipairs({"PROFILE_EVENT_GROUP_ICON","PROFILE_EVENT_PICKER_H","PROFILE_EVENT_TYPE_BTN_H",
      "PROFILE_EVENT_TYPE_ROW_H","PROFILE_LAYOUT_VERSION","PROFILE_OPINION_HEADER_H",
      "PROFILE_OPINION_ROW_H","PROFILE_TAG_COL_GAP","PROFILE_TAG_GROUP_GAP",
      "PROFILE_TAG_GROUP_HEADING_H","PROFILE_TAG_ROW_H"}) do controls[key]=20 end
    local frame={profilePanels={}}
    Raidwise:CreateProfilePanels(frame,widget(),440,controls)
    for _,key in ipairs({"opinion","facts","events","notes","history"}) do assert(frame.profilePanels[key],key) end
    Raidwise:RefreshProfileHistoryPanel(frame,{changes={}},14)
    assert(#frame.historyRows==1)
  `);
});

test("every shipped module compiles as Lua 5.1", async () => {
  const lua = await Lua.create();
  try {
    assert.equal(lua.doStringSync("return _VERSION"), "Lua 5.1");
    const toc = await readFile(new URL("../Raidwise/Raidwise.toc", import.meta.url), "utf8");
    for (const name of toc.split(/\r?\n/).filter(line => line.endsWith(".lua"))) {
      const source = await readFile(new URL(`../Raidwise/${name}`, import.meta.url), "utf8");
      lua.global.set("source", source.replace(/^\uFEFF/, ""));
      lua.doStringSync("assert(loadstring(source))");
    }
  } finally { lua.global.close(); }
});
