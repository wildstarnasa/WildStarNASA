local XmlNode = {}

function XmlNode:New(strName, strType, strClass, tAttributes)
    local this = {
		strName = strName,
		strClass = strClass,
		strType = strType,
		tXml = {
			__XmlNode = strType,
			Class = strClass,
			Name = strName
		}
	}
	if tAttributes then
		for k,v in pairs(tAttributes) do
			if k == "AnchorPoints" then
				this.tXml["LAnchorPoint"] = v[1]
				this.tXml["TAnchorPoint"] = v[2]
				this.tXml["RAnchorPoint"] = v[3]
				this.tXml["BAnchorPoint"] = v[4]
			elseif k == "AnchorOffsets" then
				this.tXml["LAnchorOffset"] = v[1]
				this.tXml["TAnchorOffset"] = v[2]
				this.tXml["RAnchorOffset"] = v[3]
				this.tXml["BAnchorOffset"] = v[4]
			else
				this.tXml[k] = v
			end
		end
	end
    setmetatable(this, self)
    self.__index = self 
    return this
end

function XmlNode:Append(tNode)
	table.insert(self.tXml, tNode.tXml)
	return self
end

function XmlNode:Attribute(strName, value)
	if value ~= nil then
		self.tXml[strName] = value
		return self
	else
		return self.tXml[strName]
	end
end

function XmlNode:ToXmlDoc()
	local tXmlDoc = {
		__XmlNode = "Forms"
	}
	table.insert(tXmlDoc, self.tXml)
	return XmlDoc.CreateFromTable(tXmlDoc)
end

function XmlNode:LoadForm(wndParent, tHandler)
	return Apollo.LoadForm(self:ToXmlDoc(), self.strName, wndParent, tHandler)
end

Apollo.RegisterPackage(XmlNode, "Drafto:Lib:XmlNode-1.1", 1, {})