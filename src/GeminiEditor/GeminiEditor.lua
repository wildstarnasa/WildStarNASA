local GeminiEditor = {} 

local VERSION = "1.0.2"

-------------------------------------------------------------------------------
-- Libraries
-------------------------------------------------------------------------------

local GeminiDesigner
local GeminiConsole
local glog
local JScanBot
local XmlNode
local XmlDocument
local LuaUtils

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local nDetailsTop = 34
local nDetailsBottom = 115
local clrSelected = "xkcdDustyBlue"
local clrNormal = "00ffffff"

-- Dependencies loaded
function GeminiEditor:OnLoad()
	GeminiDesigner = Apollo.GetAddon("GeminiDesigner")
	GeminiConsole = Apollo.GetAddon("GeminiConsole")
	JScanBot = Apollo.GetAddon("JScanBot")
	XmlDocument = Apollo.GetPackage("Drafto:Lib:XmlDocument-1.0").tPackage
	XmlNode = Apollo.GetPackage("Drafto:Lib:XmlNode-1.1").tPackage
	LuaUtils = Apollo.GetPackage("Drafto:Lib:LuaUtils-1.2").tPackage
	local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
	glog = GeminiLogging:GetLogger({
		level = GeminiLogging.INFO,
		pattern = "%d %n %c %l - %m",
		appender = "GeminiConsole"
	})
	
	-- State
	self.strCharName = GameLib.GetAccountRealmCharacter().strCharacter
	
	self.tScripts = {}
	self.tCurScript = nil
	self.bCurScriptChanged = false
	self.nNewScriptCounter = 1
	
	self.tAddons = {}
	self.tCurAddon = nil
	self.tCurAddonScript = nil
	self.bCurAddonChanged = false
	
	self.nSendTimeStart = 0
	self.tSendReceipts = {}
	self.tPendingReceives = {}
	
	-- Forms
	local xmlMain = XmlDoc.CreateFromFile("GeminiEditor.xml")
	self.wndMain = Apollo.LoadForm(xmlMain, "GeminiEditorMain", nil, self)
	self.wndMain:Show(false)
	self.xmlIncomingScript = XmlDoc.CreateFromFile("IncomingScript.xml")
	
	-- Tabs
	self.wndScriptTab = self.wndMain:FindChild("ScriptTab")
	self.wndAddonTab = self.wndMain:FindChild("AddonTab")
	self.wndScriptChooserContainer = self.wndMain:FindChild("ScriptChooserBG")
	self.wndAddonChooserContainer = self.wndMain:FindChild("AddonChooserBG")
	
	-- Script List
	self.wndScriptChooser = self.wndMain:FindChild("ScriptChooser")
	self.wndDelete = self.wndMain:FindChild("DeleteScript")
	self.wndDelete:Enable(false)
	
	-- Addon List
	self.wndAddonChooser = self.wndMain:FindChild("AddonChooser")
	self.wndNewPackage = self.wndMain:FindChild("NewAddonPackage")
	self.wndNewPackage:Enable(false)
	self.wndNewWindow = self.wndMain:FindChild("NewAddonWindow")
	self.wndNewWindow:Enable(false)
	
	-- Export
	self.wndExport = self.wndMain:FindChild("ExportWrapper")
	self.wndExport:Show(false)
	self.wndShowExport = self.wndMain:FindChild("ShowExport")
	self.wndSendToPlayers = self.wndMain:FindChild("SendToPlayers")
	self.wndSaveToFile = self.wndMain:FindChild("SaveToFile")
	self.wndPlayerList = self.wndMain:FindChild("PlayerList")
	self.wndExportPath = self.wndMain:FindChild("ExportPath")
	if not JScanBot then
		self.wndExportPath:Enable(false)
		self.wndSaveToFile:Enable(false)
	end
	
	-- Script Details
	self.wndScriptDetails = self.wndMain:FindChild("ScriptDetails")
	self.wndScriptName = self.wndMain:FindChild("ScriptName")
	self.wndScriptType = self.wndMain:FindChild("ScriptType")
	self.wndScriptCreationDate = self.wndMain:FindChild("ScriptCreationDate")
	self.wndScriptAuthor = self.wndMain:FindChild("ScriptAuthor")
	self.wndScriptImplicitLogger = self.wndMain:FindChild("ImplicitLogger")
	self.wndScriptImplicitXmlDocument = self.wndMain:FindChild("ImplicitXmlDocument")
	self.wndScriptImplicitJScanBot = self.wndMain:FindChild("ImplicitJScanBot")
	
	-- Run
	self.wndRun = self.wndMain:FindChild("RunScript")
	self.wndRun:Enable(false)
	
	-- Editor
	self.wndEditorContainer = self.wndMain:FindChild("EditorContainer")
	self.wndEditor = self.wndMain:FindChild("Editor")
	
	-- Send status
	self.wndSendStatus = self.wndMain:FindChild("ScriptSendStatus")
	self.wndSendStatusText = self.wndMain:FindChild("ScriptSendStatusText")
	
	-- Slash Command
	Apollo.RegisterSlashCommand("gedit", "OnSlashCommand", self)
	
	-- Join ICCommLib channels
	self.chanScript = ICCommLib.JoinChannel("GeminiEditor_Script", "OnICCScript", self)
	self.chanReceipt = ICCommLib.JoinChannel("GeminiEditor_Receipt", "OnICCReceipt", self)
	
	-- Temporary disables
	--self.wndMain:FindChild("SendToPlayers"):Enable(false)
	--self.wndMain:FindChild("SaveScriptToFile"):Enable(false)
	--self.wndPlayerList:Enable(false)
	--self.wndExportPath:Enable(false)
	
	-- Initalize script form
	self:ShowScriptDetails(false)
	self:ClearCurrentScript()
end

-- Dependency load error
function GeminiEditor:OnDependencyError(strDep, strError)
	if strDep == "JScanBot" or strDep == "GeminiDesigner" then
		return true
	else
		Print("GeminiEditor couldn't load " .. strDep .. ". Fatal error: " .. strError)
		return false
	end
end

-------------------------------------------------------------------------------
-- Persistence
-------------------------------------------------------------------------------
function GeminiEditor:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.General then return nil end
	if self.tCurScript and self.bCurScriptChanged then
		self:SaveCurrentScript()
	end
	return {
		VERSION = VERSION,
		bVisible = self.wndMain:IsVisible(),
		tAnchorPoints = {self.wndMain:GetAnchorPoints()},
		tAnchorOffsets = {self.wndMain:GetAnchorOffsets()},
		tScripts = self.tScripts,
		tAddons = self.tAddons,
		strExportPath = self.wndExportPath:GetText(),
		strPlayerList = self.wndPlayerList:GetText()
	}
end
function GeminiEditor:OnRestore(eLevel, tData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.General then return nil end
	if tData and tData.VERSION == VERSION then
		self.wndMain:Show(tData.bVisible)
		self.wndMain:SetAnchorPoints(unpack(tData.tAnchorPoints))
		self.wndMain:SetAnchorOffsets(unpack(tData.tAnchorOffsets))
		self.tScripts = tData.tScripts
		if tData.tAddons then
			self.tAddons = tData.tAddons
		end
		self.wndExportPath:SetText(tData.strExportPath)
		self.wndPlayerList:SetText(tData.strPlayerList)
		self:RebuildScriptChooser()
	end
end

-------------------------------------------------------------------------------
-- Addon Logic
-------------------------------------------------------------------------------

--
-- Scripts
--

-- Returns a new script table
function GeminiEditor:NewScript(strName, strText, bInAddon)
	if bInAddon == nil then bInAddon = false end
	local tScript = {
		bAddon = false,
		bInAddon = true and bInAddon or false,
		strName = strName,
		strId = self:NewRandomId(),
		strCreationDate = os.date(),
		strAuthor = self.strCharName,
		strType = "Script",
		bImplicitLogger = false,
		bImplicitXmlDocument = false,
		bImplicitJScanBot = false,
		strText = true and strText or "-- Write your code here!\n"
	}
	return tScript
end

-- Adds an arbitrary script to the stored left side
function GeminiEditor:AddScript(tScript)
	self.tScripts[tScript.strId] = tScript
end

-- Rebuilds the script chooser list (alphabetical order)
function GeminiEditor:RebuildScriptChooser()
	self.wndScriptChooser:DestroyChildren()
	
	-- Sort by name
	local tScriptsSorted = {}
	for k,v in pairs(self.tScripts) do
		table.insert(tScriptsSorted, v)
	end
	table.sort(tScriptsSorted, function(a,b)
		return a.strName < b.strName
	end)
	
	-- Add child windows
	for i,tScript in ipairs(tScriptsSorted) do
		local wnd = self:NewListItemWnd(tScript)
		wnd:SetData({
			bAddon = false,
			bInAddon = false,
			strId = tScript.strId
		})
		if self.tCurScript and tScript.strId == self.tCurScript.strId then
			wnd:SetBGColor(clrSelected)
		else
			wnd:SetBGColor(clrNormal)
		end
	end
	
	-- Stack children
	self.wndScriptChooser:ArrangeChildrenVert()
end

-- Creates a new line item for the one of the chooser lists
function GeminiEditor:NewListItemWnd(tItem, bIndent)
	local nLeft = bIndent and 8 or 0
	
	-- Script item
	local node = XmlNode:New("Item_" .. tItem.strId, "Form", "Window", {
		AnchorPoints = {0,0,1,0},
		AnchorOffsets = {0,0,-17,19},
		Sprite = "WhiteFill",
		Picture = true
	})
	
	-- Script name
	node:Append(XmlNode:New("ItemName_" .. tItem.strId, "Control", "Window", {
		AnchorPoints = {0,0,0.6,1},
		AnchorOffsets = {nLeft,0,-8,0},
		Font = "CRB_Interface10",
		Text = tItem.strName,
		SwallowMouseClicks = false
	}))
	
	-- Script author
	node:Append(XmlNode:New("ItemAuthor_" .. tItem.strId, "Control", "Window", {
		AnchorPoints = {0.6,0,1,1},
		AnchorOffsets = {0,0,0,0},
		Font = "CRB_Interface10",
		Text = tItem.strAuthor,
		SwallowMouseClicks = false
	}))
	

	-- Load window
	local wndParent
	if tItem.bAddon or tItem.bInAddon then
		wndParent = self.wndAddonChooser
	else
		wndParent = self.wndScriptChooser
	end
	local wnd = node:LoadForm(wndParent, self)
	
	-- Add click handler
	wnd:AddEventHandler("MouseButtonUp", "OnListItemClick", self)
	
	-- Show
	wnd:Show(true)
	
	return wnd
end

-- Utility for updating chooser script names easily
function GeminiEditor:UpdateChooserScriptName(strScriptId, strName)
	local wndScript = nil
	for i,v in ipairs(self.wndScriptChooser:GetChildren()) do
		if v:GetData().strId == strScriptId then
			v:FindChild("ItemName_" .. strScriptId):SetText(strName)
			return
		end
	end
end

-- Saves the right side to the stored left side
function GeminiEditor:SaveCurrentScript()
	local strName = self.wndScriptName:GetText()
	if strName == "" then return end
	self.tCurScript.strName = strName
	
	self.tCurScript.bImplicitLogger = self.wndScriptImplicitLogger:IsChecked()
	self.tCurScript.bImplicitXmlDocument = self.wndScriptImplicitXmlDocument:IsChecked()
	self.tCurScript.bImplicitJScanBot = self.wndScriptImplicitJScanBot:IsChecked()
	
	self.tCurScript.strText = self.wndEditor:GetText()
	
	self.tScripts[self.tCurScript.strId] = self.tCurScript
	
	self.bCurScriptChanged = false
end

-- Updates the right side for a script, and sets the current script
function GeminiEditor:SetCurrentScript(strScriptId)
	if self.tCurScript and self.bCurScriptChanged then
		self:SaveCurrentScript()
	end
	
	local tScript = self.tScripts[strScriptId]
	if not tScript then return end
	
	self.tCurScript = tScript
	
	-- Enable buttons
	self.wndDelete:Enable(true)
	self.wndRun:Enable(true)
	self.wndScriptName:Enable(true)
	self.wndExport:Enable(true)
	self.wndShowExport:Enable(true)
	
	-- Set details
	self.wndScriptName:SetText(tScript.strName)
	self.wndScriptType:SetText(tScript.strType)
	self.wndScriptCreationDate:SetText(tScript.strCreationDate)
	self.wndScriptAuthor:SetText(tScript.strAuthor)
	
	-- Enable implicit options
	self.wndScriptImplicitLogger:Enable(true)
	self.wndScriptImplicitXmlDocument:Enable(true)
	self.wndScriptImplicitJScanBot:Enable(true)
	
	-- Set implicit options
	self.wndScriptImplicitLogger:SetCheck(tScript.bImplicitLogger)
	self.wndScriptImplicitXmlDocument:SetCheck(tScript.bImplicitXmlDocument)
	self.wndScriptImplicitJScanBot:SetCheck(tScript.bImplicitJScanBot)
	
	-- Set editor text
	self.wndEditor:Enable(true)
	self.wndEditor:SetText(tScript.strText)
end

function GeminiEditor:ClearCurrentScript()
	self.tCurScript = nil
	self.bCurScriptChanged = false
	
	-- Disabled buttons
	self.wndDelete:Enable(false)
	self.wndRun:Enable(false)
	self.wndScriptName:Enable(false)
	self.wndExport:Enable(false)
	self.wndShowExport:Enable(false)
	
	-- Clear details
	self.wndScriptName:SetText("")
	self.wndScriptType:SetText("")
	self.wndScriptCreationDate:SetText("")
	self.wndScriptAuthor:SetText("")
	
	-- Disable implicit options
	self.wndScriptImplicitLogger:Enable(false)
	self.wndScriptImplicitXmlDocument:Enable(false)
	self.wndScriptImplicitJScanBot:Enable(false)
	
	-- Clear script text
	self.wndEditor:SetText("")
	self.wndEditor:Enable(false)
end

-- Shows/hides the script details on the right side
function GeminiEditor:ShowScriptDetails(bShow)
	local tOffsets = {self.wndEditorContainer:GetAnchorOffsets()}
	if bShow then
		tOffsets = {tOffsets[1], nDetailsBottom, tOffsets[3], tOffsets[4]}
	else
		tOffsets = {tOffsets[1], nDetailsTop, tOffsets[3], tOffsets[4]}
	end
	self.wndEditorContainer:SetAnchorOffsets(unpack(tOffsets))
	
	self.wndScriptDetails:Show(bShow)
end

-- Deletes a script
function GeminiEditor:DeleteScript(strScriptId)
	self.tScripts[strScriptId] = nil
end

-- Runs the current script
function GeminiEditor:RunCurrentScript()
	
	if self.bCurScriptChanged then
		self:SaveCurrentScript()
	end
	
	local strText = "do\n"
		
	if self.tCurScript.bImplicitLogger then
		strText = strText .. 
[[
local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
local glog = GeminiLogging:GetLogger({
  level = GeminiLogging.INFO,
  pattern = "%d ]] .. self.tCurScript.strName .. [[ - %m",
  appender = "GeminiConsole"
})
]]
	end
	
	if self.tCurScript.bImplicitXmlDocument then
		strText = strText .. 
[[
local XmlDocument = Apollo.GetPackage("Drafto:Lib:XmlDocument-1.0").tPackage
]]

	end
	
	if JScanBot and self.tCurScript.bImplicitJScanBot then
		strText = strText .. 
[[
local JScanBot = Apollo.GetAddon("JScanBot")
]]

	end
	strText = strText .. self.tCurScript.strText .. "\nend"
	
	-- Send chunk to GeminiConsole
	GeminiConsole:Submit(strText)
end


--
-- Addons
--

-- Creates a new addon table
function GeminiEditor:NewAddon(strName)
	local tAddon = {
		bAddon = true,
		strName = strName,
		strAuthor = self.strCharName,
		strId = self:NewRandomId(),
		strCreationDate = os.date(),
		strAuthor = self.strCharName,
		strType = "Addon",
		tBaseScript = self:NewBaseAddonScript(strName),
		tPackages = {},
		tWindows = {}
	}
	tAddon.strToc = self:CreateTocString(tAddon)
	-- TODO Add a Window?
	
	return tAddon
end

-- Adds an arbitrary addon to the stored left side
function GeminiEditor:AddAddon(tAddon)
	self.tAddons[tAddon.strId] = tAddon
end

local fnNameSort = function(a,b)
	return a.strName < b.strName
end

local function SortByName(tbl)
	local tblSorted = {}
	for k,v in pairs(tbl) do
		table.insert(tblSorted, v)
	end
	table.sort(tblSorted, fnNameSort)
	return tblSorted
end

-- Rebuilds the addon chooser list (alphabetical order)
function GeminiEditor:RebuildAddonChooser()
	self.wndAddonChooser:DestroyChildren()
	
	-- Sort by name
	local tAddonsSorted = SortByName(self.tAddons)
	
	-- Add child windows
	for i,tAddon in ipairs(tAddonsSorted) do
		local wnd = self:NewListItemWnd(tAddon)
		wnd:SetData({
			bAddon = true,
			bInAddon = false,
			strType = "Addon",
			strId = tAddon.strId
		})
		if self.tCurAddon and tAddon.strId == self.tCurAddon.strId then
			if self.tCurAddonScript == nil then
				wnd:SetBGColor(clrSelected)
			else
				wnd:SetBGColor(clrNormal)
			end
			
			-- Add base script
			local wndBase = self:NewListItemWnd(tAddon.tBaseScript, true)
			wndBase:SetData({
				bAddon = false,
				bInAddon = true,
				strType = "Script",
				strId = tAddon.tBaseScript.strId,
				strAddonId = tAddon.strId
			})
			if self.tCurAddonScript and self.tCurAddonScript.strId == tAddon.tBaseScript.strId then
				wndBase:SetBGColor(clrSelected)
			else
				wndBase:SetBGColor(clrNormal)
			end
				
			-- Add packages
			local tPackagesSorted = SortByName(tAddon.tPackages)
			for j,tPackage in ipairs(tPackagesSorted) do
				local wnd = self:NewListItemWnd(tPackage, true)
				wnd:SetData({
					bAddon = false,
					bInAddon = true,
					strType = "Script",
					strId = tPackage.strId,
					strAddonId = tAddon.strId
				})
				if self.tCurAddonScript and self.tCurAddonScript.strId == tPackage.strId then
					wnd:SetBGColor(clrSelected)
				else
					wnd:SetBGColor(clrNormal)
				end
			end
			
			-- Add windows
			local tWindowsSorted = SortByName(tAddon.tWindows)
			for j,tWindow in ipairs(tWindowsSorted) do
				local wnd = self:NewListItemWnd(tWindow, true)
				wnd:SetData({
					bAddon = false,
					bInAddon = true,
					strType = "Window",
					strId = tWindow.strId,
					strAddonId = tAddon.strId
				})
				if self.tCurAddonWindow and self.tCurAddonWindow.strId == tWindow.strId then
					wnd:SetBGColor(clrSelected)
				else
					wnd:SetBGColor(clrNormal)
				end
			end
		else
			wnd:SetBGColor(clrNormal)
		end
	end
	
	-- Stack children
	self.wndAddonChooser:ArrangeChildrenVert()
end

-- Updates the right side for an addon script, and sets the current addon script
function GeminiEditor:SetCurrentAddonScript(strAddonId, strScriptId)
	if self.tCurAddonScript and self.bCurAddonScriptChanged then
		self:SaveCurrentAddonScript()
	end
	
	local tAddon = self.tAddons[strAddonId]
	if not tAddon then return end
	local tScript
	if tAddon.tBaseScript.strId == strScriptId then
		tScript = tAddon.tBaseScript
	else
		tScript = tAddon.tPackages[strScriptId]
	end
	if not tScript then return end
	
	self.tCurAddon = tAddon
	self.tCurAddonScript = tScript
	
	-- Enable buttons
	self.wndRun:Enable(false)
	self.wndScriptName:Enable(true)
	self.wndExport:Enable(true)
	self.wndShowExport:Enable(true)
	
	-- Set details
	self.wndScriptName:SetText(tScript.strName)
	self.wndScriptType:SetText(tScript.strType)
	self.wndScriptCreationDate:SetText(tScript.strCreationDate)
	self.wndScriptAuthor:SetText(tScript.strAuthor)
	
	-- Disable implicit options
	self.wndScriptImplicitLogger:Enable(false)
	self.wndScriptImplicitXmlDocument:Enable(false)
	self.wndScriptImplicitJScanBot:Enable(false)
	
	-- Set editor text
	self.wndEditor:Enable(true)
	self.wndEditor:SetText(tScript.strText)
end

function GeminiEditor:NewBaseAddonScript(strName)
	local strText = 
[[local %n = {}

function %n:OnLoad()
  -- Write your code here!
end

function %n:OnDependencyError(strDep, strError)
  return true
end

function %n:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self 
  return o
end

Apollo.RegisterAddon(%n:new(), false, "", {})]]
	strText = strText:gsub("%%n", strName)
	
	return self:NewScript(strName, strText, true)
end

function GeminiEditor:NewAddonPackage(strName)
	local strText = 
[[local %n = {}

function %n:OnLoad()
  -- Write your code here!
end

function %n:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self 
  return o
end

Apollo.RegisterPackage(%n:new(), "%n", 1, {})]]
	strText = strText:gsub("%%n", strName)
	
	return self:NewScript(strName, strText, true)
end

-- Creates the toc.xml string for the given addon
function GeminiEditor:CreateTocString(tAddon)
	local strToc = 
[[<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<Addon Author="]] .. self.strCharName .. 
[[" APIVersion="]] .. Apollo.GetAPIVersion() .. 
[[" Name="]] .. tAddon.strName .. 
[[" Description="">
]]

	for strId,tScript in pairs(tAddon.tPackages) do
		strToc = strToc .. "  <Script Name=\"" .. tScript.strName .. ".lua\"/>\n"
	end
	
	for strId,tWindow in pairs(tAddon.tWindows) do
		strToc = strToc .. "  <Form Name=\"" .. tWindow.strName .. ".xml\"/>\n"
	end
	
	strToc = strToc .. "\n</Addon>"
	
	return strToc
end


--
-- Export
--

function GeminiEditor:SaveScriptToFile()
	local strExportPath = self.wndExportPath:GetText()
	if strExportPath == "" then return end
	
	if self.bCurScriptChanged then
		self:SaveCurrentScript()
	end
	
	JScanBot:OpenFile(strExportPath)
	JScanBot:WriteToFile(strExportPath, self.tCurScript.strText)
	JScanBot:CloseFile(strExportPath)
end

local SEND_TIMEOUT = 30

function GeminiEditor:SendToPlayers()
	local strPlayerList = self.wndPlayerList:GetText()
	if strPlayerList == "" then return end
	
	self.wndSendToPlayers:Enable(false)
	
	if self.bCurScriptChanged then
		self:SaveCurrentScript()
	end
	
	string.gsub(strPlayerList, "%s+", "")
	
	local tRecipients = {}
	for p in string.gmatch(strPlayerList, "[^,%s]+") do
		tRecipients[p] = true
	end
	
	self.tCurScript.strText = self:EscapeScript(self.tCurScript.strText)
	
	glog:info(self.tCurScript)
	self.tPendingSend = {
		strSender = self.strCharName,
		tRecipients = tRecipients,
		tScript = self.tCurScript
	}
	self.chanScript:SendMessage(self.tPendingSend)
	--self:OnICCScript(nil, self.tPendingSend)
	
	self.tCurScript.strText = self:UnescapeScript(self.tCurScript.strText)
	
	self.tSendReceipts = {}
	self.wndSendStatusText:SetText("Sending script \"" .. self.tCurScript.strName .. "\" " .. "(" .. SEND_TIMEOUT .. ")")
	self.wndSendStatus:Show(true)
	self.wndSendStatus:ToFront()
	self:BeginSendTimeout()
end

function GeminiEditor:SaveToClipboard()
	if self.bCurScriptChanged then
		self:SaveCurrentScript()
	end
	
	self.wndEditor:CopyTextToClipboard()
end

function GeminiEditor:BeginSendTimeout()
	Apollo.CreateTimer("Gemini:Editor:SendTimeoutTimer", 1, true)
	Apollo.RegisterTimerHandler("Gemini:Editor:SendTimeoutTimer", "OnSendTimeoutTimer", self)
	self.nSendTimeStart = os.time()
end

function GeminiEditor:OnSendTimeoutTimer()
	local nTimeDiff = os.time() - self.nSendTimeStart
	if LuaUtils:GetTableSize(self.tPendingSend.tRecipients) == LuaUtils:GetTableSize(self.tSendReceipts) or nTimeDiff >= SEND_TIMEOUT then
		local strText = "Finished!\nReceived by: "
		if LuaUtils:GetTableSize(self.tSendReceipts) > 0 then
			for k,v in pairs(self.tSendReceipts) do 
				strText = strText .. v.strRecipient .. ", "
			end
		else
			strText = strText .. "Nobody!"
		end
		glog:info("new status text: " .. strText)
		self.wndSendStatusText:SetText(strText)
		Apollo.CreateTimer("Gemini:Editor:SendTimeoutTimer", 1, false)		-- WTF? Need to call this, then stop the timer in a separate function?!
		self:StopSendTimeoutTimer()
		self:BeginHideSendStatusTimeout()
		self.tSendReceipts = {}
		self.wndSendToPlayers:Enable(true)
	else
		self.wndSendStatusText:SetText("Sending script \"" .. self.tPendingSend.tScript.strName .. "\" " .. "(" .. SEND_TIMEOUT - nTimeDiff .. ")")
	end
end
	
function GeminiEditor:BeginHideSendStatusTimeout()
	Apollo.CreateTimer("Gemini:Editor:HideSendStatusTimer", 4, false)
	Apollo.RegisterTimerHandler("Gemini:Editor:HideSendStatusTimer", "OnHideSendStatusTimer", self)
end

function GeminiEditor:OnHideSendStatusTimer()
	self.wndSendStatus:Show(false)
end

function GeminiEditor:StopSendTimeoutTimer()
	Print("Stopping timer")
	Apollo.StopTimer("Gemini:Editor:SendTimeoutTimer")
end


-------------------------------------------------------------------------------
-- Form Event Handlers
-------------------------------------------------------------------------------

--
-- Tabs and Choosers
--
function GeminiEditor:OnScriptTypeClick(wndHandler, wndControl, eMouseButton)
	if wndHandler == self.wndScriptTab then
		if self.wndScriptChooserContainer:IsVisible() then return end
		self.wndScriptTab:SetBGColor("00ffffff")
		self.wndAddonTab:SetBGColor("ffffffff")
		self.wndScriptChooserContainer:Show(true)
		self.wndAddonChooserContainer:Show(false)
		self:RebuildScriptChooser()
	else
		if self.wndAddonChooserContainer:IsVisible() then return end
		self.wndScriptTab:SetBGColor("ffffffff")
		self.wndAddonTab:SetBGColor("00ffffff")
		self.wndScriptChooserContainer:Show(false)
		self.wndAddonChooserContainer:Show(true)
		self:RebuildAddonChooser()
	end
end

function GeminiEditor:OnListItemClick(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	local tData = wndHandler:GetData()
	if tData.bAddon then
		self.tCurAddon = self.tAddons[tData.strId]
		self.tCurAddonScript = nil
		self:ClearCurrentScript()
		self:RebuildAddonChooser()
		self.wndNewPackage:Enable(true)
		self.wndNewWindow:Enable(true)
	elseif tData.bInAddon then
		if tData.strType == "Script" then
			self:SetCurrentAddonScript(tData.strAddonId, tData.strId)
			self:RebuildAddonChooser()
		elseif tData.strType == "Window" then
			--[[if GeminiDesigner then
				self.wndMain:Show(false)
				GeminiDesigner:EditWindow(nil, "OnDesignerClosed", self)
			else
				Print("GeminiDesigner not found.")
			end--]]
		end
	else
		self:SetCurrentScript(tData.strId)
		self:RebuildScriptChooser()
		self.wndNewPackage:Enable(true)
		self.wndNewWindow:Enable(true)
	end
end

--
-- Scripts
--
function GeminiEditor:OnNewScript(wndHandler, wndControl, eMouseButton)
	local tScript = self:NewScript("New Script " .. self.nNewScriptCounter, false)
	self.nNewScriptCounter = self.nNewScriptCounter + 1
	self:AddScript(tScript)
	self:SetCurrentScript(tScript.strId)
	self:RebuildScriptChooser()
end

function GeminiEditor:OnDeleteScript(wndHandler, wndControl, eMouseButton)
	self:DeleteScript(self.tCurScript.strId)
	self:ClearCurrentScript()
	self:RebuildScriptChooser()
end

function GeminiEditor:OnCurScriptChanged(wndHandler, wndControl, arg3)
	if self.tCurScript then
		self.bCurScriptChanged = true
		if wndHandler == self.wndScriptName then
			self.tScripts[self.tCurScript.strId].strName = arg3
			self:UpdateChooserScriptName(self.tCurScript.strId, arg3)	-- arg3 is the new EditBox text here
		end
	end
end

function GeminiEditor:OnRunScript(wndHandler, wndControl)
	self:RunCurrentScript()
end

--
-- Addons
--

function GeminiEditor:OnNewAddon(wndHandler, wndControl, eMouseButton)
	glog:info("OnNewAddon")
	local tAddon = self:NewAddon("NewAddon")
	self:AddAddon(tAddon)
	self:SetCurrentAddonScript(tAddon.tBaseScript.strId)
	self:RebuildAddonChooser()
end

function GeminiEditor:OnNewAddonPackage(wndHandler, wndControl)
	local tPackage = self:NewAddonPackage("NewPackage")
	self.tCurAddon.tPackages[tPackage.strId] = tPackage
	self:SetCurrentAddonScript(tPackage)
	self:RebuildAddonChooser()
end

function GeminiEditor:OnNewAddonWindow(wndHandler, wndControl)
	-- TODO Make new window item; open GeminiDesigner??
end

function GeminiEditor:OnDesignerClosed(tWindow)
	glog:info("Designer Closed")
	glog:info(tWindow)
	-- Save new window
	self.wndMain:Show(true)
end

--
-- Export
--
function GeminiEditor:OnShowExport(wndHandler, wndControl, eMouseButton)
	self.wndExport:Show(true)
end

function GeminiEditor:OnCloseExport(wndHandler, wndControl)
	self.wndExport:Show(false)
end

function GeminiEditor:OnSaveToClipboard()
	if self.tCurScript then
		self:SaveToClipboard()
	end
end

function GeminiEditor:OnSendToPlayers()
	if self.tCurScript then
		self:SendToPlayers()
	end
end

function GeminiEditor:OnSaveToFile()
	if self.tCurScript then
		self:SaveScriptToFile()
	end
end

--
-- Misc
--
function GeminiEditor:OnScriptDetailsToggle(wndHandler, wndControl, eMouseButton)
	self:ShowScriptDetails(wndHandler:IsChecked())
end

function GeminiEditor:OnClose(wndHandler, wndControl)
	self.wndMain:Show(false)
end

function GeminiEditor:OnSlashCommand(strCommand, strParam)
	self.wndMain:Show(true)
end

function GeminiEditor:OnReloadUI()
	RequestReloadUI()
end

--
-- Incoming Script Dialog
--
function GeminiEditor:OnAcceptScript(wndHandler, wndControl)
	local strScriptId = wndHandler:GetData()
	local tScript = self.tPendingReceives[strScriptId]
	self.tPendingReceives[strScriptId] = nil
	
	if self.bCurScriptChanged then
		self:SaveCurrentScript()
	end
	
	self:AddScript(tScript)
	self:SetCurrentScript(tScript.strId)
	self:RebuildScriptChooser()
	
	local tResponse = {
		strRecipient = self.strCharName,
		strScriptId = tScript.strId,
		bAccepted = true
	}
	
	glog:info("Sending response: ")
	glog:info(tResponse)
	self.chanReceipt:SendMessage(tResponse)
	
	wndHandler:GetParent():Destroy()
end

function GeminiEditor:OnDeclineScript(wndHandler, wndControl)
	local strScriptId = wndHandler:GetData()
	self.tPendingReceives[strScriptId] = nil
	
	local tResponse = {
		strRecipient = self.strCharName,
		strScriptId = tScript.strId,
		bAccepted = false
	}
	
	glog:info("Sending response: ")
	glog:info(tResponse)
	self.chanReceipt:SendMessage(tResponse)
	
	wndHandler:GetParent():Destroy()
end

-------------------------------------------------------------------------------
-- ICCommLib Event Handlers
-------------------------------------------------------------------------------

--
-- Incoming Script
--
function GeminiEditor:OnICCScript(arg1, tData)
	glog:info(tData)
	glog:info(arg1)
	local tScript = tData.tScript
	if tData and tData.tRecipients[self.strCharName] and not self.tScripts[tScript.strId] then
		tScript.strText = self:UnescapeScript(tScript.strText)
		self.tPendingReceives[tScript.strId] = tScript
		local wnd = Apollo.LoadForm(self.xmlIncomingScript, "IncomingScriptForm", self.wndMain, self)
		wnd:FindChild("ReceiveScriptText"):SetText(tData.strSender .. " is sending you a script named \"" .. tScript.strName .. "\".")
		wnd:FindChild("AcceptScript"):SetData(tScript.strId)
		wnd:FindChild("DeclineScript"):SetData(tScript.strId)
		self.wndMain:Show(true)
		wnd:Show(true)
		wnd:ToFront()
	end
end

--
-- Outgoing Script Receipt
--
function GeminiEditor:OnICCReceipt(arg1, tData)
	if tData then
		glog:info("Script received:")
		glog:info(tData)
		self.tSendReceipts[tData.strRecipient] = tData
	end
end


-------------------------------------------------------------------------------
-- Utility Methods
-------------------------------------------------------------------------------
function GeminiEditor:NewRandomId()
	return tostring(math.random(1000000000)) .. tostring(math.random(1000000000))
end

function GeminiEditor:EscapeScript(strText)
	strText = strText:gsub("\r\n", "__rn__")
	strText = strText:gsub("\n", "__n__")
	strText = strText:gsub("\t", "__t__")
	return strText
end

function GeminiEditor:UnescapeScript(strText)
	strText = strText:gsub("__rn__", "\r\n")
	strText = strText:gsub("__n__", "\n")
	strText = strText:gsub("__t__", "\t")
	return strText
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function GeminiEditor:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    return o
end
Apollo.RegisterAddon(GeminiEditor:new(), false, "", {
	"GeminiDesigner",
	"GeminiConsole", 
	"JScanBot", 
	"Gemini:Logging-1.2", 
	"Drafto:Lib:LuaUtils-1.2", 
	"Drafto:Lib:XmlNode-1.1", 
	"Drafto:Lib:XmlDocument-1.0"
})
