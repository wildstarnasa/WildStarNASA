-----------------------------------------------------------------------------------------------
-- Client Lua Script for GeminiConsole
-- Copyright (c) NCsoft. All rights reserved
-- Author:  draftomatic
-- Creates a Lua console window on /lua slash command
-- The console will attempt to parse and evaluate the input, and follows the conventions of
-- the standard lua command line utility, i.e.:
-- If a line starts with "=" the rest of the line is evaluated as an expression and the result is printed.
-- There are two types of errors that can happen: parse and execute.
-----------------------------------------------------------------------------------------------
local VERSION = "1.2.1"

local GeminiConsole = {}

local GeminiInterface = nil
local inspect
local LuaUtils
local Queue
local JScanBot

-- Constants
local kstrColorDefault = "FFFFFFFF"
local kstrColorError = "FFD12424"
local kstrColorInspect = "FF5AAFFA"

-- Initialization
function GeminiConsole:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	-- For keeping track of command history
	self.cmdHistory = {}
	self.cmdHistoryIndex = 1
	self.nonMarkupText = ""
	self.sLineBuffer = ""
	self.nTabHitCounter = 0
	self.tConfig = {
		bUseJSB = false,
		strJSBPath = "C:\\temp\\JScanBot-output.txt",
		bJSBAppend = true
	}
		
    return o
end
function GeminiConsole:Init()
    Apollo.RegisterAddon(self, false, "", {
		"Drafto:Lib:inspect-1.2", 
		"Drafto:Lib:LuaUtils-1.2", 
		"Drafto:Lib:Queue-1.2", 
		--"JScanBot"
	})
end

-- GeminiConsole OnLoad
function GeminiConsole:OnLoad()
	inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
	LuaUtils = Apollo.GetPackage("Drafto:Lib:LuaUtils-1.2").tPackage
	Queue = Apollo.GetPackage("Drafto:Lib:Queue-1.2").tPackage
	JScanBot = Apollo.GetAddon("JScanBot")

	-- Load Window
	self.xmlMain = XmlDoc.CreateFromFile("GeminiConsole.xml")
	self.wndMain = Apollo.LoadForm(self.xmlMain, "GeminiConsoleWindow", nil, self)

	-- Find Window components
	self.wndConsoleContainer = self.wndMain:FindChild("ConsoleContainer")
	self.wndConsole = self.wndMain:FindChild("Console")	-- Console window for evaluation output
	self.wndInput = self.wndMain:FindChild("Input")		-- Text input at the bottom
	self.wndClipboardWorkaround = self.wndMain:FindChild("ClipboardWorkaround")
	self.wndShowOnReloadInput = self.wndMain:FindChild("ShowOnReload")
	self.wndFPS = self.wndMain:FindChild("FPS")

	self.wndConfig = self.wndMain:FindChild("ConfigWrapper")
	self.wndConfig:Show(false)
	self.wndUseJSB = self.wndMain:FindChild("UseJSB")
	self.wndJSBPath = self.wndMain:FindChild("JSBPath")
	self.wndJSBAppend = self.wndMain:FindChild("JSBAppend")
	
	-- Register Event Handlers
	Apollo.RegisterSlashCommand("lua", "ConsoleShowToggle", self)
	Apollo.RegisterSlashCommand("console", "ConsoleShowToggle", self)
	Apollo.RegisterEventHandler("GeminiConsole_ButtonClick", "ConsoleShowToggle", self)
	--Apollo.RegisterSlashCommand("lua", "OnLuaSlashCommand", self)
	--Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)

	-- Line buffer
	self.lineQueue = Queue.new()
	Apollo.CreateTimer("LineQueueTimer", 0.001, true)
	Apollo.RegisterTimerHandler("LineQueueTimer", "OnLineQueueTimer", self)

	-- FPS update timer
	Apollo.CreateTimer("FPSTimer", 1.5, true)
	Apollo.RegisterTimerHandler("FPSTimer", "OnFPSTimer", self)
	
	-- Append initial help text
	self:AppendHelpText()

	-- Update config UI
	self:UpdateConfig(self.tConfig)

	--GeminiInterface = g
	--GeminiInterface.AddUserToggle("GeminiConsole_Button", "GeminiConsole", "CRB_Basekit:kitIcon_Holo_HazardProximity", "GeminiConsole_ButtonClick", false)

end

function GeminiConsole:OnDependencyError(strDep, strError)
	if strDep == "JScanBot" then
		--Print("JScanBot not found, error: " .. strError)
		return true
	else
		Print("GeminiConsole couldn't load " .. strDep .. ". Fatal error: " .. strError)
		return false
	end
end

-- toggle console display (triggered by SlashCommand "/lua" and the GeminiInterface button)
function GeminiConsole:ConsoleShowToggle()
	if self.wndMain:IsShown() then
		self.wndMain:Show(false)
	else
		self.wndMain:Show(true)
		self.wndInput:SetFocus()

		-- Reset badge count
		if GeminiInterface then
			self.nBadgeCount = 0
			GeminiInterface.SetUserToggleBadge("GeminiConsole_Button", self.nBadgeCount)
		end
	end
end

-- on SlashCommand "/lua"
--[[function GeminiConsole:OnLuaSlashCommand()
	self.wndMain:Show(true) -- show the window
	self.wndInput:SetFocus()	-- Focus on the text input to start
end--]]

-- Persistence
function GeminiConsole:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.General then return nil end
	return {
		--sConsoleText = self.nonMarkupText,			-- Hack to get console text out of WildStar.
		VERSION = VERSION,
		bVisible = self.wndMain:IsVisible(),
		tAnchorPoints = {self.wndMain:GetAnchorPoints()},
		tAnchorOffsets = {self.wndMain:GetAnchorOffsets()},
		tCmdHistory = self.cmdHistory,
		tConfig = self.tConfig
	}
end
function GeminiConsole:OnRestore(eLevel, tData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.General then return nil end
	if not tData or not tData.VERSION == VERSION then return end
	self.wndMain:Show(tData.bVisible)
	if tData.tAnchorPoints then
		self.wndMain:SetAnchorPoints(unpack(tData.tAnchorPoints))
	end
	if tData.tAnchorOffsets then
		self.wndMain:SetAnchorOffsets(unpack(tData.tAnchorOffsets))
	end
	if tData.tCmdHistory then
		self.cmdHistory = tData.tCmdHistory
		self.cmdHistoryIndex = #self.cmdHistory
	end
	if tData.tConfig then
		self:UpdateConfig(tData.tConfig)
	end
end

-- Appends text to the console with given color (or default color) and newline
function GeminiConsole:Append(text, color, bSupressNewline)
	local newText = tostring(text)

	local newLine = "\n"
	if bSupressNewline == true then newLine = "" end

	self.nonMarkupText = self.nonMarkupText .. newText .. newLine

	-- Prepare text for printing
	newText = LuaUtils:EscapeHTML(newText .. newLine)

	-- Clip text to account for bug that crashes the game if string is too big
	--local maxText = 30000
	--if #newText > maxText then
		--newText = string.sub(newText, #newText - maxText, #newText)
	--end

	-- Split multiline text so that we can wrap each line in markup separately
	if string.find(newText, "\n") then
		local tempText = ""
		for s in string.gmatch(newText, "[^\n]+") do
			if #s > 0 then
				if color then
					s = LuaUtils:markupTextColor(s, color)
				end
				tempText = tempText .. s .. "&#13;&#10;"
			end
		end
		newText = tempText
	else
		if color then
			newText = LuaUtils:markupTextColor(newText, color)
		end
	end

	-- Append line buffer
	self.sLineBuffer = self.sLineBuffer .. newText

	-- Append console if newline
	if not bSupressNewline then
		self:QueueLine(self.sLineBuffer)
		self.sLineBuffer = ""
	end

end

function GeminiConsole:OnLineQueueTimer()
	if Queue.Size(self.lineQueue) > 0 then
		self:AddLine(Queue.PopRight(self.lineQueue))
	end
end

function GeminiConsole:QueueLine(sLine)
	Queue.PushLeft(self.lineQueue, sLine)
end

function GeminiConsole:AddLine(sLine)
	local bLockScroll = self.wndConsole:GetVScrollPos() == self.wndConsole:GetVScrollRange()

	--Print(sLine)
	local lineItem = Apollo.LoadForm(self.xmlMain, "LineItem", self.wndConsole, self)
	local xml = XmlDoc.new()
	xml:AddLine(sLine, ApolloColor.new("white"), "Courier", "Left")
	lineItem:SetDoc(xml)
	lineItem:SetHeightToContentHeight()
	
	local nQueueSize = Queue.Size(self.lineQueue)
	if nQueueSize % 10 == 0 then
		self.wndConsole:ArrangeChildrenVert()
	end

	-- Set the scrollbar to the bottom
	if bLockScroll then
		self.wndConsole:SetVScrollPos(self.wndConsole:GetVScrollRange())
	end
end

--- Prints help text to console
function GeminiConsole:AppendHelpText()
	local color1 = "FF63EB7E"
	local color2 = "FF7FB5EB"
	local stars = "*******************************************"
	--self:Append(stars, color2)
	--self:Append("* ", color2, true)
	--self:Append("GeminiConsole v1.1", color1)
	--self:Append(stars, color2)
	self:Append("Start typing Lua code in the box below to begin.")
	self:Append("")
	self:Append("Special commands:")
	local specialCmdFormat1 = "%-16s"
	local specialCmdFormat2 = "%-30s"
	self:Append(string.format(specialCmdFormat1, "help"), color1, true)
	self:Append(string.format(specialCmdFormat2, "Shows this help text."), nil)
	self:Append(string.format(specialCmdFormat1, "= <expr>"), color1, true)
	self:Append(string.format(specialCmdFormat2, "Evaluates <expr> and prints the result."), nil)
	self:Append(string.format(specialCmdFormat1, "inspect <expr>"), color1, true)
	self:Append(string.format(specialCmdFormat2, "Evaluates <expr> and recursively prints the result."), nil)
	self:Append(string.format(specialCmdFormat1, "reload"), color1, true)
	self:Append(string.format(specialCmdFormat2, "Reloads all addons (Reload UI)"), nil)
	self:Append(string.format(specialCmdFormat1, "cls | clear"), color1, true)
	self:Append(string.format(specialCmdFormat2, "Clears the console text."), nil)
	self:Append(string.format(specialCmdFormat1, "quit | exit"), color1, true)
	self:Append(string.format(specialCmdFormat2, "Exits WildStar."), nil)
	--self:Append("")
	self:Append(stars, color2)
	self:Append("")
end

-- Not working
function GeminiConsole:OnKeyDown(wndHandler, wndControl, strKeyName, nCode, eModifier)
	self:Append("OnKeyDown fired")
end

-- Not working
function GeminiConsole:InputKeyDown(wndHandler, wndControl, strKeyName, nScanCode, nMetakeys)
	self:Append(strKeyName)
end

-- Working?
function GeminiConsole:InputChanged(wndHandler, wndControl, strText)
	if LuaUtils:EndsWith(strText, "\n") then
		if not Apollo.IsShiftKeyDown() then
			self:SubmitInput(wndHandler, wndControl, nil)
		end
	end
end

-- Return key; delegates to SubmitInput
function GeminiConsole:OnInputEnter(wndHandler, wndControl)
	self:SubmitInput(wndHandler, wndControl, nil)
end

-- Tab key; cycle through command history
function GeminiConsole:OnWindowKeyTab(wndHandler, wndControl)
	if #self.cmdHistory < 1 then return end -- aka no history
	local entry = #self.cmdHistory+self.nTabHitCounter
	if entry < 1 then -- don't index out of the table, lets start from the newest again
		self.nTabHitCounter = 0
		entry = #self.cmdHistory+self.nTabHitCounter
	end
	self.wndInput:SetText(self.cmdHistory[entry])
	self.nTabHitCounter = self.nTabHitCounter - 1 -- cycle "backwards" from newest to oldest
end

-- Event handler for submit clicks
function GeminiConsole:SubmitInput(wndHandler, wndControl, eMouseButton)
	local strInput = self.wndInput:GetText()
	self:Submit(strInput, true)
end

-- Evaluates the input and updates the console with the input+result
-- If bEcho is true, the input will be appended to the console as well as the result
function GeminiConsole:Submit(strText, bEcho)

	local sInput = LuaUtils:Trim(strText)	-- Trim whitespace
	self.wndInput:SetText("")

	-- Reset the tab hit counter
	self.nTabHitCounter = 0

	-- Empty input causes problems
	if sInput == "" then
		self.wndInput:SetFocus()
		return
	end

	-- Command will be executed, so add to history
	table.insert(self.cmdHistory, sInput)
	self.cmdHistoryIndex = #self.cmdHistory + 1		-- Reset history index

	-- Append command to console.
	if bEcho then
		self:Append("> " .. string.gsub(sInput, "\n", "\n> "))
	end

	-- Check for special commands

	-- Flag for beginning with "="
	local isEcho = false

	-- Help command
	if sInput == "help" then
		self:AppendHelpText()
		return

	-- Clear console special command
	elseif sInput == "clear" or sInput == "cls" then
		self.wndConsole:DestroyChildren()
		self.nonMarkupText = ""
		self.wndInput:SetFocus()
		--self.wndConsole:SetHeightToContentHeight()
		return

	-- Exit game special command
	elseif sInput == "quit" or sInput == "exit" then	
		ExitGame()		-- Starts 30sec countdown
		ExitNow()		-- Overrides 30sec countdown
		return

	-- "reload" special commadn to reload the UI
	elseif sInput == "reload" then
		RequestReloadUI()		-- Apollo call
		return

	-- "inspect" special command
	elseif LuaUtils:StartsWith(sInput, "inspect ") then
		sInput = string.gsub(sInput, "inspect ", "return ")		-- trick to evalutate expressions. lua.c does the same thing.

		--local inspectVar = _G[sInput]		-- Kind of a hack. Looks for global variables

		-- Parse
		local inspectLoadResult, inspectLoadError = loadstring(sInput)

		-- Execute
		if inspectLoadResult == nil or inspectLoadError then		-- Parse error
			self:Append("Error parsing expression:", kstrColorError)
			self:Append(string.gsub(sInput, "return ", ""), kstrColorError)
		else

			-- Run code in protected mode to catch runtime errors
			local status, inspectCallResult = pcall(inspectLoadResult)

			if status == false then					-- Execute error
				self:Append("Error evaluating expression:", kstrColorError)
				self:Append(inspectCallResult)
			else
				-- Use metatable for userdata
				if type(inspectCallResult) == "userdata" then
					inspectCallResult = getmetatable(inspectCallResult)
				end
				self:Append(inspect(inspectCallResult), kstrColorInspect)		-- Inspect and print
			end
		end


		self.wndInput:SetFocus()
		return

	-- Slash Commands
	elseif LuaUtils:StartsWith(sInput, "/") then
		ChatSystemLib.Command(sInput)		-- Pass to chat system
		self.wndInput:SetFocus()
		return

	-- Expression evaluation. Input starting with "=" will be evaluated and the result printed as a string.
	elseif LuaUtils:StartsWith(sInput, "=") then
		sInput = "return " .. string.sub(sInput, 2)			-- trick to evalutate expressions. lua.c does the same thing.
		isEcho = true
	end

	-- Parse
	local result, loadError = loadstring(sInput)

	-- Execute
	if result == nil or loadError then		-- Parse error
		self:Append("Error parsing statement:", kstrColorError)
		self:Append(loadError, kstrColorError)
	else

		-- Run code in protected mode to catch runtime errors
		local status, callResult = pcall(result)

		if status == false then			-- Execute error
			self:Append("Error executing statement:", kstrColorError)
			self:Append(callResult, kstrColorError)
		elseif isEcho then
			self:Append(callResult)		-- Print result if "="
		end
	end

	-- Refocus the input
	self.wndInput:SetFocus()
end

-- Sets the text input to history+1
function GeminiConsole:HistoryForward(wndHandler, wndControl, eMouseButton)
	if self.cmdHistoryIndex + 1 <= #self.cmdHistory then
		self.cmdHistoryIndex = self.cmdHistoryIndex + 1
		local newText = self.cmdHistory[self.cmdHistoryIndex]
		self.wndInput:SetText(newText)
	end
end

-- Sets the input text to history-1
function GeminiConsole:HistoryBackward(wndHandler, wndControl, eMouseButton)
	if self.cmdHistoryIndex - 1 > 0 then
		self.cmdHistoryIndex = self.cmdHistoryIndex - 1
		local newText = self.cmdHistory[self.cmdHistoryIndex]
		self.wndInput:SetText(newText)
	end
end

-- when the close button is clicked
function GeminiConsole:OnCancel()
	self.wndMain:Show(false) -- hide the window
end

-- when the reload button is clicked
function GeminiConsole:OnReloadUI()
	RequestReloadUI()
end

-- Not working
function GeminiConsole:ConsoleChanging( wndHandler, wndControl, strNewText, strOldText, bAllowed )
	self:Append("ConsoleChanging fired.")
	self.wndConsole:SetText(strOldText)
end

-- Saves the console text to the clipboard
-- Attempts to use JScanBot to save to a file if it's installed.
-- Otherwise uses a 2nd hidden EditBox since the main one uses class="MLWindow" which doesn't have the clipboard feature.
function GeminiConsole:SaveToClipboard(wndHandler, wndControl, eMouseButton)
	local tConfig = self.tConfig
	if JScanBot and tConfig.bUseJSB and tConfig.strJSBPath ~= "" then
		Print("Console saved to file: " .. tConfig.strJSBPath)
		JScanBot:OpenFile(tConfig.strJSBPath, tConfig.bJSBAppend)
		JScanBot:WriteToFile(tConfig.strJSBPath, self.nonMarkupText)
		JScanBot:CloseFile(tConfig.strJSBPath)
	else
		self.wndClipboardWorkaround:SetText(self.nonMarkupText)
		self.wndClipboardWorkaround:CopyTextToClipboard()
		self.wndClipboardWorkaround:SetText("")
		--self:Append("Console text copied to clipboard.", kstrColorInspect)
	end
end

function GeminiConsole:HistoryBackwardHidden( wndHandler, wndControl, eMouseButton )
	self:Append("HistoryBackwardHidden fired.")
end

function GeminiConsole:UseJSBCheck( wndHandler, wndControl, eMouseButton )
	self.tConfig.bUseJSB = true
end
function GeminiConsole:UseJSBUncheck( wndHandler, wndControl, eMouseButton )
	self.tConfig.bUseJSB = false
end

function GeminiConsole:JSBAppendCheck( wndHandler, wndControl, eMouseButton )
	self.tConfig.bJSBAppend = true
end
function GeminiConsole:JSBAppendUncheck( wndHandler, wndControl, eMouseButton )
	self.tConfig.bJSBAppend = false
end

function GeminiConsole:OnJSBPathChanged(wndHandler, wndControl, strText)
	self.tConfig.strJSBPath = strText
end

function GeminiConsole:UpdateConfig(tConfig)
	self.tConfig = tConfig

	if JScanBot then
		self.wndUseJSB:SetCheck(tConfig.bUseJSB)
		self.wndJSBAppend:SetCheck(tConfig.bJSBAppend)
		if tConfig.strJSBPath then
			self.wndJSBPath:SetText(tConfig.strJSBPath)
		end
	else
		self.wndUseJSB:Enable(false)
		self.wndJSBAppend:Enable(false)
		self.wndJSBPath:Enable(false)
	end
end

function GeminiConsole:OnShowConfig(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	self.wndConfig:Show(true)
	self.wndConfig:ToFront()
end

function GeminiConsole:OnHideConfig(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	self.wndConfig:Show(false)
end

function GeminiConsole:OnFPSTimer()
	self.wndFPS:SetText(GameLib.GetFrameRate())
end


-----------------------------------------------------------------------------------------------
-- GeminiConsole Instance
-----------------------------------------------------------------------------------------------
local GeminiConsoleInst = GeminiConsole:new()
GeminiConsoleInst:Init()


