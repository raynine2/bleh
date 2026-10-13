-- Tidebound: Eggfall: how the client scripts tell the audio, VFX and UI layers what is happening (GDD Sections 8-9).
-- Like MotionBus, every LocalScript on a client shares this one table. Nothing here talks to the server.
--   ClientBus.hold(name, seconds)  -- ask for a music state ("Reveal", "Extract", "Wipe", "Hunt"...) for a while
--   ClientBus.release(name)        -- drop it early
--   ClientBus.duck(rule, seconds)  -- a Soundtrack.ducking rule ("important", "swell", "voice")
--   ClientBus.gacha(stage, part?)  -- a Soundtrack.gacha stage: "PreReveal", "Reveal", "RarityConfirm"
--   ClientBus.flash(color, from)   -- a full-screen flash, limited to 3 per second and softened by Reduce Flashing
--   ClientBus.menuOpen             -- true while any menu window is open (Menu music, UI bus not ducked)
--   ClientBus.underwater           -- true while the camera is under the sea (TideboundUnderwater; fires "underwater")
--   ClientBus.underwaterDepth      -- studs from the camera up to the surface (negative above it)
--   ClientBus.submersion           -- 0..1, the smoothed underwater blend every underwater effect follows
--   ClientBus.settings             -- the player's audio / VFX / accessibility settings (saved by the server)
--   ClientBus.signal               -- BindableEvent fired as (kind, ...) for everything above

local ClientBus = {}

ClientBus.holds = {} -- [state] = os.clock() it ends at
ClientBus.ducks = {} -- [rule] = os.clock() it ends at
ClientBus.menuOpen = false
ClientBus.menus = {} -- [name] = true, so two windows don't fight over menuOpen
ClientBus.underwater = false
ClientBus.underwaterDepth = -math.huge
ClientBus.submersion = 0

ClientBus.settings = {
	musicVolume = 1,
	sfxVolume = 1,
	ambienceVolume = 1,
	uiVolume = 1,
	reduceFlashing = false, -- Section 8 VFX Clarity Rule 3: screen flashes at 20% strength
	vfxQuality = "Auto", -- "Auto", "High", "Medium", "Low": scales every particle count (Rule 2)
	cameraShake = true,
}

ClientBus.signal = Instance.new("BindableEvent")

function ClientBus.hold(name: string, seconds: number?)
	local untilTime = os.clock() + (seconds or 1e9)
	ClientBus.holds[name] = math.max(ClientBus.holds[name] or 0, untilTime)
	ClientBus.signal:Fire("hold", name)
end

function ClientBus.release(name: string)
	ClientBus.holds[name] = nil
	ClientBus.signal:Fire("release", name)
end

function ClientBus.holding(name: string): boolean
	local untilTime = ClientBus.holds[name]
	return untilTime ~= nil and untilTime > os.clock()
end

function ClientBus.duck(rule: string, seconds: number)
	ClientBus.ducks[rule] = math.max(ClientBus.ducks[rule] or 0, os.clock() + seconds)
	ClientBus.signal:Fire("duck", rule)
end

function ClientBus.gacha(stage: string, part: Instance?)
	ClientBus.signal:Fire("gacha", stage, part)
end

function ClientBus.setMenu(name: string, open: boolean)
	ClientBus.menus[name] = open or nil
	local any = next(ClientBus.menus) ~= nil
	if any ~= ClientBus.menuOpen then
		ClientBus.menuOpen = any
		ClientBus.signal:Fire("menu", any)
	end
end

-- Section 8 Rule 5: at most 3 full-screen flashes per second. Returns how strong this flash may be (0 = skip).
local flashTimes = {}
function ClientBus.flashAllowed(): number
	local now = os.clock()
	for i = #flashTimes, 1, -1 do
		if now - flashTimes[i] > 1 then
			table.remove(flashTimes, i)
		end
	end
	if #flashTimes >= 3 then
		return 0
	end
	table.insert(flashTimes, now)
	return ClientBus.settings.reduceFlashing and 0.2 or 1
end

function ClientBus.flash(color: Color3, from: number?)
	local strength = ClientBus.flashAllowed()
	if strength > 0 then
		ClientBus.signal:Fire("flash", color, strength, from or 0.4)
	end
end

function ClientBus.applySettings(settings)
	if type(settings) ~= "table" then
		return
	end
	for key, value in pairs(settings) do
		if ClientBus.settings[key] ~= nil and type(value) == type(ClientBus.settings[key]) then
			ClientBus.settings[key] = value
		end
	end
	ClientBus.signal:Fire("settings")
end

return ClientBus
