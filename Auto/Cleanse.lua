-- Cleanse: a bind, in the list Game Actions, for a character that knows a spell that removes a
-- debuff (Auto/CleanseModel.lua lists them). One press casts that spell on the first member of
-- the party, you first, who has a debuff of a kind the spell removes, else on a friendly target
-- that has one. With nobody to cleanse a press casts nothing (no mana, no wait), and the chat
-- says why once, until there was someone to cleanse again. In a fight it casts on your target
-- while it is a friend, else on you.
--
-- The game casts, not the addon: the bind clicks one of the game's secure buttons, which runs a
-- chat command (Core/AdapterCleanse.lua says why). The game locks the button in a fight and gives
-- nothing there a way to look at auras, so the command is written out of a fight: each time the
-- party's auras or the party change, and one last time when a fight starts (the game still takes
-- a change at that moment). The press in a fight runs that last command.
-- All of that runs only while a button or a fixed slot has the bind. A character with no such
-- spell has no bind, and nothing of this runs for it. The button is made at login all the same,
-- with no command, so the bind core finds it when a key gets the bind and hears its press
-- (Sticky Layers, Core/BindCore.lua).
--
-- The same rule puts a small mark on a member of the party wheel (Screen/WheelPlate.lua): Mark.
-- The log (kind "cleanse") has the spells found, the first commands written out of a fight and at
-- a fight's start, the first presses, and what the game hid or refused: three lines of each at
-- most in one session.
local _, ns = ...

local Cleanse = ns.Module("Cleanse", { "secure", "cleanse" }, "Cleanse")
ns.Cleanse = Cleanse

local Model = ns.CleanseModel

local BUTTON = "GamepadSuiteCleanse"
-- the bind, as the game names it
local COMMAND = "CLICK " .. BUTTON .. ":LeftButton"
local MAX_NOTES = 3     -- lines for the log of one subject in one session

local button, written
local removers = {}     -- what the character removes each kind of debuff with (Model.Removers)
local following = false -- a button has the bind: the party's auras are followed
local watched = {}      -- the units of the last command written: unit -> true
local told              -- the chat said "nobody to cleanse" for the empty command of now
local learned           -- the spells found, as the log has them
local notes = {}        -- subject -> lines the log has of it

local function note(about, text)
    if (notes[about] or 0) < MAX_NOTES then
        notes[about] = (notes[about] or 0) + 1
        ns.Log.Add("cleanse", text)
    end
end

-- The kind of debuff on a member that the character can remove now, or nil. nil too while the
-- game hides the member's auras: then no mark shows, the log says so, and true comes second.
function Cleanse.Mark(unit)
    local kinds = ns.Adapter.DebuffKinds(unit)
    if kinds == nil then
        note("hidden", "The game hides the auras of " .. unit .. ": no mark shows, and the press goes to a friendly target or to you.")
    end
    return Model.Mark(kinds, removers), kinds == nil
end

-- The bind list's entry (Core/Catalog.lua), with the picture of the first such spell. nil for a
-- character that knows no such spell.
function Cleanse.Bind()
    local first = removers.first
    if not first then
        return nil
    end
    return { kind = "command", id = COMMAND, name = "Cleanse", detail = "First party member with a debuff you can remove. In combat: your friendly target, or you.", icon = first.icon }
end

-- Makes the button, out of a fight. The log has the command of the first presses: that the
-- press reached the button, and what the game ran. A press of the empty command (nobody to
-- cleanse) says so in the chat, once for that cause.
local function make()
    if button then
        return
    end
    button = ns.Adapter.CleanseButton(BUTTON)
    button:HookScript("PostClick", function()
        note("press", "A press ran " .. (written and written ~= "" and written or "nothing") .. (ns.Adapter.InCombat() and ", in a fight." or "."))
        if written == "" and not told and not ns.Adapter.InCombat() then
            told = true
            ns.Print("Cleanse: your party and your target have no debuff you can remove.")
        end
    end)
end

-- Writes the command of the next press. It runs out of a fight only.
local function write()
    make()
    local units = ns.Adapter.PartyUnits()
    if #units == 0 then
        units = { "player" }
    end
    watched = {}
    for _, unit in ipairs(units) do
        watched[unit] = true
    end
    local text = Model.Text(removers, units, Cleanse.Mark, ns.fightStarted, not ns.fightStarted and ns.Adapter.FriendTarget()) or ""
    if text ~= "" then
        told = nil
    end
    if text ~= written then
        local ok, err = ns.Adapter.SetCleanse(button, text)
        written = ok and text or nil
        if not ok then
            note("refused", "The game kept the command: " .. err)
        elseif ns.fightStarted then
            note("fight", "A fight starts. The next press runs " .. text .. ".")
        else
            note("command", "The next press runs " .. (text ~= "" and text or "nothing") .. ".")
        end
    end
end

local function refresh()
    ns.Queue.Run("Cleanse", write)
end

-- The game's word of a change of auras comes for every unit; only the party's count (in a raid the
-- player's own raid group, by its raid numbers), and the target's while it is a friend.
local function aura(unit)
    if watched[unit] or unit == "target" and ns.Adapter.FriendTarget() then
        refresh()
    end
end

-- Out of a fight the auras and the target are followed.
local function calmEvents(on)
    if on then
        ns.On("UNIT_AURA", "Cleanse", aura)
        ns.On("PLAYER_TARGET_CHANGED", "Cleanse", refresh)
    else
        ns.Off("UNIT_AURA", "Cleanse")
        ns.Off("PLAYER_TARGET_CHANGED", "Cleanse")
    end
end

-- A fight starts: the command for the fight, and no more work on auras until it ends. If the
-- game has locked the button already, the command stays as it was until the fight ends.
local function fight()
    calmEvents(false)
    if ns.Adapter.InCombat() then
        note("locked", "A fight started with the button locked: the press keeps the command it had.")
    end
    refresh()
end

local function calm()
    calmEvents(true)
    refresh()
end

-- The party's auras are followed only while the character has such a spell and the bind is on a
-- button or a fixed slot. With the bind gone the button keeps its last command, which nothing presses.
local function follow()
    local now = removers.first ~= nil and ns.Binds.Uses(COMMAND)
    if now ~= following then
        following = now
        if now then
            ns.On("GROUP_ROSTER_UPDATE", "Cleanse", refresh)
            ns.On("PLAYER_REGEN_DISABLED", "Cleanse", fight)
            ns.On("PLAYER_REGEN_ENABLED", "Cleanse", calm)
            calmEvents(not ns.fightStarted)
        else
            for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
                ns.Off(event, "Cleanse")
            end
            calmEvents(false)
        end
    end
    if following then
        refresh()
    end
end

-- The spells the character knows changed: what it removes each kind with, read again.
local function learn()
    local ids, known, found = {}, {}, {}
    for i, spell in ipairs(Model.SPELLS) do
        ids[i] = spell.id
    end
    for _, spell in ipairs(ns.Adapter.KnownSpells(ids)) do
        known[spell.id] = spell
    end
    removers = Model.Removers(known)
    for _, kind in ipairs(Model.KINDS) do
        found[#found + 1] = removers[kind] and (kind .. ": " .. removers[kind].name .. " (" .. removers[kind].id .. ")") or nil
    end
    local text = found[1] and table.concat(found, ", ") or "none"
    if text ~= learned then
        learned = text
        note("spells", "The spells that remove a debuff: " .. text .. ".")
    end
    follow()
end

function Cleanse.OnLogin()
    ns.Queue.Run("Cleanse button", make)
    learn()
    ns.On("SPELLS_CHANGED", "Cleanse", learn)
    ns.Listen("bind", "Cleanse", follow)
    ns.Listen("slots", "Cleanse", follow)
end
