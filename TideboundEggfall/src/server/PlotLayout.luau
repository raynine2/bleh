-- Tidebound: Eggfall: one Home Nest plot's layout (Delta Section 7), shared by ExpansionBuilder (the shell)
-- and BaseService (the creatures and signs that change). Offsets are in plot space: the plot's -Z faces the
-- Harbor Ring lagoon, so the gate is at the front and the five rooms form a horseshoe at the back.

local PlotLayout = {}

PlotLayout.SIZE = 120

-- Rooms face the plot centre. `size` is width x wall height x depth.
PlotLayout.rooms = {
	hatch = { pos = Vector3.new(-34, 0, 36), size = Vector3.new(22, 11, 16), title = "HATCH CHAMBER" },
	aquarium = { pos = Vector3.new(0, 0, 40), size = Vector3.new(30, 13, 18), title = "AQUARIUM HALL" },
	workshop = { pos = Vector3.new(34, 0, 36), size = Vector3.new(22, 11, 16), title = "ROD WORKSHOP" },
	trophy = { pos = Vector3.new(-40, 0, 4), size = Vector3.new(22, 11, 16), title = "TROPHY ROOM" },
	altar = { pos = Vector3.new(40, 0, 4), size = Vector3.new(22, 11, 16), title = "PRESTIGE ALTAR", dais = 1.5 },
}

-- Outdoor zones (they don't count toward the canon's 5 rooms).
PlotLayout.pen = { pos = Vector3.new(-14, 0, -10), radius = 16 }
PlotLayout.vault = { pos = Vector3.new(40, 0, -32), size = Vector3.new(14, 8, 14) }
PlotLayout.deck = { pos = Vector3.new(-30, 0, -46), size = Vector3.new(24, 1, 16) }

PlotLayout.gate = Vector3.new(0, 0, -58)
PlotLayout.plinth = Vector3.new(12, 0, -46)
PlotLayout.treadmill = Vector3.new(16, 0, -14)
PlotLayout.trough = Vector3.new(-14, 0, -24)
PlotLayout.arrival = Vector3.new(0, 0, -50) -- where Travel drops the owner

-- Plot space -> world CFrame for a room: facing the plot centre at floor height.
function PlotLayout.roomCFrame(origin, room)
	local p = room.pos
	local towardCentre = Vector3.new(-p.X, 0, -p.Z)
	return origin * CFrame.lookAt(p, p + towardCentre)
end

-- Is a world position inside this plot's square?
function PlotLayout.contains(origin, position)
	local localPos = origin:PointToObjectSpace(position)
	local half = PlotLayout.SIZE / 2
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half
end

return PlotLayout
