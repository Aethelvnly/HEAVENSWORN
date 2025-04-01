-- StateManager.lua
-- Manages player states (stunned, dead, etc.)
local StateManager = {}
StateManager.__index = StateManager

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create or get events folder
local Events = ReplicatedStorage:FindFirstChild("CentralDataEvents")
if not Events then
	Events = Instance.new("Folder")
	Events.Name = "CentralDataEvents"
	Events.Parent = ReplicatedStorage
end

-- Create state events
local StateEvents = {
	PlayerStateChanged = Events:FindFirstChild("PlayerStateChanged") or Instance.new("BindableEvent"),
	StateEffectApplied = Instance.new("BindableEvent"),
	StateEffectRemoved = Instance.new("BindableEvent"),
	StateTimerStarted = Instance.new("BindableEvent"),
	StateTimerEnded = Instance.new("BindableEvent")
}

-- Place events in folder if they don't exist
for name, event in pairs(StateEvents) do
	if event.Parent ~= Events then
		event.Name = name
		event.Parent = Events
	end
end

-- Define all possible player states
local PLAYER_STATES = {
	isDead = {
		default = false,
		priority = 100, -- Highest priority
		blocksCombat = true,
		blocksMovement = true,
		blocksAbilities = true,
		blocksInteraction = true
	},
	isInCombat = {
		default = false,
		priority = 10,
		cooldown = 5 -- Time after damage taken or dealt before leaving combat
	},
	hasOverhealth = {
		default = false,
		priority = 1,
		visual = true
	},
	isRagdolled = {
		default = false,
		priority = 80,
		blocksMovement = true,
		blocksAbilities = true
	},
	isGuarding = {
		default = false,
		priority = 50,
		blocksAbilities = true,
		modifiesMovement = true
	},
	isStunned = {
		default = false,
		priority = 90,
		blocksMovement = true,
		blocksAbilities = true,
		blocksInteraction = true
	},
	isSlowed = {
		default = false,
		priority = 30,
		modifiesMovement = true
	},
	isSilenced = {
		default = false,
		priority = 60,
		blocksAbilities = true
	},
	isInvulnerable = {
		default = false,
		priority = 70,
		blocksDamage = true
	}
}

-- Initialize a new StateManager for a player
function StateManager.new(playerId)
	local self = setmetatable({}, StateManager)

	-- Core properties
	self.playerId = playerId

	-- Initialize states
	self.states = {}
	for stateName, stateInfo in pairs(PLAYER_STATES) do
		self.states[stateName] = stateInfo.default
	end

	-- Track timed states
	self.stateTimers = {}

	-- Track state effects (buffs/debuffs)
	self.stateEffects = {}

	return self
end

-- Set a state
function StateManager:setState(stateName, value, duration, source)
	if self.states[stateName] == nil then
		warn("Invalid state name:", stateName)
		return false
	end

	-- If trying to set a state but a higher priority state blocks it
	if value == true then
		local stateInfo = PLAYER_STATES[stateName]
		for otherStateName, otherState in pairs(self.states) do
			if otherState == true and stateName ~= otherStateName then
				local otherStateInfo = PLAYER_STATES[otherStateName]
				if otherStateInfo.priority > stateInfo.priority then
					-- Check if the higher priority state blocks this state
					if otherStateInfo.blocksAllStates or 
						(stateName == "isInCombat" and otherStateInfo.blocksCombat) or
						(stateName == "isGuarding" and otherStateInfo.blocksAbilities) then
						warn("Cannot set state " .. stateName .. " due to higher priority state: " .. otherStateName)
						return false
					end
				end
			end
		end
	end

	local oldValue = self.states[stateName]

	-- If no change, just return
	if oldValue == value and not duration then
		return true
	end

	self.states[stateName] = value

	-- Clear any existing timer for this state
	if self.stateTimers[stateName] then
		self:_clearStateTimer(stateName)
	end

	-- Set up timer if duration is provided
	if duration and duration > 0 then
		self:_startStateTimer(stateName, duration, not value)
	end

	-- Handle special state logic
	if stateName == "isDead" and value == true then
		-- Automatically set certain states when dead
		self:setState("isGuarding", false)
		self:setState("isInCombat", false)
	end

	-- Fire state changed event
	StateEvents.PlayerStateChanged:Fire(self.playerId, stateName, oldValue, value, source)

	return true
end

-- Get a state value
function StateManager:getState(stateName)
	return self.states[stateName]
end

-- Get all states (for queries that need to check multiple states)
function StateManager:getAllStates()
	return table.clone(self.states)
end

-- Check if the player can perform an action
function StateManager:canPerformAction(actionType)
	-- Different action types to check for
	if actionType == "movement" then
		return not (self.states.isDead or self.states.isStunned or self.states.isRagdolled)
	elseif actionType == "abilities" then
		return not (self.states.isDead or self.states.isStunned or self.states.isRagdolled or 
			self.states.isGuarding or self.states.isSilenced)
	elseif actionType == "interaction" then
		return not (self.states.isDead or self.states.isStunned)
	elseif actionType == "takeDamage" then
		return not (self.states.isDead or self.states.isInvulnerable)
	else
		warn("Unknown action type:", actionType)
		return true
	end
end

-- Apply a state effect (buff/debuff)
function StateManager:applyStateEffect(effectData)
	if not effectData or not effectData.id or not effectData.states then
		warn("Invalid effect data")
		return false
	end

	-- Generate a unique identifier for this effect instance
	local effectId = effectData.id .. "_" .. tick()

	-- Store the effect
	self.stateEffects[effectId] = {
		data = effectData,
		appliedStates = {}
	}

	-- Apply each state change from the effect
	for stateName, stateValue in pairs(effectData.states) do
		if self:setState(stateName, stateValue, effectData.duration, effectData.id) then
			self.stateEffects[effectId].appliedStates[stateName] = stateValue
		end
	end

	-- Fire event
	StateEvents.StateEffectApplied:Fire(self.playerId, effectId, effectData)

	-- If the effect has a duration, set up removal
	if effectData.duration and effectData.duration > 0 then
		task.delay(effectData.duration, function()
			self:removeStateEffect(effectId)
		end)
	end

	return effectId
end

-- Remove a state effect
function StateManager:removeStateEffect(effectId)
	local effect = self.stateEffects[effectId]
	if not effect then
		return false
	end

	-- Revert each state change if no other effect is maintaining it
	for stateName, stateValue in pairs(effect.appliedStates) do
		-- Check if any other effect maintains this state
		local otherEffectMaintainsState = false
		for otherId, otherEffect in pairs(self.stateEffects) do
			if otherId ~= effectId and otherEffect.appliedStates[stateName] ~= nil then
				otherEffectMaintainsState = true
				break
			end
		end

		-- If no other effect maintains this state, revert to default
		if not otherEffectMaintainsState then
			self:setState(stateName, PLAYER_STATES[stateName].default, nil, "effectRemoved")
		end
	end

	-- Remove the effect
	self.stateEffects[effectId] = nil

	-- Fire event
	StateEvents.StateEffectRemoved:Fire(self.playerId, effectId, effect.data)

	return true
end

-- Start a timer for a state
function StateManager:_startStateTimer(stateName, duration, revertValue)
	if self.stateTimers[stateName] then
		self:_clearStateTimer(stateName)
	end

	local connection
	connection = task.delay(duration, function()
		if self.stateTimers[stateName] then
			self:_clearStateTimer(stateName)
			if revertValue ~= nil then
				self:setState(stateName, revertValue, nil, "timerEnded")
			end
			StateEvents.StateTimerEnded:Fire(self.playerId, stateName)
		end
	end)

	self.stateTimers[stateName] = {
		endTime = tick() + duration,
		duration = duration,
		connection = connection,
		revertValue = revertValue
	}

	StateEvents.StateTimerStarted:Fire(self.playerId, stateName, duration, revertValue)

	return true
end

-- Clear a state timer
function StateManager:_clearStateTimer(stateName)
	if not self.stateTimers[stateName] then
		return
	end

	if self.stateTimers[stateName].connection then
		task.cancel(self.stateTimers[stateName].connection)
	end

	self.stateTimers[stateName] = nil
end

-- Get time remaining on a state timer
function StateManager:getStateTimeRemaining(stateName)
	if not self.stateTimers[stateName] then
		return 0
	end

	local remaining = self.stateTimers[stateName].endTime - tick()
	return math.max(0, remaining)
end

-- Get state metadata (priority, what it blocks, etc.)
function StateManager:getStateMetadata(stateName)
	return PLAYER_STATES[stateName]
end

-- Enter combat state
function StateManager:enterCombat()
	local combatState = PLAYER_STATES.isInCombat
	self:setState("isInCombat", true, combatState.cooldown, "combatAction")
end

-- Refresh combat timer
function StateManager:refreshCombat()
	if self.states.isInCombat then
		local combatState = PLAYER_STATES.isInCombat
		self:_startStateTimer("isInCombat", combatState.cooldown, false)
	else
		self:enterCombat()
	end
end

-- Reset all states to default
function StateManager:reset()
	-- Clear all state timers
	for stateName in pairs(self.stateTimers) do
		self:_clearStateTimer(stateName)
	end

	-- Clear all state effects
	for effectId in pairs(self.stateEffects) do
		self.stateEffects[effectId] = nil
	end

	-- Reset all states to default
	for stateName, stateInfo in pairs(PLAYER_STATES) do
		if self.states[stateName] ~= stateInfo.default then
			self:setState(stateName, stateInfo.default, nil, "reset")
		end
	end
end

-- Serialize state data for saving
function StateManager:serialize()
	local data = {
		states = table.clone(self.states),
		stateTimers = {}
	}

	-- Save remaining time for each state timer
	for stateName, timer in pairs(self.stateTimers) do
		data.stateTimers[stateName] = {
			remaining = math.max(0, timer.endTime - tick()),
			revertValue = timer.revertValue
		}
	end

	return data
end

-- Deserialize state data from save
function StateManager:deserialize(data)
	if not data or not data.states then
		return false
	end

	-- Set states
	for stateName, value in pairs(data.states) do
		if self.states[stateName] ~= nil then
			self.states[stateName] = value
		end
	end

	-- Restore state timers
	for stateName, timerData in pairs(data.stateTimers or {}) do
		if timerData.remaining and timerData.remaining > 0 then
			self:_startStateTimer(stateName, timerData.remaining, timerData.revertValue)
		end
	end

	return true
end

-- Export events for other systems to listen to
StateManager.Events = StateEvents

-- Export constants
StateManager.PLAYER_STATES = PLAYER_STATES

return StateManager