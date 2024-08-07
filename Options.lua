local _, Telecom = ...
local LSM = LibStub("LibSharedMedia-3.0")


local LSM_FontObjects = {}

for i, font in ipairs(LSM:List("font")) do
	LSM_FontObjects[font] = CreateFont("LibSharedMedia_Font_"..font)
	LSM_FontObjects[font]:SetFont(LSM:Fetch("font", font), 10, "")
end

local frame = Telecom:CreateOptionsFrame("Telecom")

LSM.RegisterCallback(frame, "LibSharedMedia_Registered", function(event, mediaType, key)
	if mediaType ~= "font" then return end
	LSM_FontObjects[key] = CreateFont("LibSharedMedia_Font_"..key)
	LSM_FontObjects[key]:SetFont(LSM:Fetch("font", key), 10, "")
end)

LSM:Register("sound", "TellMessage", [[Sound\Interface\iTellMessage.ogg]])

SlashCmdList["TELECOM"] = function(msg)
	frame:Open()
end
SLASH_TELECOM1 = "/telecom"

local optionsAppearance = frame:AddSubCategory("Appearance", true)
optionsAppearance:CreateOptions({
	{
		type = "Dropdown",
		text = "Font",
		tooltip = "Sets the font used by the chat log.",
		key = "font",
		func = function(self, font)
			Telecom.chatLog:SetFont(LSM:Fetch("font", font), Telecom.db.fontSize, "")
		end,
		menuList = function(self)
			return LSM:List("font")
		end,
		properties = {
			fontObject = LSM_FontObjects,
		},
	},
	{
		type = "Slider",
		text = "Font size",
		tooltip = "Sets the font size of the chat log.",
		key = "fontSize",
		func = function(self, value)
			Telecom.chatLog:SetFont(LSM:Fetch("font", Telecom.db.font), value, "")
		end,
		min = 8,
		max = 32,
		step = 1,
	},
	{
		type = "Dropdown",
		text = "Sound effect",
		tooltip = "Sets the sound effect played on incoming messages.",
		key = "sound",
		func = function(self, sound)
			-- hack not to play the sound when settings are loaded from a triggered event
			if not GetMouseButtonClicked() then return end
			PlaySoundFile(LSM:Fetch("sound", sound), "MASTER")
		end,
		menuList = function(self)
			return LSM:List("sound")
		end,
	},
	{
		type = "CheckButton",
		text = "Show Battle.net friends in thread list",
		tooltip = "If enabled, will include all Battle.net friends in the thread list that hasn't got an active thread.",
		key = "threadListBNetFriends",
		func = "UpdateThreads",
	},
	{
		type = "CheckButton",
		text = "Show WoW friends in thread list",
		tooltip = "If enabled, will include all WoW friends in the thread list that hasn't got an active thread.",
		key = "threadListWoWFriends",
		func = "UpdateThreads",
	},
	{
		type = "CheckButton",
		text = "Include offline friends in thread list",
		tooltip = "If enabled, will also include offline friends in the thread list.",
		key = "threadListShowOffline",
		func = "UpdateThreads",
	},
	{
		newColumn = true,
		type = "Slider",
		text = "Frame width",
		tooltip = "Sets the width of the main frame.",
		key = "width",
		func = function(self, value)
			TelecomFrame:SetWidth(value)
		end,
		min = 256,
		max = 1024,
		step = 1,
	},
	{
		type = "Slider",
		text = "Frame height",
		tooltip = "Sets the height of the main frame.",
		key = "height",
		func = function(self, value)
			TelecomFrame:SetHeight(value)
			Telecom:CreateScrollButtons()
			Telecom:UpdateThreadList()
		end,
		min = 160,
		max = 1024,
		step = 1,
	},
	{
		type = "Slider",
		text = "Thread list width",
		tooltip = "Sets the width of the thread list.",
		key = "threadListWidth",
		func = function(self, value)
			Telecom.threadListInset:SetWidth(value)
			Telecom.threadListInset:GetWidth()
			Telecom:CreateScrollButtons()
		end,
		min = 64,
		max = 256,
		step = 1,
	},
})

local optionsBehaviour = frame:AddSubCategory("Behaviour", true)
optionsBehaviour:CreateOptions({
	{
		type = "CheckButton",
		text = "Clear editbox focus on send",
		tooltip = "If enabled, will clear the editbox focus after sending a message.",
		key = "clearEditboxFocusOnSend",
	},
	{
		type = "CheckButton",
		text = "Clear editbox on focus lost",
		tooltip = "If enabled, will clear editbox text when editbox focus is lost.",
		key = "clearEditboxOnFocusLost",
	},
	{
		type = "CheckButton",
		text = "Editbox text per thread",
		tooltip = "If enabled, will keep editbox text individually per thread.",
		key = "editboxTextPerThread",
		func = function(self, value)
			if not value then
				for i, thread in ipairs(Telecom.db.threads) do
					thread.editboxText = nil
				end
			end
		end,
	},
	{
		type = "Dropdown",
		text = "Suppress chat frame during:",
		tooltip = "Select conditions for which to prevent addon from appearing when receiving a message.",
		set = function(self, arg, checked)
			Telecom.db.suppress[arg] = checked
		end,
		get = function(self, arg)
			return Telecom.db.suppress[arg]
		end,
		multiSelect = true,
		properties = {
			text = {
				combat = "During combat",
				encounter = "During boss encounters",
				pvp = "In PvP instances",
				dnd = "While flagged DND",
			},
			keepShownOnClick = true,
		},
		menuList = {
			"combat",
			"encounter",
			"pvp",
			"dnd",
		},
	},
	{
		type = "CheckButton",
		text = "Default handler while suppressed",
		tooltip = "If enabled, messages will be sent and received using the default chat frame during suppression.",
		key = "defaultHandlerWhileSuppressed",
	},
	{
		type = "CheckButton",
		text = "Close threads on logout",
		tooltip = "Close all open threads when you logout.",
		key = "closeThreadsOnLogout",
	},
})

frame:AddSubCategory("Archive", true):CreateOptions({
	{
		type = "CheckButton",
		text = "Auto delete Battle.net messages",
		tooltip = "If enabled, archived Battle.net messages will be automatically deleted.",
		-- key = "autoDeleteArchiveBNet",
		set = function(self, value)
			Telecom.db.autoCleanArchive.BN_WHISPER = value
		end,
		get = function(self)
			return Telecom.db.autoCleanArchive.BN_WHISPER
		end,
	},
	{
		type = "Dropdown",
		text = "Delete Battle.net messages after:",
		tooltip = "Specifies for how long Battle.net messages will remain archived.",
		set = function(self, time) Telecom.db.archiveKeep.BN_WHISPER = time end,
		get = function() return Telecom.db.archiveKeep.BN_WHISPER end,
		-- func = function(self, value) self:SetText((value == 0) and "Immediately" or SecondsToTime(value)) end,
		disabled = function() return not Telecom.db.autoCleanArchive.BN_WHISPER end,
		menuList = (function()
			local DAY = 24 * 3600
			local t = {}
			for i = 0, 7 do
				tinsert(t, i * DAY)
			end
			return t
		end)(),
		properties = {
			text = function(value)
				return (value == 0) and "Immediately" or SecondsToTime(value)
			end,
		},
	},
	{
		type = "CheckButton",
		text = "Auto delete WoW messages",
		tooltip = "If enabled, archived WoW messages will be automatically deleted.",
		-- key = "autoDeleteArchiveWoW",
		set = function(self, value)
			Telecom.db.autoCleanArchive.WHISPER = value
		end,
		get = function(self)
			return Telecom.db.autoCleanArchive.WHISPER
		end,
	},
	{
		type = "Dropdown",
		text = "Delete WoW messages after:",
		tooltip = "Specifies for how long WoW messages will remain archived.",
		set = function(self, time) Telecom.db.archiveKeep.WHISPER = time end,
		get = function() return Telecom.db.archiveKeep.WHISPER end,
		-- func = function(self, value) self:SetText((value == 0) and "Immediately" or SecondsToTime(value)) end,
		disabled = function() return not Telecom.db.autoCleanArchive.WHISPER end,
		menuList = (function()
			local DAY = 24 * 3600
			local t = {}
			for i = 0, 7 do
				tinsert(t, i * DAY)
			end
			return t
		end)(),
		properties = {
			text = function(value)
				return (value == 0) and "Immediately" or SecondsToTime(value)
			end,
		},
	},
})

frame:AddSubCategory("Formatting", true):CreateOptions({
	{
		type = "CheckButton",
		text = "Include timestamps",
		key = "timestamps",
		func = function(self)
			Telecom:RefreshThread(Telecom:GetSelectedThread())
		end,
	},
	{
		type = "Dropdown",
		text = "Timestamp format",
		-- tooltip = "Sets the font used by the chat log.",
		key = "timestampFormat",
		func = function(self)
			Telecom:RefreshThread(Telecom:GetSelectedThread())
		end,
		disabled = function() return not Telecom.db.timestamps end,
		menuList = {
			-- "",
			TIMESTAMP_FORMAT_HHMM,
			TIMESTAMP_FORMAT_HHMMSS,
			TIMESTAMP_FORMAT_HHMM_AMPM,
			TIMESTAMP_FORMAT_HHMMSS_AMPM,
			TIMESTAMP_FORMAT_HHMM_24HR,
			TIMESTAMP_FORMAT_HHMMSS_24HR,
		},
		properties = {
			text = function(value) return value == "" and "None" or date(value, time({year = 1970, month = 1, day = 1, hour = 15, min = 27, sec = 32})) end,
		},
	},
	{
		type = "CheckButton",
		text = "Indent",
		key = "indentWrap",
		func = function(self, value) Telecom.chatLog:SetIndentedWordWrap(value) end,
	},
	{
		type = "CheckButton",
		text = "Use class colors",
		tooltip = "Color incoming messages' sender by their class.",
		key = "classColors",
		func = function(self, value) Telecom:RefreshThread(Telecom:GetSelectedThread()) end,
	},
	{
		newColumn = true,
		type = "CheckButton",
		text = "Use separate color for outgoing whispers",
		-- tooltip = "If enabled, will use default color for Battle.net whispers.",
		-- key = "threadListBNetFriends",
		set = function(self, value) Telecom.db.separateOutgoingColor = value end,
		get = function(self) return Telecom.db.separateOutgoingColor end,
		func = function(self, value)
			local info = Telecom.db.useDefaultColor.BN_WHISPER and ChatTypeInfo["BN_WHISPER"] or Telecom.db.color.BN_WHISPER
			Telecom:UpdateChatColor("BN_WHISPER", info.r, info.g, info.b)
			local info = Telecom.db.useDefaultColor.WHISPER and ChatTypeInfo["WHISPER"] or Telecom.db.color.WHISPER
			Telecom:UpdateChatColor("WHISPER", info.r, info.g, info.b)
		end,
	},
	{
		type = "CheckButton",
		text = "Use default color for Battle.net whispers",
		tooltip = "If enabled, will use default color for Battle.net whispers.",
		-- key = "threadListBNetFriends",
		set = function(self, value) Telecom.db.useDefaultColor.BN_WHISPER = value end,
		get = function(self) return Telecom.db.useDefaultColor.BN_WHISPER end,
		func = function(self, value)
			local info = value and ChatTypeInfo["BN_WHISPER"] or Telecom.db.color.BN_WHISPER
			Telecom:UpdateChatColor("BN_WHISPER", info.r, info.g, info.b)
		end,
	},
	{
		type = "ColorButton",
		text = "Battle.net whisper color",
		tooltip = "Sets the color used for Battle.net whisper messages.",
		-- key = "threadListBNetFriends",
		set = function(self, value) Telecom.db.color.BN_WHISPER = value end,
		get = function(self) return Telecom.db.color.BN_WHISPER end,
		func = function(self, value)
			if not Telecom.db.useDefaultColor.BN_WHISPER then
				Telecom:UpdateChatColor("BN_WHISPER", value.r, value.g, value.b)
			end
		end,
		disabled = function() return Telecom.db.useDefaultColor.BN_WHISPER end,
	},
	{
		type = "ColorButton",
		text = "Battle.net outgoing whisper color",
		tooltip = "Sets the color used for outgoing Battle.net whisper messages.",
		-- key = "threadListBNetFriends",
		set = function(self, value) Telecom.db.color.BN_WHISPER_INFORM = value end,
		get = function(self) return Telecom.db.color.BN_WHISPER_INFORM end,
		func = function(self, value)
			if not Telecom.db.useDefaultColor.BN_WHISPER then
				Telecom:UpdateChatColor("BN_WHISPER", value.r, value.g, value.b)
			end
		end,
		disabled = function() return Telecom.db.useDefaultColor.BN_WHISPER or not Telecom.db.separateOutgoingColor end,
	},
	{
		type = "CheckButton",
		text = "Use default color for WoW whispers",
		tooltip = "If enabled, will use default color for WoW whispers.",
		-- key = "threadListBNetFriends",
		set = function(self, value) Telecom.db.useDefaultColor.WHISPER = value end,
		get = function(self) return Telecom.db.useDefaultColor.WHISPER end,
		func = function(self, value)
			local info = value and ChatTypeInfo["WHISPER"] or Telecom.db.color.WHISPER
			Telecom:UpdateChatColor("WHISPER", info.r, info.g, info.b)
		end,
	},
	{
		type = "ColorButton",
		text = "WoW whisper color",
		tooltip = "Sets the color used for WoW whisper messages.",
		-- key = "threadListBNetFriends",
		set = function(self, value) Telecom.db.color.WHISPER = value end,
		get = function(self) return Telecom.db.color.WHISPER end,
		func = function(self, value)
			if not Telecom.db.useDefaultColor.WHISPER then
				Telecom:UpdateChatColor("WHISPER", value.r, value.g, value.b)
			end
		end,
		disabled = function() return Telecom.db.useDefaultColor.WHISPER end,
	},
	{
		type = "ColorButton",
		text = "WoW outgoing whisper color",
		tooltip = "Sets the color used for outgoing WoW whisper messages.",
		-- key = "threadListBNetFriends",
		set = function(self, value) Telecom.db.color.WHISPER_INFORM = value end,
		get = function(self) return Telecom.db.color.WHISPER_INFORM end,
		func = function(self, value)
			if not Telecom.db.useDefaultColor.WHISPER then
				Telecom:UpdateChatColor("WHISPER", value.r, value.g, value.b)
			end
		end,
		disabled = function() return Telecom.db.useDefaultColor.WHISPER or not Telecom.db.separateOutgoingColor end,
	},
})

function Telecom:LoadSettings()
	frame:SetDatabase(self.db)
	frame:SetHandler(self)
	frame:SetupControls()
end
