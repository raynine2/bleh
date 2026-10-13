-- Tidebound: Eggfall: how the client scripts share a character's joints (Big Update).
-- TideboundMotion owns every R15 joint write (idle, run, sprint, jump, landing, hurt, stun, carry, cheer and
-- the rest). Other client scripts never write joints: they publish what they want here, and Motion layers it.
--   arms[character] = { weight = 0..1, pose = { shR, elR, shL, elL, waist, inR, inL }, body = { hipRX, kneeRX, ... }? }
--     the fishing arms; `body` (Patch 10) is an optional lower-body pose in TideboundMotion's keys (legs, root)
--   launch[character] = { start = os.clock(), duration = seconds }  -- a geyser launch is flying you (Patch 10)
--   cutscene = true while a cutscene owns the camera (TideboundClient stops your movement for it)
--   pose[character] = { name = string, untilTime = os.clock() }  -- a one-off full-body pose a cutscene asks for
--   dash[character] = { start = os.clock(), kind = 1..3 }  -- your own dash, played at once (Patch 18; others
--     see it through the DashAt / DashKind attributes the server sets)
--   tired[character] = true while your own stamina is empty (Patch 18; others see the Tired attribute)
--   kick = { at = os.clock(), amount = degrees, length = seconds }  -- a punch of the camera's field of view
--   skill[character] = { start = os.clock(), rod, alt }  -- your own rod ability, played at once (Patch 21;
--     others see it through SkillRod / SkillAlt / SkillAt)
--   stamina = { value, winded, lastDrain, shownAt }  -- your stamina (Patch 19): TideboundClient refills it and
--     drains it on the sprint, TideboundDash spends it on dashes
--   ride[character] = { style, start, jumpAt?, jumpLength, speed?, lean? }  -- your own fish ride (12 Oct 2026,
--     TideboundRide; others see it through the Riding / RideJumpAt attributes RideService sets)

local MotionBus = {}

MotionBus.arms = {}
MotionBus.pose = {}
MotionBus.launch = {}
MotionBus.cutscene = false
MotionBus.dash = {}
MotionBus.tired = {}
MotionBus.kick = nil :: { at: number, amount: number, length: number }?
MotionBus.skill = {}
MotionBus.stamina = { value = 100, winded = false, lastDrain = 0, shownAt = 0 }
MotionBus.ride = {}

return MotionBus
