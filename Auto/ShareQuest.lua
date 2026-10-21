-- Share Quests: in a party, the player takes a quest and a member says "share". The quest log trip is 5 to 25 presses;
-- the pop-up (Screen/Popup.lua) offers the share with one hold: the quest's name, and "Hold to share with Bob" (or
-- "Bob, Ann", or past two "3"). Hold Y one second and let go: the game shares the quest with the party
-- (Core/AdapterShare.lua), and the pop-up reads "Shared" for 2 seconds.
--
-- It shows only in a party (never a raid), for a quest the game lets the player share, when at least one member is not
-- on it, and never for a quest a member offered (the quest window's giver was a player). Once for each quest in a
-- session: a share done, or a pop-up let run out, does not come back for that quest. Auto Quest that takes three quests
-- in a row makes three: they wait in turn, 10 seconds each. Out of combat (it waits for the end, 30 seconds at most); it
-- goes when the group ends or no member is left who lacks it. The hold is the pop-up's (Screen/PopupHold.lua): no key
-- is taken, a tap of Y does Y's bind. If the game refuses the share at the let-go, the hold turns to "hold, let go,
-- press" for the session; refused again, it is off for the session with one chat line. A member out of reach is left
-- to the game: its own line says so.
--
-- The log (kind "share") has the first quest taken in a party with what was found, and the first share.
local _, ns = ...

local Share = ns.Module("ShareQuest", { "shareQuests" }, "Share Quests")
ns.ShareQuest = Share

local ROW = "windows.share_quests"   -- the row; On while the settings lack it
local SECONDS, WAIT = 10, 30

local offered = {}     -- the quests offered in this session
local fromPlayer, offerID   -- the last quest offer came from a player, and its quest
local told = {}

local function note(kind, text)
    if not told[kind] then
        told[kind] = true
        ns.Log.Add("share", text)
    end
end

local function on()
    return not ns.Registry.Has(ROW) or ns.Registry.Get(ROW) == true
end

-- True while a share of this quest would do something.
local function still(id)
    local info = ns.Adapter.InParty() and ns.Adapter.ShareInfo(id)
    return info and info.pushable and #info.names > 0 and info or nil
end

local ACT = { key = "Y", go = "Let go to share", again = "Press once more: share", fight = "Share after combat", after = "Shared",
    fallback = "press", log = "share",
    line = "Share Quests (Screen, Pop-ups) is off for this session. The game did not let Gamepad Suite share the quest.",
    words = function(item) return "Hold to share with " .. item.names end,
    steps = function(item) return "Hold, let go, press: share with " .. item.names end,
    done = function(item)
        local made = ns.Adapter.ShareQuest(item.who)
        note("shared", "a let-go shared quest " .. item.who .. ": the call was made: " .. tostring(made))
        return made
    end }

-- A quest was taken (one frame after the game's word: its log index is there then).
local function took(id)
    if not on() or type(id) ~= "number" or offered[id] then
        return
    elseif not ns.Adapter.InParty() then
        return
    end
    local byPlayer = fromPlayer and (offerID == nil or offerID == id)
    local info = ns.Adapter.ShareInfo(id)
    note("taken", "QUEST_ACCEPTED " .. id .. ": pushable " .. tostring(info and info.pushable) .. ", members not on it "
        .. (info and #info.names or 0) .. ", offered by a player " .. tostring(byPlayer))
    if byPlayer or not (info and info.pushable and #info.names > 0) then
        return
    end
    offered[id] = true
    ns.Popup.Show({ owner = "share", each = true, who = id, title = info.title or "Share this quest", seconds = SECONDS, wait = WAIT,
        calm = true, key = "Y", acts = { ACT }, names = ns.PopupModel.Names(info.names),
        valid = function()
            return still(id) ~= nil
        end })
end

-- The group changed: a share pop-up of a group that ended goes; the names of the others are read again.
local function regroup()
    local item = ns.Popup.Shown()
    if not ns.Adapter.InParty() then
        ns.Popup.Hide("share")
    elseif item and item.owner == "share" then
        local info = still(item.who)
        if info then
            item.names = ns.PopupModel.Names(info.names)
            ns.PopupHold.Sync()
        else
            ns.Popup.Hide("share", item.who)
        end
    end
end

function Share.OnLogin()
    ns.On("QUEST_DETAIL", "ShareQuest", function()
        fromPlayer, offerID = ns.Adapter.OfferFromPlayer()
    end)
    ns.On("QUEST_ACCEPTED", "ShareQuest", function(id)
        C_Timer.After(0, function()
            ns.Call("ShareQuest", took, id)
            fromPlayer, offerID = false, nil
        end)
    end)
    ns.On("GROUP_ROSTER_UPDATE", "ShareQuest", regroup)
    ns.Listen("setting", "ShareQuest", function(key)
        if key == ROW and not on() then
            ns.Popup.Hide("share")
        end
    end)
end
