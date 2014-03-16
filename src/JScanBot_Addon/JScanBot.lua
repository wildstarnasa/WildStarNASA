local JScanBot = {} 

local Queue
local glog

local UPDATE_INTERVAL = 0.3			-- In seconds
local TOKEN = "JScanBot"
local DELIMITER = ":::"
local STRING_BUFFER_SIZE = 8000		-- Message characters to write to clipboard in each batch

function JScanBot:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    return o
end
function JScanBot:Init()
    Apollo.RegisterAddon(self, false, "", {"Gemini:Logging-1.2", "Drafto:Lib:Queue-1.2"})
end

function JScanBot:OnLoad()
	Queue = Apollo.GetPackage("Drafto:Lib:Queue-1.2").tPackage
	local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
	glog = GeminiLogging:GetLogger({
		level = GeminiLogging.FATAL,
		pattern = "%d %n %c %l - %m",
		appender = "GeminiConsole"
	})
	
	self.messageQueue = Queue.new()
	
	self.tOpenPaths = {}
	
	self.wndMain = Apollo.LoadForm("JScanBot.xml", "Form", nil, self)
	self.wndMain:Show(false)
	self.wndClipboardHidden = self.wndMain:FindChild("ClipboardHidden")
	self.wndClipboardHistory = self.wndMain:FindChild("ClipboardHistory")
	
	Apollo.CreateTimer("JScanBot_ClipboardMessageQueueTimer", 0.4, true)
	Apollo.RegisterTimerHandler("JScanBot_ClipboardMessageQueueTimer", "OnClipboardMessageQueueTimer", self)
	
	glog:info("Loaded JScanBot")
end

function JScanBot:OnDependencyError(strDep, strError)
	Print("JScanBot couldn't load " .. strDep .. ". Fatal error: " .. strError)
	return false
end
------------------------------------------------------------

function JScanBot:OnClipboardMessageQueueTimer()
	if Queue.Size(self.messageQueue) > 0 then
		local strMessage = Queue.PopRight(self.messageQueue)
		--self.wndClipboardHistory:SetText(self.wndClipboardHistory:GetText() .. "\n" .. strMessage)
		self.wndClipboardHidden:SetText(strMessage)
		self.wndClipboardHidden:CopyTextToClipboard()
	end
end

function JScanBot:QueueMessage(strMessage)
	Queue.PushLeft(self.messageQueue, strMessage)
end

------------------------------------------------------------

function JScanBot:OpenFile(strPath, bAppend)
	glog:info("Opening file: " .. strPath)
	self.tOpenPaths[strPath] = true
	
	local strMessageType
	if bAppend then
		strMessageType = "OpenFileAppend"
	else
		strMessageType = "OpenFile"
	end
	
	local strMessage = TOKEN .. DELIMITER .. strMessageType .. DELIMITER .. strPath
	self:QueueMessage(strMessage)
end

function JScanBot:CloseFile(strPath)
	glog:info("Closing file: " .. strPath)
	
	local strMessage = TOKEN .. DELIMITER .. "CloseFile" .. DELIMITER.. strPath
	self:QueueMessage(strMessage)
	
	self.tOpenPaths[strPath] = nil
end

function JScanBot:WriteToFile(strPath, strText)
	if strPath == nil then return end
	glog:info("Writing to file: " .. strPath)
	
	local tTextParts = {}
	
	if #strText > STRING_BUFFER_SIZE then
		local nCursor = 1
		while nCursor < #strText do
			local nCursorNext = nCursor + STRING_BUFFER_SIZE
			if nCursorNext > #strText then
				nCursorNext = #strText
			end
			local strMessageText = string.sub(strText, nCursor, nCursorNext - 1)
			nCursor = nCursorNext
			table.insert(tTextParts,strMessageText)
		end
	else
		table.insert(tTextParts, strText)
	end
	
	for i,strPart in ipairs(tTextParts) do
		local strMessage = TOKEN .. DELIMITER .. "WriteToFile" .. DELIMITER .. strPath .. DELIMITER .. strPart
		self:QueueMessage(strMessage)
	end
end

function JScanBot:IsFileOpen(strPath)
	return self.tOpenPaths[strPath] == true
end

function JScanBot:GetOpenFiles()
	local tPaths = {}
	for k,v in pairs(self.tOpenPaths) do
		if v == true then
			table.insert(tPaths, k)
		end
	end
	return tPaths
end

local JScanBotInst = JScanBot:new()
JScanBotInst:Init()
