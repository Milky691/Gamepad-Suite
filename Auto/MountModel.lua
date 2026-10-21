-- The rules of the binds Mount and Random Mount, with no game calls. A mount here is one entry of
-- the adapter's list: { id =, name =, spell = the name a chat command casts it by, usable =,
-- favorite = }. forms is the adapter's { aquatic =, travel =, wolf = }: the names of the forms the
-- character knows, each nil when it does not.
local _, ns = ...

local Model = {}

-- The mounts that the game calls usable where the character stands, in the journal's order.
function Model.Usable(mounts)
    local usable = {}
    for _, mount in ipairs(mounts) do
        if mount.usable then
            usable[#usable + 1] = mount
        end
    end
    return usable
end

-- One of the list by chance. roll is a number from 0 up to 1, not 1 itself.
function Model.Random(mounts, roll)
    return mounts[math.floor(roll * #mounts) + 1]
end

-- What the bind Mount summons on land, as the name to cast: a mount by chance of the favorites,
-- or of all the character's mounts when none is a favorite. Of those, only the ones the game
-- calls usable where the character stands, while there is one: a mount that the character's
-- riding skill is too low for, or one for one place of the world, would only bring the game's
-- red line. With no mount: Travel Form for a druid, else Ghost Wolf for a shaman. nil when there
-- is none of these. The second value is the journal's number of a picked mount, nil for a form.
function Model.Pick(mounts, forms, roll)
    local all, favorites = {}, {}
    for _, mount in ipairs(mounts) do
        if mount.spell then
            all[#all + 1] = mount
            if mount.favorite then
                favorites[#favorites + 1] = mount
            end
        end
    end
    local pool = favorites[1] and favorites or all
    local usable = Model.Usable(pool)
    pool = usable[1] and usable or pool
    if pool[1] then
        local mount = Model.Random(pool, roll)
        return mount.spell, mount.id
    end
    return forms.travel or forms.wolf
end

-- The macro text of the bind Mount. The game reads the conditions at the press, in a fight too:
-- on a mount it gets off. In a fight nothing else happens. In water a druid takes Aquatic Form.
-- On land the pick. A mount is cast outdoors only: indoors the chat gives the game's reason
-- (Model.Line). A form, and a mount in water for a character with no Aquatic Form, is cast all
-- the same, so the game says in its own red words why not. The line that gets off comes last, so
-- no line after it can read the character as off the mount already.
function Model.Text(pick, forms)
    local lines = {}
    if forms.aquatic then
        lines[#lines + 1] = "/cast [nomounted,nocombat,swimming] " .. forms.aquatic
    end
    if pick then
        local form = pick == forms.travel or pick == forms.wolf
        lines[#lines + 1] = "/cast [nomounted,nocombat" .. (forms.aquatic and ",noswimming" or "") .. (form and "" or ",outdoors") .. "] " .. pick
    end
    lines[#lines + 1] = "/dismount [mounted]"
    return table.concat(lines, "\n")
end

-- What the chat says, one time in a session.
Model.TEXT = {
    none = "Mount: this character has no mount.",
    randomNone = "Random Mount: this character has no mount.",
    cannot = "Mount: you cannot summon a mount here.",
}

-- The chat line after a press of the bind Mount, once per cause. last: the cause of the line said
-- last. before: on a mount at the press; fight: in combat; why: the game's reason the picked mount
-- cannot be summoned here ("" for none given), nil when it can. Gives the line (nil for none) and
-- the cause to keep. On a mount and in combat the press says nothing; a press that can summon
-- ends the cause, so the next "cannot" is told again.
function Model.Line(last, before, fight, why)
    if before or fight then
        return nil, last
    elseif why == nil or why == last then
        return nil, why
    end
    return why == "" and Model.TEXT.cannot or "Mount: " .. why, why
end

if ns then
    ns.MountModel = Model
end
return Model
