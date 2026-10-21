-- Rumble: the controller rumbles when the game's own low health warning shows (one long pulse)
-- and when a spell lights up, ready to use (two short pulses). The strength is the Rumble
-- setting of the Controller tab; Off stops both. A change of that setting rumbles once, so the
-- player feels the new strength. The range tick (Screen/Range.lua) plays its pulse through
-- Rumble.Pulse too, so it has the same strength and the same Off. The game events of the page
-- Rumble Events (Auto/RumbleEvents.lua) and Rumble When Ready (Auto/RumbleReady.lua) play their
-- patterns (Auto/RumbleModel.lua) through Rumble.Event.
local _, ns = ...

local Rumble = ns.Module("Rumble", { "rumble" }, "Rumble")
ns.Rumble = Rumble

local STRENGTH = { Light = 0.3, Medium = 0.6, Strong = 1.0 }
-- a spell that lights up: two pulses of 0.12 s, the second 0.25 s after the start of the first
local PROC = { { 0, 0.12 }, { 0.25, 0.12 } }
local lastProc = 0
-- game events that come within MERGE seconds of each other give one pattern
local MERGE = 0.1
local gathered            -- the most urgent pattern of the events that are being gathered now
local mine, mineEnds = nil, 0   -- the pattern of a game event that plays now, and when it ends
local busyUntil = 0     -- when the pulse, or the pair of pulses, that plays now is over
local stopsAt, playing = 0, nil   -- when the game stops the rumble that it plays now, and its strength
local told, lines = {}, 0

-- One line for each kind of thing, the first time in a session: the events that rumble come
-- (with Rumble Off too), and what the game did with the first pulse. Read from the saved file.
local function note(kind, text)
    if not told[kind] and lines < 16 then
        told[kind], lines = true, lines + 1
        ns.Log.Add("rumble", text)
    end
end

-- True while a pulse plays, or a pair of pulses is not over yet. The game has one rumble at a
-- time: a new pulse ends the one that plays. So a pulse that can be left out (the range tick)
-- asks here first, and is left out while this is true.
function Rumble.Busy()
    return GetTime() < busyUntil
end

-- One pulse at the strength of the setting. false when the setting is Off or the game cannot
-- rumble. why: what asked for it, for the log.
function Rumble.Pulse(seconds, why)
    local strength = STRENGTH[ns.Registry.Get("feel.rumble")]
    if not strength then
        return false
    end
    local now = GetTime()
    -- a shorter pulse at the same strength is felt inside the one that plays: it does not cut
    -- that one short
    if now + seconds < stopsAt and strength == playing then
        return true
    end
    local ok, played = pcall(ns.Adapter.Rumble, "High", strength, seconds)
    if not ok then
        note("refused", "the game refused a pulse: " .. tostring(played))
        return false
    end
    if not played then
        note("cannot", "no pulse: this game build cannot rumble")
        return false
    end
    stopsAt, playing = now + seconds, strength
    busyUntil = math.max(busyUntil, stopsAt)
    note("played", string.format("the game took the first pulse (%s): strength %.1f for %.2f s", why or "the range tick or a new strength", strength, seconds))
    return true
end

-- A pattern: its pulses, each { start, seconds } from now. It is one thing: the time between its
-- pulses is not free for another pulse. False when its first pulse does not play.
function Rumble.Play(pattern, why)
    local now = GetTime()
    if not Rumble.Pulse(pattern[1][2], why) then
        return false
    end
    for i = 2, #pattern do
        local at, seconds = pattern[i][1], pattern[i][2]
        busyUntil = math.max(busyUntil, now + at + seconds)
        C_Timer.After(at, function()
            Rumble.Pulse(seconds, why)
        end)
    end
    return true
end

local function flush()
    local name = gathered
    gathered = nil
    local patterns = ns.RumbleModel.PATTERNS
    if GetTime() < mineEnds and patterns[mine].rank >= patterns[name].rank then
        return
    end
    local pattern = patterns[name]
    if Rumble.Play(pattern, name) then
        local last = pattern[#pattern]
        mine, mineEnds = name, GetTime() + last[1] + last[2]
        note("pattern " .. name, "a pattern played: " .. name .. " (" .. #pattern .. (#pattern == 1 and " pulse)" or " pulses)"))
    end
end

-- A game event that rumbles: name is its pattern in Auto/RumbleModel.lua. The events that come
-- within MERGE seconds give one pattern, the most urgent one's; while one plays, only a more
-- urgent one plays. None while the game says the controller is not in use.
function Rumble.Event(name)
    if not ns.Adapter.PadActive() then
        return
    end
    if gathered then
        if ns.RumbleModel.PATTERNS[name].rank > ns.RumbleModel.PATTERNS[gathered].rank then
            gathered = name
        end
        return
    end
    gathered = name
    C_Timer.After(MERGE, function()
        ns.Call("Rumble", flush)
    end)
end

function Rumble.OnLogin()
    ns.Adapter.OnLowHealthWarning(function()
        note("low", "the game's low health warning showed (Rumble " .. tostring(ns.Registry.Get("feel.rumble")) .. ")")
        Rumble.Pulse(0.6, "low health")
    end)
    -- an event this game version does not have is left out
    pcall(ns.On, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "Rumble", function(spell)
        note("proc", "a spell lit up: " .. tostring(spell) .. " (Rumble " .. tostring(ns.Registry.Get("feel.rumble")) .. ")")
        -- some spells light up together: one pair of pulses for them, not one pair for each
        local now = GetTime()
        if now - lastProc < 1 then
            return
        end
        lastProc = now
        Rumble.Play(PROC, "a spell lit up")
    end)
end
