-- The rules of three small helpers, with no game calls: Mark Next (Auto/MarkNext.lua), Look
-- Behind (Auto/LookBehind.lua) and Stay Seated While Eating (Auto/Seated.lua).
local _, ns = ...

local Model = {}

-- ---------------------------------------------------------------- Mark Next
-- The kill order, by the game's numbers for the raid marks: skull, cross, square, moon, triangle,
-- diamond, circle, star. After the star the next mark is the skull again. (The step from one
-- mark to the next is made by the game's restricted code, which runs in a fight too:
-- Core/AdapterExtras.lua.)
Model.MARKS = { 8, 7, 6, 5, 4, 3, 2, 1 }

-- The order starts again at the skull when a fight ends, and when the button was not pressed
-- for this many seconds.
Model.MARK_IDLE = 15

-- The chat line, once per role, for a press in a raid without the right to mark.
Model.MARK_RAID = "Mark Next: in a raid only the leader or an assistant can mark."

-- The wait after a press is over: does the order start again now? pressed is when the press
-- that began the wait came, last when the button was pressed the last time. A later press has a
-- wait of its own. Not in a fight: the game locks the button there, and the end of the fight
-- starts the order again.
function Model.MarkStartsAgain(pressed, last, fight)
    return pressed == last and not fight
end

-- ---------------------------------------------------------------- Look Behind
-- The camera turns half way round at a press and back at the let-go. turned: it looks behind
-- now. down: true for a press, false for a let-go, nil to bring the camera back (a fight starts,
-- a reload). Returns two things: does it look behind after this, and must the camera turn now.
-- A let-go with no press before it turns nothing. A press while the camera looks behind means
-- that the let-go of the press before never came: that press brings the camera back.
function Model.Look(turned, down)
    if down then
        return not turned, true
    end
    return false, turned
end

-- Does the top pop-up hold this controller button now ("Y", "X"), so a press of it is the pop-up's hold and not
-- Look Behind's turn? item: the pop-up that shows (Screen/Popup.lua), its acts as Screen/PopupHold.lua has them. key:
-- the one button of this press (nil: not known, or a trigger is held, and then the pop-up holds nothing). The pop-up
-- hears no hold in combat, none for an act that is off or not offered now, and none for an act of the press grammar
-- (that one takes the key as a bind of its own, so Look Behind never gets the press).
function Model.PopupHolds(item, key, fight)
    if fight or not key or not (item and item.acts) then
        return false
    end
    for _, act in ipairs(item.acts) do
        if act.key == key and not act.off and not act.press and (not act.can or act.can(item)) then
            return true
        end
    end
    return false
end

-- The places of the pad's buttons that are down. buttons is the pad's own table: place -> true.
function Model.Down(buttons)
    local down = {}
    for place, on in pairs(buttons) do
        if on then
            down[#down + 1] = place
        end
    end
    return down
end

-- True when every button that was down at the press is up: the hold is over, also when the game
-- never told of the let-go (the key went to a window, or to another set of binds). An empty list
-- tells nothing: the pad could not be read.
function Model.AllUp(held, buttons)
    for _, place in ipairs(held) do
        if buttons[place] then
            return false
        end
    end
    return #held > 0
end

-- ---------------------------------------------------------------- Stay Seated While Eating
Model.FULL = 0.9    -- a push of the left stick this far is a full push (1 is all the way)
Model.STAND = 0.5   -- seconds a full push must last to stand the character up

function Model.Full(x, y)
    return x * x + y * y >= Model.FULL * Model.FULL
end

-- Is the left stick kept from the game now? on: the switch. eating: the character eats or
-- drinks (asked out of a fight only, so a fight ends it). gameplay: no window has the
-- controller. stood: the player pushed fully in this meal, to stand up.
function Model.Seated(on, eating, gameplay, stood)
    return (on and eating and gameplay and not stood) and true or false
end

-- One stick told to one of the meal's two frames. It is the two-frame way of the wheels
-- (Screen/WheelModel.lua says why two), turned round: the wall takes the walking stick, and the
-- camera's stick passes the ear. The game tells a stick by its own name first (Left, Right) and
-- then by the name it acts on (Movement, Camera), the walking stick before the camera's. So
-- the wall goes up at the left stick's own name and comes down when it has the walking stick
-- (or the camera's stick: then the walking stick did not come in this frame of the screen).
-- ConsolePort does this for a wheel on the left stick (ConsolePort/Controller/Radial.lua 41 to
-- 55 and 96 to 104). Every push of the left stick is kept, also a small one.
-- s is what the frames remember in one meal: { kept = 0, passed = 0, turned = 0, lost = 0 }.
-- name is the stick, onWall is true when the wall was told (it is up), now is the game's time
-- (the same for one frame of the screen), far is the square of the stick's push.
-- Gives true when the wall must be up for the next stick. It counts for the log: kept (the wall
-- took the walking stick), passed (the walking stick passed the ear: the character can stand
-- up), turned (the camera's stick passed), lost (the wall took the camera's stick).
function Model.SeatStick(s, name, onWall, now, far)
    if now ~= s.tick then
        s.tick, s.walk = now, false
    end
    if name == "Left" then
        s.walk = far > 0
    elseif name == "Movement" then
        local count = onWall and "kept" or "passed"
        s[count] = s[count] + (far > 0 and 1 or 0)
        s.walk = false
    elseif name == "Camera" then
        local count = onWall and "lost" or "turned"
        s[count] = s[count] + 1
        s.walk = false
    end
    return s.walk
end

if ns then
    ns.ExtrasModel = Model
end
return Model
