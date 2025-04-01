-- AbilityManager.lua
-- Manages ability slots, activation, and effects
local AbilityManager = {}
AbilityManager.__index = AbilityManager

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create or get events folder
local Events = ReplicatedStorage:FindFirstChild("CentralDataEvents")
if not Events then
	Events = Instance.new("Folder")
	Events.Name = "CentralDataEvents"
	Events.Parent = ReplicatedStorage
end

-- Create ability events
local AbilityEvents = {
	AbilityAdded = Events:FindFirstChild("AbilityAdded") or Instance.new("BindableEvent"),
	AbilityRemoved = Events:FindFirstChild("AbilityRemoved") or Instance.new("BindableEvent"),
	AbilityActivated = Instance.new("BindableEvent"),
	AbilityCooldownStarted = Instance.new("BindableEvent"),
	AbilityCooldownEnded = Instance.new("BindableEvent")
}

-- Place events in folder if they don't exist
for name, event in pairs(AbilityEvents) do
	if event.Parent ~= Events then
		event.Name = name
		event.Parent = Events
	end
end

-- Define ability slots and their sources
local ABILITY_SLOTS = {
	E = "Weapon", -- Weapon-based ability
	R = "Weapon", -- Weapon-based ability
	T = "SubAspect", -- Sub-aspect based ability
	Y = "SubAspect", -- Sub-aspect based ability
	G = "SubAspect", -- Sub-aspect based ability
	Z = "SubAspect", -- Sub-aspect based ability
	X = "SubAspect", -- Sub-aspect based ability
	C = "SubAspect"  -- Sub-aspect based ability
}

-- Initialize a new AbilityManager for a player
function AbilityManager.new(playerId)
	local self = setmetatable({}, AbilityManager)
	
	-- Core properties
	self.playerId = playerId
	
	-- Ability system
	self.abilities = {}
	for slot, _ in pairs(ABILITY_SLOTS) do
		self.abilities[slot] = nil
	end
	
	-- Track cooldowns
	self.cooldowns = {}
	
	-- Cache for ability data
	self._cache = {}
	
	return self
end

-- Set an ability to a specific slot
function AbilityManager:setAbility(slot, ability)
	if not ABILITY_SLOTS[slot] then
		warn("Invalid ability slot:", slot)
		return false
	end

	if not ability or not ability.id then
		warn("Invalid ability format")
		return false
	end

	local oldAbility = self.abilities[slot]
	self.abilities[slot] = ability
	
	-- Cancel any ongoing cooldown for the old ability
	if oldAbility and self.cooldowns[slot] then
		self:_clearCooldown(slot)
	end

	-- Fire event
	AbilityEvents.AbilityAdded:Fire(self.playerId, slot, ability)

	return true
end

-- Remove an ability from a slot
function AbilityManager:removeAbility(slot)
	if not ABILITY_SLOTS[slot] then
		warn("Invalid ability slot:", slot)
		return false
	end

	local oldAbility = self.abilities[slot]
	if oldAbility then
		self.abilities[slot] = nil
		
		-- Cancel any ongoing cooldown
		if self.cooldowns[slot] then
			self:_clearCooldown(slot)
		end
		
		AbilityEvents.AbilityRemoved:Fire(self.playerId, slot, oldAbility)
		return true
	end

	return false
end

-- Get an ability from a slot
function AbilityManager:getAbility(slot)
	return self.abilities[slot]
end

-- Get the source of an ability slot
function AbilityManager:getSlotSource(slot)
	return ABILITY_SLOTS[slot]
end

-- Get all abilities from a specific source
function AbilityManager:getAbilitiesBySource(source)
	local result = {}
	
	for slot, slotSource in pairs(ABILITY_SLOTS) do
		if slotSource == source and self.abilities[slot] then
			result[slot] = self.abilities[slot]
		end
	end
	
	return result
end

-- Clear all abilities from a specific source
function AbilityManager:clearAbilitiesBySource(source)
	for slot, slotSource in pairs(ABILITY_SLOTS) do
		if slotSource == source and self.abilities[slot] then
			self:removeAbility(slot)
		end
	end
end

-- Activate an ability
function AbilityManager:activateAbility(slot, targetPosition, targetEntity)
	local ability = self.abilities[slot]
	
	if not ability then
		warn("No ability in slot:", slot)
		return false
	end
	
	-- Check if ability is on cooldown
	if self.cooldowns[slot] then
		warn("Ability on cooldown:", slot)
		return false
	end
	
	-- Here you would implement the actual ability activation logic
	-- This would likely include:
	-- 1. Checking if the player has enough resources (mana, stamina, etc.)
	-- 2. Validating the target is valid
	-- 3. Applying effects
	
	-- For now, we'll just fire an event and start the cooldown
	AbilityEvents.AbilityActivated:Fire(self.playerId, slot, ability, targetPosition, targetEntity)
	
	-- Start cooldown if the ability has one
	if ability.cooldown and ability.cooldown > 0 then
		self:_startCooldown(slot, ability.cooldown)
	end
	
	return true
end

-- Start a cooldown for an ability
function AbilityManager:_startCooldown(slot, duration)
	-- Cancel any existing cooldown
	if self.cooldowns[slot] then
		self:_clearCooldown(slot)
	end
	
	-- Create a new cooldown
	local cooldownEndTime = tick() + duration
	self.cooldowns[slot] = {
		endTime = cooldownEndTime,
		duration = duration,
		connection = nil
	}
	
	-- Fire cooldown started event
	AbilityEvents.AbilityCooldownStarted:Fire(self.playerId, slot, duration)
	
	-- Create a delayed function to end the cooldown
	local connection
	connection = task.delay(duration, function()
		if self.cooldowns[slot] then
			self:_clearCooldown(slot)
			AbilityEvents.AbilityCooldownEnded:Fire(self.playerId, slot)
		end
	end)
	
	-- Store the connection so we can cancel it if needed
	self.cooldowns[slot].connection = connection
	
	return cooldownEndTime
end

-- Clear a cooldown
function AbilityManager:_clearCooldown(slot)
	if not self.cooldowns[slot] then
		return
	end
	
	-- Cancel the timer if it exists
	if self.cooldowns[slot].connection then
		task.cancel(self.cooldowns[slot].connection)
	end
	
	-- Remove the cooldown
	self.cooldowns[slot] = nil
end

-- Get remaining cooldown time for an ability
function AbilityManager:getCooldownRemaining(slot)
	if not self.cooldowns[slot] then
		return 0
	end
	
	local remaining = self.cooldowns[slot].endTime - tick()
	return math.max(0, remaining)
end

-- Check if an ability is on cooldown
function AbilityManager:isOnCooldown(slot)
	return self.cooldowns[slot] ~= nil
end

-- Get all abilities (for serialization)
function AbilityManager:getAllAbilities()
	return table.clone(self.abilities)
end

-- Set all abilities (for deserialization)
function AbilityManager:setAllAbilities(abilitiesData)
	-- Clear existing abilities
	for slot in pairs(self.abilities) do
		self:removeAbility(slot)
	end
	
	-- Set new abilities
	for slot, abilityData in pairs(abilitiesData) do
		if ABILITY_SLOTS[slot] then
			self:setAbility(slot, abilityData)
		end
	end
end

-- Reset all abilities
function AbilityManager:reset()
	-- Clear all abilities
	for slot in pairs(self.abilities) do
		self:removeAbility(slot)
	end
	
	-- Clear all cooldowns
	for slot in pairs(self.cooldowns) do
		self:_clearCooldown(slot)
	end
end

-- Export events for other systems to listen to
AbilityManager.Events = AbilityEvents

-- Export constants
AbilityManager.ABILITY_SLOTS = ABILITY_SLOTS

return AbilityManager
