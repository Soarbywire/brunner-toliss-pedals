-- ==========================================================
-- Brunner rudder pedals <-> ToLiss rudder trim bridge (FlyWithLua)
-- Pedals physically follow rudder trim; pilot input is sent to
-- X-Plane as yaw relative to the trimmed pedal position.
-- ==========================================================

-- ==========================================
-- TUNING
-- ==========================================
local TRIM_FRICTION   = 0.05    -- hysteresis on the trim dataref (~0.7 deg on ToLiss).
                                -- Pedals only move when trim changes by more than this.
local STILL_RATE      = 0.01    -- trim slower than this (units/s) counts as stopped
local SETTLE_TIME     = 0.5     -- seconds trim must be still before the friction latches again
local TRIM_SLEW_RATE  = 0.3    -- max speed the pedals follow trim (trim units per second)
local REST_DEADBAND   = 0.015   -- yaw deadband when the pedals are settled
                                -- (raise to 0.04 if 'yaw' flickers with feet off)
local MOTION_DEADBAND = 0.10    -- yaw deadband while the motor is moving the pedals
local DEADBAND_DECAY  = 0.3     -- how fast MOTION_DEADBAND shrinks back to REST_DEADBAND (per second)
local HW_SCALE        = 1.20048 -- trim units -> pedal hardware units
local YAW_SMOOTH_TAU  = 0.033   -- yaw output smoothing time constant (seconds)
local GATE_ON_ENGINES = false   -- true = pedals only follow trim with an engine running
local SHOW_DEBUG      = false   -- true = on-screen readout of trim/mech/pedal/yaw
-- ==========================================

-- 0. Only run in ToLiss Airbuses (matched by ICAO code)
--    A319 = A319, A20N = A320neo, A321 = A321ceo, A21N = A321neo/LR/XLR,
--    A339 = A330-900, A346 = A340-600
local TOLISS_ICAO = { A319 = true, A20N = true, A321 = true, A21N = true, A339 = true, A346 = true }

if not TOLISS_ICAO[PLANE_ICAO] then
    logMsg("Brunner pedal script: " .. tostring(PLANE_ICAO) .. " is not a ToLiss Airbus, not loading")
    return
end

-- 1. Shared datarefs for Simux
define_shared_DataRef("airbus/rudder_trim_normalized", "Float")
define_shared_DataRef("airbus/raw_pedal_position", "Float")

-- 2. Bindings
DataRef("toliss_trim",     "sim/flightmodel/controls/rud_trim",        "readonly")
DataRef("scaled_trim_out", "airbus/rudder_trim_normalized",            "writable")
DataRef("raw_pedal_in",    "airbus/raw_pedal_position",                "readonly")
DataRef("xp_yaw",          "sim/cockpit2/controls/yoke_heading_ratio", "writable")
DataRef("frame_period",    "sim/time/framerate_period",                "readonly")
eng_running = dataref_table("sim/flightmodel/engine/ENGN_running")

-- State
local committed_trim = 0.0
local mechanical_trim_position = 0.0
local dynamic_deadband = REST_DEADBAND
local final_smooth_yaw = 0.0
local last_toliss_trim = 0.0
local tracking = false
local still_time = 0.0
local is_first_run = true

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- 3. Main loop
function process_brunner_pedals()
    local dt = frame_period
    if dt == nil or dt <= 0 then return end
    if dt > 0.1 then dt = 0.1 end  -- no big jumps after pauses or loading stutters

    if is_first_run then
        committed_trim = toliss_trim
        mechanical_trim_position = toliss_trim
        last_toliss_trim = toliss_trim
        is_first_run = false
    end

    -- A. Breakout friction with tracking:
    --    Small AP trim tweaks are ignored. Once trim moves past TRIM_FRICTION,
    --    the pedals follow it continuously (no stop-start steps) until the
    --    trim has been still for SETTLE_TIME, then the friction latches again.
    local trim_rate = math.abs(toliss_trim - last_toliss_trim) / dt
    last_toliss_trim = toliss_trim

    if tracking then
        committed_trim = toliss_trim
        if trim_rate < STILL_RATE then
            still_time = still_time + dt
            if still_time >= SETTLE_TIME then tracking = false end
        else
            still_time = 0.0
        end
    elseif math.abs(toliss_trim - committed_trim) > TRIM_FRICTION then
        tracking = true
        still_time = 0.0
        committed_trim = toliss_trim
    end

    -- B. Target position (optional engine gate)
    local target = committed_trim
    if GATE_ON_ENGINES then
        local engine_running = (eng_running[0] > 0) or (eng_running[1] > 0)
        if not engine_running then target = mechanical_trim_position end
    end

    -- C. Single slew limiter: pedals glide to the new trim, never snap
    local step = TRIM_SLEW_RATE * dt
    local move = clamp(target - mechanical_trim_position, -step, step)
    local moving = math.abs(move) > 0.00001
    mechanical_trim_position = mechanical_trim_position + move

    -- D. Send trim position to the pedals
    local scaled_trim = clamp(mechanical_trim_position * HW_SCALE, -1.0, 1.0)
    scaled_trim_out = scaled_trim

    -- E. Widen the deadband while the motor moves, then shrink it back
    if moving then
        dynamic_deadband = MOTION_DEADBAND
    else
        dynamic_deadband = math.max(REST_DEADBAND, dynamic_deadband - DEADBAND_DECAY * dt)
    end

    -- F. Pilot input = pedal displacement from the trimmed position
    local diff = raw_pedal_in - scaled_trim
    if diff > dynamic_deadband then
        diff = diff - dynamic_deadband
    elseif diff < -dynamic_deadband then
        diff = diff + dynamic_deadband
    else
        diff = 0.0
    end

    -- G. Back to X-Plane yaw units
    local yaw = clamp(diff / HW_SCALE, -1.0, 1.0)

    -- H. Frame-rate-independent smoothing
    local alpha = 1.0 - math.exp(-dt / YAW_SMOOTH_TAU)
    final_smooth_yaw = final_smooth_yaw + (yaw - final_smooth_yaw) * alpha
    if math.abs(final_smooth_yaw) < 0.00001 then final_smooth_yaw = 0.0 end

    xp_yaw = final_smooth_yaw
end

do_every_frame("process_brunner_pedals()")

-- 4. Optional debug readout
if SHOW_DEBUG then
    function draw_pedal_debug()
        draw_string(50, 600, string.format(
            "trim %.4f  mech %.4f  pedal %.4f  yaw %.4f  db %.3f",
            toliss_trim, mechanical_trim_position, raw_pedal_in, xp_yaw, dynamic_deadband))
    end
    do_every_draw("draw_pedal_debug()")
end
