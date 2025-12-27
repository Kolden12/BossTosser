local gui          = require "gui"
local task_manager = require "core.task_manager"
local settings     = require "core.settings"
local tracker      = require "core.tracker" -- Added tracker

local local_player, player_position

local function update_locals()
    local_player = get_local_player()
    player_position = local_player and local_player:get_position()
end

local function main_pulse()
    settings:update_settings()
    if not local_player or not settings.enabled then return end
    task_manager.execute_tasks()
end

local function render_pulse()
    if not local_player or not settings.enabled then return end
    
    local current_task = task_manager.get_current_task()
    local px, py, pz = player_position:x(), player_position:y(), player_position:z()
    
    -- TIMER OVERLAY: Show wait time remaining on screen
    local current_os_time = os.time()
    local wait_time = gui.elements.chest_wait_time:get()
    
    if tracker.chest_opened_time ~= nil and current_os_time < tracker.chest_opened_time + wait_time then
        local remaining = math.ceil((tracker.chest_opened_time + wait_time) - current_os_time)
        local screen_width = graphics.get_screen_width()
        local timer_pos = vec2:new(screen_width / 4, 60)
        graphics.text_2d("POST-CHEST DELAY: " .. remaining .. "s", timer_pos, 20, color_yellow(255))
    end

    if current_task then
        local draw_pos = vec3:new(px, py - 2, pz + 3)
        graphics.text_3d("Current Task: " .. current_task.name, draw_pos, 14, color_white(255))
    end
end

BosserPlugin = {
    enable = function ()
        console.print('BOSSER ACTIVATING')
        gui.elements.main_toggle:set(true)
    end,
    disable = function ()
        console.print('BOSSER DEACTIVATING')
        gui.elements.main_toggle:set(false)
    end,
    status = function ()
        return {
            ['enabled'] = gui.elements.main_toggle:get(),
            ['task'] = task_manager.get_current_task()
        }
    end,
}

on_update(function()
    update_locals()
    main_pulse()
end)

on_render_menu(gui.render)
on_render(render_pulse)
