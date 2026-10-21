-- Auto Quest: quests are taken and handed in with no press. At a gossip or a quest list the
-- quest to hand in is chosen first, then a quest on offer; an offer is accepted, a quest that is
-- done is completed, and a hand-in with one reward or none is finished. A hand-in with a choice
-- of rewards stops, and the player chooses. So does a window where the game asks first (a quest
-- that flags for PvP, a hand-in that costs money) and the offer of a grey quest. With a full
-- quest log no offer is taken; a repeatable quest stays on the list, and in a group a quest for
-- a group waits for A (Auto/QuestsModel.lua). Holding View
-- when the window opens pauses it, and Pause Automation pauses it and Skip Gossip (Quests.Paused). Each step is the game's own call for that button of its
-- window (Core/AdapterDialogue.lua), as ForeverPlus makes them on this game build; none of them
-- is locked in combat. Nothing runs on a timer while no talk is on.
-- The step is made one frame after the game's event, as the dialogue view makes the step of a
-- press. The game's notes mark these events SynchronousEvent: a step made inside one can bring
-- the next window, or the end of the talk, before the dialogue view has heard of this window,
-- and the view would then show a window that is gone. One frame later the view has heard it, so
-- the end of the talk always reaches it.
-- With the game's controller interface on, Auto Quest and Skip Gossip act only while the
-- dialogue view holds the talk. A step taken while the game's own quest or gossip window is up
-- closes that window as addon code: the game's controller code then changes its binds and calls
-- SetPreferredGamepadInteractTarget, which the game blocks for addons (FrameControlsManager.lua
-- 482 to 545 and 113 to 122, InputBindingManager.lua 38 to 46, MainActionBarFrame.lua 285 to 291;
-- RXPGuides issue 417 has the same block). With the mouse interface that code returns at once
-- (482 to 485), and while the view holds the talk the game's window never showed (493 to 495).
local _, ns = ...

local Quests = ns.Module("Quests", { "dialogue" }, "Auto Quest")
ns.Quests = Quests

local Model = ns.QuestsModel
local MAX_NOTES = 30
local notes = 0

local function note(text)
    if notes < MAX_NOTES then
        notes = notes + 1
        ns.Log.Add("quests", text)
    end
end

-- Why Auto Quest and Skip Gossip must not act at this window, or nil when they may.
function Quests.Paused()
    if ns.Automation.Paused() then
        return "automation is paused"
    elseif ns.Adapter.ViewHeld() then
        return "View is held"
    elseif not ns.Adapter.ControllerUI() then
        return nil
    elseif ns.Adapter.DialogueGameWindow() then
        return "the game's own window is up with the controller interface"
    elseif not ns.DialogueTake.Has() then
        return "the dialogue view does not hold the talk (" .. tostring(ns.DialogueTake.Off() or "it is off, in combat or no controller is in use") .. ")"
    end
end

-- A window of a talk opened a frame ago: the one step for it, if there is one.
local function act(kind, event)
    if not ns.Registry.Get("helpers.quests") then
        return
    end
    local paused = Quests.Paused()
    if paused then
        note(event .. ": " .. paused .. ", so nothing is done")
        return
    end
    local data, problem
    if kind == "gossip" then
        data, problem = ns.Adapter.DialogueGossip()
    elseif kind == "greeting" then
        data, problem = ns.Adapter.DialogueGreeting()
    else
        data, problem = ns.Adapter.DialogueQuest(kind)
    end
    if problem ~= "" then
        note(event .. ": the window could not be read (" .. problem .. ")")
        return
    end
    local step, value = Model.Step(kind, data)
    if not step then
        -- (a gossip with no quest is Skip Gossip's, and says nothing here)
        if kind ~= "gossip" or value ~= "no quest to take or to hand in" then
            note(event .. ": nothing done: " .. value)
        end
        return
    end
    local done, why = ns.Adapter.DialogueDo(step, value)
    note(event .. ": " .. step .. (value and " " .. tostring(value) or "") .. (done and "" or " was refused: " .. why))
end

function Quests.OnLogin()
    for event, kind in pairs({ GOSSIP_SHOW = "gossip", QUEST_GREETING = "greeting", QUEST_DETAIL = "offer", QUEST_PROGRESS = "progress", QUEST_COMPLETE = "handin" }) do
        ns.On(event, "Quests", function()
            if ns.Registry.Get("helpers.quests") then
                C_Timer.After(0, function()
                    ns.Call("Quests", act, kind, event)
                end)
            end
        end)
    end
end
