-- Voice Transcription: a bind, in the list Game Actions. A press turns the transcription of the voice channel the
-- player is in on or off, as the game's Chat Channels window does with RB (Core/AdapterVoice.lua). The game added
-- that in build 1.60.1.70425 with no key bind of its own, so this bind is ours (the owner, 2026-10-17: "add the
-- voice binds to our game actions bindings list"). Nothing runs but at a press and at the game's word of a change.
-- The chat says why nothing could change, once per cause. What changed it says when the game tells of it
-- (VOICE_CHAT_CHANNEL_TRANSCRIBING_CHANGED, as the game's own button hears it: Blizzard_ChatFrame/Shared/
-- VoiceChatTranscriptionButton.lua 8 and 24), so a change in the game's own window is told the same way, and a call
-- the game did not act on says nothing false.
local _, ns = ...

local Voice = ns.Module("VoiceText", { "voiceText" }, "Voice Transcription")
ns.VoiceText = Voice

local BUTTON = "GamepadSuiteVoiceText"
-- the game's picture of an ear, as the other voice binds have (Core/Catalog.lua)
local ART = "Interface\\Icons\\INV_Misc_Ear_Human_02"
local WHY = {
    allowed = "Voice Transcription is not allowed in this voice chat.",
    setting = "Voice Transcription is off in the game's options. Turn on speech to text under Accessibility.",
    channel = "Voice Transcription works in a voice channel. Join one first.",
    refused = "Voice Transcription: the game did not take the change.",
}
local told = 0      -- lines in the log this session
local said          -- the cause of the last "why not" line, until a press can act or the cause changes
local shown         -- the state the last on or off line told
local heard = false -- the game's word of a change is in the log

-- The bind list's entry (Core/Catalog.lua).
function Voice.Bind()
    return { kind = "command", id = "CLICK " .. BUTTON .. ":LeftButton", name = "Voice Transcription", detail = "Press to turn it on or off", icon = ART }
end

-- The "why not" line, once per cause: quiet when the cause is the one of the line before.
local function say(cause)
    if cause ~= said then
        said = cause
        if cause then
            ns.Print(WHY[cause])
        end
    end
end

local function press()
    local why, channel, on = ns.Adapter.VoiceText()
    if why then
        say(why)
        return
    end
    local ok, err = pcall(ns.Adapter.SetVoiceText, channel, not on)
    say(not ok and "refused" or nil)
    told = told + 1
    if told <= 2 then
        ns.Log.Add("voice", "transcription " .. (on and "off" or "on") .. " for channel " .. tostring(channel) .. ": "
            .. (ok and "the game took the call" or "the game refused (" .. tostring(err) .. ")"))
    end
end

-- The game tells of a change, from this bind or from its own window: the on or off line, once per state.
local function changed(channel, now)
    now = now and true or false
    if now ~= shown then
        shown = now
        ns.Print("Voice Transcription " .. (now and "on." or "off."))
    end
    if not heard then
        heard = true
        ns.Log.Add("voice", "the game told of a change: " .. (now and "on" or "off") .. " for channel " .. tostring(channel))
    end
end

function Voice.OnLogin()
    -- the state now (off with no voice channel), so a word of the game that changes nothing says nothing
    shown = select(3, ns.Adapter.VoiceText()) == true
    ns.On("VOICE_CHAT_CHANNEL_TRANSCRIBING_CHANGED", "VoiceText", changed)
    -- The button that the bind clicks. A secure button (made out of a fight), so the bind core can hear its press
    -- too (Sticky Layers, Core/BindCore.lua), as Minimap Zoom's.
    ns.Queue.Run("VoiceText", function()
        local button = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
        button:RegisterForClicks("AnyDown")
        button:SetScript("OnClick", function()
            ns.Call("VoiceText", press)
        end)
    end)
end
