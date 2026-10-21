-- The rules of the bind Cleanse and of the debuff mark on the party wheel, with no game calls
-- (Auto/Cleanse.lua asks the game, Screen/WheelPlate.lua draws the mark).
local _, ns = ...

local Model = {}

-- The spells that remove a debuff, by the game's number, each with the kinds of debuff it
-- removes. The character's own spells decide, not its class: a druid before level 14 removes
-- nothing. For one kind the spell higher in the list is used: Cleanse before Purify, Abolish
-- Poison before Cure Poison. One rank is enough: a spell cast by its name alone is cast at the
-- highest rank the character knows.
Model.SPELLS = {
    { id = 4987, kinds = { "Poison", "Disease", "Magic" } },   -- Cleanse (paladin)
    { id = 1152, kinds = { "Poison", "Disease" } },            -- Purify (paladin)
    { id = 527, kinds = { "Magic" } },                         -- Dispel Magic (priest)
    { id = 552, kinds = { "Disease" } },                       -- Abolish Disease (priest)
    { id = 528, kinds = { "Disease" } },                       -- Cure Disease (priest)
    { id = 2870, kinds = { "Disease" } },                      -- Cure Disease (shaman)
    { id = 2893, kinds = { "Poison" } },                       -- Abolish Poison (druid)
    { id = 8946, kinds = { "Poison" } },                       -- Cure Poison (druid)
    { id = 526, kinds = { "Poison" } },                        -- Cure Poison (shaman)
    { id = 2782, kinds = { "Curse" } },                        -- Remove Curse (druid)
    { id = 475, kinds = { "Curse" } },                         -- Remove Lesser Curse (mage)
}
-- The kinds of debuff, in the order the mark takes them when a member has more than one.
Model.KINDS = { "Magic", "Curse", "Poison", "Disease" }

-- What the character removes each kind with. known is { [number] = { id, name, icon } } of the
-- spells of the list that the character knows. Gives kind -> that spell, and first: the first
-- spell of the list that it knows. Empty for a character that knows none.
function Model.Removers(known)
    local out = {}
    for _, spell in ipairs(Model.SPELLS) do
        local have = known[spell.id]
        if have then
            out.first = out.first or have
            for _, kind in ipairs(spell.kinds) do
                out[kind] = out[kind] or have
            end
        end
    end
    return out
end

-- The kind of debuff that a member's mark shows: the first of KINDS that the member has and the
-- character can remove. kinds is { kind = true }, or nil while the game hides the auras: no mark.
function Model.Mark(kinds, removers)
    for _, kind in ipairs(Model.KINDS) do
        if kinds and kinds[kind] and removers[kind] then
            return kind
        end
    end
    return nil
end

-- The chat command that the next press of Cleanse runs, or nil for a character that removes
-- nothing. units is the party, the player first; mark(unit) gives Model.Mark for a unit, and true
-- after it while the game hides that unit's auras. friend: the target is a friend who lives.
-- Out of a fight the spell goes to the first member with a debuff that the character can remove,
-- else to the target when it is such a friend with one (a stranger too). With nobody, the command
-- is empty: a press casts nothing and costs no mana (Auto/Cleanse.lua says why, once). While the
-- game hides someone's auras the addon cannot know, so the command is the one of a fight.
-- In a fight the command cannot change, so it names no member: the spell goes to the target while
-- it is a friend and alive, else to the player. Its spell is the one for the debuff found at the
-- fight's start, or the first one the character knows.
function Model.Text(removers, units, mark, fight, friend)
    local unit, kind, blind, hid
    for _, each in ipairs(units) do
        kind, hid = mark(each)
        blind = blind or hid
        if kind then
            unit = each
            break
        end
    end
    if not unit and friend and not fight then
        kind, hid = mark("target")
        unit, blind = kind and "target" or nil, blind or hid
    end
    local spell = kind and removers[kind] or removers.first
    if not spell then
        return nil
    elseif unit and not fight then
        return "/cast [@" .. unit .. "] " .. spell.name
    elseif not fight and not blind then
        return ""
    end
    return "/cast [@target,help,nodead][@player] " .. spell.name
end

if ns then
    ns.CleanseModel = Model
end
return Model
