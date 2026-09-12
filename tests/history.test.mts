import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Lua } from "wasmoon-lua5.1";

test("history migration is idempotent and ratings, events, and notes persist", async () => {
  const lua = await Lua.create();
  try {
    assert.equal(lua.doStringSync("return _VERSION"), "Lua 5.1");
    lua.doStringSync(`
      Raidwise = {db={}}
      function Raidwise:T(key) return key end
      function time() return 1000 end
      function date() return "test date" end
      function UnitGUID() return "SELF" end
      function GetRealmName() return "Realm" end
      function ChatFrame_AddMessageEventFilter() end
      function PlaySound() end
      Raidwise.UITheme = {}
      Raidwise.Widgets = { T=function(key) return key end }
    `);
    for (const module of ["PlayerHistory", "PlayerHistoryStore", "RatingPresentation", "ProfileDraft", "ProfilePanels", "CharacterProfile"]) {
      lua.doStringSync(await readFile(new URL(`../Raidwise/${module}.lua`, import.meta.url), "utf8"));
    }
    lua.doStringSync(`
      local legacy = {guid="A",name="Tester",metAt=100,
        rating={personal={opinion="positive",tags={"raid_leader","late","experienced"},updatedAt=500}}}
      Raidwise.db.history={A=legacy}
      local entry=Raidwise:EnsureHistoryEntryForGuid("A")
      local personal=Raidwise:GetPersonalRating(entry)
      assert(entry.rating.personal.reputationV2 and personal.facts[1]=="raid_leader")
      assert(#entry.events==1 and entry.events[1].type=="late_arrival")
      Raidwise:EnsurePersonalRating(entry); Raidwise:EnsureHistoryEntryForGuid("A")
      assert(#entry.events==1 and entry.lastSeenAt==100 and entry.meetCount==1)
      local tag=Raidwise:RatingTagGroups()[1].tags[1].id
      Raidwise:SavePersonalRatingForGuid("A",nil,"negative",{tag},{"raid_leader"})
      assert(entry.rating.personal.opinion=="negative" and entry.rating.personal.tags[1]==tag)
      local event={id="draft-1",type="same_party",eventAt=1000,context={zoneName="Test zone"}}
      Raidwise:SaveHistoryEventsForGuid("A",nil,{event})
      event.context.zoneName="Changed draft"
      assert(#entry.events==1 and entry.events[1].context.zoneName=="Test zone")
      Raidwise:SaveProfileNotesForGuid("A",nil,"Private note")
      assert(entry.notes=="Private note")
      Raidwise:SaveProfileNotesForGuid("A",nil,"")
      assert(entry.notes=="")
      Raidwise:SaveHistoryEventsForGuid("A",nil,{})
      assert(#entry.events==0)
      local persisted=Raidwise.db
      Raidwise.db=nil; Raidwise.db=persisted
      assert(Raidwise:GetHistoryEntry("A").rating.personal.opinion=="negative")
      assert(Raidwise:SavePersonalRatingForGuid("",nil,"positive",{})==nil)
      -- Draft changes and cancellation must not mutate persisted ratings/events.
      local draft = Raidwise:CreateProfileDraft(entry)
      draft.draftOpinion="positive"
      Raidwise:AddProfileDraftEvent(draft,"same_party")
      assert(entry.rating.personal.opinion=="negative" and #entry.events==0)
      draft=Raidwise:CreateProfileDraft(entry) -- discard/reopen
      assert(draft.draftOpinion=="negative" and #draft.draftEvents==0)
      local tags=Raidwise:RatingTagGroups()[1].tags
      draft.draftTags={}
      for index=1,3 do assert(Raidwise:ToggleProfileDraftTag(draft,tags[index].id)) end
      local ok,key=Raidwise:ToggleProfileDraftTag(draft,tags[4].id)
      assert(not ok and key=="RATING_GROUP_LIMIT" and #draft.draftTags==3)
      assert(Raidwise:ToggleProfileDraftTag(draft,tags[1].id) and #draft.draftTags==2)
      Raidwise:AddProfileDraftEvent(draft,"same_party")
      local id=draft.draftEvents[1].id
      Raidwise:RemoveProfileDraftEvent(draft,id)
      assert(#draft.draftEvents==0)
      -- Exercise the real UI command wrappers with a minimal frame.
      Raidwise.raidDetailFrame={profileMember=entry,profileDraft=draft}
      Raidwise:SetProfileOpinion("positive")
      Raidwise:AddProfileEvent("same_party")
      assert(entry.rating.personal.opinion=="negative" and #entry.events==0)
      Raidwise:CommitProfileRating()
      assert(entry.rating.personal.opinion=="positive" and #entry.events==1)
      local reopened=Raidwise:CreateProfileDraft(entry)
      reopened.draftEvents[1].context.zoneName="Draft only"
      assert(entry.events[1].context.zoneName~="Draft only")
      Raidwise:SaveProfileNotes("Saved through UI")
      assert(entry.notes=="Saved through UI")
      Raidwise:ResetProfileNotes()
      assert(entry.notes=="")
    `);
  } finally { lua.global.close(); }
});
