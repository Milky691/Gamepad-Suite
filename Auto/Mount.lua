-- Mount and Random Mount: two binds, in the list Game Actions.
--   Mount is one macro text that the game runs at the press, and whose conditions it reads
--   itself, in a fight too. On a mount the press gets off. In a fight it does nothing more. In
--   water a druid that knows Aquatic Form takes it. On land, outdoors: a mount that chance picks
--   of the favorites of the game's mount journal, or of all the character's mounts when none is a
--   favorite; with no mount, Travel Form for a druid or Ghost Wolf for a shaman that knows it.
--   Where the mount cannot come (indoors, a riding skill too low) the chat gives the game's own
--   reason, once per reason; in water with no Aquatic Form, and for a form, the game's red words.
--   The pick is written into the text out of a fight: after each press, and when the journal or
--   the spells change. All of that runs only while a button or a fixed slot has the bind.
--   Random Mount summons one of the mounts the game calls usable here, by chance, through the
--   journal's own call. A press on a mount gets off, in a fight too; in a fight it does nothing
--   more. Indoors and in water the game says in its own red words why no mount comes.
--
-- The game's code does not prove that "/cast" summons a journal mount on this game, or that an
-- addon may call the journal's summon. So the log (kind "mount") has the first presses of each
-- bind, and whether the character was on a mount a few seconds after: one try of both binds
-- tells which way works.
local _, ns = ...

local Mount = ns.Module("Mount", { "mounts" }, "Mount")
ns.Mount = Mount
-- the second bind: a module of its own, so the bind list can ask each for its entry
local Random = ns.Module("RandomMount", { "mounts" }, "Random Mount")
ns.RandomMount = Random

local Model = ns.MountModel

local BUTTON, RANDOM_BUTTON = "GamepadSuiteMount", "GamepadSuiteRandomMount"
local COMMAND = "CLICK " .. BUTTON .. ":LeftButton"
-- the picture of the game's own Mounts tab, and a running horse for the mount that chance picks
local ART, RANDOM_ART = "Interface\\Icons\\INV_Horse3Saddle008_Chestnut", "Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MOUNTUP"
local MAX_NOTES = 6     -- lines of each sort for the log in one session
-- seconds from a press to the look for the log: the cast of a mount can take 3 seconds on
-- Classic rules, and a look before its end would read "not on a mount"
local SETTLE = 5
-- What changes the pick: the journal is filled after a loading screen, a mount is learned or made
-- a favorite, a form is learned.
local EVENTS = { "PLAYER_ENTERING_WORLD", "NEW_MOUNT_ADDED", "MOUNT_JOURNAL_SEARCH_UPDATED", "SPELLS_CHANGED" }

local button            -- the button of the bind Mount, made at login
local pick, forms       -- what the text casts on land, and the forms, as written last
local picked            -- the journal's number of the mount in the text, nil for a form
local following = false -- a button has the bind Mount: the journal and the spells are followed
local before, indoors   -- on a mount, and indoors, when the key went down
local why               -- the game's reason the pick cannot be summoned there, asked at the key-down
local said              -- the cause of the last "cannot" line
local inside = false    -- the first press indoors of the session is in the log
local told = {}         -- the chat lines of this session
local notes = {}

local function note(sort, words)
    notes[sort] = (notes[sort] or 0) + 1
    if notes[sort] <= MAX_NOTES then
        ns.Log.Add("mount", words)
        return true
    end
end

local function tell(what)
    if not told[what] then
        told[what] = true
        ns.Print(Model.TEXT[what])
    end
end

-- The bind list's entries (Core/Catalog.lua).
function Mount.Bind()
    return { kind = "command", id = COMMAND, name = "Mount", detail = "A favorite mount, or get off", icon = ART }
end

function Random.Bind()
    return { kind = "command", id = "CLICK " .. RANDOM_BUTTON .. ":LeftButton", name = "Random Mount", detail = "One of your mounts, or get off", icon = RANDOM_ART }
end

local write

-- For the log: whether the character is on a mount a moment after a press of a bind.
local function settled(bind)
    C_Timer.After(SETTLE, function()
        ns.Log.Add("mount", bind .. ": " .. SETTLE .. " seconds after the press, on a mount: " .. tostring(ns.Adapter.Mounted()))
    end)
end

-- After a press of the bind Mount: the chat line for a press that had nothing to do or could not
-- summon here, the log for the first presses, and a new pick for the next press.
local function used()
    if not forms then
        return  -- (no text yet: no key and no slot has the bind)
    end
    local fight = ns.Adapter.InCombat()
    if not (before or fight or pick or forms.aquatic) then
        tell("none")
    end
    local line
    line, said = Model.Line(said, before, fight, why)
    if line then
        ns.Print(line)
    end
    -- (the macro word "outdoors" is the engine's: the first press indoors tells if the game knows it)
    local words = "Mount: on a mount at the press: " .. tostring(before) .. ", in combat: " .. tostring(fight) .. ", indoors: " .. tostring(indoors)
        .. "; on land it casts " .. tostring(pick) .. "; why it cannot: " .. tostring(why)
    local logged = note("press", words)
    if indoors and not inside then
        inside = true
        if not logged then
            ns.Log.Add("mount", words)
            logged = true
        end
    end
    if logged then
        settled("Mount")
    end
    ns.Queue.Run("Mount", write)
end

-- Makes the button of the bind Mount, out of a fight. It is made at login, before any key has
-- the bind, so the bind core finds it when a key gets the bind and hears its press too (Sticky
-- Layers, Core/BindCore.lua). With no text yet a press of it does nothing.
local function make()
    if button then
        return
    end
    button = ns.Adapter.MountButton(BUTTON)
    -- Before the game runs the text: the place, and the game's reason the mount cannot come here.
    -- Not asked on a mount, in combat, for a form, or in water (there the game says it in red).
    button:HookScript("PreClick", function()
        before, indoors, why = ns.Adapter.Mounted(), ns.Adapter.Indoors(), nil
        if picked and not before and not ns.Adapter.InCombat() and not ns.Adapter.Swimming() then
            -- (a game whose journal says yes indoors: the text's "outdoors" stops the cast all the same)
            why = ns.Adapter.MountWhy(picked) or (indoors and "" or nil)
        end
    end)
    button:HookScript("PostClick", function()
        ns.Call("Mount", used)
    end)
end

-- Writes the text of the bind Mount with a new pick. Out of a fight only.
write = function()
    make()
    forms = ns.Adapter.MountForms()
    pick, picked = Model.Pick(ns.Adapter.Mounts(), forms, math.random())
    button:SetAttribute("macrotext", Model.Text(pick, forms))
end

local function refresh()
    ns.Queue.Run("Mount", write)
end

-- At login and at each change of the binds or the fixed slots: the journal and the spells are
-- followed only while a button or a fixed slot has the bind Mount.
local function follow()
    local now = ns.Binds.Uses(COMMAND)
    if now == following then
        return
    end
    following = now
    for _, event in ipairs(EVENTS) do
        if now then
            pcall(ns.On, event, "Mount", refresh)
        else
            ns.Off(event, "Mount")
        end
    end
    if now then
        refresh()
    end
end

-- A press of Random Mount.
local function chance()
    if ns.Adapter.Mounted() then
        ns.Adapter.Dismount()
        return
    elseif ns.Adapter.InCombat() then
        return
    end
    local mounts, all = ns.Adapter.Mounts()
    if not mounts[1] then
        tell("randomNone")
        note("none", "the character has none of the " .. all .. " mounts that the journal lists")
        return
    end
    -- (where the game calls no mount usable, it is asked all the same, and says why in its own red words)
    local usable = Model.Usable(mounts)
    local mount = Model.Random(usable[1] and usable or mounts, math.random())
    local ok, why = ns.Adapter.Summon(mount.id)
    if note("random", "Random Mount: " .. #mounts .. " mounts, " .. #usable .. " usable here; asked for " .. mount.name .. ": "
        .. (ok and "the game took the call" or "the game refused (" .. tostring(why) .. ")")) then
        settled("Random Mount")
    end
end

function Mount.OnLogin()
    -- Both buttons, out of a fight. Random Mount's is a secure button too, so the bind core can
    -- hear its press (Sticky Layers, Core/BindCore.lua). Its press runs our code, not a secure action.
    ns.Queue.Run("RandomMount", function()
        local made = CreateFrame("Button", RANDOM_BUTTON, UIParent, "SecureActionButtonTemplate")
        made:RegisterForClicks("AnyDown")
        made:SetScript("OnClick", function()
            ns.Call("Mount", chance)
        end)
        make()
    end)
    -- (builds before 0.21.0 learned the fastest mount here; nothing reads it now)
    GamepadSuiteCharDB.mounts = nil
    follow()
    ns.Listen("bind", "Mount", follow)
    ns.Listen("slots", "Mount", follow)
end
