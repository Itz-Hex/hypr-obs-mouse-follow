--[[
    Hyprland Mouse Follow Script for OBS Studio
    -------------------------------------------
    Author: Ollie Wells
    License: GNU General Public License v3.0
    Vesion: 1.0
    -------------------------------------------
]]

obs = obslua

-- Settings
local source_name = ""
local interval_ms = 50
local display_width = 2560
local display_height = 1440
local output_width = 1080
local output_height = 1920
local zoom_scale = 1.58125
local smoothing_factor = 0.1

local timer = nil
local current_x = -1
local current_y = -1

-- Get mouse position using hyprctl
function get_mouse_position()
    local cmd = "hyprctl cursorpos"
    local handle = io.popen(cmd)
    if not handle then return nil end
    
    local output = handle:read("*a")
    handle:close()

    local x, y = output:match("^%s*(%d+)%s*,%s*(%d+)%s*$")
    return tonumber(x), tonumber(y)
end

-- Update the position of the source based on the mouse position.
function update_crop()
    local x, y = get_mouse_position()
    if not x then return end

    if current_x == -1 then current_x = x end
    if current_y == -1 then current_y = y end

    current_x = current_x + (x - current_x) * smoothing_factor
    current_y = current_y + (y - current_y) * smoothing_factor

    local left = math.min(math.max(current_x * zoom_scale - output_width  / 2, 0), display_width  * zoom_scale - output_width)
    local top  = math.min(math.max(current_y * zoom_scale - output_height / 2, 0), display_height * zoom_scale - output_height) 
    
    set_source_position(source_name, -left, -top)
end

-- Set the transform position of a source to (x, y).
function set_source_position(source_name, x, y)
  local scene = obs.obs_frontend_get_current_scene()
  if not scene then return end
  
  local scene_source = obs.obs_scene_from_source(scene)
  local scene_item = obs.obs_scene_find_source(scene_source, source_name)
  
  if scene_item then
    local pos = obs.vec2()
    pos.x = x
    pos.y = y
    
    obs.obs_sceneitem_set_pos(scene_item, pos)
  end
  
  obs.obs_source_release(scene)
end

function set_source_size(source_name)
    local scene = obs.obs_frontend_get_current_scene()
    if not scene then return end

    local scene_source = obs.obs_scene_from_source(scene)
    local scene_item = obs.obs_scene_find_source(scene_source, source_name)

    if scene_item then
        local scaled_width = display_width * zoom_scale
        local scaled_height = display_height * zoom_scale

        obs.obs_sceneitem_set_bounds_type(scene_item, obs.OBS_BOUNDS_STRETCH)

        obs.obs_sceneitem_set_bounds_alignment(scene_item, 0)

        local bounds = obs.vec2()
        bounds.x = scaled_width
        bounds.y = scaled_height

        obs.obs_sceneitem_set_bounds(scene_item, bounds)
    end

    obs.obs_source_release(scene)
end

-- Set a script description.
function script_description()
    return "Moves cropped area to follow mouse (Horizontal pan only)"
end

-- Initialise the script properties.
function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_text(props, "source_name", "Source Name", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(props, "interval_ms", "Update Interval (ms)", 16, 200, 1)
    obs.obs_properties_add_int(props, "display_width", "Display Width", 0, 9999, 1)
    obs.obs_properties_add_int(props, "display_height", "Display Height", 0, 9999, 1)
    obs.obs_properties_add_int(props, "output_width", "Output Width", 0, 9999, 1)
    obs.obs_properties_add_int(props, "output_height", "Output Height", 0, 9999, 1)
    obs.obs_properties_add_float(props, "zoom_scale", "Zoom Scale", 1, 10, 0.25)
    obs.obs_properties_add_float(props, "smoothing_factor", "Smoothing Factor (0.01 = very slow/smooth, 1 = no smoothing)", 0.01, 1, 0.25)
    return props
end

-- Called when the script runs.
function script_update(settings)
    print("OBS Hypr Mouse Follow Script Running")
    source_name = obs.obs_data_get_string(settings, "source_name")
    interval_ms = obs.obs_data_get_int(settings, "interval_ms")
    display_width = obs.obs_data_get_int(settings, "display_width")
    display_height = obs.obs_data_get_int(settings, "display_height")
    output_width = obs.obs_data_get_int(settings, "output_width")
    output_height = obs.obs_data_get_int(settings, "output_height")
    zoom_scale = obs.obs_data_get_double(settings, "zoom_scale")
    smooting_factor = obs.obs_data_get_double(settings, "smoothing_factor")

    set_source_size(source_name) 

    if timer then obs.timer_remove(timer) end
    if source_name ~= "" then
        timer = obs.timer_add(update_crop, interval_ms)
    end
end

-- Clean-up when unloaded.
function script_unload()
    if timer then obs.timer_remove(timer) end
end
