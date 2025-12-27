-- Import required modules
local utils = require "core.utils"
local tracker = require "core.tracker"
local enums = require "data.enums"
local explorerlite = require "core.explorerlite"
local settings = require "core.settings"
local gui = require "gui"

-- Variables for stuck detection
local last_position = nil
local last_move_time = 0
local stuck_threshold = 20
local last_unstuck_attempt_time = 0
local unstuck_cooldown = 30
local unstuck_attempt_timeout = 5
local unstuck_attempt_start = 0

-- Variables for chest interaction cooldown
local last_chest_interaction_time = 0
local chest_interaction_cooldown = 10 

-- Function to find and return any EGB chest actor or Boss_WT_Belial_Chest
local function find_egb_chest()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:find("EGB_Chest") == 1 or name == "Boss_WT_Belial_Chest" then
            console.print("Found chest: " .. name)
            return actor
        end
    end
    return nil
end

local function check_if_stuck()
    local current_pos = get_player_position()
    local current_time = os.time()
    if last_position and utils.distance_to(last_position) < 0.1 then
        if current_time - last_move_time > stuck_threshold then
            if current_time - last_unstuck_attempt_time >= unstuck_cooldown then
                last_unstuck_attempt_time = current_time
                return true
            end
        end
    else
        last_move_time = current_time
    end
    last_position = current_pos
    return false
end

local function movement_spell_to_target(target)
    local local_player = get_local_player()
    if not local_player then return end
    local movement_spell_id = {288106, 358761, 355606, 1663206, 1871821, 337031}
    for _, spell_id in ipairs(movement_spell_id) do
        if local_player:is_spell_ready(spell_id) then
            local success = cast_spell.position(spell_id, target, 3.0)
            if success then return true end
        end
    end
    return false
end

-- Define the task
local task = {
    name = "Open EGB Chest",
    
    shouldExecute = function()
        local chest = find_egb_chest()
        return chest ~= nil
    end,

    Execute = function()
        local current_time_inject = get_time_since_inject()

        -- Stuck detection logic
        if check_if_stuck() then
            if unstuck_attempt_start == 0 then
                unstuck_attempt_start = current_time_inject
            elseif current_time_inject - unstuck_attempt_start > unstuck_attempt_timeout then
                unstuck_attempt_start = 0
                return
            end
            local unstuck_target = explorerlite.find_unstuck_target()
            if unstuck_target then
                explorerlite:set_custom_target(unstuck_target)
                movement_spell_to_target(unstuck_target)
                pathfinder.force_move_raw(unstuck_target)
            end
        else
            unstuck_attempt_start = 0
        end

        local chest = find_egb_chest()
        if chest then
            local actor_position = chest:get_position()
            
            -- Move to chest
            if utils.distance_to(actor_position) > 2 then
                explorerlite:set_custom_target(actor_position)
                explorerlite:move_to_target()
            end

            -- Interact with chest
            if utils.distance_to(actor_position) <= 2 then
                local current_time_os = os.time()
                
                if current_time_os - last_chest_interaction_time >= chest_interaction_cooldown then
                    interact_object(chest)
                    last_chest_interaction_time = current_time_os
                    
                    -- Update tracker with the current time when chest is opened
                    tracker.chest_opened_time = current_time_os
                    console.print("Chest opened. Delay timer for Altar started.")
                end
            end
        end
    end
}

return task
