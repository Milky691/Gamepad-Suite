-- Pet Hungry: a hunter's pet turns content, then unhappy, and its damage drops. The pop-up (Screen/Popup.lua) says so
-- and feeds, but only when the bags hold a food this pet eats: "Your pet is hungry" (content) or "Your pet is
-- unhappy", with "Roasted Boar Meat x12 in your bags. Damage 75%." With no such food there is no pop-up, only one chat
-- line that names what it eats, once for each pet until food was there again and is gone again: a pop-up the player
-- cannot act on would stand there until they buy the right food.
--
-- The cause is the pet, the step of happiness it fell to, and if food was found (Auto/FeedPetModel.lua Cause). A
-- cause shows one time in a session. It comes again only when the happiness falls another step, when food the pet
-- eats comes into the bags while it is still hungry, or for another pet. A rise never shows. A pet that comes out
-- already hungry is a cause once. Not in combat (the game feeds no pet then): a fall in a fight shows after it if it
-- is still true. Feed Pet must be known (Core/AdapterFeed.lua FeedUsable).
--
-- The press. With the bind Feed Pet on a button, the hint shows that button and no key is taken: the bind feeds
-- (Auto/FeedPet.lua). Without one: hold Y 1 second, let go, press Y once more (Screen/PopupHold.lua, the press
-- grammar): the press clicks the bind's own secure button, which casts Feed Pet and gives it the food of the bags
-- (Core/AdapterFeed.lua). A cast is a secure click, which only a real press makes, and a tap of Y stays Y's bind until
-- the hold. It goes after 15 seconds, at the feed, at a rise of happiness, when the pet goes, and at a window, a
-- wheel or the keyboard (it waits 60 seconds for them).
--
-- ForeverPlus shows an icon for a content or unhappy pet on its buff bar (qol_foreverplus/ForeverPlus/Modules/
-- BuffExpiry.lua 2404 to 2419): it looks at no food and does not feed, so this row stays on beside it.
--
-- The game tells of happiness at UNIT_HAPPINESS for "pet" and of a new pet at UNIT_PET; the bags are heard only while
-- the pet is hungry. Nothing runs between those events. The log (kind "feed") has the first fall, what was found, and
-- the first feed by the pop-up.
local _, ns = ...

local Hungry = ns.Module("PetHungry", { "secure", "feedPet", "petHungry" }, "Pet Hungry")
ns.PetHungry = Hungry

local Model = ns.FeedPetModel
local ROW = "windows.pet_hungry"     -- the row; On while the settings lack it
local COMMAND = "CLICK GamepadSuiteFeedPet:LeftButton"
local SECONDS, WAIT, HAPPY = 15, 60, 3

local pet, step       -- the pet and its last reading of happiness
local causes = {}     -- the causes shown or told in this session, until the pet's happiness rises again
local dieted = {}     -- the pets whose diet the chat named, until food was there again
local told = {}

local function note(kind, text)
    if not told[kind] then
        told[kind] = true
        ns.Log.Add("feed", text)
    end
end

local function on()
    return not ns.Registry.Has(ROW) or ns.Registry.Get(ROW) == true
end

local function fight()
    return ns.fightStarted or ns.Adapter.InCombat()
end

-- The bags are heard while the pet is hungry.
local function listen(look)
    if step and step < HAPPY and on() then
        ns.On("BAG_UPDATE_DELAYED", "PetHungry", look)
    else
        ns.Off("BAG_UPDATE_DELAYED", "PetHungry")
    end
end

-- The press grammar's act: the feed, by the secure button of the bind Feed Pet.
local ACT = { key = "Y", press = true, steps = "Hold, let go, press: feed", go = "Let go, then press once more",
    again = "Press once more: feed", fight = "Feed after combat", log = "pet feed",
    line = "Pet Hungry (Screen, Pop-ups): the feed press is off for this session. Put Feed Pet on a button to feed with one press.",
    done = function()
        note("fed", "a press of the pop-up's Y clicked the Feed Pet button")
        ns.Popup.Hide("pet")
    end }

-- The pop-up for a fall to this step with this food.
local function offer(happy, damage, food)
    local mine = pet
    local item = { owner = "pet", title = Model.HUNGRY[happy], text = Model.FoodLine(food.name, ns.Adapter.FoodLeft(food.id), damage),
        seconds = SECONDS, wait = WAIT, calm = true }
    -- still true when it comes to show: the same pet, still as hungry, the food still there
    function item.valid()
        local now = ns.Adapter.PetHappiness()
        return ns.Adapter.PetGUID() == mine and now ~= nil and now <= happy and ns.Adapter.FoodLeft(food.id) > 0
    end
    if ns.Binds.Uses(COMMAND) then
        local keys = ns.Adapter.KeysOf and ns.Adapter.KeysOf(COMMAND)
        item.keys, item.key, item.hint = keys or {}, keys and keys[#keys] or nil, keys and "Press to feed" or "Press your Feed Pet bind"
    else
        ACT.secure = ns.FeedPet.Prime()
        if not ACT.secure or ACT.off then
            note("no button", "the pet is hungry, and the Feed Pet button " .. (ACT.off and "press is off" or "is not made") .. ": nothing shows")
            return
        end
        item.acts, item.key = { ACT }, "Y"
    end
    local got = ns.Popup.Show(item)
    note("offer", "happiness fell to " .. happy .. " (damage " .. tostring(damage) .. "%); food " .. tostring(food.name) .. " (item "
        .. food.id .. ") found; " .. (item.acts and "the press grammar on Y" or "the bind's own button") .. "; the pop-up: " .. tostring(got))
end

-- A fall of happiness, or food in the bags while it is hungry: a new cause shows or is told, one time.
local function judge(happy, damage)
    local food = Model.Best(ns.Adapter.PetFoods())
    local cause = Model.Cause(pet, happy, food ~= nil)
    if causes[cause] then
        return
    elseif not select(2, ns.Adapter.FeedUsable()) then
        note("unknown", "the pet is hungry, and Feed Pet is not known: nothing shows")
        return
    end
    causes[cause] = true
    if food then
        dieted[pet] = nil
        offer(happy, damage, food)
    elseif not dieted[pet] then
        dieted[pet] = true
        ns.Print(Model.NoFood(happy, ns.Adapter.PetDiet()))
        note("none", "happiness fell to " .. happy .. "; no food it eats in the bags: one chat line")
    end
end

-- A look at the pet: at the game's word of happiness, of a new pet, of the bags, and after a fight.
local function look()
    if not on() then
        return
    end
    local happy, damage = ns.Adapter.PetHappiness()
    local now = ns.Adapter.PetGUID()
    if not happy or not now then
        pet, step = nil, nil
        ns.Popup.Hide("pet")
        listen(look)
        return
    end
    -- a new pet is a fresh cause once: it came out as if from happy
    local was = now == pet and step or HAPPY
    pet, step = now, happy
    listen(look)
    if happy > was or happy == HAPPY then
        -- (it was fed, or it is happy: its next fall is a new cause)
        for cause in pairs(causes) do
            if cause:find(now .. ":", 1, true) == 1 then
                causes[cause] = nil
            end
        end
        ns.Popup.Hide("pet")
    elseif not fight() then
        judge(happy, damage)
    end
end

function Hungry.OnLogin()
    if ns.Adapter.Class() ~= "HUNTER" then
        -- no row for another class, as the bind Feed Pet is a hunter's only (Auto/FeedPet.lua)
        Hungry.on, Hungry.missing = false, "a hunter"
        return
    end
    ns.OnUnit("UNIT_HAPPINESS", "pet", "PetHungry", look)
    ns.On("UNIT_PET", "PetHungry", function(unit)
        if unit == "player" then
            look()
        end
    end)
    ns.On("PLAYER_REGEN_ENABLED", "PetHungry", look)
    -- a feed by the bind or by the pop-up: it goes (the happiness rises over the game's own time)
    ns.Listen("feed:pressed", "PetHungry", function()
        ns.Popup.Hide("pet")
    end)
    ns.Listen("setting", "PetHungry", function(key)
        if key == ROW then
            if on() then
                look()
            else
                ns.Popup.Hide("pet")
                listen(look)
            end
        end
    end)
    look()
end
