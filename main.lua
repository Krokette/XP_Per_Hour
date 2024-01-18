-- Constants
local update_frequency = 3
local bt = "UIPanelButtonTemplate"
local stopped = "XP Per Hour [off]"
local no_data = "0 XP per hour"

-- State
local state = {}
state.is_started = false
state.is_paused = false

-- Create addon UI
local function create_ui()
    local display_frame = CreateFrame("Frame")
    display_frame:SetSize(200, 50)
    display_frame:SetPoint(unpack(state.position))
    display_frame:SetMovable(true)
    display_frame:EnableMouse(true)
    display_frame:RegisterForDrag("LeftButton")
    display_frame:SetScript("OnDragStart", display_frame.StartMoving)
    display_frame:SetScript("OnDragStop", function(...)
        display_frame.StopMovingOrSizing(...)
        XP_Per_Hour_Position = {display_frame:GetPoint()}
    end)

    local display_string = display_frame:CreateFontString(nil,
                                                          "OVERLAY",
                                                          "GameTooltipText")
    display_string:SetPoint("TOPLEFT", display_frame, "TOPLEFT", 0, 0)
    display_string:SetText(stopped)
    state.display_string = display_string

    local button_start = CreateFrame("Button", nil, display_frame, bt)
    button_start:SetPoint("TOPLEFT", display_string, "BOTTOMLEFT", -1, -2)
    button_start:SetSize(60, 20)
    button_start:SetScale(0.7)
    button_start:SetText("Start")

    local fns = {}
    fns.start_handler = function(self)
        state.is_started = true
        state.is_paused = false  -- Reset pause state when starting
        -- Clear XP state
        state.flush_xp_gain(state)
        -- Attach OnUpdate handler
        state.event_frame:SetScript("OnUpdate", state.on_update_handler)
        display_string:SetText(no_data)
        -- Change self handler
        fns.change_to_stop_button()
    end
    fns.stop_handler = function(self)
        state.is_started = false
        
        -- Remove OnUpdate handler
        state.event_frame:SetScript("OnUpdate", nil)
        display_string:SetText(stopped)
        -- Change self handler
        fns.change_to_start_button()
    end
    fns.change_to_start_button = function()
        button_start:SetText("Start")
        button_start:SetScript("OnClick", fns.start_handler)
    end
    fns.change_to_stop_button = function()
        button_start:SetText("Stop")
        button_start:SetScript("OnClick", fns.stop_handler)
    end

    -- Initialize first handler (start)
    fns.change_to_start_button()

    local button_flush = CreateFrame("Button", nil, display_frame, bt)
    button_flush:SetPoint("LEFT", button_start, "RIGHT", 4, 0)
    button_flush:SetSize(60, 20)
    button_flush:SetScale(0.7)
    button_flush:SetText("Clear")
    button_flush:SetScript("OnClick", function(self)
        if state.is_started then
            -- Clear XP state
            state.flush_xp_gain(state)
        end
    end)

    --pause button
    local button_pause = CreateFrame("Button", nil, display_frame, bt)
    button_pause:SetPoint("LEFT", button_flush, "RIGHT", 4, 0)
    button_pause:SetSize(60, 20)
    button_pause:SetScale(0.7)
    button_pause:SetText("Pause")
    button_pause:SetScript("OnClick", function(self)
        if state.is_started then
            state.is_paused = not state.is_paused
            if state.is_paused then
                -- Pause button clicked, update UI and stop updating XP
                state.display_string:SetText("Paused")
                state.event_frame:SetScript("OnUpdate", nil)
            else
                -- Resume button clicked, update UI and resume updating XP
                state.display_string:SetText(Round(state.xp_per_hour) .. " XP per hour")
                state.event_frame:SetScript("OnUpdate", state.on_update_handler)
            end
        end
    end)
    --
end

-- XP functions
local function flush_xp_gain(state)
    state.time_interval_start = GetTime()
    state.xp_start_interval = UnitXP("player")
    state.display_string:SetText(no_data)
end
state.flush_xp_gain = flush_xp_gain

local function update_xp(state)
    local time_current = GetTime()
    local xp_current = UnitXP("player")
    local xp_gained = xp_current - state.xp_start_interval
    local time_since_interval_start = time_current - state.time_interval_start
    -- print(state.xp_gained_interval)
    -- print(time_since_interval_start)
    state.xp_per_hour = xp_gained / time_since_interval_start * 3600
    state.display_string:SetText(Round(state.xp_per_hour) .. " XP per hour")
end
state.update_xp = update_xp

-- Events that are watched
local events = {"ADDON_LOADED", "PLAYER_XP_UPDATE", "PLAYER_LOGIN"}

-- Event handlers
local event_handlers = {
    ADDON_LOADED = function(...)
        local addon_name = ...
        if addon_name == "XP_Per_Hour" then
            state.position = XP_Per_Hour_Position or {"CENTER", 0, 0}
            create_ui()
        end
    end,
    PLAYER_XP_UPDATE = function(...)
        if state.is_started then update_xp(state) end
    end
}

-- Create event frame
local event_frame = CreateFrame("Frame")
state.event_frame = event_frame
event_frame.time_since_update = 0

-- Register events on frame
for _, event in ipairs(events) do event_frame:RegisterEvent(event) end

-- Handle events
event_frame:SetScript("OnEvent", function(_, event, ...)
    local handler = event_handlers[event]
    local is_relevant_event = handler and type(handler) == "function"
    if is_relevant_event then return handler(...) end
end)

-- OnUpdate handler
state.on_update_handler = function(self, elapsed)
    self.time_since_update = self.time_since_update + elapsed
    if self.time_since_update > update_frequency then
        -- Update XP state every 4 seconds
        update_xp(state)
        -- Reset update tracker variable
        self.time_since_update = 0
    end
end
