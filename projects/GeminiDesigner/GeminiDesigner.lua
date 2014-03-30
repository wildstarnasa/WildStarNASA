-----------------------------------------------------------------
-- GeminiDesigner
-- An in-game Form creation tool
-- @author Togglebutton
-- @author draftomatic
-- Copyright 2014 NCSOFT
-----------------------------------------------------------------

local GeminiDesigner = {} 

local glog
local HUDControl
local XmlDocument

local ktControlProperties = {
	["EditBox"] = {
		"EditBox_StylesEX",
	},
	["Button"] = {
		"Button_StylesEX",
		"Button_General",
		"Button_Type",
		"Button_HotKey",
		"Button_Colors",
	},
	["Grid"] = {
		"Grid_StylesEX",
		"Grid_Cells",
		"Grid_TextColor",
		"Grid_CellColor",
		"Grid_Columns",
	},
	["TabWindow"] = {
		"TabWindow_Margins",
	},
	["ProgressBar"] = {
		"ProgressBar_StylesEX",
		"ProgressBar_Sprites",
		"ProgressBar_TextRect",
		"ProgressBar_RadialBarRange",
		"ProgressBar_Points",
	},
	["SliderBar"] = {
		"SliderBar_StylesEX",
		"SliderBar_Values",
		"SliderBar_Sprites",
	},
	["TreeControl"] = {
		"TreeControl_StylesEX",
		"TreeControl_Node",
		"TreeControl_Lines",
	},
}

local ktDefaultWindowAttributes = {
	AnchorPoints = {0,0,0,0},
	AnchorOffsets = {0,0,200,120}
}


--
-- OnLoad
--
function GeminiDesigner:OnLoad()
	
	-- Get packages
	local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
	glog = GeminiLogging:GetLogger({
		level = GeminiLogging.INFO,
		pattern = "%d %n %c %l - %m",
		appender = "GeminiConsole"
	})
	XmlDocument = Apollo.GetPackage("Drafto:Lib:XmlDocument-1.0").tPackage
	HUDControl = Apollo.GetAddon("HUDControl")
	
	-- State
	self.strCharName = GameLib.GetAccountRealmCharacter().strCharacter
	self.bEditing = false			-- Flag for whether we're editing (GeminiDesigner is modal)
	self.tCurFormDoc = nil			-- Entire <Forms> XML document that we're editing
	self.tCurFormNode = nil			-- <Form> XmlNode in tCurFormDoc that we're editing
	self.tSelectedNode = nil		-- Currently selected Window XmlNode
	self.wndVirtualForm = nil		-- The Window representing tCurFormNode
	
    -- Forms
	self.xmlDoc = XmlDoc.CreateFromFile("GeminiDesigner.xml")
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "GeminiDesignerForm", nil, self)
	self.wndMain:Show(false)
	
	-- Windows
	self.wndSelectOverlay = self.wndMain:FindChild("SelectOverlay")		-- Window used to overlay, or "select", the selected virtual Window.
	self.wndProperties = self.wndMain:FindChild("PropertiesWindow")		-- Floating Window properties dialog
	self.wndToolbar = self.wndMain:FindChild("ToolBarWindow")			-- Floating toolbar dialog
	
	-- Slash Commands
	Apollo.RegisterSlashCommand("gdesign", "OnGeminiDesignerOn", self)
	
	-- Initialize UI
	self.tTabButtons = {
		"WindowTab",
		"FlagsTab",
		"EventsTab",
	}
	
	-- Setup main 3 tabs
	self.tTabForms = {
		"WindowTabForm",
		"FlagsTabForm",
		"EventsTabForm",
	}
	
	self.wndWindowTab = Apollo.LoadForm(self.xmlDoc, "WindowTabForm", self.wndProperties, self)
	self.wndFlagsTab = Apollo.LoadForm(self.xmlDoc, "FlagsTabForm", self.wndProperties, self)
	self.wndEventsTab = Apollo.LoadForm(self.xmlDoc, "EventsTabForm", self.wndProperties, self)
	
	self:SetActiveTab(self.wndProperties:FindChild("WindowTab"))
end

function GeminiDesigner:OnDependencyError(strDep, strError)
	if strDep == "HUDControl" then
		Print("HUDControl not found. Can't hide Carbine interfaces!")
	end
	return true
end


--
-- API Calls
--

--- Enter edit mode.
-- @param tWindow The window to load into the editor. If nil, a new Window will be created.
-- @param streCallback Name of a callback function to fire when the editor is closed
-- @param tCallbackSelf The table that contains the callback function.
function GeminiDesigner:OpenForm(tFormDoc, strFormName, strCallback, tCallbackSelf)
	if self.bEditing then return end
	
	self.bEditing = true
	self.strCallback = strCallback
	self.tCallbackSelf = tCallbackSelf
	
	-- Make a new form if one wasn't given
	if not tFormDoc then
		strFormName = "Form1"
		tFormDoc = true and tFormDoc or self:NewFormDoc("NewForm", strFormName)
	end
	
	-- Initialize this Form
	self:SetCurrentFormDoc(tFormDoc, strFormName)
end

-- Returns a new Form Document table
function GeminiDesigner:NewFormDoc(strDocName, strFormName)
	local tFormDoc = {
		strName = strDocName,
		strId = self:NewRandomId(),
		strCreationDate = os.date(),
		strAuthor = self.strCharName,
		strType = "Form",
		tDoc = XmlDocument.NewForm()
	}
	
	-- Add a Form to the XmlDocument
	local tFormNode = tForm.tDoc:NewFormNode(strFormName)
	tFormDoc.tDoc:GetRoot():AddChild(tFormNode)
	
	return tFormDoc
end


--
-- Addon Logic
--

-- Loads a new Form into the editor. 
-- This is sort of the "driver" for reloading the entire editor with a new Form.
function GeminiDesigner:SetCurrentFormDoc(tFormDoc, strFormName)
	
	-- Save and finalize current Form, if we're editing one
	if self.tFormDoc ~= nil then
		self:SaveNodeProperties()
		self:FinalizeEdits()
	end
	
	-- Set new state
	self.tCurFormDoc = tFormDoc
	self.tCurFormNode = self.tCurFormDoc.tDoc:GetRoot():FindChildByName(strFormName)
	
	-- Load first child Window, or clear selected node
	local tChildren = self.tCurFormNode:GetChildren()
	if #tChildren > 0 then
		self:SetSelectedNode(tChildren[1])
	else
		self:ClearSelectedNode()
	end
end

-- Sets the selected (Window) node in tCurFormNode.
-- This is sort of the "driver" for reloading the entire editor with a new Form.
function GeminiDesigner:SetSelectedNode(tNode)
	
	-- Save and finalize current ndoe, if we're editing one
	if self.tSelectedNode ~= nil then
		self:SaveNodeProperties()
	end
	
	-- Set new state
	self.tSelectedNode = tNode
	self.tCurFormNode = self.tCurFormDoc.tDoc:GetRoot():FindChildByName(strFormName)
	
	-- Load Window Properties
	self:LoadNodeProperties()
end

-- Small driver to clear the current node without closing the Form,
-- i.e. "set to no selected node"
function GeminiDesigner:ClearSelectedNode()
	if not self.tSelectedNode then return end
	self.tSelectedNode = nil
	self:ClearNodeProperties()
	self.wndVirtualForm:Destroy()
end

-- Creates a new virtual Window for tCurFormNode
function GeminiDesigner:RebuildVirtualForm()
	-- TODO recursive function that creates a "fake" Window representing the selected node.
	-- 1 event handler on the top parent
end

-- "Selects" virtual Window tWnd by overlaying wndSelectOverlay.
-- tNode is the corresponding XmlNode in tCurFormNode.
function GeminiDesigner:AttachOverlayToVirtualWindow(tWnd)
	local tPos = tWnd:GetPos
	self.wndSelectOverlay:SetAnchorPoints(tWnd:GetAnchorPoints())
end

-- Shows or hides GeminiDesigner
function GeminiDesigner:Show(bShow)
	if HUDControl then
		HUDControl:SetAllAddonsVisible(not bShow)
	end
	self.wndMain:Show(bShow)
end

-- Fires callback for current Form
function GeminiDesigner:FinalizeEdits()
	if self.strCallback and self.tCallbackSelf then
		self.tCallbackSelf[self.strCallback](self.tCurFormNode)
	end
end

-- Saves the currently selected Window node, parsing inputs, etc.
function GeminiDesigner:SaveNodeProperties()
	if not self.tSelectedNode then return end
	
	-- Window Attributes
	for i,v in pairs(self.wndWindowTab:GetChildren()) do
		self.tSelectedNode:Attribute(self:ParseAttributeInput(v))
	end
		
	-- Styles Attributes
	for i,v in pairs(self.wndFlagsTab:FindChild("StylesFrame"):GetChildren()) do
		self.tSelectedNode:Attribute(self:ParseAttributeInput(v))
	end
	
	-- TextFlags Attributes
	for i,v in pairs(self.wndFlagsTab:FindChild("TextFlagsFrame"):GetChildren()) do
		self.tSelectedNode:Attribute(self:ParseAttributeInput(v))
	end
	
	-- Control-Specific Attributes
	local strControlType = self.tSelectedNode:Attribute("Class")
	if strControlType ~= "Grid" then		-- Temporary until GridToTable is refactored
		local tContainerNames = ktControlProperties[strControlType]
		for i,v in pairs(ktControlProperties[strControlType]) do
			for i2, v2 in pairs(self.wndControlTab:FindChild(v):GetChildren()) do
				self.tSelectedNode:Attribute(self:ParseAttributeInput(v))
			end
		end
	end
	
	-- Clear current children nodes (we're going to rebuild them)
	self.tSelectedNode:RemoveAllChildren()
	
	-- Events
	for k,v in pairs(self.tCurEvents) do
		local tEventNode = self.tCurFormDoc.tDoc:NewEventNode(k, v)
		self.tSelectedNode:AddChild(tEventNode)
	end
	
	-- Add any special control children (i.e. Grid)
	-- TODO for Togglebutton
	
	-- Pixies? Don't have UI for that yet =)
	
end

-- Parses a single input, returning the name and value
function GeminiDesigner:ParseAttributeInput(wndControl)
	local strName, value
	local strInputName = wndControl:GetName()
	if string.find(strName, "input_") then
		strName = strInputName:sub((strInputName:find("_")+1))	-- split on first "_", returning second half
		if LuaUtils:StartsWith(strName, "b") then
			value = wndControl:IsChecked()
		elseif LuaUtils:StartsWith(strName, "s") then
			if #wndControl:GetText() > 0 then
				value = wndControl:GetText()
			end
		elseif LuaUtils:StartsWith(strName, "n") then
			if #wndControl:GetText() > 0 then
				value = tonumber(wndControl:GetText())
			end
		end
		strName = strName:sub(3)  -- Removes first 2 characters; the type and the underscore
	end
	return strName, value
end

-- Sets the properies inputs for tSelectedNode. Opposite of SaveNodeProperties.
function GeminiDesigner:LoadNodeProperties()
	-- TODO for Togglebutton
end

-- Clears (and disables?) the node properties inputs.
function GeminiDesigner:ClearNodeProperties()
	-- TODO for Togglebutton
end

-- TODO Refactor this to work with an XmlNode
function GeminiDesigner:GridToTable(wndControl)
	local tGridContents = {}
	local nColumns = wndControl:GetColumnCount()
	local nRows = wndControl:GetRowCount()
	
	for iRow = 1, nRows do
		tGridContents[iRow] = {}
		for iCol = 1, nColumns do
			tGridContents[iRow][iCol] = wndControl:GetCellText(iRow, iCol)
		end
	end
	glog:info(tGridContents)
	return tGridContents
end

function GeminiDesigner:AddGridData(tData, wndGrid)
	local currRow = wndGrid:AddRow("")
	for i,v in pairs(tData) do
		wndGrid:SetCellText(currRow, i, v)
	end
end

-- Custom Tabs routine
function GeminiDesigner:SetActiveTab(wndHandler, wndControl, eMouseButton)
	-- "disable" all
	for i,v in pairs(self.tTabForms) do
		self.wndProperties:FindChild(v):Show(false)
	end
	
	for i,v in pairs(self.tTabButtons) do
		local wndTab = self.wndProperties:FindChild(v)
		wndTab:SetSprite("CRB_ChatLogSprites:sprChatTabUnselected")
		wndTab:SetTextColor("UI_BtnTextHoloNormal")
	end
	
	-- Set "active"
	wndHandler:SetSprite("CRB_ChatLogSprites:sprChatTabSelected")
	wndHandler:SetTextColor("UI_BtnTextHoloPressedFlyby")
	
	local wndActiveTab = self.wndProperties:FindChild(tostring(wndHandler:GetName()).."Form")
	wndActiveTab:Show(true)
	
end

-- Custom Tabs routine
function GeminiDesigner:ShowControlTab(strControlType)
	self.wndControlTab:DestroyChildren()
	local wndCurrFrame
	if ktControlProperties[strControlType] then
		for i,v in pairs(ktControlProperties[strControlType]) do
			wndCurrFrame = Apollo.LoadForm(self.xmlDoc, v, self.wndControlTab, self)
		end
		self.wndControlTab:ArrangeChildrenVert()
		self.wndControlTab:RecalculateContentExtents()
	end
	self.wndControlTab:SetVScrollPos(0)
end


--
-- Slash Commands
--

-- /gdesign
function GeminiDesigner:OnGeminiDesignerOn()
	self:Show(true)
end


--
-- Form Event Handlers
--

-- Virtual Window Callback
-- wndControl will be the top-level Window. Use wndHandler as the one that was clicked.
function GeminiDesigner:OnVirtualWindowClick(wndControl, wndHandler)
	if wndHandler == self.tSelectedNode then return end		-- TODO Consider focus change here?
	self:SaveNodeProperties()
	local tData = wndHandler:GetData()
	self:Set
	self.tSelectedNode = self.tCurFormNode.tDoc:GetRoot():FindChild(function(tNode)
		return tNode.strId == tData.strId
	end)
	self:AttachOverlayToVirtualWindow(wndHandler)
	-- TODO fill out inputs for this window
end

-- General/UI
function GeminiDesigner:OnCloseEditor()
	if self.bEditing then
		self:SaveNodeProperties()
		self:FinalizeEdits()
		self.bEditing = false
	end
	self:Show(false)
end

function GeminiDesigner:AddControl(wndHandler, wndControl)
	-- This is a hackey bit since Button:GetContentType() returns a 0 length string instead of the string from the XML
	local strControlType = string.sub(wndControl:GetName(),5)
	self:ShowControlTab(strControlType)
end

function GeminiDesigner:ShowAddColumn()
	local wndAddEventDialog = Apollo.LoadForm(self.xmlDoc, "AddColumnForm", self.wndMain, self)
end

function GeminiDesigner:AddColumn(wndHandler, wndControl)
	if wndControl:GetName() == "input_OK" then
		local wndEventsGrid = self.wndControlTab:FindChild("Grid_Columns"):FindChild("input_t_Columns")
		local tData = {
			wndControl:GetParent():FindChild("input_s_Text"):GetText(),
			tonumber(wndControl:GetParent():FindChild("input_n_Width"):GetText()),
			wndControl:GetParent():FindChild("input_s_Sprite"):GetText(),
			wndControl:GetParent():FindChild("input_s_TextColor"):GetText(),
			tostring(wndControl:GetParent():FindChild("input_b_DT_CENTER"):IsChecked()),
			--[[wndControl:GetParent():FindChild("input_b_DT_RIGHT"):IsChecked(),
			wndControl:GetParent():FindChild("input_b_DT_VCENTER"):IsChecked(),
			wndControl:GetParent():FindChild("input_b_DT_BOTTOM"):IsChecked(),
			wndControl:GetParent():FindChild("input_b_DT_WORDBREAK"):IsChecked(),
			wndControl:GetParent():FindChild("input_b_SINGLELINE"):IsChecked(),
			wndControl:GetParent():FindChild("input_b_SimpleSort"):IsChecked(),]]
		}
		self:AddGridData(tData,wndEventsGrid)
		glog:info(tData)
	end
	wndControl:GetParent():Show(false)
	wndControl:GetParent():Destroy()
end

function GeminiDesigner:ShowAddEvent()
	local wndAddEventDialog = Apollo.LoadForm(self.xmlDoc, "AddEventForm", self.wndMain, self)
end

function GeminiDesigner:AddEvent(wndHandler, wndControl)
	if wndControl:GetName() == "input_OK" then
		local wndEventsGrid = self.wndEventsTab:FindChild("input_t_EventList")
		local tData = {
			wndControl:GetParent():FindChild("input_EventName"):GetText(),
			wndControl:GetParent():FindChild("input_HandlerName"):GetText(),
		}
		self:AddGridData(tData,wndEventsGrid)
		glog:info(tData)
	end
	wndControl:GetParent():Show(false)
	wndControl:GetParent():Destroy()
end

function GeminiDesigner:DeleteEvent(wndHandler, wndControl)
	local wndEventsGrid = self.wndEventsTab:FindChild("input_t_EventList")
	wndEventsGrid:DeleteRow(wndEventsGrid:GetCurrentRow())
end


-------------------------------------------------------------------------------
-- Utility Methods
-------------------------------------------------------------------------------
function GeminiDesigner:NewRandomId()
	return tostring(math.random(1000000000)) .. tostring(math.random(1000000000))
end


--
-- Initialization
--
function GeminiDesigner:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    return o
end

Apollo.RegisterAddon(GeminiDesigner:new(), false, "", {
	"HUDControl",
	"Gemini:Logging-1.2",
	"Drafto:Lib:XmlDocument-1.0"
	-- *Don't* depend on GeminiEditor!
})