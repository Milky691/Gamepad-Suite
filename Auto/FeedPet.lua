-- Feed Pet: a bind for a hunter, in the list Game Actions. One press feeds the pet the best food
-- of the bags that this pet eats (Auto/FeedPetModel.lua has the rule). With no pet out, a dead
-- pet, no such food, or Feed Pet not known, the press does nothing, and the chat says one time what
-- is missing. A pet that died after the last look is asked at the press. In a fight the press does
-- nothing: the game feeds no pet then. The pop-up Pet Hungry (Auto/PetHungry.lua) uses the same
-- button and food (Feed.Prime, Feed.Button), and hears each press ("feed:pressed").
--
-- The game feeds, not the addon: the bind clicks one of the game's secure buttons
-- (Core/AdapterFeed.lua says why). The game locks such a button in a fight, so the food is
-- chosen out of a fight: when the bind is put on a button, when the bags change and when the
-- pet changes. A change in a fight waits for its end. Nothing runs between those events.
--
-- All of that runs only while a button or a fixed slot has the bind. A hunter with Feed Pet on no
-- button and in no slot hears no event and looks at no bag; the button is made at login all the
-- same, with no action, so the bind core finds it when a key gets the bind and hears its press
-- (Sticky Layers, Core/BindCore.lua). Another class has no such bind, and nothing of this runs for it.
--
-- That the button feeds on this game is proved by the game's own code only. So the log (kind
-- "feed") has the first presses: the food, how many of it the bags held before and after, and
-- whether the spell still waited for its food after the press (then the second step failed).
local _, ns = ...

local Feed = ns.Module("FeedPet", { "secure", "feedPet" }, "Feed Pet")
ns.FeedPet = Feed

local Model = ns.FeedPetModel

local BUTTON = "GamepadSuiteFeedPet"
-- the bind, as the game names it
local COMMAND = "CLICK " .. BUTTON .. ":LeftButton"
-- the game's own picture of the spell Feed Pet
local ART = "Interface\\Icons\\Ability_Hunter_BeastTraining"
local MAX_NOTES = 3     -- presses for the log in one session

local button
local following = false -- a button has the bind: the pet and the bags are followed
local food              -- the food of the next press, or nil
local missing           -- what stops a feed now: "pet", "food" or nil
local told = {}         -- what the chat has said, until that thing is there again
local notes = 0

-- The bind list's entry (Core/Catalog.lua). nil for a class with no pet to feed.
function Feed.Bind()
    if ns.Adapter.Class() ~= "HUNTER" then
        return nil
    end
    return { kind = "command", id = COMMAND, name = "Feed Pet", detail = "The best food in your bags", icon = ART }
end

-- After each press out of a fight: the chat line for a press that could feed nothing, and for
-- the first presses the log.
local refresh
local function pressed()
    if ns.Adapter.InCombat() then
        return
    end
    ns.Send("feed:pressed")
    -- the pet died, or went, since the last look: the press says so, and the button loses its food
    local state = ns.Adapter.PetState()
    if state ~= "alive" and missing ~= "pet" and missing ~= "dead" then
        missing = Model.Missing(state, food)
        refresh()
    end
    if missing then
        if not told[missing] then
            told[missing] = true
            ns.Print(Model.TEXT[missing])
        end
    elseif food and notes < MAX_NOTES then   -- (no food and nothing missing: no look yet, the bind is on no key)
        notes = notes + 1
        local fed, before, waits = food, ns.Adapter.FoodLeft(food.id), ns.Adapter.SpellWaits()
        C_Timer.After(1.5, function()
            ns.Log.Add("feed", "a press fed item " .. fed.id .. " (level " .. fed.level .. ") from bag " .. fed.bag .. ", place " .. fed.slot
                .. ": the bags held " .. before .. " before and " .. ns.Adapter.FoodLeft(fed.id) .. " a moment after"
                .. "; the spell still waited for its food after the press: " .. tostring(waits))
        end)
    end
end

-- Makes the button, out of a fight: at login, or at the first look.
local function make()
    if not button then
        button = ns.Adapter.FeedButton(BUTTON)
        button:HookScript("PostClick", pressed)
    end
end

-- Looks at the pet and the bags, and gives the button the food of the next press. It runs out of
-- a fight only.
local function look()
    make()
    local pet = ns.Adapter.PetState()
    food = pet == "alive" and Model.Best(ns.Adapter.PetFoods()) or nil
    missing = Model.Missing(pet, food, select(2, ns.Adapter.FeedUsable()))
    if missing == "spell" then
        food = nil
    end
    -- a thing that is there again can be told of the next time it is missing
    for what in pairs(told) do
        if what ~= missing then
            told[what] = nil
        end
    end
    ns.Adapter.SetFeed(button, food)
end

function refresh()
    ns.Queue.Run("FeedPet", look)
end

-- For the pop-up Pet Hungry: the button gets the food of the next press now (out of a fight), and is given back.
function Feed.Prime()
    refresh()
    return button
end

-- At login and at each change of the binds or the fixed slots: the pet and the bags are followed
-- only while a button or a fixed slot has the bind. The game's word of the pet comes for every
-- unit; only the player's counts.
local function follow()
    local now = ns.Binds.Uses(COMMAND)
    if now == following then
        return
    end
    following = now
    if now then
        ns.On("UNIT_PET", "FeedPet", function(unit)
            if unit == "player" then
                refresh()
            end
        end)
        ns.On("BAG_UPDATE_DELAYED", "FeedPet", refresh)
        refresh()
    else
        ns.Off("UNIT_PET", "FeedPet")
        ns.Off("BAG_UPDATE_DELAYED", "FeedPet")
    end
end

function Feed.OnLogin()
    if ns.Adapter.Class() ~= "HUNTER" then
        return
    end
    ns.Queue.Run("FeedPet button", make)
    follow()
    ns.Listen("bind", "FeedPet", follow)
    ns.Listen("slots", "FeedPet", follow)
end
