-- Equipment Sets: each equipment set of the character is a bind, in a list of its own in the bind
-- list. A press of its button wears the set.
--   The sets are the game's own: the player makes one in the character window, on the Equipment
--   Manager tab. The addon keeps no set and has no page for them. A character with no set has no
--   such list.
--   The game wears the set, not the addon: the bind clicks one of the game's secure buttons
--   (Core/AdapterGear.lua). So a press works in a fight, where the game's rule is that only the
--   weapons change (main hand, off hand, ranged). The rest goes on when the fight ends: that one
--   call is the addon's, out of the fight, and one chat line at the press says that it will come.
--   A set with an item that is not in the bags goes on without it, and the chat names the place
--   one time.
-- Nothing runs while nothing happens: the sets are read when the game says that they changed,
-- and the rest of the work is done at a press.
--
-- The game's files do not prove that its server has sets for this kind of game, what its call
-- changes in a fight, or that it takes the call from an addon after one. The log (kind "gear")
-- has the count of sets, what the first presses changed a second after each, and the game's
-- answer to the first calls after a fight.
local _, ns = ...

local Gear = ns.Module("GearSets", { "secure", "gearSets" }, "Equipment Sets")
ns.GearSets = Gear

local Model = ns.GearModel

local SETTLE = 1         -- seconds from a press to the read for the log: a swap takes a moment
local LINES = 3          -- lines in the log for each: presses in a fight, presses out of one, calls after a fight
local button
local names = {}         -- key -> the name of each set, as of the game's last word on its sets
local written = {}       -- the same, as it is on the button
local told = {}          -- key -> the chat line said last for it: a line is said one time
local waiting            -- the key of the set that the end of this fight wears
local before             -- what the character wore when the key of a set went down, before the game's call
local logged = { [true] = 0, [false] = 0, after = 0 }
local some               -- the log has "no set" (false) or "sets" (true)
local asked              -- { id = the game's number of the set, key }: the last swap the bind asked for out of a fight
local heard              -- the log has the game's word at the end of a swap (once a session)
local pressed

-- The sets as entries for the bind list (Core/Catalog.lua).
function Gear.Binds()
    return Model.Binds(ns.Adapter.GearSets())
end

-- For a wheel and for a tap on a fixed slot: bind -> the click that does the same (Model.Clicks).
function Gear.Clicks()
    return Model.Clicks(names)
end

-- Says a line in the chat when it is not the line said last for this key. nil forgets the line.
local function say(key, text)
    if text and told[key] ~= text then
        ns.Print(text)
    end
    told[key] = text
end

-- Puts the name of every set on the button, under its key, and takes off a set that is gone. The
-- game locks the button in a fight, so this runs out of one (ns.Queue).
local function write()
    if not button then
        button = ns.Adapter.GearButton(Model.BUTTON)
        -- what a press changes is counted from what was on before the game's call, whether the
        -- game moves the items at the call or a moment after it
        button:HookScript("PreClick", function()
            before = ns.Adapter.GearWorn()
        end)
        button:HookScript("PostClick", function(_, key, down)
            if down then
                ns.Call("GearSets", pressed, key)
            end
        end)
    end
    for key in pairs(written) do
        if not names[key] then
            button:SetAttribute("set-" .. key, nil)
        end
    end
    for key, name in pairs(names) do
        if written[key] ~= name then
            button:SetAttribute("set-" .. key, name)
        end
    end
    written = names
end

-- Reads the sets' names: at login, after a loading screen, and when the game says that a set
-- was made, saved, named anew or deleted.
local function read()
    local sets = ns.Adapter.GearSets()
    local old, changed = names, false
    names = {}
    for _, set in ipairs(sets) do
        local key = Model.Key(set.name)
        names[key], changed = set.name, changed or old[key] == nil
    end
    for key in pairs(old) do
        changed = changed or names[key] == nil
    end
    if some ~= (#sets > 0) then
        some = #sets > 0
        ns.Log.Add("gear", #sets .. " equipment sets; the game says sets can be used: " .. ns.Adapter.GearSetsAllowed())
    end
    ns.Queue.Run("GearSets", write)
    -- A wheel and a fixed slot take a set's click when the binds are built (Core/AdapterWheel.lua,
    -- MenuButtons). The first build is before this login, so they are built again with the sets.
    if changed then
        ns.Send("wheels")
    end
end

-- The end of a fight: the part of the set that the fight kept back goes on. With nothing left
-- to change (the game put all of it on in the fight, or the set is gone) no call is made.
local function wear(key)
    waiting = nil
    local set = Model.Find(ns.Adapter.GearSets(), key)
    if not set or #Model.Changes(set, ns.Adapter.GearWorn()) == 0 then
        return
    end
    local ok, why = ns.Adapter.WearGearSet(set.name)
    asked = ok and { id = set.id, key = key } or asked
    if logged.after < LINES then
        logged.after = logged.after + 1
        ns.Log.Add("gear", set.name .. ", the call after a fight: " .. (ok and "the game took it" or "the game did not take it (" .. tostring(why) .. ")"))
    end
end

local function later(key)
    ns.Queue.Run("GearSets wear", function()
        wear(key)
    end)
end

-- For the log, a moment after a press: how many places the press had to change, how many are
-- still not the set's, and what the game says of the set.
local function note(key, fight, count)
    local set = Model.Find(ns.Adapter.GearSets(), key)
    if set then
        ns.Log.Add("gear", set.name .. (fight and ", a press in a fight: " or ", a press out of a fight: ") .. count .. " places to change, "
            .. #Model.Changes(set, ns.Adapter.GearWorn()) .. " after " .. SETTLE .. " s; worn in full: " .. tostring(set.worn)
            .. "; items the game cannot find: " .. set.lost .. " (" .. #set.gone .. " with a place)")
    end
end

-- A press of a set's bind: the game's button has made the game's call. The addon's part comes
-- after it: the chat lines, and the call that waits for the end of a fight.
pressed = function(key)
    local set = Model.Find(ns.Adapter.GearSets(), key)
    if not set then
        return say(key, Model.NO_SET)
    elseif not written[key] then
        -- The button did not have this set at the press (the set is new in this fight, or the
        -- game had its sets ready with no word about it): the addon's call wears it, now or
        -- when the fight ends.
        read()
        return later(key)
    end
    local fight = ns.Adapter.InCombat()
    local changes = Model.Changes(set, before or ns.Adapter.GearWorn())
    -- one line for each cause: an item not in the bags; out of a fight, a set that is on already
    -- (in one, that press says nothing and the line said before still stands); else none
    local gone = Model.GoneText(set)
    if gone or #changes > 0 or not fight then
        say(key, gone or (#changes == 0 and Model.OnText(set)) or nil)
    end
    -- (the game's word at the end of the swap tells when it could not put it all on; in a fight
    -- the rest waits by the game's rule, and the line for that is Model.LaterText)
    if not fight and #changes > 0 then
        asked = { id = set.id, key = key }
    end
    if fight and #changes > 0 then
        -- the line is for a part that the game's rule keeps back; one line for a set in a fight
        if #Model.Later(changes) > 0 and waiting ~= key then
            ns.Print(Model.LaterText(set))
        end
        -- (the call is asked for with any change: it does nothing when all of the set is on by then)
        waiting = key
        later(key)
    end
    if logged[fight] < LINES then
        logged[fight] = logged[fight] + 1
        C_Timer.After(SETTLE, function()
            ns.Call("GearSets", note, key, fight, #changes)
        end)
    end
end

-- The game ended a swap of a set: a swap of a press that it could not end is said, once a cause.
local function swapped(done, id)
    local key, set = asked and asked.id == id and asked.key, nil
    for _, one in ipairs(ns.Adapter.GearSets()) do
        set = set or (one.id == id and one) or nil
    end
    if not heard then
        heard = true
        ns.Log.Add("gear", "the game's word at the end of a swap: done " .. tostring(done) .. ", set " .. (set and set.name or tostring(id)))
    end
    if key then
        asked = nil
    end
    if key and set and not done then
        say(key, Model.FailText(set))
    end
end

function Gear.OnLogin()
    ns.Adapter.OnGearSets(read)
    ns.Adapter.OnGearSwap(swapped)
    ns.On("PLAYER_ENTERING_WORLD", "GearSets", read)
    read()
end
