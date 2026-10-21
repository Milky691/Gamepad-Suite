-- The rules of the bind Minimap Zoom, with no game calls: which zoom step one press goes to.
-- Auto/MinimapZoom.lua asks the game and sets the step.
local _, ns = ...

local Model = {}

-- The three steps a press goes through: all the way out, the middle, all the way in. The game counts
-- its zoom steps from 0 (out) to the count less one (in). A minimap with two steps has two to go
-- through; one with fewer has nothing to cycle.
function Model.Steps(levels)
    if type(levels) ~= "number" or levels < 2 then
        return {}
    end
    local top = levels - 1
    local middle = math.floor(top / 2)
    if middle > 0 and middle < top then
        return { 0, middle, top }
    end
    return { 0, top }
end

-- The step one press goes to from the zoom now: the next one further in, and after the last one all
-- the way out again. A zoom between two steps (the player used the game's own zoom binds) goes to
-- the step after it. nil when there is nothing to cycle.
function Model.Next(zoom, levels)
    local steps = Model.Steps(levels)
    for _, step in ipairs(steps) do
        if step > zoom then
            return step
        end
    end
    return steps[1]
end

if ns then
    ns.MinimapZoomModel = Model
end
return Model
