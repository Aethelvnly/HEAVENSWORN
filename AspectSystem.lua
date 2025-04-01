-- AspectSystem.lua
-- Handles aspects, sub-aspects, and their abilities/passives
local AspectSystem = {}
AspectSystem.__index = AspectSystem

-- Aspect types and their passive benefits
local ASPECTS = {
	Creation = {
		subAspects = {"Forge", "Tide", "Choir", "Architect"},
		passivePerks = {
			-- Define Creation aspect passive perks
			defense = 5,
			resistance = 5
		}
	},
	Chaos = {
		subAspects = {"Ruin", "Wild Card", "Stagnation", "Spiral"},
		passivePerks = {
			-- Define Chaos aspect passive perks
			strength = 10,
			speed = 5
		}
	},
	Null = {
		subAspects = {},
		passivePerks = {
			-- Define Null aspect passive perks
		}
	}
}

-- Sub-aspect passive perks
local SUB_ASPECT_PASSIVES = {
	-- Creation sub-aspects
	Forge = {
		strength = 3,
		defense = 2
	},
	Tide = {
		maxHealth = 20,
		resistance = 3
	},
	Choir = {
		resistance = 5,
		maxStamina = 15
	},
	Architect = {
		defense = 8,
		maxHealth = 10
	},

	-- Chaos sub-aspects
	Ruin = {
		strength = 8,
		defense = -3
	},
	["Wild Card"] = {
		speed = 10,
		maxStamina = 20
	},
	Stagnation = {
		resistance = 10,
		speed = -5
	},
	Spiral = {
		maxHealth = 15,
		strength = 5,
		defense = -2
	}
}

-- Helper function for deep copying a table
local function deepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

function AspectSystem.new(centralData)
	local self = setmetatable({}, AspectSystem)

	-- Reference to central data
	self.centralData = centralData
	self.playerId = centralData.playerId

	-- Aspect data
	self.aspect = nil
	self.subAspect = nil
	self.aspectPassives = {}
	self.subAspectPassives = {}
	self.hasAspectBeenSet = false

	return self
end

-- Aspect management
function AspectSystem:setAspect(aspectName, force)
	if not ASPECTS[aspectName] then
		warn("Invalid aspect name:", aspectName)
		return false
	end

	if self.hasAspectBeenSet and not force then
		warn("Aspect for player " .. self.playerId .. " cannot be changed after initial setting.")
		return false
	end

	local oldAspect = self.aspect
	self.aspect = aspectName
	self.aspectPassives = deepCopy(ASPECTS[aspectName].passivePerks or {})
	self.hasAspectBeenSet = true

	-- Clear sub-aspect if it's not valid for the new aspect
	if self.subAspect and not table.find(ASPECTS[aspectName].subAspects, self.subAspect) then
		self:setSubAspect(nil)
	end

	-- Fire event
	self.centralData.Events.AspectChanged:Fire(self.playerId, oldAspect, aspectName)

	return true
end

function AspectSystem:setSubAspect(subAspectName)
	if not self.aspect then
		warn("Cannot set sub-aspect without a primary aspect")
		return false
	end

	local availableSubAspects = ASPECTS[self.aspect].subAspects

	if subAspectName and (not availableSubAspects or not table.find(availableSubAspects, subAspectName)) then
		warn("Sub-aspect '" .. subAspectName .. "' is not available for the '" .. self.aspect .. "' aspect.")
		return false
	end

	local oldSubAspect = self.subAspect
	self.subAspect = subAspectName

	-- Update sub-aspect passives
	if subAspectName and SUB_ASPECT_PASSIVES[subAspectName] then
		self.subAspectPassives = deepCopy(SUB_ASPECT_PASSIVES[subAspectName])
	else
		self.subAspectPassives = {}
	end

	-- Fire event
	self.centralData.Events.SubAspectChanged:Fire(self.playerId, oldSubAspect, subAspectName)

	return true
end

-- Getters
function AspectSystem:getAspect()
	return self.aspect
end

function AspectSystem:getSubAspect()
	return self.subAspect
end

function AspectSystem:getAspectPassives()
	return self.aspectPassives
end

function AspectSystem:getSubAspectPassives()
	return self.subAspectPassives
end

function AspectSystem:resetAspects()
	local oldAspect = self.aspect
	local oldSubAspect = self.subAspect

	self.aspect = nil
	self.subAspect = nil
	self.aspectPassives = {}
	self.subAspectPassives = {}
	self.hasAspectBeenSet = false

	-- Fire events
	if oldAspect then
		self.centralData.Events.AspectChanged:Fire(self.playerId, oldAspect, nil)
	end

	if oldSubAspect then
		self.centralData.Events.SubAspectChanged:Fire(self.playerId, oldSubAspect, nil)
	end

	return true
end

-- Serialization
function AspectSystem:serialize()
	return {
		aspect = self.aspect,
		subAspect = self.subAspect,
		hasAspectBeenSet = self.hasAspectBeenSet
	}
end

-- Deserialization
function AspectSystem:deserialize(data)
	if not data then return false end

	if data.aspect then
		self:setAspect(data.aspect, true) -- Force set the aspect
	end

	if data.subAspect then
		self:setSubAspect(data.subAspect)
	end

	self.hasAspectBeenSet = data.hasAspectBeenSet or false

	return true
end

-- Export constants
AspectSystem.ASPECTS = ASPECTS
AspectSystem.SUB_ASPECT_PASSIVES = SUB_ASPECT_PASSIVES

return AspectSystem
