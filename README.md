# Brunner Rudder Pedals for ToLiss Airbuses

A FlyWithLua script that makes Brunner force-feedback rudder pedals behave like the real Airbus:

- The pedals physically move with rudder trim, as they do in the aircraft, gliding to the new position rather than snapping.
- Small autopilot trim adjustments are ignored ("breakout friction"), so the pedals stay still during normal AP flight and only move when the trim genuinely changes.
- Your pedal input is sent to X-Plane as rudder relative to the trimmed pedal position, so a trimmed pedal at rest gives zero rudder input.

The script only runs in ToLiss Airbuses: A319, A320neo, A321 (ceo/neo/LR/XLR), A330-900 and A340-600. In any other aircraft it does nothing.

## Requirements

- X-Plane 12
- FlyWithLua NG (or NG+)
- Brunner rudder pedals with SimUX

## Installation

1. Copy `brunner_toliss_pedals.lua` into:
   `X-Plane 12/Resources/plugins/FlyWithLua/Scripts/`
2. Start X-Plane and load a ToLiss Airbus, or use **Plugins > FlyWithLua > Reload all Lua script files** if X-Plane is already running.

## Required SimUX settings

These settings are essential. The script will not work properly without them.

### 1. Rudder deadzone must be 0.0%

Set the deadzone on the rudder axis in SimUX to **0.0%**.

Any deadzone stops the pedals reporting their true position near center. The script then reads the gap between where the pedals were told to go and where they report as a rudder input. The autopilot fights that phantom input, and you feel the pedals moving during AP flight. A deadzone also causes the rudder to show full deflection on the ECAM at startup.

### 2. Trim settings must all be on

In SimUX, open **Rudder > List of Effects > Trim**, enable the Trim effect, and set all three options to **On**:

| Setting | Value |
|---|---|
| Read trim from simulation | On |
| Write trim to simulation | On |
| Write trim to device | On |

### 3. Dataref mappings

The script creates two datarefs that SimUX must use in place of the default rudder datarefs:

| Dataref | Direction | Purpose |
|---|---|---|
| `airbus/rudder_trim_normalized` | Script to SimUX | Trim position the pedals should move to |
| `airbus/raw_pedal_position` | SimUX to script | Actual pedal position |

Load a ToLiss aircraft first so the script has created these datarefs. Then, in SimUX, turn on **Show Advanced Settings** (bottom of the screen) and open the dataref mappings.

#### Input Mappings (sim to pedals)

Edit the mapping used by **Behavior: Rudder - Trim** (Actuator: Rudder Pilot, "Trim position for the assigned control surface") and set:

| Field | Value |
|---|---|
| X-Plane Dataref | `airbus/rudder_trim_normalized` |
| X-Plane Datatype | float |
| X-Plane Unit | Ratio Signed |
| SimData Variable | `controls/rudder/trim/position` |
| Read Mode | OnChange |
| Is Array | No |
| Conditions | None |

#### Output Mappings (pedals to sim)

Edit the mapping used by **Actuator: Rudder Pilot** (Role: Rudder, "Actuator position for Rudder") and set:

| Field | Value |
|---|---|
| X-Plane Dataref | `airbus/raw_pedal_position` |
| X-Plane Datatype | float |
| X-Plane Unit | Ratio Signed |
| SimData Variable | `controls/rudder/position` |
| Write Mode | OnChange |
| Is Array | No |
| Conditions | None |

Click **Apply & Save** when done. The two edited mappings show an **M** badge (manually edited). With **Show Live Data** on, the green dot next to each mapping lights up when data is flowing.

### 4. No yaw axis in X-Plane

While flying the ToLiss, the pedals must **not** also be assigned as a yaw axis in X-Plane's joystick settings. The script feeds rudder input to X-Plane itself; a second binding causes conflicting inputs.

Note: because the script only runs in ToLiss aircraft, other aircraft will need the pedals to reach X-Plane another way, such as a yaw axis binding or a separate SimUX profile.

## Tuning

All settings are at the top of the script.

| Setting | Default | What it does |
|---|---|---|
| `TRIM_FRICTION` | 0.05 | Trim change (about 0.7°) needed before the pedals move. Higher means the pedals move less often under AP. |
| `STILL_RATE` | 0.01 | Trim moving slower than this counts as stopped. |
| `SETTLE_TIME` | 0.5 | Seconds the trim must be still before the friction latches again. Once trim breaks out, the pedals follow it smoothly until it stops. |
| `TRIM_SLEW_RATE` | 0.3 | How fast the pedals follow trim changes. |
| `REST_DEADBAND` | 0.015 | Rudder deadband when the pedals are settled. Raise to 0.04 if you get phantom rudder input. |
| `MOTION_DEADBAND` | 0.10 | Rudder deadband while the pedals are being moved by trim, so the motor's movement isn't read as your input. |
| `DEADBAND_DECAY` | 0.3 | How quickly the deadband shrinks back after trim movement. |
| `HW_SCALE` | 1.20048 | Conversion between trim units and pedal hardware units. |
| `YAW_SMOOTH_TAU` | 0.033 | Smoothing on the rudder output, in seconds. |
| `GATE_ON_ENGINES` | false | Set to true to make the pedals follow trim only with an engine running. |
| `SHOW_DEBUG` | false | Set to true to show live values on screen. |

## Troubleshooting

Set `SHOW_DEBUG = true` and reload the scripts. A line of numbers appears on screen:

- `trim`: ToLiss rudder trim
- `mech`: trim position the pedals are being sent to
- `pedal`: actual pedal position reported by SimUX
- `yaw`: rudder input sent to X-Plane
- `db`: current deadband

With the AP on and your feet off the pedals, `pedal` should be close to `mech` × 1.2 and `yaw` should stay at 0.0000.

| Symptom | Likely cause |
|---|---|
| Pedals twitch with AP on, `yaw` not 0 | Pedals not reaching the commanded position. Check the SimUX deadzone is 0.0%, then try raising `REST_DEADBAND`. |
| `pedal` stuck at exactly 0.0000 near center | Deadzone in SimUX. Set it to 0.0%. |
| Rudder at full deflection on the ECAM at startup | SimUX deadzone, or the pedals also bound as a yaw axis in X-Plane. |
| Movement felt but `mech`, `pedal` and `yaw` all steady | A SimUX force effect, not the script. |
| No rudder at all | Check you're in a ToLiss aircraft and that the FlyWithLua log has no errors. |
| Debug text not visible in VR | Change the `600` in `draw_string(50, 600, ...)` to a smaller number. |

## License

MIT. See [LICENSE](LICENSE).
