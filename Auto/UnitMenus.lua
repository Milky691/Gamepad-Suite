-- Target Menu and My Menu: two binds, in the list Targeting. A press opens the game's own menu of the target
-- (Inspect, Trade, Invite, Whisper) or of the player's own portrait (loot, the group, raid marks): the menu a right
-- click on the portrait opens (the owner, 2026-10-17: "the gamepad inspect isnt a bind anywhere"; "a bind that brings
-- up the submenu on ourselves, like the right click portrait thingy"). Each is a key bound to a right click on the
-- game's own unit frame (Core/AdapterMenus.lua), so the menu opens at the let-go, as the game's own does.
-- Friendly Player Menu (Combat tab): with a friendly player as the target, out of combat, the Dynamic Interact button
-- opens the target's menu while nothing else is in reach (Core/BindSecure.lua, the flag "menu"), but only when the
-- button's own bind has nothing for that player: no bind, a game command, a macro, an enemy spell. A heal or a buff on
-- it casts (a buff before the pull), as does Healer Mode's party wheel for such a spell. The game's restricted code
-- cannot tell a player from an NPC, so the flag comes from here at each change of target, form or bind, out of combat.
local _, ns = ...

local Target = ns.Module("TargetMenu", { "unitMenus" }, "Target Menu")
local Mine = ns.Module("SelfMenu", { "unitMenus" }, "My Menu")
local Friend = ns.Module("FriendMenu", { "unitMenus" }, "Friendly Player Menu")
ns.TargetMenu, ns.SelfMenu, ns.FriendMenu = Target, Mine, Friend

local KEY = "combat.friend_menu"
local told, castTold = false, false

-- The bind list's entries (Core/Catalog.lua).
function Target.Bind()
    return { kind = "command", id = ns.Adapter.TARGET_MENU, name = "Target Menu", detail = "Inspect, trade, invite, whisper",
        icon = "Interface\\Cursor\\Crosshair\\Inspect" }
end

function Mine.Bind()
    return { kind = "command", id = ns.Adapter.SELF_MENU, name = "My Menu", detail = "Your portrait's menu: loot, group, marks",
        icon = "Interface\\Icons\\INV_Misc_Head_Human_01" }
end

-- The bind of our button ours in the state in use, when it can be cast on a friendly player: a spell or an item that is
-- helpful and reaches another unit (the healer wheel's own ask, Core/AdapterWheel.lua FriendlySpell). Else nil.
local function forFriend(ours)
    local get = ns.Registry.Get
    local forms = get("layers.forms_and_stances") ~= "Off" and ns.Adapter.Forms() or {}
    local state = ns.Adapter.BindState(get("layers.combat_set"), forms, get("layers.forms_and_stances") == "Combat First")
    local bind = ns.BindRules.Find(ns.Binds.Get, state, 1, ours)
    bind = bind and ns.BindRules.Real(bind)
    local kind = bind and bind.kind
    return (kind == "spell" or kind == "item") and ns.Adapter.FriendlySpell(bind.id, kind) and bind or nil
end

-- The target, the fight, a form, a bind or the row changed: the Dynamic Interact button opens the menu or not.
local function check()
    local ours = ns.Registry.Get("combat.dynamic_interact")
    local friend = ns.Registry.Get(KEY) and ns.Adapter.FriendlyPlayerTarget()
    -- (the bumper that holds the group never opens the menu: Core/BindSecure.lua)
    local cast = friend and ours and ours ~= "Off" and (ours == ns.BindAsk.GroupBumper() or forFriend(ours))
    local on = friend and not cast or false
    ns.BindCore.Flag("menu", on)
    if on and not told then
        told = true
        ns.Log.Add("menu", "a friendly player is the target, out of combat: the Dynamic Interact button opens the target's menu")
    elseif type(cast) == "table" and not castTold then
        castTold = true
        ns.Log.Add("menu", "a friendly player is the target, and the Dynamic Interact button's bind " .. tostring(cast.name or cast.id)
            .. " can be cast on them: it runs, the menu waits")
    end
end

function Friend.OnLogin()
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "UPDATE_SHAPESHIFT_FORM" }) do
        ns.On(event, "FriendMenu", check)
    end
    ns.Listen("bind", "FriendMenu", check)
    ns.Listen("setting", "FriendMenu", function(key)
        if key == KEY then
            check()
        end
    end)
    check()
end
