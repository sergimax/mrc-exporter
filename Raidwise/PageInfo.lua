-- PageInfo

local Addon = Raidwise
local W = Addon.Widgets
local UI = Addon.UITheme

Addon.Pages = Addon.Pages or {}

local LAYOUT_VERSION = 4

local GITHUB_URL = "https://github.com/sergimax/Raidwise-addon"

local SECTION_ICON_SIZE = 18

-- Body locale key per menu page id (Info itself is omitted; intro covers slash commands).
local SECTION_BODY_KEYS = {
	cooldowns = "INFO_SECTION_COOLDOWNS",
	export = "INFO_SECTION_EXPORT",
	raid = "INFO_SECTION_RAID",
	composition = "INFO_SECTION_COMPOSITION",
	geartarget = "INFO_SECTION_GEARTARGET",
	history = "INFO_SECTION_HISTORY",
	settings = "INFO_SECTION_SETTINGS",
}

local function ApplyInfoHeadingFont(fontString)
	W.ApplyFontSize(fontString, UI.INFO_HEADING_SIZE)
end

local function ApplyInfoBodyFont(fontString)
	W.ApplyFontSize(fontString, UI.INFO_BODY_SIZE)
	fontString:SetSpacing(UI.INFO_LINE_SPACING or 0)
end

local function PageLayoutVersion(pageKey)
	local pageModule = Addon.Pages and Addon.Pages[pageKey]
	if pageModule and pageModule.LAYOUT_VERSION then
		return pageModule.LAYOUT_VERSION
	end
	return 1
end

local function FeatureMenuPages()
	local pages = Addon.MenuPages
	if type(pages) ~= "table" then
		return {}
	end
	local list = {}
	for index = 1, #pages do
		local pageInfo = pages[index]
		if pageInfo and pageInfo.id and SECTION_BODY_KEYS[pageInfo.id] then
			list[#list + 1] = pageInfo
		end
	end
	return list
end

local function LayoutInfoContent(page)
	if not page or not page.content then
		return
	end
	local content = page.content
	local width = content:GetWidth() or W.ContentInnerWidth()
	local y = 0

	if page.aboutHeading then
		page.aboutHeading:ClearAllPoints()
		page.aboutHeading:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		y = y + (page.aboutHeading:GetStringHeight() or 14) + UI.INFO_HEADING_GAP
	end
	if page.intro then
		page.intro:ClearAllPoints()
		page.intro:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		page.intro:SetWidth(width)
		y = y + (page.intro:GetStringHeight() or 40) + UI.INFO_BLOCK_GAP
	end

	if page.featureSections then
		for index = 1, #page.featureSections do
			local section = page.featureSections[index]
			section:ClearAllPoints()
			section:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
			section:SetWidth(width)
			if section.body then
				section.body:SetWidth(width)
			end
			local bodyH = (section.body and section.body:GetStringHeight()) or 40
			local height = SECTION_ICON_SIZE + 6 + bodyH
			section:SetHeight(height)
			y = y + height + UI.INFO_SECTION_GAP
		end
	end

	if page.repoHeading then
		page.repoHeading:ClearAllPoints()
		page.repoHeading:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		y = y + (page.repoHeading:GetStringHeight() or 14) + UI.INFO_HEADING_GAP
	end
	if page.repoHint then
		page.repoHint:ClearAllPoints()
		page.repoHint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		page.repoHint:SetPoint("RIGHT", content, "RIGHT", 0, 0)
		y = y + (page.repoHint:GetStringHeight() or 12) + UI.INFO_HEADING_GAP
	end
	if page.repoHost and page.copyBtn then
		page.copyBtn:ClearAllPoints()
		page.copyBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
		page.repoHost:ClearAllPoints()
		page.repoHost:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		page.repoHost:SetPoint("RIGHT", page.copyBtn, "LEFT", -UI.ACTION_BTN_GAP, 0)
		y = y + UI.ACTION_BTN_H
	end

	content:SetHeight(math.max(y, 1))
end

local function RefreshInfoPage(page)
	if not page then
		return
	end
	if page.aboutHeading then
		page.aboutHeading:SetText(W.T("INFO_ABOUT"))
	end
	if page.intro then
		page.intro:SetText(W.T("INFO_INTRO"))
	end
	if page.featureSections then
		for index = 1, #page.featureSections do
			local section = page.featureSections[index]
			local pageInfo = section.pageInfo
			if pageInfo then
				if section.title then
					section.title:SetText(W.T(pageInfo.labelKey))
				end
				if section.version then
					section.version:SetText("v" .. tostring(PageLayoutVersion(pageInfo.key)))
				end
				if section.body and section.bodyKey then
					section.body:SetText(W.T(section.bodyKey))
				end
				if section.icon and pageInfo.icon then
					section.icon:SetTexture(pageInfo.icon)
					section.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				end
			end
		end
	end
	if page.repoHeading then
		page.repoHeading:SetText(W.T("INFO_GITHUB"))
	end
	if page.repoHint then
		page.repoHint:SetText(W.T("INFO_REPO_HINT"))
	end
	if page.copyBtn and page.copyBtn.label then
		page.copyBtn.label:SetText(W.T("BTN_SELECT_ALL"))
	end
	LayoutInfoContent(page)
end

local function CreateFeatureSection(parent, pageInfo, bodyKey)
	local section = CreateFrame("Frame", nil, parent)
	section.pageInfo = pageInfo
	section.bodyKey = bodyKey

	local icon = section:CreateTexture(nil, "ARTWORK")
	icon:SetSize(SECTION_ICON_SIZE, SECTION_ICON_SIZE)
	icon:SetPoint("TOPLEFT", 0, 0)
	if pageInfo.icon then
		icon:SetTexture(pageInfo.icon)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	section.icon = icon

	local title = W.CreateFontString(section, nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	title:SetPoint("TOP", icon, "TOP", 0, 1)
	title:SetJustifyH("LEFT")
	ApplyInfoHeadingFont(title)
	title:SetText(W.T(pageInfo.labelKey))
	W.SetFontColor(title, UI.GOLD)
	section.title = title

	local version = W.CreateFontString(section, nil, "OVERLAY", "GameFontNormalSmall")
	version:SetPoint("LEFT", title, "RIGHT", 6, 0)
	version:SetJustifyH("LEFT")
	version:SetText("v" .. tostring(PageLayoutVersion(pageInfo.key)))
	W.SetFontColor(version, UI.TEXT_DISABLED)
	section.version = version

	local body = W.CreateFontString(section, nil, "OVERLAY", "GameFontHighlight")
	body:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -6)
	body:SetJustifyH("LEFT")
	body:SetJustifyV("TOP")
	ApplyInfoBodyFont(body)
	body:SetText(W.T(bodyKey))
	section.body = body

	return section
end

local function CreateInfoPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints(parent)

	local scrollName = "RaidwiseInfoScrollV" .. tostring(LAYOUT_VERSION)
	local existingScroll = _G[scrollName]
	if existingScroll then
		existingScroll:Hide()
		existingScroll:SetParent(nil)
	end

	local scroll = CreateFrame("ScrollFrame", scrollName, page, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -24, 0)
	page.scroll = scroll

	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(W.ContentInnerWidth() - 28)
	scroll:SetScrollChild(content)
	page.content = content

	local aboutHeading = W.CreateFontString(content, nil, "OVERLAY", "GameFontNormal")
	aboutHeading:SetJustifyH("LEFT")
	ApplyInfoHeadingFont(aboutHeading)
	aboutHeading:SetText(W.T("INFO_ABOUT"))
	W.SetFontColor(aboutHeading, UI.GOLD)
	page.aboutHeading = aboutHeading

	local intro = W.CreateFontString(content, nil, "OVERLAY", "GameFontHighlight")
	intro:SetJustifyH("LEFT")
	intro:SetJustifyV("TOP")
	ApplyInfoBodyFont(intro)
	intro:SetText(W.T("INFO_INTRO"))
	page.intro = intro

	page.featureSections = {}
	local menuPages = FeatureMenuPages()
	for index = 1, #menuPages do
		local pageInfo = menuPages[index]
		local bodyKey = SECTION_BODY_KEYS[pageInfo.id]
		local section = CreateFeatureSection(content, pageInfo, bodyKey)
		page.featureSections[#page.featureSections + 1] = section
	end

	local repoHeading = W.CreateFontString(content, nil, "OVERLAY", "GameFontNormal")
	repoHeading:SetJustifyH("LEFT")
	ApplyInfoHeadingFont(repoHeading)
	repoHeading:SetText(W.T("INFO_GITHUB"))
	W.SetFontColor(repoHeading, UI.GOLD)
	page.repoHeading = repoHeading

	local repoHint = W.CreateFontString(content, nil, "OVERLAY", "GameFontHighlight")
	repoHint:SetJustifyH("LEFT")
	ApplyInfoBodyFont(repoHint)
	repoHint:SetText(W.T("INFO_REPO_HINT"))
	page.repoHint = repoHint

	local copyBtn = W.CreatePlainButton(content, 130, UI.ACTION_BTN_H, W.T("BTN_SELECT_ALL"))
	copyBtn:SetScript("OnClick", function()
		Addon:SelectRepoUrl()
	end)
	page.copyBtn = copyBtn

	local repoBox, repoHost = W.CreateLineCopyBox(content, "RaidwiseRepoBoxV" .. tostring(LAYOUT_VERSION))
	repoBox:SetText(GITHUB_URL)
	repoBox:SetScript("OnEditFocusLost", function(edit)
		edit:HighlightText(0, 0)
		if (edit:GetText() or "") == "" then
			edit:SetText(GITHUB_URL)
		end
	end)
	page.repoBox = repoBox
	page.repoHost = repoHost

	page.layoutVersion = LAYOUT_VERSION
	LayoutInfoContent(page)
	return page
end

function Addon:SelectRepoUrl()
	local frame = self.mainFrame
	if not frame or not frame.repoBox then
		return
	end
	self:SelectTab("info")
	local repoBox = frame.repoBox
	repoBox:SetText(GITHUB_URL)
	repoBox:SetFocus()
	repoBox:HighlightText()
	if frame.repoHint then
		frame.repoHint:SetText(W.T("INFO_REPO_SELECTED"))
	end
end

Addon.Pages.Info = {
	id = "info",
	LAYOUT_VERSION = LAYOUT_VERSION,
	Create = CreateInfoPage,
	Refresh = RefreshInfoPage,
	ApplyLocale = RefreshInfoPage,
}
