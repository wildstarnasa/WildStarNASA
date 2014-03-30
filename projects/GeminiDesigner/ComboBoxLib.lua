local ComboBoxLib = {}
local ComboBox = {}

local XmlNode = Apollo.GetPackage("XmlNode-1.0").tPackage
ComboBoxLib.iCount = 0

function ComboBoxLib:New(wndContainer, tMenuList, tButtonSkin, tFont, bCombo)
	-- tButtonSkin { nWidth = 24, strSkinName = "CharacterWindowSprites:btn_TitleSelect" }
	-- tFont = { strFont = "CRB_Interface12", strColor = "ffffffff" }
	ComboBoxLib.iCount = ComboBoxLib.iCount + 1
	local tAnchorPoints = wndContainer:GetAnchorPoints()
	local tAnchorOffsets = {wndContainer:GetAnchorOffsets()}
	
	local xmlButton = XmlNode:New(
		"ComboButton"..ComboBoxLib.iCount,
		"Form",
		"Button",
		{
			AnchorPoints = {1,0,1,1},
			AnchorOffsets = {-(tButtonSkin.nWidth or 24),0,0,0},
			Base = tButtonSkin.strSkinName or "CharacterWindowSprites:btn_TitleSelect",
		},
	)
		
	local xmlEditBox = XmlNode:New(
		"ComboEditBox"..ComboBoxLib.iCount,
		"Form",
		"EditBox",
		{
			AnchorPoints = {0,0,1,1},
			AnchorOffsets = {5,0,-(tButtonSkin.nWidth or 24),0},
			Font = tFont.strFont or "CRB_Interface12",
			TextColor = tFont.strColor or "ffffffff",
			DT_VCENTER = true,
			ReadOnly = not(bCombo == true)
		},
	)
		
	local xmlList = XmlNode:New(
		"ComboList"..ComboBoxLib.iCount,
		"Form",
		"Grid",
		{
			AnchorPoints = {tAnchorPoints.LAnchorPoint,tAnchorPoints.TAnchorPoint,tAnchorPoints,tAnchorPoints.RAnchorPoint,0},
			AnchorOffsets = {tAnchorOffsets[1],tAnchorOffsets[4],tAnchorOffsets[3],tAnchorOffsets[4] + 48},
			Font = "CRB_InterfaceMedium_BO",
			CellBGNormalColor = "ffffffff",
			BGColor = "ffffffff",
			TextColor = "ff0000ff",
			Template="CRB_NormalFramedThin",
			Border = true,
			UseTemplateBG = true,
			MultiColumn = false,
			HeaderRow = false,
			SelectWholeRow = true,
			CellBGBase = "ActionSetBuilder_TEMP:spr_TEMP_ActionSetBottomTierBG",
			RowHeight = 28,
			{
				__XmlNode = "Column"
				Name = "",
				Width = "48",
				TextColor = "White",
				Image = "",
				MinWidth = wndContainer:GetWidth(),
				MaxWidth = wndContainer:GetWidth(),
				DT_VCENTER = "1",
			},
		},
	)
	
	local wndEditBox = xmlEditBox:LoadForm(wndContainer, self)
	local wndButton = xmlButton:LoadForm(wndContainer, self)
	local wndList = xmlList:LoadForm(wndContainer:GetParent(),self)
	
	wndButton
	
	return ComboBox:New(wndEditBox, wndButton, wndList, tMenuList, ComboBoxLib.iCount, o)
	
end

function ComboBoxLib:ButtonOnClick(wndHandler, wndControl, eMouseButton)
	
end
--[[
<Control Class="Grid"
	Font="CRB_InterfaceMedium_BO"
	Text=""
	Template="CRB_NormalFramedThin"
	TooltipType="OnCursor"
	Name="Grid"
	BGColor="ffffffff"
	TextColor="ff0000ff"
	TooltipColor=""
	CellBGNormalColor="ffffffff"
	CellBGSelectedColor="UI_TextHoloBody"
	CellBGNormalFocusColor="ff112233"
	CellBGSelectedFocusColor="ffffffff"
	TextNormalColor="ffffffff"
	TextSelectedColor="UI_TextHoloBodyHighlight"
	TextNormalFocusColor="ffffffff"
	TextSelectedFocusColor="ff31fcf6"
	TextDisabledColor="9d666666"
	Border="1"
	UseTemplateBG="1"
	MultiColumn="1"
	SelectWholeRow="1"
	HeaderRow="1"
	TextId=""
	HeaderBG="OldMetalSprites:OldMetalControlFrame"
	CellBGBase="ActionSetBuilder_TEMP:spr_TEMP_ActionSetBottomTierBG"
	HeaderFont="CRB_HeaderSmall"
	RowHeight="28"
	HeaderHeight="28"
	VScroll="1"
	Sprite=""
	DT_CENTER="1"
	DT_VCENTER="1"
	VariableHeight="1"
	VScrollLeftSide="0"
	TestAlpha="0"
	Overlapped="1"
	Tooltip=""
	TooltipId=""
	TooltipFont="CRB_InterfaceLarge_B"
	IgnoreTooltipDelay="0"
>
	<Column
		Name=""
		Width="48"
		TextColor="White"
		Image=""
		MinWidth="48"
		MaxWidth="48"
		MergeLeft="0"
		SimpleSort="1"
		DT_CENTER="0"
		DT_VCENTER="1"
	/>
	<Event Name="GridSelChange" Function="OnListItemSelected"/>
</Control>
]]

-- Functions for interacting with a ComboBox

function ComboBox:New(wndEditBox, wndButton, wndList, tlist, iComboCount ,o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
	
	self.wndEditBox = wndEditBox
	self.wndButton = wndButton
	self.wndList = wndList
	self.tList = tList
	self.ComboCount = iComboCount
	return o
end

function ComboBox:AddItem(tItemData)
	table.insert(self.tList,tItemData)
	-- return the slot it was inserted into
	return #self.tList
end

function ComboBox:RemoveItem(iIndex)
	table.remove(self.tList, iIndex)
end

function ComboBox:Select(iIndex)
	self.wndEditBox:SetData(
		{
			iIndex = iIndex,
			self.tList[iIndex],
		}
	)
	--self.wndList:SetSelected()
end

function ComboBox:RemoveAll()
	for i = 1, #self.tList do
		self.tList[i] = nil
	end
	self.wndList:DeleteAll()
end

function ComboBox:SetData(tData)
	self:RemoveAll()
	for i,v in pairs(tData) do
		self.tList[i] = v
	end
	for i, v in pairs(tData) do
		self.wndList:AddRow(v.strText or v.value, nil, v)
	end
end

local EnumReturnType = {
	TABLE = 0,
	INDEX = 1,
	VALUE = 2,
	TEXT = 3,
}

function ComboBox:GetSelected(enumReturnType)

	local tSelected = self.wndEditBox:GetData
	
	if EnumReturnType[enumReturnType] == 0 then
		return tSelected.tData
	elseif EnumReturnType[enumReturnType] == 1 then
		return tSelected.iIndex
	elseif EnumReturnType[enumReturnType] == 2 then
		return tSelected.tData.value
	elseif EnumReturnType[enumReturnType] == 3 then
		return tSelected.tData.strText
	else
		return tSelected.tData
	end
end

Apollo.RegisterPackage(ComboBoxLib, "ComboBoxLib-1.0", 1, {"XmlNode-1.0"})