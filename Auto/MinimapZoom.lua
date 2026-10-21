-- Minimap Zoom: a bind, in the list Game Menus. Each press takes the minimap one step on through
-- three zoom steps: all the way out, the middle, all the way in, and then out again. The game's own
-- binds Minimap Zoom In and Minimap Zoom Out go one step at a press; this one is for a player who
-- wants one button for the whole range.
--
-- Nothing runs but at a press: one question to the game and one call (Core/AdapterMinimap.lua).
-- The notes of the game do not mark the minimap's zoom calls as restricted, but they cannot prove
-- that an addon may use them in a fight. So the log (kind "minimap") has the first two presses out
-- of a fight and the first two in one, with the step, the game's answer and the zoom after it.
local _, ns = ...

local Zoom = ns.Module("MinimapZoom", { "minimapZoom" }, "Minimap Zoom")
ns.MinimapZoom = Zoom

local Model = ns.MinimapZoomModel

local BUTTON = "GamepadSuiteMinimapZoom"
-- the game's picture of a spyglass
local ART = "Interface\\Icons\\INV_Misc_Spyglass_03"

local told = {}     -- lines in the log: [false] out of a fight, [true] in a fight

-- The bind list's entry (Core/Catalog.lua).
function Zoom.Bind()
    return { kind = "command", id = "CLICK " .. BUTTON .. ":LeftButton", name = "Minimap Zoom", detail = "Press again for the next zoom step", icon = ART }
end

local function press()
    local zoom, levels = ns.Adapter.MinimapZoom()
    local step = zoom and Model.Next(zoom, levels)
    if not step then
        return
    end
    local fight = ns.Adapter.InCombat()
    local ok, why = ns.Adapter.SetMinimapZoom(step)
    told[fight] = (told[fight] or 0) + 1
    if told[fight] <= 2 then
        ns.Log.Add("minimap", (fight and "in a fight: " or "out of a fight: ") .. "zoom " .. zoom .. " of " .. levels - 1
            .. " to " .. step .. ": " .. (ok and "the game took the call" or "the game refused (" .. tostring(why) .. ")")
            .. "; the zoom is " .. tostring(ns.Adapter.MinimapZoom()) .. " now")
    end
end

function Zoom.OnLogin()
    -- The button that the bind clicks: a press of it is one step. A secure button (made out of a
    -- fight), so the bind core can hear its press too (Sticky Layers, Core/BindCore.lua).
    ns.Queue.Run("MinimapZoom", function()
        local button = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("AnyDown")
        button:SetScript("OnClick", function()
            ns.Call("MinimapZoom", press)
        end)
    end)
end
