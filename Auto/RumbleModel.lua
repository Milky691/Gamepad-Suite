-- Rumble Events, the rules (no game calls): the pattern of each game event, which pattern is the
-- more urgent, the row that turns each event on, and how long a cooldown must be to count.
-- The pack is build_plan/packs/P15_rumble_events.md.
local _, ns = ...

local Model = {}
ns.RumbleModel = Model

-- A pattern is its pulses, each { start, seconds } from the first one, and its rank: when events
-- come together, the one with the higher rank plays. Each feels different from the others and
-- from the pulses that were there before (low health 0.6 s, a proc 2 x 0.12 s, the range tick
-- 0.14 s). No pulse is longer than 0.4 s: the game is told once for each pulse, and a long one
-- could fade before its end (the other addons send it again each 0.1 s; we keep pulses short).
Model.PATTERNS = {
    death = { rank = 6, { 0, 0.3 }, { 0.45, 0.3 }, { 0.9, 0.3 } },
    control = { rank = 5, { 0, 0.4 } },
    ask = { rank = 4, { 0, 0.2 }, { 0.4, 0.2 } },
    whisper = { rank = 3, { 0, 0.06 }, { 0.15, 0.06 }, { 0.3, 0.06 } },
    level = { rank = 2, { 0, 0.1 }, { 0.2, 0.1 }, { 0.4, 0.4 } },
    ready = { rank = 1, { 0, 0.1 } },
}

-- The game's events: the row that turns each one on, its pattern, and the unit it is heard for.
-- A duel or a trade asks for an answer, as a ready check does: the same pattern.
local GROUP, WHISPERS, DANGER, LEVEL = "feel.rumble_group", "feel.rumble_whispers", "feel.rumble_danger", "feel.rumble_level"
Model.EVENTS = {
    READY_CHECK = { row = GROUP, pattern = "ask" },
    PARTY_INVITE_REQUEST = { row = GROUP, pattern = "ask" },
    CONFIRM_SUMMON = { row = GROUP, pattern = "ask" },
    RESURRECT_REQUEST = { row = GROUP, pattern = "ask" },
    CHAT_MSG_WHISPER = { row = WHISPERS, pattern = "whisper" },
    CHAT_MSG_BN_WHISPER = { row = WHISPERS, pattern = "whisper" },
    PLAYER_DEAD = { row = DANGER, pattern = "death" },
    LOSS_OF_CONTROL_ADDED = { row = DANGER, pattern = "control", unit = "player" },
    PLAYER_LEVEL_UP = { row = LEVEL, pattern = "level" },
    DUEL_REQUESTED = { row = LEVEL, pattern = "ask" },
    TRADE_REQUEST = { row = LEVEL, pattern = "ask" },
}

-- Rumble When Ready counts a cooldown of 10 seconds or more, measured with our own clock from the
-- game's word that it started (a moment after its true start, so a little less than 10). Spells
-- used each 4 to 8 seconds (Mortal Strike, Mind Blast, Earth Shock) would pulse through the whole
-- fight; from 10 seconds are the ones a player waits for (Kick, Pummel, Blink, Frost Nova).
Model.FLOOR = 9.5
