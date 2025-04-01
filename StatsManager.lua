-- StatsManager.lua
-- Handles player stats and calculations
local StatsManager = {}
StatsManager.__index = StatsManager

-- Define default values
local DEFAULT_STATS = {
	health = 100,
	maxHealth = 100,
	stamina = 100,
	maxStamina = 100,
	strength = 10,
	attackSpeed = 1, -- Default attack speed multiplier
	movementSpeed = 16,
	defense = 0,
	resistance = 0,
	potency = 1,     -- Default potency multiplier (1 means no change)
	healthRegenRate = 0,
	staminaRegenRate = 0,
	staminaBurst = 0,
	magicProficiency = 0
}

-- Helper function for deep copying a table (same as before)
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

function StatsManager.new(centralData)
	local self = setmetatable({}, StatsManager)

	-- Reference to central data
	self.centralData = centralData
	self.playerId = centralData.playerId

	-- Core stats
	self.health = DEFAULT_STATS.health
	self.maxHealth = DEFAULT_STATS.maxHealth
	self.stamina = DEFAULT_STATS.stamina
	self.maxStamina = DEFAULT_STATS.maxStamina
	self.overhealth = 0

	-- Stat tables
	self.baseStats = deepCopy(DEFAULT_STATS)
	self.currentStats = deepCopy(DEFAULT_STATS)

	-- Cache for optimization (you can use this later if needed)
	self._cache = {}

	return self
end

-- Apply modifiers to stats (same as before)
function StatsManager:_applyModifiers(stats, modifiers, add)
	local factor = add and 1 or -1

	for statName, modifier in pairs(modifiers) do
		if stats[statName] then
			if type(modifier) == "table" then
				-- Handle nested modifiers
				for subStatName, subModifier in pairs(modifier) do
					if stats[subStatName] then
						stats[subStatName] = stats[subStatName] + (subModifier * factor)
					end
				end
			else
				stats[statName] = stats[statName] + (modifier * factor)
			end
		end
	end

	return stats
end

-- Calculate specific affected stats (modified to include all stats)
function StatsManager:recalculateAffectedStats(affectedSources)
	local oldStats = table.clone(self.currentStats)
	local newCalculatedStats = deepCopy(self.baseStats)

	-- Get all stat modifiers from equipment if equipment was affected
	if affectedSources.equipment then
		for _, item in pairs(self.centralData.equipment:getAllItems()) do
			if item and item.statModifiers then
				self:_applyModifiers(newCalculatedStats, item.statModifiers, true)
			end
		end
	end

	-- Apply aspect passives if aspect was affected
	if affectedSources.aspect then
		local aspectPassives = self.centralData.aspects:getAspectPassives()
		if aspectPassives then
			self:_applyModifiers(newCalculatedStats, aspectPassives, true)
		end
	end

	-- Apply sub-aspect passives if sub-aspect was affected
	if affectedSources.subAspect then
		local subAspectPassives = self.centralData.aspects:getSubAspectPassives()
		if subAspectPassives then
			self:_applyModifiers(newCalculatedStats, subAspectPassives, true)
		end
	end

	-- Update current stats
	self.currentStats = newCalculatedStats

	-- Update dependent values (make sure all your new max stats are included)
	self.maxHealth = self.currentStats.maxHealth
	self.maxStamina = self.currentStats.maxStamina

	-- Clamp current health and stamina to new maximums
	self.health = math.min(self.health, self.maxHealth)
	self.stamina = math.min(self.stamina, self.maxStamina)

	-- Fire stat modified event
	local changedStats = {}
	for statName, oldValue in pairs(oldStats) do
		if self.currentStats[statName] ~= oldValue then
			changedStats[statName] = {old = oldValue, new = self.currentStats[statName]}
		end
	end

	if next(changedStats) then
		self.centralData.Events.StatsModified:Fire(self.playerId, oldStats, self.currentStats)
	end

	return self.currentStats
end

-- Full recalculation of all stats (same as before)
function StatsManager:recalculateAllStats()
	return self:recalculateAffectedStats({
		equipment = true,
		aspect = true,
		subAspect = true
	})
end

-- Health management (same as before)
function StatsManager:updateHealth(amount)
	local oldHealth = self.health
	self.health = math.clamp(self.health + amount, 0, self.maxHealth)
	self.centralData.Events.HealthChanged:Fire(self.playerId, oldHealth, self.health)
	return self.health
end

function StatsManager:setHealth(value)
	return self:updateHealth(value - self.health)
end

-- Stamina management (same as before)
function StatsManager:updateStamina(amount)
	local oldStamina = self.stamina
	self.stamina = math.clamp(self.stamina + amount, 0, self.maxStamina)
	self.centralData.Events.StaminaChanged:Fire(self.playerId, oldStamina, self.stamina)
	return self.stamina
end

function StatsManager:setStamina(value)
	return self:updateStamina(value - self.stamina)
end

-- Overhealth management (same as before)
function StatsManager:setOverhealth(value)
	local oldValue = self.overhealth
	self.overhealth = math.max(0, value)
	self.centralData.states:setState("hasOverhealth", self.overhealth > 0)
	self.centralData.Events.OverhealthChanged:Fire(self.playerId, oldValue, self.overhealth)
	return self.overhealth
end

-- Base stat management (modified to include all new stats)
function StatsManager:setBaseStat(statName, value)
	if self.baseStats[statName] == nil then
		warn("Invalid stat name:", statName)
		return false
	end

	self.baseStats[statName] = value

	-- Recalculate stats affected by this change
	self:recalculateAllStats()

	return true
end

function StatsManager:getBaseStat(statName)
	return self.baseStats[statName]
end

function StatsManager:getCurrentStat(statName)
	return self.currentStats[statName]
end

-- Regeneration (new functions)
function StatsManager:regenerateHealth(deltaTime)
	local regenAmount = self.currentStats.healthRegenRate * deltaTime
	if regenAmount ~= 0 then
		self:updateHealth(regenAmount)
	end
end

function StatsManager:regenerateStamina(deltaTime)
	local regenAmount = self.currentStats.staminaRegenRate * deltaTime
	if regenAmount ~= 0 then
		self:updateStamina(regenAmount)
	end
end

-- Get Stamina Burst (new function)
function StatsManager:getStaminaBurstAmount()
	return self.currentStats.staminaBurst
end

-- Magic Proficiency (new function)
function StatsManager:getMagicProficiency()
	return self.currentStats.magicProficiency
end

function StatsManager:setMagicProficiency(value)
	local oldValue = self.currentStats.magicProficiency
	self.baseStats.magicProficiency = value -- Update base stat as well for saving
	self:recalculateAllStats() -- Recalculate to update current stat
	-- You might want to fire a specific event for magic proficiency change if needed
	return true
end

-- Reset stats (modified to include all new stats)
function StatsManager:reset(fullReset)
	-- Reset health, stamina, and overhealth to max/default
	self.health = self.maxHealth
	self.stamina = self.maxStamina
	self.overhealth = 0

	if fullReset then
		-- Reset base stats to default
		self.baseStats = deepCopy(DEFAULT_STATS)

		-- Reset current stats
		self.currentStats = deepCopy(DEFAULT_STATS)

		-- Reset dependent values
		self.maxHealth = DEFAULT_STATS.maxHealth
		self.maxStamina = DEFAULT_STATS.maxStamina
	end

	-- Fire events
	self.centralData.Events.HealthChanged:Fire(self.playerId, 0, self.health)
	self.centralData.Events.StaminaChanged:Fire(self.playerId, 0, self.stamina)
	self.centralData.Events.OverhealthChanged:Fire(self.playerId, 0, 0)
	self.centralData.Events.StatsModified:Fire(self.playerId, {}, self.currentStats) -- Always fire on reset

	return true
end

-- Serialization (modified to include all new stats)
function StatsManager:serialize()
	return {
		health = self.health,
		maxHealth = self.maxHealth,
		stamina = self.stamina,
		maxStamina = self.maxStamina,
		overhealth = self.overhealth,
		baseStats = deepCopy(self.baseStats),
		currentStats = deepCopy(self.currentStats)
	}
end

-- Deserialization (modified to include all new stats)
function StatsManager:deserialize(data)
	if not data then return false end

	self.health = data.health or DEFAULT_STATS.health
	self.maxHealth = data.maxHealth or DEFAULT_STATS.maxHealth
	self.stamina = data.stamina or DEFAULT_STATS.stamina
	self.maxStamina = data.maxStamina or DEFAULT_STATS.maxStamina
	self.overhealth = data.overhealth or 0

	-- Load stats
	if data.baseStats then
		for statName, value in pairs(data.baseStats) do
			self.baseStats[statName] = value
		end
	end

	if data.currentStats then
		for statName, value in pairs(data.currentStats) do
			self.currentStats[statName] = value
		end
	end

	-- After loading, ensure dependent values are updated
	self.maxHealth = self.currentStats.maxHealth
	self.maxStamina = self.currentStats.maxStamina

	return true
end

return StatsManager
