-- CentralData.lua (Streamlined Core)
-- Central coordinator for player data systems
local CentralData = {}
CentralData.__index = CentralData

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local StatsManager = require(script.Parent.StatsManager)
local EquipmentManager = require(script.Parent.EquipmentManager)
local AspectSystem = require(script.Parent.AspectSystem)
local AbilityManager = require(script.Parent.AbilityManager)
local StateManager = require(script.Parent.StateManager)

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
	SubAspectChanged = Instance.new("BindableEvent"),
	AspectChanged = Instance.new("BindableEvent")
}

-- Place events in folder
for name, event in pairs(DataEvents) do
	event.Name = name
	event.Parent = Events
end

-- Initialize default player data structure
function CentralData.new(playerId)
	local self = setmetatable({}, CentralData)

	-- Core identifier
	self.playerId = playerId

	-- Initialize all managers with references to this central data object
	self.stats = StatsManager.new(self)
	self.equipment = EquipmentManager.new(self)
	self.aspects = AspectSystem.new(self)
	self.abilities = AbilityManager.new(self)
	self.states = StateManager.new(self)

	-- Setup event connections
	self:_setupEventConnections()

	return self
end

-- Set up internal event connections between modules
function CentralData:_setupEventConnections()
	-- Example: When equipment changes, update stats
	DataEvents.EquipmentChanged.Event:Connect(function(playerId, slot, oldItem, newItem)
		if playerId == self.playerId then
			self.stats:recalculateAffectedStats({equipment = true})
		end
	end)

	-- When aspect changes, update abilities and stats
	DataEvents.AspectChanged.Event:Connect(function(playerId, oldAspect, newAspect)
		if playerId == self.playerId then
			self.abilities:updateFromAspectChange(oldAspect, newAspect)
			self.stats:recalculateAffectedStats({aspect = true})
		end
	end)

	-- When sub-aspect changes, update abilities and stats
	DataEvents.SubAspectChanged.Event:Connect(function(playerId, oldSubAspect, newSubAspect)
		if playerId == self.playerId then
			self.abilities:updateFromSubAspectChange(oldSubAspect, newSubAspect)
			self.stats:recalculateAffectedStats({subAspect = true})
		end
	end)

	-- Health reaches zero - set dead state
	DataEvents.HealthChanged.Event:Connect(function(playerId, oldHealth, newHealth)
		if playerId == self.playerId and newHealth <= 0 and oldHealth > 0 then
			self.states:setState("isDead", true)
		end
	end)
end

-- Simplified API methods that delegate to appropriate managers

-- Health management
function CentralData:updateHealth(amount)
	return self.stats:updateHealth(amount)
end

function CentralData:setHealth(value)
	return self.stats:setHealth(value)
end

-- Stamina management
function CentralData:updateStamina(amount)
	return self.stats:updateStamina(amount)
end

function CentralData:setStamina(value)
	return self.stats:setStamina(value)
end

-- Equipment management (delegated to EquipmentManager)
function CentralData:equipItem(slot, item)
	return self.equipment:equipItem(slot, item)
end

function CentralData:unequipItem(slot)
	return self.equipment:unequipItem(slot)
end

function CentralData:getEquippedItem(slot)
	return self.equipment:getItem(slot)
end

-- Aspect system (delegated to AspectSystem)
function CentralData:setAspect(aspectName, force)
	return self.aspects:setAspect(aspectName, force)
end

function CentralData:setSubAspect(subAspectName)
	return self.aspects:setSubAspect(subAspectName)
end

function CentralData:getAspect()
	return self.aspects:getAspect()
end

function CentralData:getSubAspect()
	return self.aspects:getSubAspect()
end

-- Ability management (delegated to AbilityManager)
function CentralData:setAbility(slot, ability)
	return self.abilities:setAbility(slot, ability)
end

function CentralData:removeAbility(slot)
	return self.abilities:removeAbility(slot)
end

function CentralData:getAbility(slot)
	return self.abilities:getAbility(slot)
end

-- Overhealth management
function CentralData:setOverhealth(value)
	return self.stats:setOverhealth(value)
end

-- State management (delegated to StateManager)
function CentralData:setState(stateName, value)
	return self.states:setState(stateName, value)
end

function CentralData:getState(stateName)
	return self.states:getState(stateName)
end

-- Reset player (for death or respawn)
function CentralData:reset()
	self.stats:reset()
	self.states:resetAllStates()
	return true
end

-- Complete reset of all character data
function CentralData:resetCharacterData()
	self.stats:reset(true) -- Full reset
	self.equipment:resetAllEquipment()
	self.aspects:resetAspects()
	self.abilities:resetAllAbilities()
	self.states:resetAllStates()

	print("Character data for player " .. self.playerId .. " has been reset.")
	return true
end

-- Serialization for saving/networking
function CentralData:serialize()
	local data = {
		playerId = self.playerId,
		stats = self.stats:serialize(),
		equipment = self.equipment:serialize(),
		aspects = self.aspects:serialize(),
		abilities = self.abilities:serialize(),
		states = self.states:serialize()
	}
	return data
end

-- Deserialization for loading
function CentralData:deserialize(data)
	if type(data) ~= "table" or not data.playerId then
		warn("Invalid data format for deserialization")
		return false
	end

	self.playerId = data.playerId

	-- Deserialize each system in order of dependencies
	self.stats:deserialize(data.stats)
	self.equipment:deserialize(data.equipment)
	self.aspects:deserialize(data.aspects)
	self.abilities:deserialize(data.abilities)
	self.states:deserialize(data.states)

	-- Final recalculation to ensure consistency
	self.stats:recalculateAllStats()

	return true
end

-- Export events for other systems to listen to
CentralData.Events = DataEvents

return CentralData
