-- Sit at a Campfire: near a campfire, with nothing else in reach, the Dynamic Interact button
-- makes the player sit, and a line on screen names the button. The game gives a buff to a
-- player who is near a campfire (Core/AdapterAuto.lua names it); that is how the addon knows.
-- Out of a fight only: an addon cannot change a key in a fight, and the game hides buffs there.
--
-- The line shows while the fire is near and the character stands. The game has no call that
-- tells if a character sits, so the addon keeps count from what the game does tell: its sit
-- command ran (the character sits down, or stands up), the character started to move, jumped,
-- began a cast or came into combat (it stands), a buff came that only a seated character has
-- (it sits). Nothing is asked on a timer: each of these is an event of the game.
--
-- The line never names a button that does something else at that moment: it waits while a
-- window has the controller, while the character is on a mount (it cannot sit) or in water (the
-- sit command would sink it), while something to interact with is in reach, while a fishing pole
-- is in the hands (the button fishes then), while Healer Mode at Bumpers holds that bumper for the
-- group, and while the game itself has the button for one of its own controls. The sit command is
-- on the button only while the character can sit, so on a mount or in water a press does the
-- button's own bind, and the line and the button agree (the owner frame drops it in water by
-- itself). A seated character keeps it: a second press stands it up. The log (kind "campfire")
-- keeps a few lines: a campfire came near; each time the line shows (and what the game reads the
-- button as, when that is not the sit command) or goes, with the reason; each time the character
-- sits or stands, with the sign.
local _, ns = ...

local Campfire = ns.Module("Campfire", { "secure", "auras" }, "Sit at a Campfire")
ns.Campfire = Campfire

local MAX_NOTES = 12    -- lines of each sort for the log in one session
-- The sizes of the line, in the units of the mockup. It must read on a handheld held at arm's
-- length: the words are the Theme's title size (on a screen of 2560 x 1600 at the interface scale
-- 0.72 they are 44 pixels high) and the button's picture is 67 pixels.
local GLYPH, BESIDE = 52, 36

local prompt, glyphs = nil, {}
local atFire = false    -- a campfire was near at the last look
local seated = false    -- the character sits, as far as the addon can tell
local was = {}          -- the signs of a seated character at the last look: { welcome =, meal = }
local mounted = false   -- the character was on a mount at the last look (a mount is a buff: its change is heard)
local swimming = false  -- the character is in water (the owner frame of the binds tells: the message "swim")
local said = false      -- what the log last said of the line at this fire: why it is away, nil for "it shows", false for nothing yet
local notes = {}

local function note(sort, text)
    notes[sort] = (notes[sort] or 0) + 1
    if notes[sort] <= MAX_NOTES then
        ns.Log.Add("campfire", text)
    end
end

local function build()
    local Theme, px = ns.Theme, ns.Theme.px
    prompt = CreateFrame("Frame", "GamepadSuiteSitPrompt", UIParent)
    prompt:SetSize(px(440), px(56))
    prompt:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, px(310))
    prompt:Hide()
    prompt.before = Theme.Text(prompt, "title", "cream")
    prompt.before:SetText("Press")
    prompt.before:SetPoint("RIGHT", prompt, "CENTER", -px(BESIDE), 0)
    prompt.after = Theme.Text(prompt, "title", "cream")
    prompt.after:SetText("to sit")
    prompt.after:SetPoint("LEFT", prompt, "CENTER", px(BESIDE), 0)
    -- it comes in softly
    local fade = prompt:CreateAnimationGroup()
    local alpha = fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.6)
    prompt:SetScript("OnShow", function()
        fade:Play()
    end)
end

local function glyph(key)
    if not glyphs[key] then
        glyphs[key] = ns.Widgets.Glyph(prompt, key, ns.Theme.px(GLYPH))
        glyphs[key]:SetPoint("CENTER", prompt, "CENTER", 0, 0)
    end
    for name, frame in pairs(glyphs) do
        frame:SetShown(name == key)
    end
end

-- Why the character cannot sit at the press now, or nil: the reasons the sit command stays off the button too.
local function away(button)
    if not ns.Pad.Gameplay() then
        return "a window has the controller"
    elseif mounted then
        return "the character is on a mount"
    elseif swimming then
        return "the character is in water"
    elseif ns.Adapter.InteractNear() then
        return "something to interact with is in reach"
    elseif ns.Hands.on and ns.Hands.Rod() then
        return "a fishing pole is in the hands"
    elseif ns.BindAsk.GroupBumper() == button then
        return "Healer Mode at Bumpers holds " .. button .. " for the group"
    end
end

-- Why the line does not show now, or nil when it shows: the button would not make the character
-- sit, or the character sits already. The second answer is what the game reads the button as.
local function waits(button)
    local why = seated and "the character sits" or away(button)
    if why then
        return why
    end
    -- the game's own answer for the key: a click on a button that is not the addon's is one of
    -- the game's own controls, set above the player's binds
    local now = tostring(ns.Adapter.EffectiveBinding(ns.Adapter.KEY[button]))
    if now:find("^CLICK ") and not now:find("^CLICK GamepadSuite") then
        return "the game has " .. button .. " for a control of its own (" .. now .. ")"
    end
    return nil, now
end

-- The character sits or stands now, as far as the addon can tell. While it sits, the addon
-- waits for the game's word that it moves: only then.
local function seat(on, why)
    if on == seated then
        return
    end
    seated = on
    if on then
        ns.Adapter.OnMoved("Campfire", function(cast)
            seat(false, cast and "a cast" or "the character moved")
            Campfire.Update()
        end)
    else
        ns.Adapter.OffMoved("Campfire")
    end
    note("seat", (on and "the character sits: " or "the character stands: ") .. why)
end

-- fight: a fight starts now (the game tells of it before it locks anything).
function Campfire.Update(fight)
    if fight or ns.Adapter.InCombat() then
        if fight then
            seat(false, "a fight")
        end
        prompt:Hide()
        return
    end
    local button = ns.Registry.Get("combat.dynamic_interact")
    local fire, buff, welcome, meal, mount = ns.Adapter.NearCampfire()
    if fire == nil then
        -- the game gives no answer now (combat comes): nothing is known, so nothing changes
        prompt:Hide()
        return
    end
    mounted = mount and true or false
    if fire ~= atFire then
        -- the player walked to the fire, or away from it: the character stands
        atFire, said, was = fire, false, {}
        seat(false, fire and "a campfire came near" or "the campfire is gone")
        if fire then
            note("near", "a campfire is near" .. (buff and " (the buff " .. tostring(buff) .. ")" or ""))
        else
            note("gone", "the campfire is gone: its buff went")
        end
    end
    -- each sign counts when it comes: a buff that stays after the character stood up seats it not again
    if welcome and not was.welcome then
        seat(true, "Welcoming Campfire came")
    elseif meal and not was.meal then
        seat(true, "a meal began")
    end
    was = { welcome = welcome, meal = meal }
    local near = fire and ns.Registry.Get("combat.campfire_sit") and button ~= "Off"
    ns.BindCore.Flag("sit", near and not away(button))
    local why, reads
    if near then
        why, reads = waits(button)
    end
    if near and why ~= said then
        said = why
        -- the game reads the button as the sit command, else the log says what it reads: one try tells
        local odd = reads ~= "SITORSTAND" and (", but the game reads " .. button .. " as " .. tostring(reads)) or ""
        note("line", why and ("the line is away: " .. why) or ("the line shows: Press " .. button .. " to sit" .. odd))
    end
    local show = near and not why
    if show then
        glyph(button)
    end
    prompt:SetShown(show or false)
end

-- The game's sit command ran, or a jump (stood). At a fire and out of combat only; a character
-- that moves, or is on a mount, does not sit down.
local function sitKey(stood)
    if not atFire or mounted or ns.Adapter.InCombat() then
        return
    elseif stood then
        seat(false, "a jump")
    elseif seated or not ns.Adapter.Moving() then
        seat(not seated, "the sit command")
    end
    Campfire.Update()
end

function Campfire.OnLogin()
    build()
    if not ns.Adapter.OnSitKey(sitKey) then
        ns.Log.Add("campfire", "the game's sit command cannot be heard: the line stays while the character sits")
    end
    -- (an event or a message can bring a value of its own, and none of them means "a fight starts")
    local function look()
        Campfire.Update()
    end
    -- the player's own buffs only: the game is not asked to tell of anybody else's
    ns.OnUnit("UNIT_AURA", "player", "Campfire", look)
    ns.On("PLAYER_REGEN_DISABLED", "Campfire", function()
        Campfire.Update(true)
    end)
    -- the fire's buff can come in a fight, where it cannot be read: after the fight it is looked for
    ns.On("PLAYER_REGEN_ENABLED", "Campfire", look)
    ns.On("PLAYER_ENTERING_WORLD", "Campfire", look)
    ns.Listen("setting", "Campfire", function(key)
        if key == "combat.campfire_sit" or key == "combat.dynamic_interact" then
            Campfire.Update()
        end
    end)
    -- what the button does can change with each of these; away from a fire none of them matters
    local function atFireOnly()
        if atFire then
            Campfire.Update()
        end
    end
    ns.On("PLAYER_SOFT_INTERACT_CHANGED", "Campfire", atFireOnly)
    for _, message in ipairs({ "pad", "pad:stack", "hands" }) do
        ns.Listen(message, "Campfire", atFireOnly)
    end
    ns.Listen("swim", "Campfire", function(on)
        swimming = on and true or false
        atFireOnly()
    end)
end
