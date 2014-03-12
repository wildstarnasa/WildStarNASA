-----------------------------------------------------------------------------------------------------------------------
-- Plotter for WildStar. Supports line, stem, bar, scatter, polar, and parametric plots.
-- Copyright (c) NCsoft. All rights reserved
-- @author draftomatic
-----------------------------------------------------------------------------------------------------------------------

-- PixiePlot is converted to a constructor object, so call it directly to get a new plotter.
local PixiePlot = {}

-- A couple colors
local clrWhite = {
	a = 1,
	r = 1,
	g = 1,
	b = 1
}
local clrGrey = {
	a = 1,
	r = 0.6,
	g = 0.6,
	b = 0.6
}
local clrClear = {
	a = 0,
	r = 1,
	g = 1,
	b = 1
}

--- Constants
-- Plotting Styles
PixiePlot.LINE = 1
PixiePlot.STEM = 2
PixiePlot.SCATTER = 3
PixiePlot.PIE = 4

-- Coordinate Systems
PixiePlot.CARTESIAN = 1
PixiePlot.POLAR = 2

-- Bar graph orientations
PixiePlot.HORIZONTAL = 1
PixiePlot.VERTICAL = 2

-- Window Overlay event types
PixiePlot.MOUSE_DOWN = 1
PixiePlot.MOUSE_UP = 2
PixiePlot.MOUSE_ENTER = 3
PixiePlot.MOUSE_EXIT = 4

-- Coordinate System Conversion
local function cartToPol(x, y)
	return math.sqrt(math.pow(x,2) + math.pow(y,2)), math.atan2(y,x)
end
local function polToCart(th, r)
	return r*math.cos(th), r*math.sin(th)
end

--- Sets all plotting options (replaces current options).
-- @param tOpt Plotting options.
function PixiePlot:SetOptions(tOpt)
	self.tOpt = tOpt
end

--- Sets a plotting option by name. For a full list of option names and values, see the main PixiePlot section.
-- @param strName The option name.
-- @param opt The option value.
-- @see PixiePlot
function PixiePlot:SetOption(strName, opt)
	self.tOpt[strName] = opt
end

--- Sets the x-distance between dataSet values. Does not apply to scatter plots.
-- @param fInterval The x-distance between dataSet values.
function PixiePlot:SetXInterval(fInterval)
	self.fXInterval = fInterval
end

--- Sets the minimum (bottom) X bound for the viewbox.
-- @param fXMin The minimum x-value to display in the viewbox.
function PixiePlot:SetXMin(fXMin)
	self.fXMin = fXMin
end

--- Sets the minimum (bottom) X bound for the viewbox.
-- @param fXMax The maximum x-value to display in the viewbox.
function PixiePlot:SetXMax(fXMax)
	self.fXMax = fXMax
end

--- Sets the minimum (bottom) Y bound for the viewbox.
-- @param fYMin The minimum y-value to display in the viewbox.
function PixiePlot:SetYMin(fYMin)
	self.fYMin = fYMin
end

--- Sets the minimum (bottom) Y bound for the viewbox.
-- @param fYMax The maximum y-value to display in the viewbox.
function PixiePlot:SetYMax(fYMax)
	self.fYMax = fYMax
end

--- Redraws graph using current dataSets and settings.
function PixiePlot:Redraw()
	
	-- Reset Pixies
	self.wnd:DestroyAllPixies()
	
	if self.nDataSets > 0 then
	
		-- Draw axes
		if self.tOpt.bDrawXAxis then
			self:DrawXAxis()
		end
		if self.tOpt.bDrawYAxis then
			self:DrawYAxis()
		end
		
		-- Draw DataSets
		local i = 1
		for _,dataSet in pairs(self.dataSets) do
			local color = self.tOpt.aPlotColors[i]
			self:PlotDataSet(dataSet, color, i-1)
			i = i + 1
		end
		
		-- Draw labels
		if self.tOpt.bDrawXAxisLabel then
			self:DrawXAxisLabel()
		end
		if self.tOpt.bDrawYAxisLabel then
			self:DrawYAxisLabel()
		end
		if self.tOpt.bDrawXValueLabels then
			self:DrawXValueLabels()
		end
		if self.tOpt.bDrawYValueLabels then
			if self.tOpt.ePlotStyle == self.BAR and self.tOpt.eBarOrientation == self.HORIZONTAL then
				self:DrawXValueLabels(self.fYMax - self.fYMin)
			else
				self:DrawYValueLabels()
			end
		end
		
		-- Draw grid lines
		if self.tOpt.bDrawXGridLines then
			self:DrawXGridLines()
		end
		if self.tOpt.bDrawYGridLines then
			self:DrawYGridLines()
		end
		
	end
end




--- Adds a dataset to plot on the next Redraw.
-- @param dataSet An array of data to plot. The general format is as follows:
--		dataSet = {xStart = xStart, values = {}}
--		xStart is the x-value of the first values element. This parameter allows you to shift the x position of the 
--		graph (for pieceswise plotting, or for lining up dataSets of different length and start position). Generally
--		xStart will be the same for all dataSets.
--		
-- 		If ePlotStyle equals BAR, LINE, or STEM, values is an array of numbers representing y-values, e.g.:
--		{-4, 5, 0, 3, 8}
-- 		If ePlotStyle == SCATTER, values is an array of tables with x- and y-values, e.g.:
--		{{x=0,y=0},{x=1,y=2}, ...}
function PixiePlot:AddDataSet(dataSet)
	--Print("Adding " .. #dataSet.values .. " values")
	self:UpdateMinMaxValues(dataSet)
	--Print(self.fXMin .. " " ..self.fXMax .. " " ..self.fYMin .. " " .. self.fYMax)
	self.dataSets[self.nDataSets + 1] = dataSet
	self.nDataSets = self.nDataSets + 1
	return self.nDataSets
end

--- Removes all dataSets
function PixiePlot:RemoveAllDataSets()
	self.nDataSets = 0
	self.nNumDataSets = 0
	self.dataSets = {}
	self.fXMin = nil
	self.fXMax = nil
	self.fYMin = nil
	self.fYMax = nil
end

--- Removes a dataSet by id
-- @param nDataSetId The id of the dataSet that was returned from @see AddDataSet().
function PixiePlot:RemoveDataSet(nDataSetId)
	self.dataSets[nDataSetId] = nil
end







--- Plots the given dataSet with current options.
-- @param dataSet An array of values. Uses self.xInterval for timestep.
-- @param color The color of the current dataSet.
-- @param nBarIndex The index of the current bar graph (used only for multiple bar plot dataSets)
function PixiePlot:PlotDataSet(dataSet, color, nBarIndex)
	local maxWidth = self.wnd:GetWidth() - self.tOpt.fYLabelMargin - self.tOpt.fPlotMargin
	local maxHeight = self.wnd:GetHeight() - self.tOpt.fXLabelMargin - self.tOpt.fPlotMargin
	local clrSymbol = self.tOpt.clrSymbol
	if clrSymbol == nil then
		clrSymbol = color
	end
	
	local ePlotStyle = self.tOpt.ePlotStyle
	
	-- Line Plot
	if ePlotStyle == self.LINE or ePlotStyle == self.STEM then
		local fXRange = self.fXMax - self.fXMin
		local fYRange = self.fYMax - self.fYMin
		if self.tOpt.eCoordinateSystem == self.CARTESIAN then
			local xOffset = (dataSet.xStart - self.fXMin) / fXRange * maxWidth
			--Print(xOffset)
			local xIntervalWidth = maxWidth / (#dataSet.values - 1)
			local vPrev
			-- Line
			for i, v in ipairs(dataSet.values) do
				if v == math.huge then v = 0 end
				if ePlotStyle == self.LINE then
					if i > 1 then
						self:DrawLine(
							{
								x1 = self.tOpt.fYLabelMargin + xOffset + (i - 2) * xIntervalWidth,
								y1 = self.tOpt.fXLabelMargin + (vPrev - self.fYMin) / fYRange * maxHeight,
								x2 = self.tOpt.fYLabelMargin + xOffset + (i - 1) * xIntervalWidth,
								y2 = self.tOpt.fXLabelMargin + (v - self.fYMin) / fYRange * maxHeight
							},
							"",
							self.tOpt.fLineWidth,
							self.tOpt.strLineSprite,
							color
						)
					end
				elseif ePlotStyle == self.STEM then
					self:DrawLine(
						{
							x1 = self.tOpt.fYLabelMargin + xOffset + (i - 1) * xIntervalWidth,
							y1 = self.tOpt.fXLabelMargin + (0 - self.fYMin) / (self.fYMax - self.fYMin) * maxHeight,
							x2 = self.tOpt.fYLabelMargin + xOffset + (i - 1) * xIntervalWidth,
							y2 = self.tOpt.fXLabelMargin + (v - self.fYMin) / fYRange * maxHeight
						},
						"",
						self.tOpt.fLineWidth,
						self.tOpt.strLineSprite,
						color
					)

				end
				vPrev = v
			end
			-- Symbol
			if self.tOpt.bDrawSymbol then
				for i, v in ipairs(dataSet.values) do
					if v == math.huge then v = 0 end
					local fSymbolSize = self.tOpt.fSymbolSize
					if fSymbolSize == nil then
						fSymbolSize = self.tOpt.fLineWidth * 2
					end
					--Print(v .. "/" .. fYRange .. " out of " .. maxHeight)
					local tPos = {
						x = self.tOpt.fYLabelMargin + xOffset + (i - 1) * xIntervalWidth,
						y = self.tOpt.fXLabelMargin + (v - self.fYMin) / fYRange * maxHeight
					}
					self:DrawSymbol(
						tPos,
						fSymbolSize,
						self.tOpt.strSymbolSprite,
						clrSymbol
					)
					-- Window Overlay
					if self.tOpt.bWndOverlays then
						local wnd = self:AddWindowOverlay(tPos, self.tOpt.fWndOverlaySize)
						local tData = {
							i = i,
							x = (i - 1) * self.fXInterval + dataSet.xStart,
							y = v
						}
						wnd:SetData(tData)
						if self.tOpt.wndOverlayLoadCallback then
							self.tOpt.wndOverlayLoadCallback(tData, wnd)
						end
					end
				end
			end
			
		elseif self.tOpt.eCoordinateSystem == self.POLAR then
			
			local vPrev
			for i, v in ipairs(dataSet.values) do
				if v == math.huge then v = 0 end
				local vPol = v
				local xActual = dataSet.xStart + (i - 2) * self.fXInterval
				xActual, v = polToCart(xActual, v)
				if ePlotStyle == self.LINE then
					if i > 1 then
						local xActualPrev = dataSet.xStart + (i - 3) * self.fXInterval
						xActualPrev, vPrev = polToCart(xActualPrev, vPrev)
						self:DrawLine(
							{
								x1 = self.tOpt.fYLabelMargin + (xActualPrev - self.fXMin) / fXRange * maxWidth,
								y1 = self.tOpt.fXLabelMargin + (vPrev - self.fYMin) / fYRange * maxHeight,
								x2 = self.tOpt.fYLabelMargin + (xActual - self.fXMin) / fXRange * maxWidth,
								y2 = self.tOpt.fXLabelMargin + (v - self.fYMin) / fYRange * maxHeight
							},
							"",
							self.tOpt.fLineWidth,
							self.tOpt.strLineSprite,
							color
						)
					end
				elseif ePlotStyle == self.STEM then
					--local xActual = dataSet.xStart + (i - 2) * self.fXInterval
					--xActual, v = polToCart(xActual, v)
					self:DrawLine(
						{
							x1 = self.tOpt.fYLabelMargin + (0 - self.fXMin) / (self.fXMax - self.fXMin) * maxWidth,
							y1 = self.tOpt.fXLabelMargin + (0 - self.fYMin) / (self.fYMax - self.fYMin) * maxHeight,
							x2 = self.tOpt.fYLabelMargin + (xActual - self.fXMin) / fXRange * maxWidth,
							y2 = self.tOpt.fXLabelMargin + (v - self.fYMin) / fYRange * maxHeight
						},
						"",
						self.tOpt.fLineWidth,
						self.tOpt.strLineSprite,
						color
					)
				end
				vPrev = vPol
			end
			-- Symbol
			if self.tOpt.bDrawSymbol then
				for i, v in ipairs(dataSet.values) do
					if v == math.huge then v = 0 end
					local xActual = dataSet.xStart + (i - 2) * self.fXInterval
					local xCart, vCart = polToCart(xActual, v)
					
					local fSymbolSize = self.tOpt.fSymbolSize
					if fSymbolSize == nil then
						fSymbolSize = self.tOpt.fLineWidth * 2
					end
					--Print(vCart .. "/" .. fYRange .. " out of " .. maxHeight)
					local tPos = {
						x = self.tOpt.fYLabelMargin + (xCart - self.fXMin) / fXRange * maxWidth,
						y = self.tOpt.fXLabelMargin + (vCart - self.fYMin) / fYRange * maxHeight
					}
					self:DrawSymbol(
						tPos,
						fSymbolSize,
						self.tOpt.strSymbolSprite,
						clrSymbol
					)
					-- Window Overlay
					if self.tOpt.bWndOverlays then
						local wnd = self:AddWindowOverlay(tPos, self.tOpt.fWndOverlaySize)
						local tData = {
							i = i,
							x = (i - 1) * self.fXInterval + dataSet.xStart,
							y = v
						}
						wnd:SetData(tData)
						if self.tOpt.wndOverlayLoadCallback then
							self.tOpt.wndOverlayLoadCallback(tData, wnd)
						end
					end
				end	
			end
		end
		
	elseif ePlotStyle == self.SCATTER then
		local fXRange = self.fXMax - self.fXMin
		local fYRange = self.fYMax - self.fYMin
		if self.tOpt.eCoordinateSystem == self.POLAR then
			local xCart, yCart = polToCart(v.x, v.y)
			v = {
				x = xCart,
				y = yCart
			}
		end
		if self.tOpt.bScatterLine == true then
			local vPrev
			for i, v in ipairs(dataSet.values) do
				if i > 1 then
					self:DrawLine(
						{
							x1 = self.tOpt.fYLabelMargin + (vPrev.x - self.fXMin) / fXRange * maxWidth,
							y1 = self.tOpt.fXLabelMargin + (vPrev.y - self.fYMin) / fYRange * maxHeight,
							x2 = self.tOpt.fYLabelMargin + (v.x - self.fXMin) / fXRange * maxWidth,
							y2 = self.tOpt.fXLabelMargin + (v.y - self.fYMin) / fYRange * maxHeight
						},
						"",
						self.tOpt.fLineWidth,
						self.tOpt.strLineSprite,
						color
					)
				end
				vPrev = v
			end
		end
		local fSymbolSize = self.tOpt.fSymbolSize
		if fSymbolSize == nil then
			fSymbolSize = self.tOpt.fLineWidth * 2
		end
		for i, v in pairs(dataSet.values) do
			--local x = self.tOpt.fYLabelMargin + (v.x - self.fXMin) / fXRange * maxWidth
			--local y = self.tOpt.fXLabelMargin + (v.y - self.fYMin) / fYRange * maxHeight
			--Print("x: " .. v.x - self.fXMin .. "/" .. fXRange .. " out of " .. maxWidth)
			--Print("y: " .. v.y - self.fYMin .. "/" .. fYRange .. " out of " .. maxHeight)
			--Print("(" .. x .. ", " .. y .. ") in " .. "(" .. maxWidth .. ", " .. maxHeight .. ")")
			local tPos = {
				x = self.tOpt.fYLabelMargin + (v.x - self.fXMin) / fXRange * maxWidth,
				y = self.tOpt.fXLabelMargin + (v.y - self.fYMin) / fYRange * maxHeight
			}
			self:DrawSymbol(
				tPos,
				fSymbolSize,
				self.tOpt.strSymbolSprite,
				clrSymbol
			)
			-- Window Overlay
			if self.tOpt.bWndOverlays then
				local wnd = self:AddWindowOverlay(tPos, self.tOpt.fWndOverlaySize)
				local tData = {
					i = i,
					x = v.x,
					y = v.y
				}
				wnd:SetData(tData)
				if self.tOpt.wndOverlayLoadCallback then
					self.tOpt.wndOverlayLoadCallback(tData, wnd)
				end
			end
		end
		
	elseif self.tOpt.ePlotStyle == self.BAR then
		--Print("drawing " .. #dataSet.values .. " bars")
		if self.tOpt.eBarOrientation == self.VERTICAL then
			local fXIntervalWidth = (maxWidth - self.tOpt.fBarMargin - ((#dataSet.values-1) * self.tOpt.fBarSpacing)) / #dataSet.values
			local fTotalBarWidth = fXIntervalWidth / self:GetTableSize(self.dataSets)
			local fActualBarWidth = fTotalBarWidth - 2*self.tOpt.fBarMargin
			for i,v in ipairs(dataSet.values) do
				--Print(v .. "/" .. self.fYMax .. " out of " .. maxHeight)
				local label
				if dataSet.labels ~= nil then label = dataSet.labels[i] else label = "" end
				self:DrawRectangle({
					x1 = self.tOpt.fYLabelMargin + self.tOpt.fBarMargin + (i-1) * self.tOpt.fBarSpacing + (i-1) * fXIntervalWidth + fTotalBarWidth * nBarIndex,
					y1 = 1 + self.tOpt.fXLabelMargin,
					x2 = self.tOpt.fYLabelMargin + self.tOpt.fBarMargin + (i-1) * self.tOpt.fBarSpacing + (i-1) * fXIntervalWidth + fTotalBarWidth * nBarIndex + self.tOpt.fBarMargin + fActualBarWidth,
					y2 = 1 + self.tOpt.fXLabelMargin + (v / self.fYMax) * maxHeight
				}, 
				self.tOpt.strBarSprite, 
				color,
				self.tOpt.clrBarLabel,
				label)
			end
		else
			local fYIntervalHeight = (maxHeight - self.tOpt.fBarMargin - ((#dataSet.values-1) * self.tOpt.fBarSpacing)) / #dataSet.values
			local fTotalBarHeight = fYIntervalHeight / self:GetTableSize(self.dataSets)
			local fActualBarHeight = fTotalBarHeight - 2*self.tOpt.fBarMargin
			for i,v in ipairs(dataSet.values) do
				--Print(v .. "/" .. self.fYMax .. " out of " .. maxWidth)
				local label
				if dataSet.labels ~= nil then label = dataSet.labels[i] else label = "" end
				self:DrawRectangle({
					y1 = self.tOpt.fXLabelMargin + self.tOpt.fBarMargin + (i-1) * self.tOpt.fBarSpacing + (i-1) * fYIntervalHeight + fTotalBarHeight * nBarIndex,
					x1 = 1 + self.tOpt.fYLabelMargin,
					y2 = self.tOpt.fXLabelMargin + self.tOpt.fBarMargin + (i-1) * self.tOpt.fBarSpacing + (i-1) * fYIntervalHeight + fTotalBarHeight * nBarIndex + self.tOpt.fBarMargin + fActualBarHeight,
					x2 = 1 + self.tOpt.fYLabelMargin + (v / self.fYMax) * maxWidth
				}, 
				self.tOpt.strBarSprite, 
				color,
				self.tOpt.clrBarLabel,
				label)
			end
		end
	end
end

--- Draws X axis with current options.
function PixiePlot:DrawXAxis()
	if self.tOpt.ePlotStyle == self.BAR then
		self:DrawLine(
			{
				x1 = self.tOpt.fYLabelMargin,
				y1 = self.tOpt.fXLabelMargin,
				x2 = self.wnd:GetWidth() - self.tOpt.fPlotMargin,
				y2 = self.tOpt.fXLabelMargin
			},
			"",
			self.tOpt.fYAxisWidth,
			nil,
			self.tOpt.clrYAxis
		)
	else
		if self.fYMin <= 0 and self.fYMax >= 0 then
			local maxHeight = self.wnd:GetHeight() - self.tOpt.fXLabelMargin - self.tOpt.fPlotMargin
			local yPos = (0 - self.fYMin) / (self.fYMax - self.fYMin) * maxHeight
			self:DrawLine(
				{
					x1 = self.tOpt.fYLabelMargin,
					y1 = self.tOpt.fXLabelMargin + yPos,
					x2 = self.wnd:GetWidth() - self.tOpt.fPlotMargin,
					y2 = self.tOpt.fXLabelMargin + yPos
				},
				"",
				self.tOpt.fXAxisWidth,
				nil,
				self.tOpt.clrXAxis
			)
		end
	end
end

--- Draws Y axis with current options.
function PixiePlot:DrawYAxis()
	if self.tOpt.ePlotStyle == self.BAR then
		self:DrawLine(
			{
				x1 = self.tOpt.fYLabelMargin,
				y1 = self.tOpt.fXLabelMargin,
				x2 = self.tOpt.fYLabelMargin,
				y2 = self.wnd:GetHeight() - self.tOpt.fPlotMargin
			},
			"",
			self.tOpt.fYAxisWidth,
			nil,
			self.tOpt.clrYAxis
		)
	else
		if self.fXMin <= 0 and self.fXMax >= 0 then
			local maxWidth = self.wnd:GetWidth() - self.tOpt.fYLabelMargin - self.tOpt.fPlotMargin
			local xPos = (0 - self.fXMin) / (self.fXMax - self.fXMin) * maxWidth
			self:DrawLine(
				{
					x1 = self.tOpt.fYLabelMargin + xPos,
					y1 = self.tOpt.fXLabelMargin,
					x2 = self.tOpt.fYLabelMargin + xPos,
					y2 = self.wnd:GetHeight() - self.tOpt.fPlotMargin
				},
				"",
				self.tOpt.fYAxisWidth,
				nil,
				self.tOpt.clrYAxis
			)
		end
	end
end

--- Draws X labels with current options.
function PixiePlot:DrawXAxisLabel()
	self:DrawLine(
		{
			x1 = self.wnd:GetWidth() - self.tOpt.fPlotMargin - self.tOpt.fXAxisLabelOffset,
			y1 = self.tOpt.fXLabelMargin / 2,
			x2 = self.wnd:GetWidth() - self.tOpt.fPlotMargin,
			y2 = self.tOpt.fXLabelMargin / 2,
		},
		self.tOpt.strXLabel,
		10,
		nil,
		self.tOpt.clrXAxisLabel
	)
end

--- Draws Y labels with current options.
function PixiePlot:DrawYAxisLabel()
	self:DrawLine(
		{
			x1 = self.tOpt.fYLabelMargin / 3,
			y1 = self.wnd:GetHeight() - self.tOpt.fPlotMargin - self.tOpt.fYAxisLabelOffset,
			x2 = self.tOpt.fYLabelMargin / 3,
			y2 = self.wnd:GetHeight() - self.tOpt.fPlotMargin,
		},
		self.tOpt.strYLabel,
		10,
		nil,
		self.tOpt.clrYAxisLabel
	)
end

--- Draws X value labels with current options.
function PixiePlot:DrawXValueLabels(fXRange)
	local maxWidth = self.wnd:GetWidth() - self.tOpt.fYLabelMargin - self.tOpt.fPlotMargin
	
	if fXRange == nil then
		fXRange = self.fXMax - self.fXMin
	end
	
	local nLabels = self.tOpt.nXValueLabels
	local fInterval = fXRange / nLabels
	for i=0,nLabels do
		local fPos = i * fInterval / fXRange * maxWidth
		local fValue = self.fXMin + i * fInterval --* self.fXInterval
		local strValue
		if self.tOpt.xValueFormatter ~= nil then
			strValue = self.tOpt.xValueFormatter(fValue)
		else
			strValue = string.format("%." .. self.tOpt.nXLabelDecimals .. "f", fValue)
			if strValue == "-0.0" then strValue = "0.0" end
			if strValue == "-0" then strValue = "0" end
		end
		self:DrawLine(
			{
				x1 = self.tOpt.fYLabelMargin + fPos - self.tOpt.fXValueLabelTilt,
				y1 = 0,
				x2 = self.tOpt.fYLabelMargin + fPos,
				y2 = self.tOpt.fXLabelMargin - 10
			},
			strValue,
			20,
			nil,
			self.tOpt.clrXValueBackground,
			self.tOpt.clrXValueLabel
		)
	end
end

--- Draws Y value labels with current options.
function PixiePlot:DrawYValueLabels(fYRange)
	local maxHeight = self.wnd:GetHeight() - self.tOpt.fXLabelMargin - self.tOpt.fPlotMargin
	
	if fYRange == nil then
		fYRange = self.fYMax - self.fYMin
	end
	
	local nLabels = self.tOpt.nYValueLabels
	local fInterval = fYRange / nLabels
	for i=0,nLabels do
		local fPos = i * fInterval / fYRange * maxHeight
		local fValue = self.fYMin + i * fInterval
		local strValue
		if self.tOpt.yValueFormatter ~= nil then
			strValue = self.tOpt.yValueFormatter(fValue)
		else
			strValue = string.format("%." .. self.tOpt.nYLabelDecimals .. "f", fValue)
			if strValue == "-0.0" then strValue = "0.0" end
			if strValue == "-0" then strValue = "0" end
		end
		self:DrawLine(
			{
				x1 = 0,
				y1 = self.tOpt.fXLabelMargin + fPos - self.tOpt.fYValueLabelTilt,
				x2 = self.tOpt.fYLabelMargin - 10,
				y2 = self.tOpt.fXLabelMargin + fPos
			},
			strValue,
			20,
			nil,
			self.tOpt.clrYValueBackground,
			self.tOpt.clrYValueLabel
		)
	end
end

--- Draws X (vertical) grid lines with current options.
function PixiePlot:DrawXGridLines()
	local nLabels = self.tOpt.nXValueLabels
	local maxWidth = self.wnd:GetWidth() - self.tOpt.fYLabelMargin - self.tOpt.fPlotMargin
	local maxHeight = self.wnd:GetHeight() - self.tOpt.fXLabelMargin - self.tOpt.fPlotMargin
	
	if self.tOpt.eCoordinateSystem == self.CARTESIAN or self.tOpt.bPolarGridLines == false then
		local fXRange = self.fXMax - self.fXMin
		local fInterval = fXRange / nLabels
		for i=0,nLabels do
			local fPos = i * fInterval / fXRange * maxWidth
			self:DrawLine(
				{
					x1 = self.tOpt.fYLabelMargin + fPos,
					y1 = self.tOpt.fXLabelMargin,
					x2 = self.tOpt.fYLabelMargin + fPos,
					y2 = self.wnd:GetHeight() - self.tOpt.fPlotMargin
				},
				"",
				self.tOpt.fXGridLineWidth,
				nil,
				self.tOpt.clrXGridLine
			)
		end
	elseif self.tOpt.eCoordinateSystem == self.POLAR and self.tOpt.bPolarGridLines == true then
		local x1 = (0 - self.fXMin) / (self.fXMax - self.fXMin) * maxWidth + self.tOpt.fYLabelMargin
		local y1 = (0 - self.fYMin) / (self.fYMax - self.fYMin) * maxHeight + self.tOpt.fXLabelMargin
		local fInterval = 2*math.pi / nLabels
		for i=0,nLabels-1 do
			local angle = fInterval * i
			local x2, y2 = polToCart(angle, 99999)		-- Hack
			self:DrawLine(
				{
					x1 = x1,
					y1 = y1,
					x2 = x2,
					y2 = y2
				},
				"",
				self.tOpt.fXGridLineWidth,
				nil,
				self.tOpt.clrXGridLine
			)
		end
	end
end

--- Draws Y (horizontal) grid lines with current options.
function PixiePlot:DrawYGridLines()
	local maxHeight = self.wnd:GetHeight() - self.tOpt.fXLabelMargin - self.tOpt.fPlotMargin
	local fYRange = self.fYMax - self.fYMin
	
	local nLabels = self.tOpt.nYValueLabels
	local fInterval = fYRange / nLabels
	for i=0,nLabels do
		local fPos = i * fInterval / fYRange * maxHeight
		self:DrawLine(
			{
				x1 = self.tOpt.fYLabelMargin,
				y1 = self.tOpt.fXLabelMargin + fPos,
				x2 = self.wnd:GetWidth() - self.tOpt.fPlotMargin,
				y2 = self.tOpt.fXLabelMargin + fPos
			},
			"",
			self.tOpt.fYGridLineWidth,
			nil,
			self.tOpt.clrYGridLine
		)
	end
end

--- Adds a line to the canvas.
-- Flips y-axis.
-- @param line A table containing x1,y1,x2,y2 coordinates for the line.
-- @param width Width of the line.
-- @param sprite Sprite to use.
-- @param color A table with keys a, r, g, b. Values should be numbers 0.0-1.0.
function PixiePlot:DrawLine(line, text, width, sprite, color, clrText)
	--Print("Drawing line starting at: " .. line.x1 .. ", " .. line.y1)
	local nPixieId = self.wnd:AddPixie({
		strText = text,
		strFont = self.tOpt.strLabelFont,
		bLine = true,
		fWidth = width,
		strSprite = sprite,
		cr = color,
		crText = clrText,
		loc = {
			fPoints = {0,0,0,0},
			nOffsets = {
				line.x1,
				self.wnd:GetHeight() - line.y1,
				line.x2,
				self.wnd:GetHeight() - line.y2
			}
		},
		flagsText = {
			DT_RIGHT = true--,
			--DT_VCENTER = true
		}
	})
end

--- Adds a symbol to the canvas.
-- Flips y-axis.
-- @param pos A table containing x1,y1,x2,y2 coordinates for the symbol.
-- @param size Width and height of the symbol.
-- @param sprite Sprite to use.
-- @param color A table with keys a, r, g, b. Values should be numbers 0.0-1.0
function PixiePlot:DrawSymbol(pos, size, sprite, color)
	--Print("Drawing symbol at: " .. pos.x .. ", " .. pos.y)
	--Print("Pixie color: " .. 
	local nPixieId = self.wnd:AddPixie({
		strText = "",
		bLine = false,
		--fWidth = width,
		strSprite = sprite,
		cr = color,
		loc = {
			fPoints = {0,0,0,0},
			nOffsets = {
				pos.x - size/2,
				self.wnd:GetHeight() - (pos.y + size/2),
				pos.x + size/2,
				self.wnd:GetHeight() - (pos.y - size/2)
			}
		}
	})
	--Print("Symbol pixieid: " .. tostring(nPixieId))
end

--- Adds a data point tooltip.
-- Flips y-axis.
-- @param pos A table containing x1,y1,x2,y2 coordinates for the tooltip.
-- @param size Width and height of the tooltip. 
function PixiePlot:AddWindowOverlay(pos, size)
	local XmlNode = Apollo.GetPackage("Drafto:Lib:XmlNode-1.1").tPackage
	if not XmlNode then return end
	
	local node = XmlNode:New("PixiePlot:WindowOverlay", "Form", "Window", {
		AnchorPoints = {0,0,0,0},
		AnchorOffsets = {
			pos.x - size/2,
			self.wnd:GetHeight() - (pos.y + size/2),
			pos.x + size/2,
			self.wnd:GetHeight() - (pos.y - size/2)
		}
	})
	local wnd = node:LoadForm(self.wnd, self)
	if not wnd then 
		return 
	end
	
	wnd:AddEventHandler("MouseButtonUp", "OnWndMouseUp", self)
	wnd:AddEventHandler("MouseButtonDown", "OnWndMouseDown", self)
	wnd:AddEventHandler("MouseEnter", "OnWndMouseEnter", self)
	wnd:AddEventHandler("MouseExit", "OnWndMouseExit", self)
	
	wnd:Show(true)
	
	return wnd
end

--- Adds a rectangle to the canvas.
-- Flips y-axis.
-- @param pos A table containing x1,y1,x2,y2 coordinates for the rectangle.
-- @param sprite Sprite to use.
-- @param color A table with keys a, r, g, b. Values should be numbers 0.0-1.0
function PixiePlot:DrawRectangle(rect, sprite, color, clrText, text)
	--Print("Drawing rect: " .. rect.x1 .. ", " .. rect.y1 .." -> " .. rect.x2 .. ", " .. rect.y2)
	
	-- Draw rectangle
	local nPixieId = self.wnd:AddPixie({
		bLine = false,
		strSprite = sprite,
		cr = color,
		loc = {
			fPoints = {0,0,0,0},
			nOffsets = {
				rect.x1,
				self.wnd:GetHeight() - rect.y2,
				rect.x2,
				self.wnd:GetHeight() - rect.y1
			}
		},
		flagsText = {
			DT_VCENTER = true
		},
		fRotation = 0
	})
	
	-- Draw text as a separate pixie so it doesn't get cut off by short bars
	if text ~= nil then
		local x1, x2, y1, y2, lineWidth, DT_VCENTER
		if self.tOpt.eBarOrientation == self.VERTICAL then
			local width = rect.x2 - rect.x1
			lineWidth = 1
			x1 = rect.x1 + width / 2 - 10
			x2 = x1
			y2 = rect.y1 + 3
			y1 = self.wnd:GetHeight() - self.tOpt.fPlotMargin
			DT_VCENTER = true
		else
			local height = rect.y2 - rect.y1
			lineWidth = 1
			y1 = rect.y1 + height / 2 + 10
			y2 = y1
			x1 = rect.x1 + 3
			x2 = self.wnd:GetWidth() - self.tOpt.fPlotMargin
			DT_VCENTER = false
		end
		local nPixieId = self.wnd:AddPixie({
			strText = text,
			strFont = self.tOpt.strBarFont,
			bLine = true,
			fWidth = lineWidth,
			strSprite = "WhiteFill",
			cr = clrClear,
			crText = clrText,
			loc = {
				fPoints = {0,0,0,0},
				nOffsets = {
					x1,
					self.wnd:GetHeight() - y2,
					x2,
					self.wnd:GetHeight() - y1
				}
			},
			flagsText = {
				DT_VCENTER = false
			},
			fRotation = 0
		})
	end
end

--- Updates max/min viewbox values using the given dataSet.
-- @param dataSet The dataSet to update max/min values with.
function PixiePlot:UpdateMinMaxValues(dataSet)
	if self.tOpt.ePlotStyle == self.LINE or self.tOpt.ePlotStyle == self.STEM then
		for i,v in ipairs(dataSet.values) do
			if v == math.huge then v = 0 end
			local x = dataSet.xStart + (i - 1) * self.fXInterval
			if self.tOpt.eCoordinateSystem == self.POLAR then
				x = dataSet.xStart + (i - 2) * self.fXInterval
				x, v = polToCart(x, v)
			end
			if self.fXMin == nil or x < self.fXMin then self.fXMin = x end
			if self.fXMax == nil or x > self.fXMax then self.fXMax = x end
			if self.fYMin == nil or v < self.fYMin then self.fYMin = v end
			if self.fYMax == nil or v > self.fYMax then self.fYMax = v end
		end
	elseif self.tOpt.ePlotStyle == self.SCATTER then
		for i,v in pairs(dataSet.values) do
			if v == math.huge then v = 0 end
			if self.fXMin == nil or v.x < self.fXMin then self.fXMin = v.x end
			if self.fXMax == nil or v.x > self.fXMax then self.fXMax = v.x end
			if self.fYMin == nil or v.y < self.fYMin then self.fYMin = v.y end
			if self.fYMax == nil or v.y > self.fYMax then self.fYMax = v.y end
		end
	elseif self.tOpt.ePlotStyle == self.BAR then
		self.fXMin = 0
		self.fXMax = 1
		self.fYMin = 0
		self.nNumDataSets = self.nNumDataSets + 1
		for i,v in ipairs(dataSet.values) do
			if self.fYMax == nil or v > self.fYMax then self.fYMax = v end
		end
	end
end

--- Internal event handler for data point events
function PixiePlot:OnWndMouseDown(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	local tData = wndHandler:GetData()
	if tData and self.tOpt.wndOverlayMouseEventCallback then
		self.tOpt.wndOverlayMouseEventCallback(tData, PixiePlot.MOUSE_DOWN)
	end
end

--- Internal event handler for data point events
function PixiePlot:OnWndMouseUp(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	local tData = wndHandler:GetData()
	if tData and self.tOpt.wndOverlayMouseEventCallback then
		self.tOpt.wndOverlayMouseEventCallback(tData, PixiePlot.MOUSE_UP)
	end
end

--- Internal event handler for data point events
function PixiePlot:OnWndMouseEnter(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	local tData = wndHandler:GetData()
	if tData and self.tOpt.wndOverlayMouseEventCallback then
		self.tOpt.wndOverlayMouseEventCallback(tData, PixiePlot.MOUSE_ENTER)
	end
end

--- Internal event handler for data point events
function PixiePlot:OnWndMouseExit(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	local tData = wndHandler:GetData()
	if tData and self.tOpt.wndOverlayMouseEventCallback then
		self.tOpt.wndOverlayMouseEventCallback(tData, PixiePlot.MOUSE_EXIT)
	end
end

--- Generates a dataSet from the given function(s). If func2 is given, the dataSet will be for a scatter plot.
-- @param fXStart The starting x-value.
-- @param fXEnd The ending x-value.
-- @param fXInterval The x-interval to use.
-- @param func The function to use for generating y-values, or x-values in a scatter plot if func2 is given.
-- @param func (optional) The function to use for generating y-values in a scatter plot.
function PixiePlot:GenerateDataSet(fXStart, fXEnd, fXInterval, func, func2)
	local dataSet = {
		xStart = fXStart,
		values = {}
	}
	for x=fXStart,fXEnd,fXInterval do
		if func2 then
			table.insert(dataSet.values, {
				x = func(x),
				y = func2(x)
			})
		else
			table.insert(dataSet.values, func(x))
		end
	end
	return dataSet
end

--- Utility for getting number of keys in a table
function PixiePlot:GetTableSize(tbl)
	local count = 0
	for _ in pairs(tbl) do count = count + 1 end
	return count
end

-- "Constructor"
-- @deprecated Use PixiePlot:New(wndContainer, tOpt)
-- @param wndContainer The container for the graph. All of its content may be used so don't put anything in it; just a background.
setmetatable(PixiePlot, {
	__call = function(self, wndContainer, tOpt)
		local pp = {
			wnd = wndContainer
		}
		
		-- Plotting variables
		pp.dataSets = {}			-- This is not an array, though it does use integer keys.
		pp.nNumDataSets = 0			-- Current number of dataSets (only used for bar graphs)
		pp.nDataSets = 0			-- Counter for dataSet id's
		pp.fXInterval = 1			-- x-distance between dataSet values
		pp.fXMin = nil				-- Left plot viewbox bound
		pp.fXMax = nil				-- Right plot viewbox bound
		pp.fYMin = nil				-- Top plot viewbox bound
		pp.fYMax = nil				-- Bottom plot viewbox bound
		
		-- Plotting Options
		if tOpt then
			pp.tOpt = tOpt
		else
			pp.tOpt = tDefaultOptions
		end
		return setmetatable(pp, {__index = PixiePlot})
	end
})

-- Default options
local tDefaultOptions = {
	ePlotStyle = PixiePlot.LINE,
	eCoordinateSystem = PixiePlot.CARTESIAN,
	
	fYLabelMargin = 25,
	fXLabelMargin = 25,
	fPlotMargin = 10,
	strXLabel = "",
	strYLabel = "",
	bDrawXAxisLabel = false,
	bDrawYAxisLabel = false,
	nXValueLabels = 8,
	nYValueLabels = 8,
	bDrawXValueLabels = false,
	bDrawYValueLabels = false,
	bPolarGridLines = false,
	bDrawXGridLines = false,
	bDrawYGridLines = false,
	fXGridLineWidth = 1,
	fYGridLineWidth = 1,
	clrXGridLine = clrGrey,
	clrYGridLine = clrGrey,
	clrXAxisLabel = clrClear,
	clrYAxisLabel = clrClear,
	clrXValueLabel = clrWhite,
	clrYValueLabel = clrWhite,
	clrXValueBackground = clrClear,
	clrYValueBackground = clrClear,
	fXAxisLabelOffset = 170,
	fYAxisLabelOffset = 120,
	strLabelFont = "CRB_Interface9",
	fXValueLabelTilt = 20,
	fYValueLabelTilt = 0,
	nXLabelDecimals = 1,
	nYLabelDecimals = 1,
	xValueFormatter = nil,
	yValueFormatter = nil,
	
	bDrawXAxis = true,
	bDrawYAxis = true,
	clrXAxis = clrWhite,
	clrYAxis = clrWhite,
	fXAxisWidth = 2,
	fYAxisWidth = 2,
	
	bDrawSymbol = true,
	fSymbolSize = nil,
	strSymbolSprite = "WhiteCircle",
	clrSymbol = nil,
	
	strLineSprite = nil,
	fLineWidth = 3,
	bScatterLine = false,
	
	fBarMargin = 5,			-- Space between bars in each group
	fBarSpacing = 20,		-- Space between groups of bars
	fBarOrientation = PixiePlot.VERTICAL,
	strBarSprite = "WhiteFill",
	strBarFont = "CRB_Interface11",
	clrBarLabel = clrWhite,
	
	bWndOverlays = false,
	fWndOverlaySize = 6,
	wndOverlayMouseEventCallback = nil,
	wndOverlayLoadCallback = nil,
	
	aPlotColors = {
		{a=1,r=0.858,g=0.368,b=0.53},
		{a=1,r=0.363,g=0.858,b=0.500},
		{a=1,r=0.858,g=0.678,b=0.368},
		{a=1,r=0.368,g=0.796,b=0.858},
		{a=1,r=0.58,g=0.29,b=0.89},
		{a=1,r=0.27,g=0.78,b=0.20}
	}
}

--- Better Constructor
-- @param wndContainer the Window in which to draw the plot
-- @param tOpt The options table to use. It must be completely filled out! If nil, default options are used (recommended).
function PixiePlot:New(wndContainer, tOpt)
	-- Make a new PixiePlot object
	local this = {
		wnd = wndContainer
	}
	
	-- Set plotting variables
	this.dataSets = {}				-- This is not an array, though it does use integer keys.
	this.nNumDataSets = 0			-- Current number of dataSets (only used for bar graphs)
	this.nDataSets = 0				-- Counter for dataSet id's
	this.fXInterval = 1				-- x-distance between dataSet values
	this.fXMin = nil				-- Left plot viewbox bound
	this.fXMax = nil				-- Right plot viewbox bound
	this.fYMin = nil				-- Top plot viewbox bound
	this.fYMax = nil				-- Bottom plot viewbox bound
	
	-- Set plotting options
	if tOpt then
		this.tOpt = tOpt
	else
		this.tOpt = tDefaultOptions
	end
	
	-- Inheritance
    setmetatable(this, self)
    self.__index = self 
    return this
end

-- Register Library
Apollo.RegisterPackage(PixiePlot, "Drafto:Lib:PixiePlot-1.4", 3, {"Drafto:Lib:XmlNode-1.1"})
