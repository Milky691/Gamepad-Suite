-- Rumble When Ready (decision 23, our design GNW-05): in a fight, one short pulse when a spell's
-- cooldown of 10 seconds or more ends. The game names the spell whose cooldown changed
-- (SPELL_UPDATE_COOLDOWN). When it says that spell cools down (Adapter.Cooling, which in a fight
-- reads only the game's never-hidden yes and no, and leaves out the global cooldown), a Cooldown
-- frame of ours gets the game's own clock for it, without the global cooldown, and that clock's
-- OnCooldownDone is the end. No cooldown number is read: the length is our own clock, from the
-- game's word to the end. The game's word that the spell cools no more (a reset) is an end too.
-- Every spell the player casts counts, from any button: in a fight a controller player casts only
-- through a bound button. Two that end together give one pulse (Rumble.Event). Off at the start;
-- nothing is heard while the row is off or Rumble is Off.
local _, ns = ...

local Ready = ns.Module("RumbleReady", { "rumble", "spellState" }, "Rumble When Ready")
ns.RumbleReady = Ready

local holder
local clocks = {}   -- spell -> our Cooldown frame for it
local since = {}    -- spell -> when the game said its cooldown started, while it is watched
local told = {}

local function note(kind, text)
    if not told[kind] then
        told[kind] = true
        ns.Log.Add("rumble", text)
    end
end

local function ended(spell, how)
    local start = since[spell]
    since[spell] = nil
    if not start then
        return
    end
    local seconds, fight = GetTime() - start, ns.Adapter.InCombat()
    local pulse = fight and seconds >= ns.RumbleModel.FLOOR
    note("end " .. how .. tostring(fight), string.format("the clock of spell %s ran out (%s) after %.1f s, in combat: %s, pulse: %s", tostring(spell), how, seconds,
        tostring(fight), pulse and "yes" or "no"))
    if pulse then
        ns.Rumble.Event("ready")
    end
end

-- A clock of ours for a spell, made at its first cooldown. It is not under the game's interface:
-- it runs while that is hidden (Alt+Z, a talk). It draws nothing and takes no mouse.
local function clockOf(spell)
    if not clocks[spell] then
        if not holder then
            holder = CreateFrame("Frame")
            holder:SetSize(1, 1)
            holder:SetPoint("CENTER")
            holder:SetAlpha(0)
        end
        local clock = CreateFrame("Cooldown", nil, holder)
        clock:SetAllPoints()
        clock:SetDrawSwipe(false)
        clock:SetDrawEdge(false)
        clock:SetDrawBling(false)
        clock:SetHideCountdownNumbers(true)
        clock:SetScript("OnCooldownDone", function()
            ns.Call("RumbleReady", ended, spell, "OnCooldownDone")
        end)
        clocks[spell] = clock
    end
    return clocks[spell]
end

-- The game's word about a spell's cooldown: about is what it told (Adapter.Cooling), or nil when
-- it was about every cooldown.
local function look(spell, about)
    local bind = { kind = "spell", id = spell }
    local active, ends, sure = ns.Adapter.Cooling(bind, about)
    if active and (sure or since[spell]) then
        local clock = clockOf(spell)
        if not since[spell] then
            since[spell] = GetTime()
            note("watch " .. tostring(ends == nil), "a cooldown is watched: spell " .. tostring(spell) .. " (its numbers hidden: " .. tostring(ends == nil) .. ")")
        end
        ns.Adapter.ShowCooldown(clock, bind, true)
    elseif not active and since[spell] then
        ended(spell, "the game's word")
        clocks[spell]:Clear()
    end
end

local function heard(spell, base, _, recovery)
    if spell then
        look(spell, { spell = spell, base = base, recovery = recovery })
    else
        for watched in pairs(since) do
            look(watched)
        end
    end
end

-- The cooldown event is heard only while the row is on and Rumble is not Off.
local function listen()
    if ns.Registry.Get("feel.rumble_ready") and ns.Registry.Get("feel.rumble") ~= "Off" then
        ns.On("SPELL_UPDATE_COOLDOWN", "RumbleReady", heard)
        return
    end
    ns.Off("SPELL_UPDATE_COOLDOWN", "RumbleReady")
    for spell in pairs(since) do
        since[spell] = nil
        clocks[spell]:Clear()
    end
end

function Ready.OnLogin()
    listen()
    ns.Listen("setting", "RumbleReady", function(key)
        if key == "feel.rumble_ready" or key == "feel.rumble" then
            listen()
        end
    end)
end
