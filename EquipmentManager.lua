-- EquipmentManager.lua
-- Handles equipment, accessories, and their effects
local EquipmentManager = {}
EquipmentManager.__index = EquipmentManager

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

function EquipmentManager.new(centralData)
	local self = setmetatable({}, EquipmentManager)

	-- Reference to central data
	self.centralData = centralData
	self.playerId = centralData.playerId

	-- Equipment storage
	self.items = {}
	for _, slot in ipairs(EQUIPMENT_SLOTS) do
		self.items[slot] = nil
	end

	return self
end

-- Equipment management
function EquipmentManager:equipItem(slot, item)
	if not self.items[slot] and not table.find(EQUIPMENT_SLOTS, slot) then
		warn("Invalid equipment slot:", slot)
		return false
	end

	local oldItem = self.items[slot]
	self.items[slot] = item

	-- Determine item type for the correct event
	local isArmor = (slot == "Helmet" or slot == "Chest" or slot == "Greaves")
	local isWeapon = (slot == "Weapon")
	local isAccessory = not (isArmor or isWeapon)

	-- If equipping a weapon, update weapon abilities
	if isWeapon and item and item.abilities then
		-- Let the AbilityManager handle this via event
		self.centralData.Events.EquipmentChanged:Fire(self.playerId, slot, oldItem, item)
	end

	-- Update appearance if needed
	if item and item.appearance then
		-- Here you would call a function to update the player's appearance
		-- self:_updateAppearance(slot, item.appearance)
	end

	-- Fire the appropriate event
	if isArmor or isWeapon then
		self.centralData.Events.EquipmentChanged:Fire(self.playerId, slot, oldItem, item)
	else
		self.centralData.Events.AccessoryChanged:Fire(self.playerId, slot, oldItem, item)
	end

	return true
end

function EquipmentManager:unequipItem(slot)
	local oldItem = self.items[slot]
	if not oldItem then
		return false -- Nothing to unequip
	end

	self.items[slot] = nil

	-- Determine item type for the correct event
	local isArmor = (slot == "Helmet" or slot == "Chest" or slot == "Greaves")
	local isWeapon = (slot == "Weapon")
	local isAccessory = not (isArmor or isWeapon)

	-- Fire the appropriate event
	if isArmor or isWeapon then
		self.centralData.Events.EquipmentChanged:Fire(self.playerId, slot, oldItem, nil)
	else
		self.centralData.Events.AccessoryChanged:Fire(self.playerId, slot, oldItem, nil)
	end

	return true
end

function EquipmentManager:getItem(slot)
	return self.items[slot]
end

function EquipmentManager:getAllItems()
	return self.items
end

function EquipmentManager:resetAllEquipment()
	for slot, _ in pairs(self.items) do
		self:unequipItem(slot)
	end
	return true
end

-- Helpers for equipment stats
function EquipmentManager:getEquipmentModifiers()
	local modifiers = {}

	for slot, item in pairs(self.items) do
		if item and item.statModifiers then
			for statName, value in pairs(item.statModifiers) do
				if not modifiers[statName] then
					modifiers[statName] = 0
				end
				modifiers[statName] = modifiers[statName] + value
			end
		end
	end

	return modifiers
end

-- Item data retrieval (placeholder - would connect to your item system)
function EquipmentManager:_getItemFromId(itemId)
	-- This is a placeholder for your item system
	-- Would return the full item object based on its ID

	return {
		id = itemId,
		name = "Unknown Item",
		statModifiers = {}
	}
end

-- Serialization
function EquipmentManager:serialize()
	local data = {}

	-- Serialize equipment (store IDs or minimal data needed)
	for slot, item in pairs(self.items) do
		if item then
			-- Store the minimal representation needed to recreate the item
			data[slot] = {
				id = item.id,
				-- Add other essential properties
			}
		end
	end

	return data
end

-- Deserialization
function EquipmentManager:deserialize(data)
	if not data then return false end

	-- Load equipment
	for slot, itemData in pairs(data) do
		if itemData and itemData.id then
			-- This would be replaced with your actual item retrieval logic
			local itemInstance = self:_getItemFromId(itemData.id)
			if itemInstance then
				self:equipItem(slot, itemInstance)
			end
		end
	end

	return true
end

-- Export constants
EquipmentManager.EQUIPMENT_SLOTS = EQUIPMENT_SLOTS

return EquipmentManager
