-- CentralData.lua
-- ModuleScript to be used globally
local CentralData = {}
CentralData.__index = CentralData

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create events folder if it doesn't exist
local Events = ReplicatedStorage:FindFirstChild("CentralDataEvents")
if not Events then
	Events = Instance.new("Folder")
	Events.Name = "CentralDataEvents"
	Events.Parent = ReplicatedStorage
end

-- Create game events with namespacing to avoid conflicts
local DataEvents = {
	HealthChanged = Instance.new("BindableEvent"),
	StaminaChanged = Instance.new("BindableEvent"),
	EquipmentChanged = Instance.new("BindableEvent"),
	AccessoryChanged = Instance.new("BindableEvent"),
	AbilityAdded = Instance.new("BindableEvent"),
	AbilityRemoved = Instance.new("BindableEvent"),
	OverhealthChanged = Instance.new("BindableEvent"),
	PlayerStateChanged = Instance.new("BindableEvent"),
	StatsModified = Instance.new("BindableEvent"),
	SubAspectChanged = Instance.new("BindableEvent")
}

-- Place events in folder
for name, event in pairs(DataEvents) do
	event.Name = name
	event.Parent = Events
end

-- Define default values
local DEFAULT_STATS = {
	health = 100,
	maxHealth = 100,
	stamina = 100,
	maxStamina = 100,
	strength = 10,
	speed = 16,
	defense = 0,
	resistance = 0
}

-- Define equipment slots
local EQUIPMENT_SLOTS = {
	-- Armor slots
	"Helmet",
	"Chest",
	"Greaves",

	-- Weapon slot
	"Weapon",

	-- Accessory slots
	"Head1", "Head2", "Head3",
	"Face1", "Face2",
	"LeftArm", "RightArm",
	"Boots",
	"Neck1", "Neck2",
	"Back",
	"Coat"
}

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

-- Aspect types and their passive benefits
local ASPECTS = {
	Creation = {
		subAspects = {"Forge", "Tide", "Choir", "Architect"}
		passivePerks = {
			-- Define Creation aspect passive perks
		}
	},
	Chaos = {
		subAspects = {"Ruin", "Wild Card", "Stagnation", "Spiral"}
		passivePerks = {
			-- Define Chaos aspect passive perks
		}
	},
	Null = {
		subAspects = {}
		passivePerks = {
			-- Define Null aspect passive perks
		}
	}
}

-- Helper function for deep copying a table
local function deepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = deepCopy(value) -- Recursively deep copy nested tables
		else
			copy[key] = value -- Directly copy non-table values
		end
	end
	return copy
end

-- Helper function to deeply add or subtract modifiers from a stats table
local function applyModifiers(stats, modifiers, add)
	local factor = add and 1 or -1
	for statName, modifier in pairs(modifiers) do
		if stats[statName] then
			if type(modifier) == "table" then
				-- Handle nested modifiers (you might need more specific logic here)
				-- For simplicity, let's assume nested tables are direct additions/subtractions
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
end

-- More targeted stat update function
function CentralData:_updateStats(affectedStats)
	local oldStats = table.clone(self.currentStats)
	local newCalculatedStats = table.clone(self.baseStats) -- Start with base stats

	-- Apply equipment modifiers for the affected stats
	for slot, item in pairs(self.equipment) do
		if item and item.statModifiers then
			for statName in pairs(item.statModifiers) do
				if affectedStats[statName] then
					applyModifiers(newCalculatedStats, item.statModifiers, true)
					break -- Move to the next item if we found an affected stat
				end
			end
		end
	end

	-- Apply aspect passives for the affected stats
	if self.aspect and ASPECTS[self.aspect] then
		local aspectPerks = ASPECTS[self.aspect].passivePerks
		for statName in pairs(aspectPerks) do
			if affectedStats[statName] then
				applyModifiers(newCalculatedStats, aspectPerks, true)
				break -- No need to check other aspect perks if we found an affected stat
			end
		end
	end

	-- Apply other modifiers (you'll need to integrate this similarly)
	-- ...

	-- Update only the affected current stats
	for statName, newValue in pairs(newCalculatedStats) do
		if affectedStats[statName] and self.currentStats[statName] ~= newValue then
			self.currentStats[statName] = newValue
		end
	end

	-- Update dependent values based on potentially changed stats
	if affectedStats.maxHealth then
		self.maxHealth = self.currentStats.maxHealth
		self.health = math.min(self.health, self.maxHealth)
	end
	if affectedStats.maxStamina then
		self.maxStamina = self.currentStats.maxStamina
		self.stamina = math.min(self.stamina, self.maxStamina)
	end

	-- Fire event for the modified stats
	local changedStats = {}
	for statName, oldValue in pairs(oldStats) do
		if self.currentStats[statName] ~= oldValue and affectedStats[statName] then
			changedStats[statName] = {old = oldValue, new = self.currentStats[statName]}
		end
	end
	if next(changedStats) then -- Check if there are any changed stats
		DataEvents.StatsModified:Fire(self.playerId, oldStats, self.currentStats) -- You might want to send only the changed stats for more efficiency
	end

	return self.currentStats
end

-- Initialize default player data structure
function CentralData.new(playerId)
	local self = setmetatable({}, CentralData)

	-- Core properties
	self.playerId = playerId
	self.health = DEFAULT_STATS.health
	self.maxHealth = DEFAULT_STATS.maxHealth
	self.stamina = DEFAULT_STATS.stamina
	self.maxStamina = DEFAULT_STATS.maxStamina

	-- Base stats (before equipment/ability modifiers)
	self.baseStats = table.clone(DEFAULT_STATS)

	-- Current effective stats (after all modifiers)
	self.currentStats = table.clone(DEFAULT_STATS)

	-- Equipment and accessories
	self.equipment = {}
	for _, slot in ipairs(EQUIPMENT_SLOTS) do
		self.equipment[slot] = nil
	end

	-- Equipment stat modifiers
	self.equipmentModifiers = {}

	-- Aspect system
	self.aspect = nil
	self.subAspect = nil
	self.aspectPassives = {}
	self.hasAspectBeenSet = false


	-- Ability system
	self.abilities = {}
	for slot, _ in pairs(ABILITY_SLOTS) do
		self.abilities[slot] = nil
	end

	-- States
	self.states = {
		isDead = false,
		isInCombat = false,
		hasOverhealth = false,
		isRagdolled = false,
		isGuarding = false,
		isStunned = false
	}

	-- Special values
	self.overhealth = 0

	-- Create a private table for cached values
	self._cache = {}

	-- Setup event connections for this player
	self:_setupEventConnections()

	return self
end

-- Set up internal event connections
function CentralData:_setupEventConnections()
	-- This function would set up any internal event connections needed
	-- For example, connections between different parts of the player data
end


-- Calculate all stats based on base stats + equipment + abilities + aspects
function CentralData:recalculateStats()
	-- Start with a deep copy of base stats
	local newStats = deepCopy(self.baseStats)

	-- Apply equipment modifiers
	for slot, item in pairs(self.equipment) do
		if item and item.statModifiers then
			-- Deep copy the equipment's stat modifiers before applying
			local equipmentModifiersCopy = deepCopy(item.statModifiers)
			for statName, modifier in pairs(equipmentModifiersCopy) do
				if newStats[statName] then
					newStats[statName] = newStats[statName] + modifier
				end
			end
		end
	end

	-- Apply aspect passives
	if self.aspect and ASPECTS[self.aspect] then
		local aspectPerks = ASPECTS[self.aspect].passivePerks
		-- Deep copy the aspect's passive perks before applying
		local aspectPerksCopy = deepCopy(aspectPerks)
		for statName, modifier in pairs(aspectPerksCopy) do
			if newStats[statName] then
				newStats[statName] = newStats[statName] + modifier
			end
		end
	end

	-- Apply any other modifiers (buffs, debuffs, etc.)
	-- ...

	-- Update current stats
	local oldStats = table.clone(self.currentStats)
	self.currentStats = newStats

	-- Update dependent values
	self.maxHealth = self.currentStats.maxHealth
	self.maxStamina = self.currentStats.maxStamina

	-- Clamp current health and stamina to new maximums
	self.health = math.min(self.health, self.maxHealth)
	self.stamina = math.min(self.stamina, self.maxStamina)

	-- Fire event that stats were modified
	DataEvents.StatsModified:Fire(self.playerId, oldStats, self.currentStats)

	return self.currentStats
end

-- Health management
function CentralData:updateHealth(amount)
	local oldHealth = self.health
	self.health = math.clamp(self.health + amount, 0, self.maxHealth)

	-- Check for death state
	if self.health <= 0 and not self.states.isDead then
		self:setState("isDead", true)
	end

	-- Fire health changed event
	DataEvents.HealthChanged:Fire(self.playerId, oldHealth, self.health)

	return self.health
end

function CentralData:setHealth(value)
	return self:updateHealth(value - self.health)
end

-- Stamina management
function CentralData:updateStamina(amount)
	local oldStamina = self.stamina
	self.stamina = math.clamp(self.stamina + amount, 0, self.maxStamina)

	-- Fire stamina changed event
	DataEvents.StaminaChanged:Fire(self.playerId, oldStamina, self.stamina)

	return self.stamina
end

function CentralData:setStamina(value)
	return self:updateStamina(value - self.stamina)
end

-- Equipment management
function CentralData:equipItem(slot, item)
	if not self.equipment[slot] then
		warn("Invalid equipment slot:", slot)
		return false
	end

	local oldItem = self.equipment[slot]
	self.equipment[slot] = item

	-- Determine if this is armor or an accessory for the correct event
	local isArmor = (slot == "Helmet" or slot == "Chest" or slot == "Greaves")
	local isWeapon = (slot == "Weapon")
	local isAccessory = not (isArmor or isWeapon)

	-- If equipping a weapon, update the weapon-based abilities
	if isWeapon and item then
		if item.abilities then
			for abilitySlot, source in pairs(ABILITY_SLOTS) do
				if source == "Weapon" then
					local abilityIndex = abilitySlot == "E" and 1 or 2 -- E is first weapon ability, R is second
					if item.abilities[abilityIndex] then
						self:setAbility(abilitySlot, item.abilities[abilityIndex])
					else
						self:removeAbility(abilitySlot)
					end
				end
			end
		end
	end

	-- Update appearance if the item has an appearance property
	if item and item.appearance then
		-- This would call a function to update the player's appearance
		-- Implementation would depend on your game's character system
	end

	-- Fire the appropriate event
	if isArmor or isWeapon then
		DataEvents.EquipmentChanged:Fire(self.playerId, slot, oldItem, item)
	else
		DataEvents.AccessoryChanged:Fire(self.playerId, slot, oldItem, item)
	end

	-- Recalculate only stats affected by the new item
	local affectedStats = {}
	if item and item.statModifiers then
		for statName in pairs(item.statModifiers) do
			affectedStats[statName] = true
		end
	elseif oldItem and oldItem.statModifiers then -- If unequipping, consider the old item's stats
		for statName in pairs(oldItem.statModifiers) do
			affectedStats[statName] = true
		end
	end
	self:_updateStats(affectedStats)

	return true
end

function CentralData:unequipItem(slot)
	local oldItem = self.equipment[slot]
	if not oldItem then
		return false -- Nothing to unequip
	end

	self.equipment[slot] = nil

	-- Determine if this was armor or an accessory for the correct event
	local isArmor = (slot == "Helmet" or slot == "Chest" or slot == "Greaves")
	local isWeapon = (slot == "Weapon")
	local isAccessory = not (isArmor or isWeapon)

	-- If unequipping a weapon, clear weapon-based abilities
	if isWeapon then
		for abilitySlot, source in pairs(ABILITY_SLOTS) do
			if source == "Weapon" then
				self:removeAbility(abilitySlot)
			end
		end
	end

	-- Fire the appropriate event
	if isArmor or isWeapon then
		DataEvents.EquipmentChanged:Fire(self.playerId, slot, oldItem, nil)
	else
		DataEvents.AccessoryChanged:Fire(self.playerId, slot, oldItem, nil)
	end

	-- Recalculate only stats affected by the removed item
	local affectedStats = {}
	if oldItem and oldItem.statModifiers then
		for statName in pairs(oldItem.statModifiers) do
			affectedStats[statName] = true
		end
	end
	self:_updateStats(affectedStats)

	return true
end

-- Aspect system
function CentralData:setAspect(aspectName, force) -- Added a 'force' parameter
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
	self.aspectPassives = table.clone(ASPECTS[aspectName].passivePerks) -- Update passive perks
	self.hasAspectBeenSet = true

	-- Recalculate only stats affected by the aspect change
	local affectedStats = {}
	if ASPECTS[aspectName] then
		for statName in pairs(ASPECTS[aspectName].passivePerks) do
			affectedStats[statName] = true
		end
		if oldAspect and ASPECTS[oldAspect] then
			-- Also consider the removal of the old aspect's perks
			for statName in pairs(ASPECTS[oldAspect].passivePerks) do
				affectedStats[statName] = true
			end
		end
	end
	self:_updateStats(affectedStats)

	-- Fire event
	DataEvents.AspectChanged:Fire(self.playerId, oldAspect, aspectName)

	return true
end

function CentralData:setSubAspect(subAspectName, currentAspect) -- We need to know the character's Aspect
	if not currentAspect or not ASPECTS[currentAspect] then
		warn("Invalid current aspect provided:", currentAspect)
		return false
	end

	local availableSubAspects = ASPECTS[currentAspect].subAspects -- Assuming you'll add a 'subAspects' list to each Aspect definition

	if currentAspect ~= "Null" and (not availableSubAspects or not table.find(availableSubAspects, subAspectName)) then
		warn("Sub-aspect '" .. subAspectName .. "' is not available for the '" .. currentAspect .. "' aspect.")
		return false
	end

	local oldSubAspect = self.subAspect
	self.subAspect = subAspectName

	-- Update sub-aspect abilities
	-- This would involve looking up what abilities this sub-aspect grants
	-- and assigning them to the appropriate slots (where ABILITY_SLOTS[slot] == "SubAspect")
	for slot, source in pairs(ABILITY_SLOTS) do
		if source == "SubAspect" then
			self:removeAbility(slot) -- Clear the old sub-aspect ability in this slot
			-- Look up and set the new ability based on self.subAspect
			if self.subAspect and SUB_ASPECT_ABILITIES[self.subAspect] and SUB_ASPECT_ABILITIES[self.subAspect][slot] then
				self:setAbility(slot, SUB_ASPECT_ABILITIES[self.subAspect][slot])
			end
		end
	end

	-- Recalculate stats if sub-aspects have passive effects
	local affectedStats = {}
	if oldSubAspect and SUB_ASPECT_PASSIVES[oldSubAspect] then
		for statName in pairs(SUB_ASPECT_PASSIVES[oldSubAspect]) do
			affectedStats[statName] = true
		end
	end
	if self.subAspect and SUB_ASPECT_PASSIVES[self.subAspect] then
		for statName in pairs(SUB_ASPECT_PASSIVES[self.subAspect]) do
			affectedStats[statName] = true
		end
	end
	if next(affectedStats) then
		self:_updateStats(affectedStats)
	end

	-- Fire event
	DataEvents.SubAspectChanged:Fire(self.playerId, oldSubAspect, subAspectName)

	return true
end

-- Ability management
function CentralData:setAbility(slot, ability)
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

	-- Fire event
	DataEvents.AbilityAdded:Fire(self.playerId, slot, ability)

	return true
end

function CentralData:removeAbility(slot)
	if not ABILITY_SLOTS[slot] then
		warn("Invalid ability slot:", slot)
		return false
	end

	local oldAbility = self.abilities[slot]
	if oldAbility then
		self.abilities[slot] = nil
		DataEvents.AbilityRemoved:Fire(self.playerId, slot, oldAbility)
		return true
	end

	return false
end

function CentralData:getAbility(slot)
	return self.abilities[slot]
end

-- Overhealth management
function CentralData:setOverhealth(value)
	local oldValue = self.overhealth
	self.overhealth = math.max(0, value)
	self.states.hasOverhealth = self.overhealth > 0

	DataEvents.OverhealthChanged:Fire(self.playerId, oldValue, self.overhealth)
	return self.overhealth
end

-- State management
function CentralData:setState(stateName, value)
	if self.states[stateName] == nil then
		warn("Invalid state name:", stateName)
		return false
	end

	local oldValue = self.states[stateName]
	self.states[stateName] = value

	DataEvents.PlayerStateChanged:Fire(self.playerId, stateName, oldValue, value)
	return true
end

function CentralData:getState(stateName)
	return self.states[stateName]
end

-- Stat management
function CentralData:setBaseStat(statName, value)
	if self.baseStats[statName] == nil then
		warn("Invalid stat name:", statName)
		return false
	end

	self.baseStats[statName] = value

	-- Recalculate stats that might be affected by this base stat change
	-- You might need to adjust this based on how your stats are calculated
	local affectedStats = {[statName] = true, maxHealth = true, maxStamina = true}
	self:_updateStats(affectedStats)

	return true
end

function CentralData:getBaseStat(statName)
	return self.baseStats[statName]
end

function CentralData:getCurrentStat(statName)
	return self.currentStats[statName]
end

-- Reset player (for death or respawn)
function CentralData:reset()
	self.health = self.maxHealth
	self.stamina = self.maxStamina
	self.overhealth = 0

	-- Reset states
	for state, _ in pairs(self.states) do
		self.states[state] = false
	end

	-- Fire events
	DataEvents.HealthChanged:Fire(self.playerId, 0, self.health)
	DataEvents.StaminaChanged:Fire(self.playerId, 0, self.stamina)
	DataEvents.OverhealthChanged:Fire(self.playerId, 0, 0)

	return true
end

-- Serialization for saving/networking
function CentralData:serialize()
	local data = {
		playerId = self.playerId,
		health = self.health,
		maxHealth = self.maxHealth,
		stamina = self.stamina,
		maxStamina = self.maxStamina,
		baseStats = table.clone(self.baseStats),
		equipment = {},
		aspect = self.aspect,
		subAspect = self.subAspect,
		states = table.clone(self.states),
		overhealth = self.overhealth
	}

	-- Serialize equipment (store IDs or minimal data needed)
	for slot, item in pairs(self.equipment) do
		if item then
			-- Store the minimal representation needed to recreate the item
			-- This depends on how your items are structured
			data.equipment[slot] = {
				id = item.id,
				-- Add other essential properties
			}
		end
	end

	-- We don't need to serialize abilities as they can be derived from weapons and subAspect

	return data
end

-- Deserialization for loading
function CentralData:deserialize(data)
	if type(data) ~= "table" or not data.playerId then
		warn("Invalid data format for deserialization")
		return false
	end

	self.playerId = data.playerId
	self.health = data.health or DEFAULT_STATS.health
	self.maxHealth = data.maxHealth or DEFAULT_STATS.maxHealth
	self.stamina = data.stamina or DEFAULT_STATS.stamina
	self.maxStamina = data.maxStamina or DEFAULT_STATS.maxStamina

	-- Copy base stats
	for statName, value in pairs(data.baseStats or {}) do
		self.baseStats[statName] = value
	end

	-- Set aspect and subAspect
	if data.aspect then
		self:setAspect(data.aspect)
	end

	if data.subAspect then
		self:setSubAspect(data.subAspect)
	end

	-- Copy states
	for state, value in pairs(data.states or {}) do
		self.states[state] = value
	end

	self.overhealth = data.overhealth or 0

	-- Load equipment
	-- This part would require access to your item system to convert IDs back to items
	-- Here's a placeholder for how it might work:
	for slot, itemData in pairs(data.equipment or {}) do
		if itemData and itemData.id then
			-- This would be replaced with your actual item retrieval logic
			local itemInstance = self:_getItemFromId(itemData.id)
			if itemInstance then
				self:equipItem(slot, itemInstance)
			end
		end
	end

	-- Recalculate all stats
	self:recalculateStats()

	return true
end

-- Helper function to get item instance from ID (placeholder)
function CentralData:_getItemFromId(itemId)
	-- This is a placeholder for your item system
	-- It would return the full item object based on its ID
	-- For example, by querying a central item database module

	-- local ItemDatabase = require(game.ReplicatedStorage.ItemDatabase)
	-- return ItemDatabase:getItemById(itemId)

	-- For now, just return a dummy object
	return {
		id = itemId,
		name = "Unknown Item",
		statModifiers = {}
	}
end

function CentralData:resetCharacterData()
	-- Reset core properties to default
	self.health = DEFAULT_STATS.health
	self.maxHealth = DEFAULT_STATS.maxHealth
	self.stamina = DEFAULT_STATS.stamina
	self.maxStamina = DEFAULT_STATS.maxStamina
	self.overhealth = 0

	-- Reset base stats to default
	for statName, defaultValue in pairs(DEFAULT_STATS) do
		self.baseStats[statName] = defaultValue
	end

	-- Reset current stats (they will be recalculated anyway, but let's set them to default for clarity)
	for statName, defaultValue in pairs(DEFAULT_STATS) do
		self.currentStats[statName] = defaultValue
	end

	-- Clear equipment
	for slot in pairs(self.equipment) do
		self.equipment[slot] = nil
	end
	self.equipmentModifiers = {} -- Clear any equipment modifiers

	-- Reset aspect system
	self.aspect = nil
	self.subAspect = nil
	self.aspectPassives = {}
	self.hasAspectBeenSet = false -- Allow setting the aspect again

	-- Clear abilities
	for slot in pairs(self.abilities) do
		self.abilities[slot] = nil
	end

	-- Reset states
	for stateName in pairs(self.states) do
		self.states[stateName] = false
	end

	-- You might want to fire events to let other parts of your game know
	-- that the player's data has been reset.
	DataEvents.HealthChanged:Fire(self.playerId, self.health, self.health) -- No change, but signals a reset
	DataEvents.StaminaChanged:Fire(self.playerId, self.stamina, self.stamina) -- No change, but signals a reset
	DataEvents.OverhealthChanged:Fire(self.playerId, self.overhealth, self.overhealth) -- No change, but signals a reset
	DataEvents.EquipmentChanged:Fire(self.playerId, nil, nil, nil) -- Signal all equipment slots are now empty (you might need to adjust this based on how your event works)
	DataEvents.AccessoryChanged:Fire(self.playerId, nil, nil, nil) -- Signal all accessory slots are now empty
	DataEvents.AbilityRemoved:Fire(self.playerId, nil, nil) -- You might need to iterate through abilities and fire individual removed events if that's important for other systems
	DataEvents.SubAspectChanged:Fire(self.playerId, self.subAspect, nil) -- Signal sub-aspect has been cleared
	DataEvents.AspectChanged:Fire(self.playerId, self.aspect, nil) -- Signal aspect has been cleared

	-- Finally, recalculate the stats to ensure everything is consistent with the defaults
	self:recalculateStats()

	print("Character data for player " .. self.playerId .. " has been reset.")
end

-- Export events for other systems to listen to
CentralData.Events = DataEvents

-- Export constants
CentralData.EQUIPMENT_SLOTS = EQUIPMENT_SLOTS
CentralData.ABILITY_SLOTS = ABILITY_SLOTS
CentralData.ASPECTS = ASPECTS

return CentralData