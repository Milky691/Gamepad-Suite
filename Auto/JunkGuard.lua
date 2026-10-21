-- Quest Item Guard: an item that a quest in the log still needs ("Linen Cloth: 4/10") has one more
-- line in its tooltip, "Needed for <quest>", in the bags, at a vendor and in a link. At a vendor a
-- sale of such an item gets one chat line and a short rumble: "You sold Linen Cloth, needed for
-- Tailoring 101. Buy it back on the vendor's Buyback tab." (Windows/JunkMark.lua holds back the
-- bag window's X on such an item once, before the sale.)
--
-- The addon cannot see the game's own sale (the bag window's X, a right click, a drop on the
-- vendor), so the sale is seen after: the vendor's buyback list is kept when the vendor opens and
-- looked at again at each MERCHANT_UPDATE and BAG_UPDATE_DELAYED while it is open; an item that is
-- there more often than before was just sold. The quest log is read when it is asked, so it is
-- never out of date. The log (kind "junk") names the event that showed the first sales.
local _, ns = ...

local Guard = ns.Module("QuestGuard", { "questNeeds", "questTip" }, "Quest Item Guard")
ns.QuestGuard = Guard

local Model = ns.JunkModel

local ROW = "helpers.quest_guard"
local MAX_NOTES = 10    -- lines for the log in one session

local before            -- the buyback list at the last look while a vendor is open; nil while none is
local notes, told = 0, {}

local function note(text, once)
    if notes < MAX_NOTES and not (once and told[once]) then
        notes = notes + 1
        if once then
            told[once] = true
        end
        ns.Log.Add("junk", text)
    end
end

-- The tooltip's line for an item, or nil.
local function line(id)
    if not ns.Registry.Get(ROW) then
        return nil
    end
    local name = ns.Adapter.ItemName(id)
    local quest = name and Model.Needs(ns.Adapter.QuestLog())[name]
    if not quest then
        return nil
    end
    note("the line was added to the tooltip of " .. name, "tip")
    return Model.TipLine(quest)
end

-- One look at the buyback list: each new entry is a sale, and a sale of an item a quest needs gets the line.
local function look(event)
    local now = ns.Adapter.Buyback()
    local sold = Model.Sold(before, now)
    before = now
    if #sold == 0 then
        return
    end
    local needs = Model.Needs(ns.Adapter.QuestLog())
    for _, entry in ipairs(sold) do
        note("a sale was seen at " .. event .. ": " .. tostring(entry.name))
        local quest = entry.name and needs[entry.name]
        if quest then
            ns.Print(Model.SoldLine(entry.name, quest))
            if ns.Rumble and ns.Rumble.Pulse then
                ns.Rumble.Pulse(0.3, "a quest item was sold")
            end
        end
    end
end

local function watch(on)
    for _, event in ipairs({ "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED" }) do
        if on then
            ns.On(event, "QuestGuard", function()
                look(event)
            end)
        else
            ns.Off(event, "QuestGuard")
        end
    end
end

function Guard.OnLogin()
    -- (a fault in the line is logged and gives no line: the tooltip is the game's)
    ns.Adapter.OnItemTooltip(function(id)
        local ok, text = ns.Call("QuestGuard", line, id)
        return ok and text or nil
    end, ns.Theme.Color("gold"))
    ns.On("MERCHANT_SHOW", "QuestGuard", function()
        if ns.Registry.Get(ROW) then
            before = ns.Adapter.Buyback()
            watch(true)
        end
    end)
    ns.On("MERCHANT_CLOSED", "QuestGuard", function()
        before = nil
        watch(false)
    end)
end
