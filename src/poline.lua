-- Quick and dirty port of the Poline TypeScript library to (Roblox) Luau

export type Vector2 = { [number]: number }
export type Vector3 = { [number]: number }
export type PartialVector3 = { [number]: number | nil }
export type PositionFunction = (t: number, reverse: boolean?) -> number
export type ColorPointCollection = { xyz: Vector3?, color: Vector3?, invertedLightness: boolean? }
export type ColorPoint = {
	x: number,
	y: number,
	z: number,
	color: Vector3,
	_invertedLightness: boolean,
}
export type PolineOptions = {
	anchorColors: { Vector3 }?,
	numPoints: number?,
	positionFunction: PositionFunction?,
	positionFunctionX: PositionFunction?,
	positionFunctionY: PositionFunction?,
	positionFunctionZ: PositionFunction?,
	invertedLightness: boolean?,
	closedLoop: boolean?,
}

-- Utility functions
local function pointToHSL(xyz: Vector3, invertedLightness: boolean): Vector3
	local x, y, z = table.unpack(xyz)

	local cx = 0.5
	local cy = 0.5

	local radians = math.atan2(y - cy, x - cx)

	local deg = radians * (180 / math.pi)
	deg = (360 + deg) % 360

	local s = math.clamp(z, 0, 1)

	local dist = math.sqrt((y - cy) ^ 2 + (x - cx) ^ 2)
	local l = math.clamp(dist / cx, 0, 1)

	return { deg, s, invertedLightness and (1 - l) or l }
end

local function hslToPoint(hsl: Vector3, invertedLightness: boolean): Vector3
	local h, s, l = table.unpack(hsl)

	local cx = 0.5
	local cy = 0.5

	local radians = h / (180 / math.pi)

	local dist = (invertedLightness and (1 - l) or l) * cx

	local x = cx + dist * math.cos(radians)
	local y = cy + dist * math.sin(radians)

	local z = s

	return { x, y, z }
end

local function hueToRgb(p: number, q: number, t: number): number
	if t < 0 then
		t = t + 1
	end
	if t > 1 then
		t = t - 1
	end
	if t < 1 / 6 then
		return p + (q - p) * 6 * t
	end
	if t < 1 / 2 then
		return q
	end
	if t < 2 / 3 then
		return p + (q - p) * (2 / 3 - t) * 6
	end
	return p
end

local function hslToRgb(h, s, l)
	h = h % 360
	s = math.clamp(s, 0, 1)
	l = math.clamp(l, 0, 1)

	local r, g, b

	if s == 0 then
		r, g, b = l, l, l
	else
		local q = l < 0.5 and l * (1 + s) or l + s - l * s
		local p = 2 * l - q

		r = hueToRgb(p, q, (h / 360 + 1 / 3) % 1)
		g = hueToRgb(p, q, h / 360)
		b = hueToRgb(p, q, (h / 360 - 1 / 3) % 1)
	end

	return r, g, b
end

-- Position functions
local function linearPosition(t: number): number
	return t
end

local function exponentialPosition(t: number, reverse: boolean?): number
	if reverse then
		return 1 - (1 - t) ^ 2
	end
	return t ^ 2
end

local function quadraticPosition(t: number, reverse: boolean?): number
	if reverse then
		return 1 - (1 - t) ^ 3
	end
	return t ^ 3
end

local function cubicPosition(t: number, reverse: boolean?): number
	if reverse then
		return 1 - (1 - t) ^ 4
	end
	return t ^ 4
end

local function quarticPosition(t: number, reverse: boolean?): number
	if reverse then
		return 1 - (1 - t) ^ 5
	end
	return t ^ 5
end

local function sinusoidalPosition(t: number, reverse: boolean?): number
	if reverse then
		return 1 - math.sin(((1 - t) * math.pi) / 2)
	end
	return math.sin((t * math.pi) / 2)
end

local function asinusoidalPosition(t: number, reverse: boolean?): number
	if reverse then
		return 1 - math.asin(1 - t) / (math.pi / 2)
	end
	return math.asin(t) / (math.pi / 2)
end

local function arcPosition(t: number, reverse: boolean?): number
	if reverse then
		return math.sqrt(1 - (1 - t) ^ 2)
	end
	return 1 - math.sqrt(1 - t)
end

local function smoothStepPosition(t: number): number
	return t ^ 2 * (3 - 2 * t)
end

local positionFunctions = {
	linearPosition = linearPosition,
	exponentialPosition = exponentialPosition,
	quadraticPosition = quadraticPosition,
	cubicPosition = cubicPosition,
	quarticPosition = quarticPosition,
	sinusoidalPosition = sinusoidalPosition,
	asinusoidalPosition = asinusoidalPosition,
	arcPosition = arcPosition,
	smoothStepPosition = smoothStepPosition,
}

local function distance(p1: PartialVector3, p2: PartialVector3, hueMode: boolean?): number
	local a1 = p1[1]
	local a2 = p2[1]
	local diffA = 0

	if hueMode and a1 ~= nil and a2 ~= nil then
		diffA = math.min(math.abs(a1 - a2), 360 - math.abs(a1 - a2))
		diffA = diffA / 360
	else
		diffA = (a1 == nil or a2 == nil) and 0 or (a1 - a2)
	end

	local a = diffA
	local b = (p1[2] == nil or p2[2] == nil) and 0 or (p2[2] - p1[2])
	local c = (p1[3] == nil or p2[3] == nil) and 0 or (p2[3] - p1[3])

	return math.sqrt(a * a + b * b + c * c)
end

-- Helper functions to generate random HSL values
local function randomHSLPair(startHue: number?, saturations: Vector2?, lightnesses: Vector2?): { Vector3 }
	startHue = startHue or (math.random() * 360)
	saturations = saturations or { math.random(), math.random() * 0.5 }
	lightnesses = lightnesses or { 0.75 + math.random() * 0.2, 0.3 + math.random() * 0.2 }

	return {
		{ startHue, saturations[1], lightnesses[1] },
		{ (startHue + 60 + math.random() * 180) % 360, saturations[2], lightnesses[2] },
	}
end

local function randomHSLTriple(startHue: number?, saturations: Vector3?, lightnesses: Vector3?): { Vector3 }
	startHue = startHue or (math.random() * 360)
	saturations = saturations or { math.random(), math.random() * 0.5, math.random() * 0.75 }
	lightnesses = lightnesses or { 0.6 + math.random() * 0.2, 0.1 + math.random() * 0.3, 0.6 + math.random() * 0.2 }

	return {
		{ startHue, saturations[1], lightnesses[1] },
		{ (startHue + 60 + math.random() * 180) % 360, saturations[2], lightnesses[2] },
		{ (startHue + 60 + math.random() * 180) % 360, saturations[3], lightnesses[3] },
	}
end

local function vectorOnLine(
	t: number,
	p1: Vector3,
	p2: Vector3,
	invert: boolean?,
	fx: (t: number, invert: boolean?) -> number?,
	fy: (t: number, invert: boolean?) -> number?,
	fz: (t: number, invert: boolean?) -> number?
): Vector3
	local tModifiedX = fx and fx(t, invert) or (invert and (1 - t) or t)
	local tModifiedY = fy and fy(t, invert) or (invert and (1 - t) or t)
	local tModifiedZ = fz and fz(t, invert) or (invert and (1 - t) or t)

	local x = (1 - tModifiedX) * p1[1] + tModifiedX * p2[1]
	local y = (1 - tModifiedY) * p1[2] + tModifiedY * p2[2]
	local z = (1 - tModifiedZ) * p1[3] + tModifiedZ * p2[3]

	return { x, y, z }
end

local function vectorsOnLine(
	p1: Vector3,
	p2: Vector3,
	numPoints: number?,
	invert: boolean?,
	fx: (t: number, invert: boolean?) -> number?,
	fy: (t: number, invert: boolean?) -> number?,
	fz: (t: number, invert: boolean?) -> number?
): { Vector3 }
	numPoints = numPoints or 4
	local points = {}

	for i = 1, numPoints do
		local t = (i - 1) / (numPoints - 1)
		local point = vectorOnLine(t, p1, p2, invert, fx, fy, fz)
		table.insert(points, point)
	end

	return points
end

local ColorPoint = {}
ColorPoint.__index = ColorPoint

function ColorPoint.new(params: ColorPointCollection): ColorPoint
	local self = setmetatable({}, ColorPoint)
	self.x = 0
	self.y = 0
	self.z = 0
	self.color = { 0, 0, 0 }
	self._invertedLightness = params.invertedLightness or false

	self:positionOrColor(params)
	return self
end

function ColorPoint:positionOrColor(params: ColorPointCollection)
	if params.xyz and params.color then
		error("Point must be initialized with either x,y,z or hsl")
	elseif params.xyz then
		self.x = params.xyz[1]
		self.y = params.xyz[2]
		self.z = params.xyz[3]
		self.color = pointToHSL({ self.x, self.y, self.z }, params.invertedLightness or false)
	elseif params.color then
		self.color = params.color
		local xyz = hslToPoint(params.color, params.invertedLightness or false)
		self.x = xyz[1]
		self.y = xyz[2]
		self.z = xyz[3]
	end
end

function ColorPoint:setPosition(xyz: Vector3)
	self.x = xyz[1]
	self.y = xyz[2]
	self.z = xyz[3]
	self.color = pointToHSL({ self.x, self.y, self.z }, self._invertedLightness)
end

function ColorPoint:getPosition(): Vector3
	return { self.x, self.y, self.z }
end

function ColorPoint:setHSL(hsl: Vector3)
	self.color = hsl
	local xyz = hslToPoint(hsl, self._invertedLightness)
	self.x = xyz[1]
	self.y = xyz[2]
	self.z = xyz[3]
end

function ColorPoint:getHSL(): Vector3
	return self.color
end

function ColorPoint:getRGB(): Vector3
	local h, s, l = table.unpack(self.color)
	local r, g, b = hslToRgb(h, s, l)
	return Color3.new(r, g, b)
end

function ColorPoint:shiftHue(angle: number)
	self.color[1] = (360 + (self.color[1] + angle)) % 360
	local xyz = hslToPoint(self.color, self._invertedLightness)
	self.x = xyz[1]
	self.y = xyz[2]
	self.z = xyz[3]
end

local Poline = {}
Poline.__index = Poline

function Poline.new(params: PolineOptions): Poline
	local self = setmetatable({}, Poline)

	self._needsUpdate = true
	self._anchorPoints = {}
	self._numPoints = (params.numPoints or 4) + 2
	self.points = {}
	self._positionFunctionX = params.positionFunctionX or params.positionFunction or sinusoidalPosition
	self._positionFunctionY = params.positionFunctionY or params.positionFunction or sinusoidalPosition
	self._positionFunctionZ = params.positionFunctionZ or params.positionFunction or sinusoidalPosition
	self._anchorPairs = {}
	self.connectLastAndFirstAnchor = params.closedLoop or false
	self._invertedLightness = params.invertedLightness or false

	local anchorColors = params.anchorColors or randomHSLPair()
	if #anchorColors < 2 then
		error("Must have at least two anchor colors")
	end

	for _, color in ipairs(anchorColors) do
		table.insert(self._anchorPoints, ColorPoint.new({ color = color, invertedLightness = self._invertedLightness }))
	end

	self:updateAnchorPairs()
	return self
end

function Poline:updateAnchorPairs()
	self._anchorPairs = {}

	local anchorPointsLength = if self.connectLastAndFirstAnchor then #self._anchorPoints else (#self._anchorPoints - 1)

	for i = 1, anchorPointsLength do
		local nextIndex
		if i == #self._anchorPoints then
			nextIndex = 1
		else
			nextIndex = i + 1
		end

		local pair = {
			self._anchorPoints[i],
			self._anchorPoints[nextIndex],
		}
		table.insert(self._anchorPairs, pair)
	end

	self.points = {}
	for i, pair in ipairs(self._anchorPairs) do
		local p1position = pair[1] and pair[1]:getPosition() or { 0, 0, 0 }
		local p2position = pair[2] and pair[2]:getPosition() or { 0, 0, 0 }

		local points = vectorsOnLine(
			p1position,
			p2position,
			self._numPoints,
			i % 2 == 0,
			self._positionFunctionX,
			self._positionFunctionY,
			self._positionFunctionZ
		)

		local colorPoints = {}
		for _, p in ipairs(points) do
			table.insert(colorPoints, ColorPoint.new({ xyz = p, invertedLightness = self._invertedLightness }))
		end

		table.insert(self.points, colorPoints)
	end
end

function Poline:getNumPoints(): number
	return self._numPoints - 2
end

function Poline:setNumPoints(numPoints: number)
	if numPoints < 1 then
		error("Must have at least one point")
	end
	self._numPoints = numPoints + 2
	self:updateAnchorPairs()
end

function Poline:getPositionFunction(): PositionFunction | { PositionFunction }
	if self._positionFunctionX == self._positionFunctionY and self._positionFunctionX == self._positionFunctionZ then
		return self._positionFunctionX
	end

	return { self._positionFunctionX, self._positionFunctionY, self._positionFunctionZ }
end

function Poline:setPositionFunction(positionFunction: PositionFunction | { PositionFunction })
	if type(positionFunction) == "table" then
		if #positionFunction ~= 3 then
			error("Position function array must have 3 elements")
		end
		self._positionFunctionX = positionFunction[1]
		self._positionFunctionY = positionFunction[2]
		self._positionFunctionZ = positionFunction[3]
	else
		self._positionFunctionX = positionFunction
		self._positionFunctionY = positionFunction
		self._positionFunctionZ = positionFunction
	end

	self:updateAnchorPairs()
end

function Poline:getAnchorPoints(): { ColorPoint }
	return self._anchorPoints
end

function Poline:setAnchorPoints(anchorPoints: { ColorPoint })
	self._anchorPoints = anchorPoints
	self:updateAnchorPairs()
end

function Poline:addAnchorPoint(params: {
	xyz: Vector3?,
	color: Vector3?,
	insertAtIndex: number?,
	invertedLightness: boolean?,
}): ColorPoint
	local newAnchor = ColorPoint.new({
		xyz = params.xyz,
		color = params.color,
		invertedLightness = params.invertedLightness or self._invertedLightness,
	})

	if params.insertAtIndex then
		table.insert(self._anchorPoints, params.insertAtIndex, newAnchor)
	else
		table.insert(self._anchorPoints, newAnchor)
	end

	self:updateAnchorPairs()
	return newAnchor
end

function Poline:removeAnchorPoint(params: { point: ColorPoint?, index: number? })
	if not params.point and params.index == nil then
		error("Must provide a point or index")
	end

	local apid

	if params.index ~= nil then
		apid = params.index
	elseif params.point then
		for i, p in ipairs(self._anchorPoints) do
			if p == params.point then
				apid = i
				break
			end
		end
	end

	if apid and apid > 0 and apid <= #self._anchorPoints then
		table.remove(self._anchorPoints, apid)
		self:updateAnchorPairs()
	else
		error("Point not found")
	end
end

function Poline:updateAnchorPoint(
	params: { point: ColorPoint?, pointIndex: number?, xyz: Vector3?, color: Vector3? }
): ColorPoint
	local point = params.point

	if params.pointIndex then
		point = self._anchorPoints[params.pointIndex]
	end

	if not point then
		error("Must provide a point or pointIndex")
	end

	if not params.xyz and not params.color then
		error("Must provide a new xyz position or color")
	end

	if params.xyz then
		point:setPosition(params.xyz)
	end

	if params.color then
		point:setHSL(params.color)
	end

	self:updateAnchorPairs()
	return point
end

function Poline:getClosestAnchorPoint(
	params: { xyz: PartialVector3?, hsl: PartialVector3?, maxDistance: number? }
): ColorPoint | nil
	if not params.xyz and not params.hsl then
		error("Must provide a xyz or hsl")
	end

	local distances = {}

	if params.xyz then
		for _, anchor in ipairs(self._anchorPoints) do
			table.insert(distances, distance(anchor:getPosition(), params.xyz))
		end
	elseif params.hsl then
		for _, anchor in ipairs(self._anchorPoints) do
			table.insert(distances, distance(anchor:getHSL(), params.hsl, true))
		end
	end

	local minDistance = math.huge
	local minIndex = 1

	for i, dist in ipairs(distances) do
		if dist < minDistance then
			minDistance = dist
			minIndex = i
		end
	end

	if minDistance > (params.maxDistance or 1) then
		return nil
	end

	return self._anchorPoints[minIndex]
end

function Poline:setClosedLoop(newStatus: boolean)
	self.connectLastAndFirstAnchor = newStatus
	self:updateAnchorPairs()
end

function Poline:getClosedLoop(): boolean
	return self.connectLastAndFirstAnchor
end

function Poline:setInvertedLightness(newStatus: boolean)
	self._invertedLightness = newStatus
	self:updateAnchorPairs()
end

function Poline:getInvertedLightness(): boolean
	return self._invertedLightness
end

function Poline:getFlattenedPoints(): { ColorPoint }
	local flatPoints = {}
	for _, segment in ipairs(self.points) do
		for _, point in ipairs(segment) do
			table.insert(flatPoints, point)
		end
	end

	local result = {}
	for i, point in ipairs(flatPoints) do
		if i == 1 or (i - 1) % self._numPoints ~= 0 then
			table.insert(result, point)
		end
	end

	return result
end

function Poline:getColors(): { Vector3 }
	local colors = {}
	local flattenedPoints = self:getFlattenedPoints()

	for _, point in ipairs(flattenedPoints) do
		table.insert(colors, point:getHSL())
	end

	if self.connectLastAndFirstAnchor then
		table.remove(colors)
	end

	return colors
end

function Poline:getRGBColors(): { Color3 }
	local colors = {}
	local flattenedPoints = self:getFlattenedPoints()

	for _, point in ipairs(flattenedPoints) do
		table.insert(colors, point:getRGB())
	end

	if self.connectLastAndFirstAnchor then
		table.remove(colors)
	end

	return colors
end

function Poline:shiftHue(hShift: number?)
	hShift = hShift or 20
	for _, point in ipairs(self._anchorPoints) do
		point:shiftHue(hShift)
	end
	self:updateAnchorPairs()
end

return {
	ColorPoint = ColorPoint,
	Poline = Poline,
	pointToHSL = pointToHSL,
	hslToPoint = hslToPoint,
	positionFunctions = positionFunctions,
	distance = distance,
	randomHSLPair = randomHSLPair,
	randomHSLTriple = randomHSLTriple,
}
