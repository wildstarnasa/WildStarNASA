-------------------------------------------------------------------------------
-- GeminiLogging
-- Copyright (c) NCsoft. All rights reserved
-- Author: draftomatic
-- Logging library (loosely) based on LuaLogging.
-- Comes with appenders for GeminiConsole and Print() Debug Channel.
-------------------------------------------------------------------------------

local inspect

local GeminiLogging = {}

function GeminiLogging:OnLoad()
	
	inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
	self.console = Apollo.GetAddon("GeminiConsole")
	
	-- The GeminiLogging.DEBUG Level designates fine-grained informational events that are most useful to debug an application
	self.DEBUG = "DEBUG"
	-- The GeminiLogging.INFO level designates informational messages that highlight the progress of the application at coarse-grained level
	self.INFO = "INFO"
	-- The WARN level designates potentially harmful situations
	self.WARN = "WARN"
	-- The ERROR level designates error events that might still allow the application to continue running
	self.ERROR = "ERROR"
	-- The FATAL level designates very severe error events that will presumably lead the application to abort
	self.FATAL = "FATAL"

	-- Data structures for levels
	self.LEVEL = {"DEBUG", "INFO", "WARN", "ERROR", "FATAL"}
	self.MAX_LEVELS = #self.LEVEL
	-- Enumerate levels
	for i=1,self.MAX_LEVELS do
		self.LEVEL[self.LEVEL[i]] = i
	end

end

function GeminiLogging:OnDependencyError(strDep, strError)
	if strDep == "GeminiConsole" then return true end
	Print("GeminiLogging couldn't load " .. strDep .. ". Fatal error: " .. strError)
	return false
end

-- Factory method for loggers
function GeminiLogging:GetLogger(opt)
	
	-- Default options
	if not opt then 
		opt = {
			level = self.INFO,
			pattern = "%d %n %c %l - %m",
			appender = "GeminiConsole"
		}
	end

	-- Initialize logger object
	local logger = {}
	
	-- Set appender
	if type(opt.appender) == "string" then
		logger.append = self:GetAppender(opt.appender)
		if not logger.append then
			Print("Invalid appender")
			return nil
		end
	elseif type(opt.appender) == "function" then
		logger.append = opt.appender
	else
		Print("Invalid appender")
		return nil
	end
	
	-- Set pattern
	logger.pattern = opt.pattern
	
	-- Set level
	logger.level = opt.level
	local order = self.LEVEL[logger.level]
	
	-- Set logger functions (debug, info, etc.) based on level option
	for i=1,self.MAX_LEVELS do
		local upperName = self.LEVEL[i]
		local name = upperName:lower()
		if i >= order then
			logger[name] = function(self, message, opt)
				local debugInfo = debug.getinfo(2)		-- Get debug info for caller of log function
				--Print(inspect(debug.getinfo(3)))
				--local caller = debugInfo.name or ""
				local dir, file, ext = string.match(debugInfo.short_src, "(.-)([^\\]-([^%.]+))$")
				local caller = file or ""
				caller = string.gsub(caller, "." .. ext, "")
				local line = debugInfo.currentline or "-"
				logger:append(GeminiLogging.PrepareLogMessage(logger, message, upperName, caller, line))		-- Give the appender the level string
			end
		else
			logger[name] = function() end			-- noop if level is too high
		end
	end

	return logger
end

function GeminiLogging:PrepareLogMessage(message, level, caller, line)
	
	if type(message) ~= "string" then
		if type(message) == "userdata" then
			message = inspect(getmetatable(message))
		else
			message = inspect(message)
		end
	end
	
	local logMsg = self.pattern
	message = string.gsub(message, "%%", "%%%%")
	logMsg = string.gsub(logMsg, "%%d", os.date("%I:%M:%S%p"))		-- only time, in 12-hour AM/PM format. This could be configurable...
	logMsg = string.gsub(logMsg, "%%l", level)
	logMsg = string.gsub(logMsg, "%%c", caller)
	logMsg = string.gsub(logMsg, "%%n", line)
	logMsg = string.gsub(logMsg, "%%m", message)
	
	return logMsg
end


-------------------------------------------------------------------------------
-- Default Appenders
-------------------------------------------------------------------------------
--[[local tLevelColors = {
	DEBUG = "FF4DDEFF",
	INFO = "FF52FF4D",
	WARN = "FFFFF04D",
	ERROR = "FFFFA04D",
	FATAL = "FFFF4D4D"
}--]]
function GeminiLogging:GetAppender(name)
	if nTimeStart == nil then nTimeStart = os.time() end
	if name == "GeminiConsole" then
		return function(self, message, level)
			if GeminiLogging.console ~= nil then
				GeminiLogging.console:Append(message)
			else
				Print(message)
			end
		end
	else
		return function(self, message, level)
			Print(message)
		end
	end
	return nil
end

Apollo.RegisterPackage(GeminiLogging, "Gemini:Logging-1.2", 1, {"Drafto:Lib:inspect-1.2", "GeminiConsole"})
	