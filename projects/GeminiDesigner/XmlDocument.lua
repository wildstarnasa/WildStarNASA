local XmlDocument = {}
local XmlNode = {}

---------------------------------------------------------------------------
-- XmlDocument
---------------------------------------------------------------------------

function XmlDocument.New()
	local self = {}
    
	local tRoot = nil
	
	function self:GetRoot()
		return tRoot
	end

	function self:SetRoot(tNewRoot)
		tRoot = tNewRoot
	end

	function self:NewNode(strTag, tAttributes)
		return XmlNode.New(self, strTag, tAttributes)
	end
	
	function self:ToXmlDoc()
		return XmlDoc.CreateFromTable(tRoot:ToTable())
	end

	function self:ToTable()
		if tRoot then
			return tRoot:ToTable()
		end
	end
	
	function self:Serialize()
		if tRoot then
			return tRoot:Serialize()
		end
	end
	
    return self
end

function XmlDocument.NewForm()
	local self = {}
    
	local tRoot = XmlNode.New(self, "Forms", {})
	
	function self:GetRoot()
		return tRoot
	end

	function self:SetRoot(tNewRoot)
		tRoot = tNewRoot
	end

	function self:NewNode(strTag, tAttributes)
		return XmlNode.New(self, strTag, tAttributes)
	end
	
	function self:NewFormNode(strName, tAttributes)
		local tForm = self:NewNode("Form", tAttributes)
		tForm:Attribute("Name", strName)
		tForm:Attribute("Class", "Window")
		return tForm
	end

	function self:NewControlNode(strName, strClass, tAttributes)
		local tControl = self:NewNode("Control", tAttributes)
		tControl:Attribute("Name", strName)
		tControl:Attribute("Class", strClass)
		return tControl
	end

	function self:NewEventNode(strName, strFunction)
		local tEvent = self:NewNode("Event", {
			Name = strName,
			Function = strFunction
		})
		return tEvent
	end

	function self:LoadForm(strName, wndParent, tHandler)
		return Apollo.LoadForm(self:ToXmlDoc(), strName, wndParent, tHandler)
	end

	function self:ToXmlDoc()
		return XmlDoc.CreateFromTable(tRoot:ToTable())
	end

	function self:ToTable()
		return tRoot:ToTable()
	end

	function self:Serialize()
		return tRoot:Serialize()
	end
	
    return self
end

function XmlDocument.CreateFromTable(tXml)
	local tDoc = self.New()
	local tRoot = CreateNodeFromTable(tXml)
	for i,v in ipairs(tXml) do
		AddChildFromTable(v, tRoot)
	end
	tDoc:SetRoot(tRoot)
end

local function AddChildFromTable(tXml, tParent)
	local tNode = CreateNodeFromTable(tXml)
	tParent:AddChild(tNode)
	for i,v in ipairs(tXml) do
		AddChildFromTable(v, tNode)
	end
end

local function CreateNodeFromTable(tXml)
	local tNode = tDoc:NewNode(tXml.__XmlNode)
	for k,v in pairs(tXml) do
		tNode:Attribute(k, v)
	end
	return tNode
end

function XmlDocument.CreateFromFile(strPath)
	local xmlDoc = XmlDoc.CreateFromFile(strPath)
	if not xmlDoc then return end
	return self.CreateFromTable(xmlDoc:ToTable())
end

---------------------------------------------------------------------------
-- XmlNode (only used internally)
---------------------------------------------------------------------------

function XmlNode.New(tDoc, strTag, tAttributes)
	
	tAttributes = true and tAttributes or {}
	
    local self = {}
	local tChildren = {}
	local strText = ""
	
	function self:GetDocument()
		return tDoc
	end
	
	function self:SetDocument(tDocument)
		tDoc = tDocument
	end
	
	function self:GetChildren()
		return tChildren
	end
	
	function self:AddChild(tNode)
		table.insert(tChildren, tNode)
		tNode:SetDocument(tDoc)
		return self
	end

	function self:RemoveChild(nId)
		return table.remove(tChildren, nId)
	end

	function self:RemoveAllChildren()
		tChildren = {}
	end

	function self:GetTag()
		return strTag
	end
	
	function self:Attribute(strName, value)
		if value ~= nil then
			tAttributes[strName] = value
			return self
		else
			return tAttributes[strName]
		end
	end

	function self:Attributes(tAtts)
		if tAtts then
			tAttributes = tAtts
			return self
		else
			return tAttributes
		end
	end

	function self:Text(strTxt)
		if strTxt then
			strText = strTxt
		else
			return strText
		end
	end
	
	function self:EachChild(fn)
		for i,v in ipairs(tChildren) do
			pcall(fn, v)
			self:EachChild(fn)
		end
	end
	
	function self:FindChild(fn)
		local tNode = nil
		for i,v in ipairs(tChildren) do
			local bSuccess, bResult = pcall(fnFind, v)
			if bSuccess == true and bResult == true then
				tNode = v
				break
			else
				tNode = v:Find(fn)
			end
			if tNode ~= nil then
				break
			end
		end
		return tNode
	end
	
	function self:FindChildByName(strName)
		return self:FindChild(function(tNode)
			return tNode:Attribute("Name") == strName
		end)
	end
	
	function self:Clone()
		return tDoc:NewNode(strTag, tAttributes)
	end
	
	function self:ToTable(tXml)
		-- This node
		local tNode = {__XmlNode = strTag}
		for k,v in pairs(tAttributes) do
			if k == "AnchorPoints" then
				tNode["LAnchorPoint"] = v[1]
				tNode["TAnchorPoint"] = v[2]
				tNode["RAnchorPoint"] = v[3]
				tNode["BAnchorPoint"] = v[4]
			elseif k == "AnchorOffsets" then
				tNode["LAnchorOffset"] = v[1]
				tNode["TAnchorOffset"] = v[2]
				tNode["RAnchorOffset"] = v[3]
				tNode["BAnchorOffset"] = v[4]
			else
				tNode[k] = v
			end
		end
		
		-- Children nodes
		for i,v in ipairs(tChildren) do
			v:ToTable(tNode)
		end
		if tXml then
			table.insert(tXml, tNode)
		end
		
		return tNode
	end
	
	function self:Serialize(nLevel)
		-- Recursion variables
		nLevel = true and nLevel or 0
		
		-- Indenting
		local strIndent = ""
		for i=1,nLevel do
			strIndent = strIndent .. "  "
		end
		
		local strXml = strIndent .. "<" .. strTag
		
		-- Start tag
		for k,v in pairs(tAttributes) do
			strXml = strXml .. " " .. k .. "=\"" .. tostring(v) .. "\""
		end
		strXml = strXml .. ">\n"
		
		-- Inner text or children, not both
		if #tChildren > 0 then
			-- Children add themselves to string
			for i,v in ipairs(tChildren) do
				strXml = strXml .. v:Serialize(nLevel + 1)
			end
		elseif strText then
			strXml = strXml .. strText .. "\n"
		end
		
		-- End tag
		strXml = strXml .. strIndent .. "</" .. strTag .. ">\n"
		
		return strXml
	end
	
	return self
end

-- Register Packages
Apollo.RegisterPackage(XmlDocument, "Drafto:Lib:XmlDocument-1.0", 3, {})
--Apollo.RegisterPackage(XmlNode, "Drafto:Lib:XmlNode-2.0", 1, {})