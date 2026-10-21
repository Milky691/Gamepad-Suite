-- Track Nearest Quest: a bind, in the list Game Actions. One press makes the quest whose next
-- step is nearest the one the game points at: the game's own arrow in the world, and its marks
-- on the map and the minimap. A second press goes to the next nearest quest, and so on round the
-- quest log. The addon draws nothing. Auto/QuestTrackModel.lua has the rules.
--
-- With an empty quest log, or with no quest that has a place on the map, the press does
-- nothing, and the chat says one time what is missing.
--
-- The quest also goes in the list at the side of the screen, so its steps show there; when that
-- list is full (the game's limit) the chat says so one time, and the arrow points all the same.
--
-- Nothing runs but at a press: one look at the quest log, the call for the arrow, and the one
-- for the side list.
--
-- That quests have places on this game, and that an addon may choose the quest in a fight, is
-- not proved by the game's code. So the log (kind "quest") has the first presses out of a fight
-- and the first in one: how many quests have a place, the quest that was asked for, and if the
-- game then points at it.
local _, ns = ...

local Track = ns.Module("TrackQuest", { "questTrack" }, "Track Nearest Quest")
ns.TrackQuest = Track

local Model = ns.QuestTrackModel

local BUTTON = "GamepadSuiteTrackQuest"
-- the game's picture of a map with a compass and a marked place
local ART = "Interface\\Icons\\INV_Misc_Map02"
local MAX_NOTES = 3     -- presses for the log in one session: so many out of a fight, so many in one

local last, pressedAt   -- the quest the press before chose, and when
local told = {}         -- what the chat has said, until that thing is there again
local full = false      -- the chat said the list at the side is full, until a quest goes in it
local notes = {}        -- lines in the log: [false] out of a fight, [true] in a fight

-- The bind list's entry (Core/Catalog.lua).
function Track.Bind()
    return { kind = "command", id = "CLICK " .. BUTTON .. ":LeftButton", name = "Track Nearest Quest", detail = "Press again for the next nearest", icon = ART }
end

local function press()
    local quests = ns.Adapter.Quests()
    local near = Model.Near(quests)
    local missing = Model.Missing(quests, near)
    local fight = ns.Adapter.InCombat()
    notes[fight] = (notes[fight] or 0) + 1
    local words = (fight and "in a fight: " or "out of a fight: ") .. #quests .. " quests, " .. #near .. " with a place on the map"
    if missing then
        if not told[missing] then
            told[missing] = true
            ns.Print(Model.TEXT[missing])
        end
    else
        told = {}
        local now = GetTime()
        local quest = Model.Pick(near, ns.Adapter.TrackedQuest(), last, pressedAt and now - pressedAt)
        last, pressedAt = quest.id, now
        local took, why = ns.Adapter.TrackQuest(quest.id)
        -- and in the list at the side, so its steps show there too; past the game's limit the chat says so once
        local watch = ns.Adapter.WatchQuest(quest.id)
        if watch == "full" and not full then
            full = true
            ns.Print(Model.TEXT.full)
        elseif watch == "added" then
            full = false
        end
        words = words .. "; asked for " .. quest.title .. " (" .. Model.Yards(quest.far) .. " yd): "
            .. (took and "the game points at it" or "the game does not point at it" .. (why and " (" .. why .. ")" or ""))
            .. "; side list: " .. tostring(watch)
    end
    if notes[fight] <= MAX_NOTES then
        ns.Log.Add("quest", words)
    end
end

function Track.OnLogin()
    -- a secure button (made out of a fight), so the bind core can hear its press too (Sticky Layers, Core/BindCore.lua)
    ns.Queue.Run("TrackQuest", function()
        local button = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("AnyDown")
        button:SetScript("OnClick", function()
            ns.Call("TrackQuest", press)
        end)
    end)
end
