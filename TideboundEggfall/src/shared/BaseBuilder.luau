-- Tidebound: BaseBuilder - Player base customization, building, and equipment display system
-- Revamped for better aesthetics, more customization, and equipment showcase

local BaseBuilder = {}

-- BASE THEMES (unlockable visual styles)
BaseBuilder.Themes = {
	{ id = "Coastal", name = "Coastal Cottage", unlockCost = 0, description = "Weathered wood and ocean vibes", colors = { primary = Color3.fromRGB(200, 180, 150), accent = Color3.fromRGB(100, 150, 200), trim = Color3.fromRGB(240, 240, 250) } },
	{ id = "Tropical", name = "Tropical Paradise", unlockCost = 5000, description = "Bamboo, palm leaves, tiki torches", colors = { primary = Color3.fromRGB(160, 120, 80), accent = Color3.fromRGB(50, 180, 80), trim = Color3.fromRGB(255, 200, 100) } },
	{ id = "Modern", name = "Modern Glass", unlockCost = 15000, description = "Sleek glass and steel", colors = { primary = Color3.fromRGB(240, 240, 245), accent = Color3.fromRGB(60, 60, 70), trim = Color3.fromRGB(100, 200, 255) } },
	{ id = "Mystical", name = "Mystical Shrine", unlockCost = 50000, description = "Japanese torii gates and lanterns", colors = { primary = Color3.fromRGB(180, 50, 50), accent = Color3.fromRGB(40, 40, 50), trim = Color3.fromRGB(255, 215, 0) } },
	{ id = "Underwater", name = "Underwater Dome", unlockCost = 100000, description = "Glass dome with coral accents", colors = { primary = Color3.fromRGB(100, 200, 255), accent = Color3.fromRGB(255, 127, 80), trim = Color3.fromRGB(150, 255, 200) } },
	{ id = "Celestial", name = "Celestial Palace", unlockCost = 500000, description = "Golden pillars and starlight", colors = { primary = Color3.fromRGB(255, 240, 200), accent = Color3.fromRGB(138, 43, 226), trim = Color3.fromRGB(255, 215, 0) } },
}

-- BASE ROOMS (buildable/unlockable)
BaseBuilder.Rooms = {
	{ id = "NestHall", name = "Nest Hall", unlockCost = 0, size = Vector3.new(30, 12, 30), capacity = 20, description = "Main creature display area", slots = { nest = 20 } },
	{ id = "EquipmentVault", name = "Equipment Vault", unlockCost = 10000, size = Vector3.new(25, 12, 20), capacity = 30, description = "Display all your gear", slots = { equipment = 30, mannequin = 3 } },
	{ id = "AquariumHall", name = "Aquarium Hall", unlockCost = 25000, size = Vector3.new(40, 15, 25), capacity = 50, description = "Living water tanks for aquatic creatures", slots = { aquarium = 50 }, special = "animated fish" },
	{ id = "TrophyRoom", name = "Trophy Room", unlockCost = 50000, size = Vector3.new(30, 15, 30), capacity = 20, description = "Display boss kills and achievements", slots = { trophy = 20, plaque = 10 } },
	{ id = "Workshop", name = "Workshop", unlockCost = 20000, size = Vector3.new(20, 10, 20), description = "Craft, fuse, and upgrade equipment", slots = { workbench = 1, forge = 1, enchanter = 1 } },
	{ id = "Garden", name = "Garden", unlockCost = 15000, size = Vector3.new(35, 8, 35), description = "Grow decorative plants and trees", slots = { plant = 50 }, special = "passive pearl generation" },
	{ id = "Library", name = "Library", unlockCost = 30000, size = Vector3.new(25, 18, 20), description = "Store lore tablets and discoveries", slots = { book = 100 }, special = "read collected lore" },
	{ id = "Observatory", name = "Observatory", unlockCost = 100000, size = Vector3.new(20, 25, 20), description = "Glass dome with telescope", slots = { telescope = 1 }, special = "view distant islands" },
}

-- DECORATIVE ITEMS (place anywhere in base)
BaseBuilder.Decorations = {
	-- Lighting
	{ id = "LanternStand", name = "Lantern Stand", cost = 500, category = "Lighting", description = "Warm glow lantern", size = Vector3.new(2, 6, 2) },
	{ id = "CrystalLight", name = "Crystal Light", cost = 2000, category = "Lighting", description = "Floating glowing crystal", size = Vector3.new(1, 3, 1), effect = "particles" },
	{ id = "TorchWall", name = "Wall Torch", cost = 300, category = "Lighting", description = "Wall-mounted flame", size = Vector3.new(1, 4, 1) },
	{ id = "GlowOrb", name = "Glow Orb", cost = 5000, category = "Lighting", description = "Color-changing orb", size = Vector3.new(2, 2, 2), customizable = { color = true } },
	
	-- Furniture
	{ id = "WoodenChair", name = "Wooden Chair", cost = 200, category = "Furniture", description = "Simple chair", size = Vector3.new(3, 4, 3) },
	{ id = "CushionedSofa", name = "Cushioned Sofa", cost = 1500, category = "Furniture", description = "Comfy 3-seat sofa", size = Vector3.new(8, 4, 4) },
	{ id = "WorkDesk", name = "Work Desk", cost = 800, category = "Furniture", description = "Desk with drawers", size = Vector3.new(6, 4, 3) },
	{ id = "Bookshelf", name = "Bookshelf", cost = 1200, category = "Furniture", description = "Tall bookshelf", size = Vector3.new(5, 10, 2) },
	{ id = "StorageChest", name = "Storage Chest", cost = 600, category = "Furniture", description = "Decorative chest", size = Vector3.new(4, 3, 3) },
	
	-- Plants
	{ id = "PottedPlant", name = "Potted Plant", cost = 400, category = "Plants", description = "Small leafy plant", size = Vector3.new(2, 3, 2) },
	{ id = "PalmTree", name = "Palm Tree", cost = 3000, category = "Plants", description = "Tropical palm tree", size = Vector3.new(4, 15, 4) },
	{ id = "BambooStalk", name = "Bamboo Stalk", cost = 800, category = "Plants", description = "Tall bamboo cluster", size = Vector3.new(2, 12, 2) },
	{ id = "FlowerPot", name = "Flower Pot", cost = 300, category = "Plants", description = "Colorful flowers", size = Vector3.new(2, 2, 2), customizable = { color = true } },
	
	-- Water Features
	{ id = "Fountain", name = "Fountain", cost = 10000, category = "Water", description = "Animated water fountain", size = Vector3.new(8, 6, 8), effect = "water" },
	{ id = "KoiPond", name = "Koi Pond", cost = 15000, category = "Water", description = "Small pond with koi fish", size = Vector3.new(12, 2, 12), effect = "animated fish" },
	{ id = "Waterfall", name = "Waterfall", cost = 25000, category = "Water", description = "Cascading waterfall", size = Vector3.new(10, 15, 5), effect = "water + sound" },
	
	-- Trophies
	{ id = "FishMount", name = "Fish Mount", cost = 5000, category = "Trophy", description = "Mounted rare fish", size = Vector3.new(4, 3, 1), customizable = { fish = true } },
	{ id = "GuardianSkull", name = "Guardian Skull", cost = 20000, category = "Trophy", description = "Defeated guardian skull", size = Vector3.new(5, 5, 4) },
	{ id = "AchievementPlaque", name = "Achievement Plaque", cost = 2000, category = "Trophy", description = "Custom text plaque", size = Vector3.new(4, 3, 0.5), customizable = { text = true } },
	
	-- Special
	{ id = "PortalStone", name = "Portal Stone", cost = 50000, category = "Special", description = "Teleport to town", size = Vector3.new(3, 6, 3), functional = true },
	{ id = "MusicBox", name = "Music Box", cost = 8000, category = "Special", description = "Play ambient music", size = Vector3.new(2, 2, 2), functional = true, customizable = { track = true } },
	{ id = "TimeOrb", name = "Time Orb", cost = 100000, category = "Special", description = "Shows game day/night cycle", size = Vector3.new(3, 3, 3), effect = "particles" },
}

-- EQUIPMENT DISPLAY OPTIONS (how equipment is shown in base)
BaseBuilder.EquipmentDisplays = {
	{ id = "WallMount", name = "Wall Mount", cost = 500, description = "Mount equipment on wall", style = "wall" },
	{ id = "Pedestal", name = "Display Pedestal", cost = 800, description = "Floating equipment pedestal", style = "pedestal", effect = "glow" },
	{ id = "GlassCase", name = "Glass Case", cost = 1500, description = "Premium glass display case", style = "case", effect = "spotlight" },
	{ id = "Mannequin", name = "Mannequin", cost = 5000, description = "Full loadout display on character model", style = "mannequin", slots = 6 },
	{ id = "FloatingOrb", name = "Floating Orb", cost = 10000, description = "Equipment floats in glowing orb", style = "orb", effect = "particles + rotation" },
}

-- FLOOR TYPES (change base flooring)
BaseBuilder.Floors = {
	{ id = "WoodPlank", name = "Wood Planks", cost = 0, description = "Default wooden floor", material = "Wood" },
	{ id = "Stone", name = "Stone Tiles", cost = 2000, description = "Polished stone", material = "Slate" },
	{ id = "Marble", name = "Marble", cost = 8000, description = "Elegant marble", material = "Marble" },
	{ id = "Grass", name = "Grass", cost = 3000, description = "Natural grass", material = "Grass" },
	{ id = "Sand", name = "Beach Sand", cost = 2500, description = "Sandy beach floor", material = "Sand" },
	{ id = "WaterShallow", name = "Shallow Water", cost = 15000, description = "Walkable water floor", material = "Glass", effect = "water ripples" },
	{ id = "Crystal", name = "Crystal Floor", cost = 50000, description = "Glowing crystal", material = "Neon", effect = "glow" },
}

-- WALL TYPES (change base walls)
BaseBuilder.Walls = {
	{ id = "Wood", name = "Wooden Walls", cost = 0, description = "Default wood", material = "Wood" },
	{ id = "StoneWall", name = "Stone Walls", cost = 3000, description = "Solid stone", material = "Cobblestone" },
	{ id = "GlassWall", name = "Glass Walls", cost = 10000, description = "Transparent glass", material = "Glass", transparency = 0.3 },
	{ id = "BambooWall", name = "Bamboo Walls", cost = 5000, description = "Tropical bamboo", material = "Wood" },
	{ id = "MetalWall", name = "Metal Walls", cost = 12000, description = "Industrial metal", material = "Metal" },
	{ id = "MysticWall", name = "Mystic Walls", cost = 25000, description = "Glowing runes", material = "Neon", effect = "runes" },
}

-- CEILING TYPES
BaseBuilder.Ceilings = {
	{ id = "Wooden", name = "Wooden Ceiling", cost = 0, description = "Default wood beams", material = "Wood" },
	{ id = "GlassDome", name = "Glass Dome", cost = 20000, description = "See the sky", material = "Glass", transparency = 0.2, skyVisible = true },
	{ id = "Starlight", name = "Starlight Ceiling", cost = 50000, description = "Animated stars", material = "SmoothPlastic", effect = "stars" },
	{ id = "OpenAir", name = "Open Air", cost = 15000, description = "No ceiling", material = nil, skyVisible = true },
}

-- BASE LAYOUTS (pre-designed floor plans)
BaseBuilder.Layouts = {
	{ id = "Compact", name = "Compact Layout", cost = 0, description = "Small efficient base", plotSize = Vector3.new(40, 15, 40), rooms = { "NestHall" } },
	{ id = "Standard", name = "Standard Layout", cost = 10000, description = "Medium balanced base", plotSize = Vector3.new(60, 15, 60), rooms = { "NestHall", "EquipmentVault" } },
	{ id = "Mansion", name = "Mansion Layout", cost = 50000, description = "Large multi-room base", plotSize = Vector3.new(100, 20, 100), rooms = { "NestHall", "EquipmentVault", "AquariumHall", "TrophyRoom" } },
	{ id = "Estate", name = "Estate Layout", cost = 200000, description = "Massive estate with garden", plotSize = Vector3.new(150, 25, 150), rooms = { "NestHall", "EquipmentVault", "AquariumHall", "TrophyRoom", "Workshop", "Garden", "Library" } },
}

return BaseBuilder