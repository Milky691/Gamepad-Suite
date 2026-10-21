-- Auto Release: when the character dies, its spirit is released with the game's own Release call (Core/AdapterDeath.lua),
-- and one chat line says so. The row has three values: Off (the start), Battlegrounds, and Solo and Battlegrounds (also
-- in the open world while the player is in no group). Never in a dungeon, a raid, an arena or any group outside a
-- battleground, and never on a Hardcore realm, where death is final and the game shows its own window. Pause Automation
-- stops it (Auto/Automation.lua).
--
-- It never releases while the game offers a resurrection of the player's own (a soulstone, Reincarnation) or another
-- player offers one: the chat says why ("Soulstone is ready."), and the rest is the player's. No HasSoulstone on this build
-- (ForeverPlus's notes), so the game's own list of self resurrections is asked, the one its death window shows.
--
-- The wait: one second after the death, one timer, and every fact is asked again. The game's death window reads the self
-- resurrections on its first frames (Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua 291) and tells of a change
-- with SELF_RES_SPELL_CHANGED (Blizzard_Game/Camelot/EventRouting.lua 14): a soulstone is the character's before it
-- dies, so its option is there at once or a moment later, as is a resurrection offered in the same breath. A second
-- costs nothing in a battleground, where the spirit healer brings players back in waves. While the game would not let
-- its own Release button work (the body falls, a no-release effect), the check comes again a second later, five looks
-- at most; then the chat leaves it to the player. Nothing runs but after a death.
--
-- The log (kind "release") has the first deaths of a session: the facts, what was done, and at the next PLAYER_ALIVE
-- whether the game made the player a ghost. That proves the call from addon code works in one try.
local _, ns = ...

local Release = ns.Module("Release", { "release" }, "Auto Release")
ns.Release = Release

local KEY = "helpers.auto_release"
local WAIT, LOOKS = 1, 5
local MAX_NOTES = 9
local notes = 0
local death = 0         -- the deaths of the session, by number: a wait of an older one stops
local looks = 0         -- the looks for this death
local released = false  -- a release was asked for, and the log waits for PLAYER_ALIVE

local function note(text)
    if notes < MAX_NOTES then
        notes = notes + 1
        ns.Log.Add("release", text)
    end
end

-- True when the value lets a release be made in this place: a battleground, or with Solo and Battlegrounds the open
-- world out of a group. Also false while paused, and on a Hardcore realm.
local function fits(facts)
    local value = ns.Registry.Has(KEY) and ns.Registry.Get(KEY) or "Off"
    if value == "Off" or ns.Automation.Paused() or facts.hardcore then
        return false
    end
    return facts.kind == "pvp" or value == "Solo and Battlegrounds" and facts.kind == "none" and not facts.grouped
end

local function said(facts)
    return "in " .. tostring(facts.kind) .. (facts.grouped and " in a group" or "") .. (facts.hardcore and " (Hardcore)" or "")
end

local function look(mine)
    if mine ~= death then
        return
    end
    local facts = ns.Adapter.Death()
    if not facts.dead or facts.ghost or not fits(facts) then
        return note("after the wait: not released: dead " .. tostring(facts.dead) .. ", ghost " .. tostring(facts.ghost) .. ", " .. said(facts))
    elseif facts.own or facts.offer then
        -- (the way back by name: the game's own name of the self resurrection, "Soulstone")
        local named = type(facts.own) == "string" and facts.own or nil
        note("after the wait: not released: " .. (facts.offer and "a resurrection is on offer (" .. facts.offer .. ")"
            or "self resurrection offered: " .. tostring(named or "no name")))
        return ns.Print("Auto Release did not release your spirit. " .. (facts.offer and facts.offer .. " offers to bring you back."
            or named and named .. " is ready." or "You can bring yourself back."))
    end
    local stop = facts.falling and "the body falls" or facts.aura and "a no-release effect" or facts.time == 0 and "no release time"
    if stop then
        looks = looks + 1
        if looks < LOOKS then
            C_Timer.After(WAIT, function()
                ns.Call("Release", look, mine)
            end)
            return
        end
        note("after " .. LOOKS .. " looks: not released: " .. stop)
        return ns.Print("Auto Release did not release your spirit. The game does not allow it right now.")
    end
    local ok, err = ns.Adapter.Release()
    note("released " .. said(facts) .. ": the game " .. (ok and "took the call" or "refused (" .. tostring(err) .. ")"))
    if ok then
        released = true
        ns.Print("Auto Release released your spirit.")
    end
end

function Release.OnLogin()
    ns.On("PLAYER_DEAD", "Release", function()
        death, looks = death + 1, 0
        local facts, mine = ns.Adapter.Death(), death
        if fits(facts) then
            note("a death " .. said(facts) .. ": the release waits " .. WAIT .. " s")
            C_Timer.After(WAIT, function()
                ns.Call("Release", look, mine)
            end)
        end
    end)
    ns.On("PLAYER_ALIVE", "Release", function()
        if released then
            released = false
            note("after the release the game says the player is a ghost: " .. tostring(ns.Adapter.Death().ghost))
        end
    end)
end
