-- Tidebound: Eggfall: how the client scripts share a character's joints (Big Update).
-- TideboundMotion owns every R15 joint write (idle, run, sprint, jump, landing, hurt, stun, carry, cheer and
-- the rest). Other client scripts never write joints: they publish what they want here, and Motion layers it.
--   arms[character] = { weight = 0..1, pose = { shR, elR, shL, elL, waist, inR, inL } }  -- the fishing arms
--   cutscene = true while a cutscene owns the camera (TideboundClient stops your movement for it)
--   pose[character] = { name = string, untilTime = os.clock() }  -- a one-off full-body pose a cutscene asks for

local MotionBus = {}

MotionBus.arms = {}
MotionBus.pose = {}
MotionBus.cutscene = false

return MotionBus
