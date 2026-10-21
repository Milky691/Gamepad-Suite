-- Mark Next: a bind, in the list Markers and Pings. Each press gives the target the next raid
-- mark in kill order: skull, cross, square, moon, triangle, diamond, circle, star, and then the
-- skull again. Mark one enemy, target the next, press again. The next mark is the skull again
-- when a fight ends, and when the button was not pressed for 15 seconds. A press with no target
-- gives no mark and keeps the order. In a raid only the leader or an assistant may mark: for the
-- others a press gives no mark, keeps the order, and the chat says why once per role.
--
-- The game sets the mark, not the addon: the bind clicks one of the game's secure buttons
-- (Core/AdapterExtras.lua says why). That button steps through the order by itself, so the bind
-- works in a fight. The game has each mark one time: a mark that another enemy has moves to
-- the new target. The game does not tell an addon which marks are in use, so the order does
-- not jump over a mark that is on a unit (ControllerForever found the same on this game).
local _, ns = ...

local Mark = ns.Module("MarkNext", { "secure", "raidMark" }, "Mark Next")
ns.MarkNext = Mark

local Model = ns.ExtrasModel

local BUTTON = "GamepadSuiteMarkNext"
-- The bind, as the game names it. The on-screen buttons know the bind by it.
Mark.COMMAND = "CLICK " .. BUTTON .. ":LeftButton"

local button
local last = 0       -- when the button was pressed the last time
local said = false   -- the raid line was said for the role as it is now

-- The picture of the mark that the next press gives. It changes with the message "marknext".
function Mark.Icon()
    return ns.Catalog.CommandIcon("RAIDTARGET" .. Model.MARKS[button and button:GetAttribute("place") or 1])
end

-- The bind list's entry (Core/Catalog.lua).
function Mark.Bind()
    return { kind = "command", id = Mark.COMMAND, name = "Mark Next", detail = "The next mark, from skull to star", icon = Mark.Icon() }
end

-- The next mark is the skull again. It is called out of a fight only (the rule of the wait, and
-- the end of a fight): the game locks the button in a fight.
local function again()
    if button:GetAttribute("place") ~= 1 then
        button:SetAttribute("place", 1)
        ns.Send("marknext")
    end
end

-- May the player mark now? In a raid only the leader or an assistant may. The button's attribute
-- "allowed" tells the game's restricted code: without it a press stops, so no mark that the game
-- would refuse moves the order on. Out of a fight only (the game locks the button in one).
local function allow()
    local may = ns.Adapter.MayMark() or nil
    if button:GetAttribute("allowed") ~= may then
        button:SetAttribute("allowed", may)
        said = false
    end
end

-- The button is made out of a fight: the game lets no addon set up a secure button in one. A
-- login in a fight makes it when the fight ends.
function Mark.OnLogin()
    ns.Queue.Run("MarkNext", function()
        button = ns.Adapter.MarkButton(BUTTON, Model.MARKS)
        -- After each press: the picture of the next mark, and the wait that starts the order again.
        -- The first three presses go in the log with the mark the target has a moment later, so one
        -- try in the game shows that the game set it (alone, out of a group, too).
        -- The log has the right to mark too, and the game's own question for its marker panel: one
        -- try in a raid as a plain member tells if that question covers the rule.
        local told = 0
        button:HookScript("PostClick", function()
            if told < 3 then
                told = told + 1
                local gave, may = button:GetAttribute("marker"), button:GetAttribute("allowed")
                C_Timer.After(0.3, function()
                    ns.Log.Add("mark", ("Mark Next: the press gave mark %s; the target has mark %s; may mark: %s; the game's CanBeRaidTarget: %s"):format(
                        tostring(gave), tostring(ns.Adapter.TargetMark()), tostring(may), tostring(ns.Adapter.CanMarkTarget())))
                end)
            end
            -- a press that may not mark: the chat says why, once per role; quiet in a fight
            if not ns.Adapter.InCombat() then
                allow()
                if not button:GetAttribute("allowed") and not said then
                    said = true
                    ns.Print(Model.MARK_RAID)
                end
            end
            local pressed = GetTime()
            last = pressed
            ns.Send("marknext")
            C_Timer.After(Model.MARK_IDLE, function()
                if Model.MarkStartsAgain(pressed, last, ns.Adapter.InCombat()) then
                    ns.Call("MarkNext", again)
                end
            end)
        end)
        ns.On("PLAYER_REGEN_ENABLED", "MarkNext", again)
        -- the role changes: a member joins or leaves, a promotion, a new leader
        for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" }) do
            ns.On(event, "MarkNext", function()
                ns.Queue.Run("MarkNextRole", allow)
            end)
        end
        allow()
    end)
end
