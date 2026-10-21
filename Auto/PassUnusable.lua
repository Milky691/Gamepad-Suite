-- Pass on Gear You Cannot Wear: when a group loot roll starts for armor or a weapon that the
-- character's class can never learn (plate for a mage, a wand for a warrior), the roll is passed
-- on at once, and one chat line names the item. Off by default. Pause Automation stops it.
-- Screen/RollsModel.lua has the rule. When anything is unsure (the game does not know the item yet, a kind of item the rule
-- does not judge, the game does not say no) nothing is done, and the player rolls.
--
-- The pass is the game's own call for its Pass button (Core/AdapterRolls.lua), made at the
-- game's event for a roll's start, so nothing waits on a timer. The game's roll frame goes when
-- the server has the answer. The log (kind "rolls") has, for a few rolls in a session, what the
-- game said of the item, whether the pass ran, and whether the game ended the roll inside the call.
local _, ns = ...

local Pass = ns.Module("PassUnusable", { "rollPass" }, "Pass on Gear You Cannot Wear")
ns.PassUnusable = Pass

local Model = ns.RollsModel
local notes = 0

local function judge(id)
    if not ns.Registry.Get("helpers.pass_unusable") or ns.Automation.Paused() then
        return
    end
    local item = ns.Adapter.RollItem(id)
    local pass, why = false, "the game does not know the item yet"
    if item then
        pass, why = Model.Unusable(item, ns.Adapter.Class())
    end
    local ran, inside = false, false
    if pass then
        ran, inside = ns.Adapter.PassRoll(id)
    end
    if ran then
        ns.Print(Model.PASSED:format(item.link))
    end
    if notes < 12 then
        notes = notes + 1
        ns.Log.Add("rolls", "pass on gear you cannot wear: " .. (item and item.link .. " (" .. tostring(item.class) .. "." .. tostring(item.sub)
            .. ", Need " .. tostring(item.canNeed) .. ", usable " .. tostring(item.usable) .. "): " or "") .. why
            .. (pass and "; the pass ran " .. tostring(ran) .. ", the game ended the roll inside the call: " .. tostring(inside) or ""))
    end
end

function Pass.OnLogin()
    ns.On("START_LOOT_ROLL", "PassUnusable", judge)
end
