import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Lua } from "wasmoon-lua5.1";

const modules = [
  "InspectCoordinator", "GearCheckCatalog", "GearCheckSets", "GearCheckTrinkets",
  "GearCheckProfiles", "GearCheckBis", "GearCheckRules", "GearCheckGrades", "GearCheckExplanations", "GearCheckSelfTest", "GearCheckCollector", "GearCheck", "ChatReports", "GearCheckReports", "GearCheckDump",
];

test("final report messages preserve UTF-8, links, and preview/send equality", async () => {
  await withAddon(async (lua) => {
    lua.doStringSync("SlashCmdList = {}");
    lua.doStringSync(await readFile(new URL("../Raidwise/Raidwise.lua", import.meta.url), "utf8"));
    lua.doStringSync(`
      local network = true
      Raidwise.ResolveReportChatType = function() if network then return "PARTY" end return nil, "self" end
      local sent, localLines = {}, {}
      SendChatMessage = function(message, channel) assert(channel == "PARTY"); sent[#sent + 1] = message end
      DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) localLines[#localLines + 1] = message end }
      local long = string.rep("Я", 140)
      local prepared = Raidwise:PrepareReportMessage(long)
      assert(#prepared <= 255 and prepared:sub(-3) == "...")
      assert(prepared:sub(1, -4) == string.rep("Я", (#prepared - 3) / 2), "Split UTF-8 character")
      local link = "|cff71d5ff|Hspell:123|h[Заклинание]|h|r"
      assert(Raidwise:PrepareReportMessage(link) == link)
      local fits = Raidwise:PrepareReportMessage("[Rw] " .. link .. string.rep("x", 300))
      assert(fits:find(link, 1, true) and #fits <= 255)
      local omitted = Raidwise:PrepareReportMessage(string.rep("x", 240) .. link)
      assert(not omitted:find("|H", 1, true), "Split hyperlink")
      local report = {character={name=long}, overall={status="B"}, verdicts={b=8}, findings={}}
      for _, form in ipairs({"short", "full"}) do
        Raidwise.GetReportForm = function() return form end
        for _, mode in ipairs({"summary", "items", "enchants", "gems", "ok"}) do
          sent = {}
          local preview = Raidwise:BuildGearCheckChatMessages(report, mode)
          assert(Raidwise:PrintGearCheckReport(mode, report))
          assert(#sent == #preview)
          for index, message in ipairs(preview) do
            assert(sent[index] == message and #message <= 255)
            assert(message:sub(1, 10) == "[Rw]-gear ")
          end
        end
      end
      sent = {}
      Raidwise:SendReportChat(long)
      assert(sent[1] == prepared)
      network = false
      assert(Raidwise:PrepareReportMessage(long) == long, "Local output was unnecessarily truncated")
      local preview = Raidwise:BuildGearCheckChatMessages(report, "summary")
      Raidwise:PrintGearCheckReport("summary", report)
      for index, message in ipairs(preview) do assert(localLines[index] == message) end
    `);
  });
});

async function withAddon(run: (lua: Lua) => Promise<void>): Promise<void> {
  const lua = await Lua.create();
  try {
    assert.equal(lua.doStringSync('return _VERSION'), "Lua 5.1");
    lua.doStringSync(await readFile(new URL("lua/wow-stubs.lua", import.meta.url), "utf8"));
    for (const name of modules) {
      const source = await readFile(new URL(`../Raidwise/${name}.lua`, import.meta.url), "utf8");
      lua.doStringSync(source.replace(/^\uFEFF/, ""));
    }
    await run(lua);
  } finally {
    lua.global.close();
  }
}

test("unavailable equipment cannot claim a clean scan", async () => {
  await withAddon(async (lua) => {
    lua.doStringSync(`
      local report = {character={isSelf=false}, inspect={needed=true,complete=false}, equipment={}}
      Raidwise:EvaluateGearCheck(report)
      assert(report.overall.reason == "inspect_incomplete")
      assert(report.overall.summary == "Inspect data is incomplete; grades are provisional.")
    `);
  });
});

test("gear-check rule self-tests", async (context) => {
  await withAddon(async (lua) => {
    const count = lua.doStringSync(`
      local results, passed, total = Raidwise:GearCheckRulesSelfTest()
      local failures = {}
      for _, result in ipairs(results) do
        if not result.ok then failures[#failures + 1] = result.name end
      end
      assert(total > 0, "No rule checks were run")
      assert(passed == total, table.concat(failures, "\\n"))
      return total
    `);
    context.diagnostic(`${count} Lua rule checks passed`);
  });
});

test("collection orchestration and offline evaluation have explicit boundaries", async () => {
  await withAddon(async (lua) => {
    lua.doStringSync(`
      local calls = 0
      local snapshot = {character={classFile="WARRIOR",specTab=3,specKnown=true},equipment={}}
      local evaluate = Raidwise.EvaluateGearCheck
      Raidwise.EvaluateGearCheck = function() error("Collection invoked evaluation") end
      UnitIsUnit = function(left,right) return left == right end
      Raidwise.CollectGearCheckObservation = function(_,unit,ready)
        calls = calls + 1
        assert(unit == "player" and ready == true)
        return snapshot
      end
      assert(Raidwise:CollectGearCheck("player") == snapshot and calls == 1)
      assert(Raidwise:GetLastGearCheckReport() == snapshot)
      Raidwise.EvaluateGearCheck = evaluate
      local function forbidden() error("Evaluation read live WoW data") end
      GetItemInfo=forbidden; GetItemStats=forbidden; GetItemGem=forbidden
      UnitGUID=forbidden; UnitName=forbidden; UnitIsUnit=forbidden; GetTalentTabInfo=forbidden
      Raidwise:EvaluateGearCheck(snapshot)
      assert(snapshot.findings and snapshot.verdicts and snapshot.overall)
      assert(type(Raidwise:BuildGearCheckCategoryTooltipLines(snapshot,"gear",20)) == "table")
      local results, passed, total = Raidwise:GearCheckRulesSelfTest()
      assert(passed == total and #results == total)
    `);
  });
});

test("gem collection, cache invalidation, and meta regressions", async () => {
  await withAddon(async (lua) => {
    lua.doStringSync(await readFile(new URL("lua/gear-check-gems.lua", import.meta.url), "utf8"));
  });
});

test("roster issue reports group codes, separate categories, and retain unknown checks", async () => {
  await withAddon(async (lua) => {
    lua.doStringSync(`
      local report = { character = { name = "Tester" }, findings = {
        { code = "GEM_NOT_CHECKABLE", category = "gem", severity = "info", slot = "neck" },
        { code = "GEM_NOT_CHECKABLE", category = "gem", severity = "info", slot = "wrist" },
        { code = "GEM_NOT_CHECKABLE", category = "gem", severity = "info", slot = "neck" },
        { code = "MISSING_ENCHANT", category = "enchant", severity = "soft", slot = "head" },
        { code = "WRONG_WEAPON", category = "weapon", severity = "hard", slot = "mainHand" },
      } }
      Raidwise.GetReportForm = function() return "full" end
      local lines = Raidwise:FormatGearCheckMemberIssues(report, "enchant")
      assert(#lines == 1)
      assert(lines[1] == "[Rw]-raid Tester Enchants/Gems: GEM_NOT_CHECKABLE - neck,wrist; MISSING_ENCHANT - head", lines[1])
      assert(Raidwise:FormatGearCheckMemberIssues(report, "gear")[1] == "[Rw]-raid Tester Gear: WRONG_WEAPON - MH")
      assert(#Raidwise:FormatGearCheckMemberIssues(nil, "gear") == 0)
      assert(Raidwise:FormatGearCheckMemberIssues({}, "gear")[1] == "[Rw]-raid ? Gear: No issues in this category.")
      for index = 1, 40 do
        report.findings[#report.findings + 1] = { code = "ISSUE_" .. index, category = "gem", severity = "soft", slot = "head" }
      end
      lines = Raidwise:FormatGearCheckMemberIssues(report, "enchant")
      assert(#lines > 1)
      for _, line in ipairs(lines) do
        assert(#line <= 220, line)
        assert(string.find(line, "[Rw]-raid Tester Enchants/Gems: ", 1, true) == 1, line)
      end
      assert(string.find(lines[#lines], "ISSUE_40", 1, true))
    `);
  });
});

test("header chat radios preserve choices, colors, and exclusive selection", async () => {
  await withAddon(async (lua) => {
    lua.doStringSync(`
      local function widget()
        return setmetatable({scripts={}}, {__index=function(_, key)
          if key == "SetScript" then return function(self,event,fn) self.scripts[event]=fn end end
          if key == "SetChecked" then return function(self,value) self.checked=value end end
          if key == "SetTextColor" then return function(self,r,g,b) self.color={r,g,b} end end
          if key == "SetText" then return function(self,value) self.text=value end end
          return function() end
        end})
      end
      CreateFrame = widget
      Raidwise.Widgets = {CreateFontString=widget,SetFontColor=function() end,T=function(key) return key end}
      Raidwise.UITheme = {TEXT_BODY={1,1,1}, ACTION_BTN_H=28}
      Raidwise.db = {reportChannel="auto"}
      Raidwise.GetReportChannel = function(self) return self.db.reportChannel end
      Raidwise.SetReportChannel = function(self,id)
        self.db.reportChannel=id
        self:RefreshHeaderReportChannels()
      end
      ChatTypeInfo = {SAY={r=1,g=1,b=1},PARTY={r=0.5,g=0.5,b=1}}
      function findLocal(fn, wanted)
        for index=1,100 do
          local name,value=debug.getupvalue(fn,index)
          if not name then break end
          if name==wanted then return value end
        end
        error(wanted)
      end
    `);
    for (const module of ["PageRaid", "PageComposition", "PageGearCheckTarget", "ExporterWindow", "PageSettings"]) {
      lua.doStringSync(await readFile(new URL(`../Raidwise/${module}.lua`, import.meta.url), "utf8"));
    }
    lua.doStringSync(`
      local createTitle=findLocal(Raidwise.CreateMainFrame,"CreateTitleBar")
      local createRadios=findLocal(createTitle,"CreateHeaderReportChannels")
      local frame={}
      Raidwise.mainFrame=frame
      createRadios(frame,{}, {})
      Raidwise:RefreshHeaderReportChannels()
      local radios=frame.reportChannelRadios
      assert(#radios==8 and radios[8].checked)
      for _,radio in ipairs(radios) do
        assert(#radio.label.text<=3)
        radio.scripts.OnClick(radio)
        assert(Raidwise.db.reportChannel==radio.channelId)
        local checked=0
        for _,other in ipairs(radios) do if other.checked then checked=checked+1 end end
        assert(checked==1)
      end
      assert(radios[3].label.color[1]==0.5 and radios[3].label.color[3]==1)
      local createForms=findLocal(createTitle,"CreateHeaderReportForm")
      Raidwise.GetReportForm=function(self) return self.db.reportForm or "short" end
      Raidwise.SetReportForm=function(self,id)
        self.db.reportForm=id
        self:RefreshHeaderReportForm()
      end
      createForms(frame,{})
      Raidwise:RefreshHeaderReportForm()
      assert(frame.reportFormRadios[1].checked and not frame.reportFormRadios[2].checked)
      frame.reportFormRadios[2].scripts.OnClick()
      assert(Raidwise.db.reportForm=="full")
      assert(frame.reportFormRadios[2].checked and not frame.reportFormRadios[1].checked)
      assert(Raidwise.Pages.Settings.LAYOUT_VERSION==14)
      local updateHeader=findLocal(Raidwise.SelectTab,"UpdateShellHeader")
      for _,host in ipairs({frame.reportChannelHost,frame.reportFormHost}) do
        host.Show=function(self) self.visible=true end
        host.Hide=function(self) self.visible=false end
      end
      for _,tab in ipairs({"raid","composition","geartarget","cooldowns","export","history","settings","info"}) do
        updateHeader(frame,tab)
        assert(frame.reportChannelHost.visible==(tab=="raid" or tab=="composition" or tab=="geartarget"),tab)
        assert(frame.reportFormHost.visible==(tab=="geartarget"),tab)
      end
      assert(Raidwise.db.reportForm=="full" and Raidwise.db.reportChannel=="auto")
    `);
  });
});

test("composition reports preserve spell links and fit one chat message", async () => {
  await withAddon(async (lua) => {
    lua.doStringSync(`
      Raidwise.Widgets = {T=function(key, name, detail)
        if key == "COMP_CHAT_EFFECT_NEED" then return "[Rw] need " .. name .. " - " .. detail end
        if key == "COMP_CHAT_EFFECT_HAVE" then return "[Rw] have " .. name .. " - " .. detail end
        return key
      end}
      Raidwise.UITheme = {}
      Raidwise.T = function(self,key,who,spell)
        if key == "COMP_SRC_SPELL" then return who .. " - " .. spell end
        return who or key
      end
      GetSpellInfo = function() return "Wisdom" end
      GetSpellLink = function(id) return "|cff71d5ff|Hspell:" .. id .. "|h[Wisdom]|h|r" end
      function nestedLocal(fn,wanted,seen)
        seen=seen or {}
        if type(fn)~="function" or seen[fn] then return end
        seen[fn]=true
        for index=1,100 do
          local name,value=debug.getupvalue(fn,index)
          if not name then break end
          if name==wanted then return value end
          local found=nestedLocal(value,wanted,seen)
          if found then return found end
        end
      end
    `);
    for (const module of ["RaidComposition", "PageComposition"]) {
      lua.doStringSync(await readFile(new URL(`../Raidwise/${module}.lua`, import.meta.url), "utf8"));
    }
    lua.doStringSync(`
      local formatSource=nestedLocal(Raidwise.AnalyzeRaidComposition,"FormatSource")
      local plain,spell,linked=formatSource({race="Draenei"},20186)
      assert(spell=="Wisdom" and not string.find(plain,"|H",1,true))
      assert(string.find(linked,"|Hspell:20186",1,true))
      GetSpellLink=nil
      local fallback,_,chatFallback=formatSource({race="Draenei"},20186)
      assert(fallback==chatFallback)
      local build=nestedLocal(Raidwise.RefreshCompositionView,"BuildEffectRowMessage")
      assert(build)
      local row={tooltipTitle="Judgement of Wisdom",chatCount=0,chatSources={linked}}
      local message=build(row)
      assert(#message<=255 and string.find(message,linked,1,true))
      row.chatSources={linked,linked,linked,linked,linked,linked}
      message=build(row)
      assert(#message<=255 and string.find(message,"(+",1,true))
      local _,opens=string.gsub(message,"|Hspell:","")
      local _,closes=string.gsub(message,"|h|r","")
      assert(opens==closes and opens>0)
      row.chatCount=1
      assert(string.find(build(row),"[Rw] have",1,true)==1)
    `);
  });
});
