-- Roster and gear/rating presentation built on generic widgets.
local Addon = Raidwise
local W = Addon.Widgets
local UI = Addon.UITheme

function W.GearGradationColor(step)
	if not step or step == "" then
		return UI.GEAR_OK
	end
	local key = string.lower(tostring(step))
	if key == "s" then
		return UI.GEAR_S
	end
	if key == "d" or key == "bad" or key == "forbidden" then
		return UI.GEAR_BAD
	end
	if key == "c" or key == "replace" or key == "unwanted" then
		return UI.GEAR_REPLACE
	end
	if key == "a" or key == "good" or key == "preferred" then
		return UI.GEAR_GOOD
	end
	if key == "b" or key == "ok" or key == "acceptable" then
		return UI.GEAR_OK
	end
	return UI.GEAR_OK
end

function W.GearVerdictColor(verdict)
	return W.GearGradationColor(verdict)
end

function W.WrapGearGradation(label)
	return W.ColorText(W.GearGradationColor(label), label)
end

local GEAR_GRADATION_TOKENS = {
	"forbidden",
	"acceptable",
	"unwanted",
	"preferred",
	"S",
	"A",
	"B",
	"C",
	"D",
}

function W.ColorizeGearGradation(text)
	if not text or text == "" then
		return text
	end
	for index = 1, #GEAR_GRADATION_TOKENS do
		local token = GEAR_GRADATION_TOKENS[index]
		local colored = W.WrapGearGradation(token)
		text = text:gsub("(%f[%a])" .. token .. "(%f[%A])", colored)
	end
	return text
end

function W.FormatGearVerdictCountsLine(prefix, counts, suffix)
	counts = counts or {}
	local parts = {}
	if prefix and prefix ~= "" then
		parts[#parts + 1] = prefix
	end
	parts[#parts + 1] = W.WrapGearGradation("S") .. " " .. tostring(counts.s or 0)
	parts[#parts + 1] = " · "
	parts[#parts + 1] = W.WrapGearGradation("A") .. " " .. tostring(counts.a or 0)
	parts[#parts + 1] = " · "
	parts[#parts + 1] = W.WrapGearGradation("B") .. " " .. tostring(counts.b or 0)
	parts[#parts + 1] = " · "
	parts[#parts + 1] = W.WrapGearGradation("C") .. " " .. tostring(counts.c or 0)
	parts[#parts + 1] = " · "
	parts[#parts + 1] = W.WrapGearGradation("D") .. " " .. tostring(counts.d or 0)
	if suffix and suffix ~= "" then
		parts[#parts + 1] = suffix
	end
	return table.concat(parts)
end

function W.CreateBuffIconHost(parent)
	local host = CreateFrame("Frame", nil, parent)
	host:SetSize(UI.RAID_BUFF_ICON, UI.RAID_BUFF_ICON)
	host.icon = host:CreateTexture(nil, "ARTWORK")
	host.icon:SetAllPoints(host)
	host:EnableMouse(true)
	host:SetScript("OnEnter", function(self)
		if not self.buffName or self.buffName == "" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.buffName)
		GameTooltip:Show()
	end)
	host:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	host:Hide()
	return host
end

function W.FillRaidBuffIcons(hosts, buffs)
	buffs = buffs or {}
	for buffIndex = 1, UI.RAID_BUFF_MAX do
		local host = hosts[buffIndex]
		local buff = buffs[buffIndex]
		if host and buff and buff.icon then
			W.SetSpellIconTexture(host.icon, buff.icon)
			host.buffName = buff.name or ""
			host:Show()
		elseif host then
			host.icon:SetTexture(nil)
			host.buffName = nil
			host:Hide()
		end
	end
end

function W.CreatePartyBuffStatusHost(parent)
	local host = CreateFrame("Frame", nil, parent)
	host:SetSize(UI.PARTY_BUFF_ICON, UI.PARTY_BUFF_ICON)
	host.icon = host:CreateTexture(nil, "ARTWORK")
	host.icon:SetAllPoints(host)
	host:EnableMouse(true)
	host:SetScript("OnEnter", function(self)
		if not self.buffName or self.buffName == "" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.buffName, 1, 1, 1)
		if self.present then
			local providerText = table.concat(self.providers or {}, ", ")
			GameTooltip:AddLine(W.T("RAID_PARTY_BUFF_PRESENT", providerText), 0.2, 1, 0.2)
		else
			GameTooltip:AddLine(W.T("RAID_PARTY_BUFF_MISSING"), 1, 0.3, 0.3)
		end
		GameTooltip:Show()
	end)
	host:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return host
end

function W.FillPartyBuffStatusIcons(hosts, coverage)
	coverage = coverage or {}
	for buffIndex = 1, UI.PARTY_BUFF_MAX do
		local host = hosts[buffIndex]
		local entry = coverage[buffIndex]
		if host and entry and entry.icon then
			W.SetSpellIconTexture(host.icon, entry.icon)
			host.buffName = entry.name or ""
			host.present = entry.present and true or false
			host.providers = entry.providers or {}
			if host.present then
				host.icon:SetDesaturated(false)
				host.icon:SetVertexColor(1, 1, 1)
			else
				host.icon:SetDesaturated(true)
				host.icon:SetVertexColor(UI.TEXT_ALERT[1], UI.TEXT_ALERT[2], UI.TEXT_ALERT[3])
			end
			host:Show()
		elseif host then
			host.icon:SetTexture(nil)
			host.buffName = nil
			host.present = nil
			host.providers = nil
			host:Hide()
		end
	end
end

function W.CreateConsumableStatusHost(parent)
	local host = CreateFrame("Frame", nil, parent)
	host:SetSize(UI.PARTY_BUFF_ICON, UI.PARTY_BUFF_ICON)
	host.icon = host:CreateTexture(nil, "ARTWORK")
	host.icon:SetAllPoints(host)
	host:EnableMouse(true)
	host:SetScript("OnEnter", function(self)
		if not self.kindLabel or self.kindLabel == "" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.kindLabel, 1, 1, 1)
		if self.unknown then
			GameTooltip:AddLine(W.T(self.reasonKey or "RAID_CONSUMABLE_OUT_OF_RANGE"), 0.70, 0.70, 0.70)
		elseif self.present then
			local detail = self.detail
			if self.elixirPair then
				detail = W.T("RAID_CONSUMABLE_ELIXIRS")
			end
			if not detail or detail == "" then
				detail = W.T("RAID_PARTY_BUFF_PRESENT", self.kindLabel)
			end
			GameTooltip:AddLine(detail, 0.2, 1, 0.2)
		else
			GameTooltip:AddLine(W.T("RAID_PARTY_BUFF_MISSING"), 1, 0.3, 0.3)
		end
		GameTooltip:Show()
	end)
	host:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	host:Hide()
	return host
end

function W.FillConsumableStatusIcon(host, status, kindLabelKey)
	if not host then
		return
	end
	if not status then
		host:Hide()
		return
	end
	host.kindLabel = W.T(kindLabelKey)
	host.present = status.present and true or false
	host.unknown = status.unknown and true or false
	host.elixirPair = status.elixirPair and true or false
	host.detail = status.name or ""
	host.reasonKey = status.reasonKey
	if status.icon then
		W.SetSpellIconTexture(host.icon, status.icon)
	end
	if host.unknown then
		host.icon:SetDesaturated(true)
		host.icon:SetVertexColor(0.55, 0.55, 0.55)
	elseif host.present then
		host.icon:SetDesaturated(false)
		host.icon:SetVertexColor(1, 1, 1)
	else
		host.icon:SetDesaturated(true)
		host.icon:SetVertexColor(UI.TEXT_ALERT[1], UI.TEXT_ALERT[2], UI.TEXT_ALERT[3])
	end
	host:Show()
end

function W.FormatGuildDisplay(guildName, guildRank)
	if not guildName or guildName == "" then
		return "-"
	end
	if guildRank and guildRank ~= "" then
		return guildName .. " (" .. guildRank .. ")"
	end
	return guildName
end

function W.RatingOpinion(member)
	if Addon.GetPersonalRating then
		local rating = Addon:GetPersonalRating(member)
		return rating.opinion, rating.tags
	end
	return "neutral", {}
end

function W.RatingOpinionText(member)
	local opinion = W.RatingOpinion(member)
	if Addon.RatingOpinionLabel then
		return Addon:RatingOpinionLabel(opinion)
	end
	return tostring(opinion or "")
end

function W.RatingOpinionSymbol(member)
	local opinion = W.RatingOpinion(member)
	if Addon.RatingOpinionSymbol then
		return Addon:RatingOpinionSymbol(opinion)
	end
	return "="
end

function W.RatingOpinionIcon(member)
	local opinion = W.RatingOpinion(member)
	if Addon.RatingOpinionIcon then
		return Addon:RatingOpinionIcon(opinion)
	end
	return nil
end

function W.RatingOpinionColor(member)
	local opinion = W.RatingOpinion(member)
	if Addon.RatingOpinionColor then
		return Addon:RatingOpinionColor(opinion)
	end
	return UI.TEXT_IDLE
end

function W.FormatOpinionLine(member)
	return W.T("RATING_PROFILE_OPINION", W.RatingOpinionText(member))
end

function W.FormatTagLine(member)
	local _, tags = W.RatingOpinion(member)
	if Addon.RatingTagColoredSummary then
		return Addon:RatingTagColoredSummary(tags, 3)
	end
	return ""
end

function W.ShowMemberRatingTooltip(anchor, member, opts)
	if not member then
		return
	end
	opts = type(opts) == "table" and opts or nil
	GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
	local opinionText = W.RatingOpinionText(member)
	if Addon.RatingWrapColor and Addon.RatingOpinionColor then
		opinionText = Addon:RatingWrapColor(opinionText, Addon:RatingOpinionColor(W.RatingOpinion(member)))
	end
	GameTooltip:AddLine(W.T("COL_OPINION") .. ": " .. opinionText)
	local tags = W.FormatTagLine(member)
	if tags ~= "" then
		GameTooltip:AddLine(W.T("COL_TAGS") .. ": " .. tags, 0.8, 0.8, 0.8, true)
	end
	if Addon.GetCommunityRating then
		local community = Addon:GetCommunityRating(member)
		local percent = community and tonumber(community.positivePercent)
		if percent then
			GameTooltip:AddLine(W.T("TOOLTIP_COMMUNITY_POSITIVE", percent), 0.8, 0.8, 0.8)
			if Addon.RatingTagColoredSummary and community.tags then
				local communityTags = Addon:RatingTagColoredSummary(community.tags, 3)
				if communityTags ~= "" then
					GameTooltip:AddLine(communityTags, 0.75, 0.75, 0.75, true)
				end
			end
		end
	end
	local guildText = W.FormatGuildDisplay(member.guildName, member.guildRank)
	if guildText and guildText ~= "-" then
		GameTooltip:AddLine(W.T("COL_GUILD") .. ": " .. guildText, 0.8, 0.8, 0.8, true)
	end
	if opts and opts.gearCheck then
		W.AppendGearCheckRaidTooltip(opts.gearEntry)
	end
	if opts and type(opts.raidBuffs) == "table" and #opts.raidBuffs > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(W.T("COL_BUFFS"), UI.GOLD[1], UI.GOLD[2], UI.GOLD[3])
		for buffIndex = 1, #opts.raidBuffs do
			local buff = opts.raidBuffs[buffIndex]
			local buffName = buff and buff.name
			if buffName and buffName ~= "" then
				local icon = W.IconMarkup(buff.icon, 14)
				if icon ~= "" then
					GameTooltip:AddLine(icon .. " " .. buffName, 1, 1, 1)
				else
					GameTooltip:AddLine(buffName, 1, 1, 1)
				end
			end
		end
	end
	GameTooltip:Show()
end

local TOOLTIP_DETAIL_MAX = 6

function W.AppendGearCheckRaidTooltip(gearEntry)
	if not Addon.BuildGearCheckCategoryTooltipLines then
		return
	end

	local report = gearEntry and gearEntry.report
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(W.T("GEAR_CHECK_RAID_TIP_HEADER"), 1, 0.82, 0)

	if not report then
		local statusLabel = Addon.GetGearCheckRaidEntryStatusLabel
			and Addon:GetGearCheckRaidEntryStatusLabel(gearEntry)
			or W.T("GEAR_CHECK_RAID_NOT_SCANNED")
		GameTooltip:AddLine(statusLabel, 0.7, 0.7, 0.7, true)
		GameTooltip:AddLine(W.T("GEAR_CHECK_RAID_CLICK_HINT"), 0.6, 0.6, 0.6, true)
		return
	end

	local sections = {
		{ key = "gear", labelKey = "GEAR_CHECK_RAID_TIP_GEAR" },
		{ key = "enchantSocket", labelKey = "GEAR_CHECK_RAID_TIP_ENCHANT" },
	}

	local scanLabel = Addon:GetGearCheckScanLabel(report)
	if scanLabel then GameTooltip:AddLine(scanLabel, 1, 0.82, 0, true) end

	for sectionIndex = 1, #sections do
		local section = sections[sectionIndex]
		local block = Addon:BuildGearCheckCategoryTooltipLines(report, section.key, TOOLTIP_DETAIL_MAX)
		local gradeColor = W.GearVerdictColor(block.grade)
		GameTooltip:AddLine(
			W.T(section.labelKey, W.WrapGearGradation(block.grade)),
			gradeColor[1],
			gradeColor[2],
			gradeColor[3]
		)
		for lineIndex = 1, #block.lines do
			local line = block.lines[lineIndex]
			local color = UI.TEXT_IDLE
			if line.severity == "hard" then
				color = UI.GEAR_BAD
			elseif line.severity == "soft" then
				color = UI.GEAR_REPLACE
			elseif line.severity == "clean" then
				color = UI.GEAR_GOOD
			else
				color = { 0.8, 0.8, 0.8 }
			end
			local indent = (line.kind == "bullet") and "    " or "  "
			GameTooltip:AddLine(indent .. line.text, color[1], color[2], color[3], true)
		end
		if block.hidden and block.hidden > 0 then
			GameTooltip:AddLine(W.T("GEAR_CHECK_RAID_TIP_MORE", block.hidden), 0.6, 0.6, 0.6, true)
		end
	end

	GameTooltip:AddLine(W.T("GEAR_CHECK_RAID_CLICK_HINT"), 0.6, 0.6, 0.6, true)
end

