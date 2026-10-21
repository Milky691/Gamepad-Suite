-- Look Behind: a bind, in the list Camera. While its button is held the camera looks behind the
-- character; when the button comes up the camera is back. The game's own bind Flip Camera turns
-- the camera at one press and back at the next; this one is a hold, on any button (ControllerForever
-- has such a hold too).
--
-- The game does not say which way the camera looks: it only turns it by an amount. So the addon
-- remembers that it turned the camera, and must not lose the let-go. The game can lose it: the
-- key goes to a window, or to another set of binds, while it is held. So for the time of the
-- hold a small watch reads the pad itself, and brings the camera back when every button that
-- was down at the press is up. The camera is also brought back when a fight starts (the game
-- tells of the fight before it locks anything) and at a reload.
--
-- The game's own controller code turns the camera the same way: one half turn at the press and
-- one at the let-go (Blizzard_GamepadTargeting/TargetLogic.lua 57 to 72). The game's notes do not
-- say if an addon may turn the camera in a fight, or away from a press (the watch, the start of a
-- fight). The log (kind "look") has the first turn of each kind, in and out of a fight, with what
-- turned it and the game's answer; a call the game blocks without a word is a blocked line of its
-- own (Core/Log.lua).
--
-- On Y or X the bind meets the top pop-up's holds (a whisper's reply and invite, Screen/PopupHold.lua): a press that
-- is such a hold turns nothing, so the camera does not swing round while the player holds to reply.
local _, ns = ...

local Look = ns.Module("LookBehind", { "flipCamera" }, "Look Behind")
ns.LookBehind = Look

local Model = ns.ExtrasModel

local BUTTON = "GamepadSuiteLookBehind"
local CLICK = "CLICK " .. BUTTON .. ":LeftButton"
local ART = "Interface\\Icons\\Spell_Shadow_EvilEye"

local watch
local turned = false   -- the camera looks behind now
local held = {}        -- the places of the pad's buttons that were down at the press
local told = {}        -- the kinds of turn that are in the log, by what turned it and in a fight or not

-- The bind list's entry (Core/Catalog.lua).
function Look.Bind()
    return { kind = "command", id = CLICK, name = "Look Behind", detail = "Hold to look behind you", icon = ART }
end

-- down: true for a press of the bind's button, false for its let-go, nil to bring the camera back.
-- cause: what turned it, for the log.
local function turn(down, cause)
    local flip
    turned, flip = Model.Look(turned, down)
    if flip then
        local fight = ns.Adapter.InCombat()
        local ok, why = ns.Adapter.FlipCamera()
        local kind = (turned and "behind" or "back") .. (fight and " in a fight" or " out of a fight") .. " (" .. cause .. ")"
        if not told[kind] then
            told[kind] = true
            ns.Log.Add("look", kind .. ": " .. (ok and "the game took the call" or "the game refused (" .. tostring(why) .. ")"))
        end
    end
    held = turned and Model.Down(ns.Adapter.PadState()) or {}
    watch:SetShown(turned)
end

local function back(cause)
    return function()
        turn(nil, cause)
    end
end

-- Is this press the top pop-up's hold (a whisper's reply on Y, its invite on X)? Then the camera does not turn. The
-- button of the press is the bind's one button with no trigger held (Adapter.KeysOf; a pop-up holds nothing with a
-- trigger held). The pop-up's own word when it has one (PopupHold.Holds), else the acts of the item that shows.
local function kept()
    local keys = ns.Adapter.KeysOf and ns.Adapter.KeysOf(CLICK)
    local key = keys and #keys == 1 and keys[1] or nil
    if not key then
        return nil
    elseif ns.PopupHold and ns.PopupHold.Holds then
        return ns.PopupHold.Holds(key) and key or nil
    end
    local shown = ns.Popup and ns.Popup.Shown and ns.Popup.Shown()
    return Model.PopupHolds(shown, key, ns.fightStarted or ns.Adapter.InCombat()) and key or nil
end

-- A press or a let-go of the bind's button. A press that is a pop-up's hold turns nothing, so its let-go turns
-- nothing either (a press while the camera looks behind still brings it back).
local function pressed(down)
    local key = down and not turned and kept()
    if key then
        if not told.kept then
            told.kept = true
            ns.Log.Add("look", "a press on " .. key .. " while the pop-up holds it: no turn")
        end
        return
    end
    turn(down, down and "the press" or "the let-go")
end

-- The watch, each frame while the camera looks behind: a let-go that the game did not tell of.
local function check()
    if Model.AllUp(held, ns.Adapter.PadState()) then
        turn(false, "the pad shows the buttons up")
    end
end

function Look.OnLogin()
    watch = CreateFrame("Frame")
    watch:Hide()
    watch:SetScript("OnUpdate", function(self)
        -- a fault here would come every frame: it is logged once, the watch stops and the camera comes back
        if not ns.Call("LookBehind", check) then
            self:SetScript("OnUpdate", nil)
            ns.Call("LookBehind", back("a fault"))
        end
    end)
    -- The button that the bind clicks: it hears the press and the let-go. A secure button (made out
    -- of a fight), so the bind core can hear its press too (Sticky Layers, Core/BindCore.lua).
    ns.Queue.Run("LookBehind", function()
        local button = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetScript("OnClick", function(_, _, down)
            ns.Call("LookBehind", pressed, down and true or false)
        end)
    end)
    ns.On("PLAYER_REGEN_DISABLED", "LookBehind", back("a fight starts"))
    ns.On("PLAYER_LOGOUT", "LookBehind", back("logout"))
end
