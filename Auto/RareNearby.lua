-- Rare Nearby: a rare or a rare elite is near. The controller rumbles once (the Rumble module's own pulse, at the
-- row Rumble's strength; Off stops it) and the pop-up (Screen/Popup.lua) says "Rare nearby: Name, level 24" or "Rare
-- elite nearby: Name, level 30, in combat" for 5 seconds: the level in the game's own colour for it (grey for a low
-- rare, which can still hold a quest item; "level ??" for a boss skull), and "in combat" while the rare fights
-- someone (it may die, or they may want help). Once for each rare in a session, by its GUID. The game tells of a rare
-- three ways: its name plate shows (only while the game's enemy name plates are on), the player faces it (the game's
-- soft target), or targets it. Not for a dead rare, one the player cannot attack, or one another player has tapped
-- (Core/AdapterPopups.lua, Adapter.Rare); such a rare is not marked, so it can show later. A rare that comes while
-- the pop-up cannot show (a window, a wheel or the keyboard is open, or a pop-up before it in the order shows) is not
-- marked either.
--
-- Quiet in combat, on a flight path, and while the player is dead or a ghost: no pop-up and no rumble, and the rare
-- is not marked, so it shows at the next sighting on foot. In a fight a pulse would read as the danger pulses of
-- Rumble Events (a death, a stun), and a rare met in a fight is most often the one being fought.
-- With the row off the three events are not heard.
local _, ns = ...

local Rare = ns.Module("RareNearby", { "rareNearby" }, "Rare Nearby")
ns.RareNearby = Rare

local ROW = "windows.rare_nearby"   -- the row; On while the settings lack it
local SECONDS, PULSE = 5, 0.25
-- each event and the unit it is about (a name plate's unit comes with its event)
local EVENTS = { NAME_PLATE_UNIT_ADDED = false, PLAYER_SOFT_ENEMY_CHANGED = "softenemy", PLAYER_TARGET_CHANGED = "target" }
local AWAY = { taxi = "on a taxi", dead = "dead or a ghost", hidden = "the game hides if the player is on a taxi or dead" }

local seen, told = {}, {}

-- One line in the log (kind "rare") for each kind of thing, the first time in a session. Read from the saved file.
local function note(kind, text)
    if not told[kind] then
        told[kind] = true
        ns.Log.Add("rare", text)
    end
end

local function on()
    return not ns.Registry.Has(ROW) or ns.Registry.Get(ROW) == true
end

-- "|cff...level 24|r" in the level's colour, or "" when the level is hidden.
local function level(rare)
    if not rare.level then
        return ""
    end
    local c = rare.color
    local hex = c and string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
        or ns.Theme.Hex("cream")
    return ns.Theme.Hex("cream") .. ", |r" .. hex .. "level " .. (rare.level == -1 and "??" or rare.level) .. "|r"
end

local function look(event, unit)
    if ns.fightStarted or ns.Adapter.InCombat() then
        return
    end
    local away = ns.Adapter.PlayerAway()
    if away then
        note(away, "a rare is not shown: " .. AWAY[away])
        return
    end
    local rare, why = ns.Adapter.Rare(unit)
    if not rare then
        if why ~= "" then
            note(why, "a rare is not shown: " .. why .. " (" .. event .. ")")
        end
        return
    elseif seen[rare.guid] then
        return
    end
    local words = rare.elite and "Rare elite nearby:" or "Rare nearby:"
    local title = ns.Theme.Hex("cream") .. words .. "|r " .. rare.name .. level(rare)
        .. (rare.fighting and ns.Theme.Hex("cream") .. ", in combat|r" or "")
    if ns.Popup.Show({ owner = "rare", title = title, seconds = SECONDS }) ~= true then
        return
    end
    seen[rare.guid] = true
    -- (as Rumble.Event: none while the game says the controller is not in use)
    local pulsed = ns.Adapter.PadActive() and ns.Rumble.Pulse(PULSE, "a rare nearby") or false
    note("shown", "a rare showed (" .. event .. ", elite: " .. tostring(rare.elite) .. "); rumble: " .. tostring(pulsed))
    note("level", "a rare showed with level " .. tostring(rare.level) .. (rare.level and " (plain)" or " (hidden)")
        .. ", colour " .. (rare.color and "from the game" or "none") .. ", in combat: " .. tostring(rare.fighting))
end

-- The events are heard while the row is on, and not at all while it is off.
local function follow()
    for event, unit in pairs(EVENTS) do
        if on() then
            ns.On(event, "RareNearby", function(plate)
                look(event, unit or plate)
            end)
        else
            ns.Off(event, "RareNearby")
        end
    end
    if not on() then
        ns.Popup.Hide("rare")
    end
end

function Rare.OnLogin()
    follow()
    ns.Listen("setting", "RareNearby", function(key)
        if key == ROW then
            follow()
        end
    end)
end
