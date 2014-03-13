-----------------------------------------------------------------------------------------------------------------------
--- LuaUtils
-- Basic utilities for working with Lua
-- @author draftomatic
-----------------------------------------------------------------------------------------------------------------------

local LuaUtils = {}

--- Converts a table to a string (shallow)
function LuaUtils:PrintTable(tbl)
	local str = "{"
	for k,v in pairs(tbl) do
		str = str .. k .. "=" .. tostring(v) .. ", "
	end
	str = str .. "}"
	return str
end

function LuaUtils:GetTableSize(tbl)
	local count = 0
	for _ in pairs(tbl) do count = count + 1 end
	return count
end

function LuaUtils:Pack(...)
	return { ... }, select("#", ...)
end


function LuaUtils:FormatTime(nTime)
	if type(nTime) ~= "number" then return nTime end
	local nDays, nHours, nMinutes, nSeconds = math.floor(nTime / 86400), math.floor((nTime % 86400) / 3600), math.floor((nTime % 3600) / 60), nTime % 60;

	if nDays ~= 0 then
		return ("%dd %dh %dm %ds"):format(nDays, nHours, nMinutes, nSeconds)
	elseif nHours ~= 0 then
		return ("%dh %dm %ds"):format(nHours, nMinutes, nSeconds)
	elseif nMinutes ~= 0 then
		return ("0h %dm %ds"):format(nMinutes, nSeconds)
	else
		return ("0m %ds"):format(nSeconds)
	end
end

--- Basic string StartsWith utility
function LuaUtils:StartsWith(str, start)
	return string.sub(str, 1, string.len(start)) == start
end

function LuaUtils:EndsWith(str,endStr)
   return endStr == '' or string.sub(str, -string.len(endStr)) == endStr
end

function LuaUtils:EqualsIgnoreCase(str1, str2)
	return str1:lower() == str2:lower()
end

--- Basic string Trim utility
function LuaUtils:Trim(s)
  return s:match'^%s*(.*%S)' or ''
end

function LuaUtils:TableContainsString(t, str)
	for _,v in pairs(t) do
		if v == str then return true end
	end
	return false
end

--- Wraps a text in color format tags with the given color (aarrggbb hex string)
function LuaUtils:markupTextColor(text, color)
	--return "<T TextColor=\"" .. color .. "\">" .. text .. "</T>"	
	return string.format("<T TextColor=\"%s\">%s</T>", color, text)
end

-- Wraps a text in color format tags with the given color (aarrggbb hex string)
function LuaUtils:MarkupText(text, color, font)
	--return "<T TextColor=\"" .. color .. "\">" .. text .. "</T>"	
	return string.format("<T TextColor=\"%s\" Font=\"%s\">%s</T>", color, font, tostring(text))
end

function LuaUtils:MarkupBGColor(text, color)
	--return "<T TextColor=\"" .. color .. "\">" .. text .. "</T>"	
	return string.format("<T BGColor=\"%s\">%s</T>", color, tostring(text))
end

--- Escapes HTML characters in a string
function LuaUtils:EscapeHTML(str)
	local subst = {
		["&"] = "&amp;";
		['"'] = "&quot;";
		["'"] = "&apos;";
		["<"] = "&lt;";
		[">"] = "&gt;";
		--["\n"] = "&#13;&#10;";
	}
	return tostring(str):gsub("[&\"'<>\n]", subst)
end

--- Unescapes HTML characters in a string
function LuaUtils:UnescapeHTML(str)
	str = tostring(str)
	str = str:gsub("&quot;", '"')
	str = str:gsub("&apos;", "'")
	str = str:gsub("&lt;", "<")
	str = str:gsub("&gt;", ">")
	str = str:gsub("&#13;&#10;", "\n")		-- CRLF (Windows Only!)
	str = str:gsub("&amp;", "&")
	return str
end

-- Register Library
Apollo.RegisterPackage(LuaUtils, "Drafto:Lib:LuaUtils-1.2", 1, {})


-----------------------------------------------------------------------------------------------------------------------
--- Standard Queue Implementation
-- http://www.lua.org/pil/11.4.html
-----------------------------------------------------------------------------------------------------------------------

local Queue = {}
function Queue.new()
	return {first = 0, last = -1}
end

function Queue.PushLeft(queue, value)
	local first = queue.first - 1
	queue.first = first
	queue[first] = value
end

function Queue.PushRight(queue, value)
	local last = queue.last + 1
	queue.last = last
	queue[last] = value
end

function Queue.PopLeft(queue)
	local first = queue.first
	if first > queue.last then error("queue is empty") end
	local value = queue[first]
	queue[first] = nil        -- to allow garbage collection
	queue.first = first + 1
	return value
end

function Queue.PopRight(queue)
	local last = queue.last
	if queue.first > last then error("queue is empty") end
	local value = queue[last]
	queue[last] = nil         -- to allow garbage collection
	queue.last = last - 1
	return value
end

function Queue.Size(queue)
	return queue.last - queue.first + 1
end

-- Register Library
Apollo.RegisterPackage(Queue, "Drafto:Lib:Queue-1.2", 1, {})
