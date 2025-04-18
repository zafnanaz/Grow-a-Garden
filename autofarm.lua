--[[
@author depso (depthso)
@description Grow a Garden auto-farm script
https://www.roblox.com/games/126884695634066
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Leaderstats = LocalPlayer.leaderstats
local Backpack = LocalPlayer.Backpack
local ShecklesCount = Leaderstats.Sheckles
local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

-- --// Simple path
-- local SimplePath = loadstring(game:HttpGet('https://raw.githubusercontent.com/grayzcale/simplepath/refs/heads/main/src/SimplePath.lua'))()
-- local PathSettings = {
-- 	TIME_VARIANCE = 0,
-- 	JUMP_WHEN_STUCK = false,
-- 	COMPARISON_CHECKS = 1
-- }

--// ReGui
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId

--// Folders
local GameEvents = ReplicatedStorage.GameEvents
local Farms = workspace.Farm

local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(43, 33, 13),
}

--// ReGui configuration (Ui library)
ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})
ReGui:DefineTheme("GardenTheme", {
	WindowBg = Accent.Brown,
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.DarkGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
	CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.Green,
    SliderGrab = Accent.Green,
})

--// Globals
local SelectedSeed, AutoHarvest, SellThreshold

local function CreateWindow()
	local Window = ReGui:Window({
		Title = `{GameInfo.Name} | Depso`,
        Theme = "GardenTheme",
		Size = UDim2.fromOffset(300, 200)
	})
	return Window
end

--// Interface functions
local function Plant(Position: Vector3, Seed: string)
	GameEvents.Plant_RE:FireServer(Position, Seed)
	wait(.3)
end

local function GetFarms()
	return Farms:GetChildren()
end

local function GetFarmOwner(Farm: Folder): string
	local Important = Farm.Important
	local Data = Important.Data
	local Owner = Data.Owner

	return Owner.Value
end

local function GetFarm(PlayerName: string): Folder?
	local Farms = GetFarms()
	for _, Farm in next, Farms do
		local Owner = GetFarmOwner(Farm)
		if Owner == PlayerName then
			return Farm
		end
	end
end

local IsSelling = false
local function SellInventory()
	local Character = LocalPlayer.Character
	local Previous = Character:GetPivot()
	local PreviousSheckles = ShecklesCount.Value

	--// Prevent conflict
	if IsSelling then return end
	IsSelling = true

	Character:PivotTo(CFrame.new(62, 4, -26))
	while wait() do
		if ShecklesCount.Value ~= PreviousSheckles then break end
		GameEvents.Sell_Inventory:FireServer()
	end
	Character:PivotTo(Previous)

	wait(0.2)
	IsSelling = false
end

local function BuySeed(Seed: string)
	GameEvents.BuySeedStock:FireServer(Seed)
end

local function GetSeedInfo(Seed: Tool): number?
	local PlantName = Seed:FindFirstChild("Plant_Name")
	local Count = Seed:FindFirstChild("Numbers")
	if not PlantName then return end

	return PlantName.Value, Count.Value
end

local function CollectSeedsFromParent(Parent, Seeds: table)
	for _, Tool in next, Parent:GetChildren() do
		local Name, Count = GetSeedInfo(Tool)
		if not Name then continue end

		Seeds[Name] = {
            Count = Count,
            Tool = Tool
        }
	end
end

local function CollectCropsFromParent(Parent, Crops: table)
	for _, Tool in next, Parent:GetChildren() do
		local Name = Tool:FindFirstChild("Item_String")
		if not Name then continue end

		table.insert(Crops, Tool)
	end
end

local function GetOwnedSeeds(): table
	local Character = LocalPlayer.Character
	
	local Seeds = {}
	CollectSeedsFromParent(Backpack, Seeds)
	CollectSeedsFromParent(Character, Seeds)

	return Seeds
end

local function GetInvCrops(): table
	local Character = LocalPlayer.Character
	
	local Crops = {}
	CollectCropsFromParent(Backpack, Crops)
	CollectCropsFromParent(Character, Crops)

	return Crops
end

local function GetSeedCount(SeedName: string): number
	local Seeds = GetOwnedSeeds()
	return Seeds[Name]
end

local function GetArea(Base: BasePart)
	local Center = Base:GetPivot()
	local Size = Base.Size

	--// Bottom left
	local X1 = math.ceil(Center.X - (Size.X/2))
	local Z1 = math.ceil(Center.Z - (Size.Z/2))

	--// Top right
	local X2 = math.floor(Center.X + (Size.X/2))
	local Z2 = math.floor(Center.Z + (Size.Z/2))

	return X1, Z1, X2, Z2
end

local function EquipCheck(Tool)
    local Character = LocalPlayer.Character
    local Humanoid = Character.Humanoid

    if Tool.Parent ~= Backpack then return end
    Humanoid:EquipTool(Tool)
end

--// Auto farm functions
local MyFarm = GetFarm(LocalPlayer.Name)
local MyImportant = MyFarm.Important
local PlantLocations = MyImportant.Plant_Locations
local PlantsPhysical = MyImportant.Plants_Physical

local Dirt = PlantLocations:GetChildren()[1]
local X1, Z1, X2, Z2 = GetArea(Dirt)
--print("Area:", X2-X1, Z2-Z1)

local function AutoPlant()
	local Seed = SelectedSeed.Selected
	local SeedData = SelectedSeed.Value
    local Count = SeedData.Count
    local Tool = SeedData.Tool

    local Planted = 0
	local Step = 1

    EquipCheck(Tool)
	
	for X = X1, X2, Step do
		for Z = Z1, Z2, Step do
			if Planted > Count then break end
            
			Planted += 1
			Plant(Vector3.new(X, 0.13, Z), Seed)
		end
	end
end

local function HarvestPlant(Plant: Model)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if not Prompt then return end
	fireproximityprompt(Prompt)
end

local function GetSeedStock(AllowNoStock: boolean): table
	local SeedStock = {}

	local PlayerGui = LocalPlayer.PlayerGui
	local SeedShop = PlayerGui.Seed_Shop
	local Items = SeedShop:FindFirstChild("Item_Size", true).Parent
	
	for _, Item in next, Items:GetChildren() do
		local MainFrame = Item:FindFirstChild("Main_Frame")
		if not MainFrame then continue end

		local StockText = MainFrame.Stock_Text.Text
		local StockCount = tonumber(StockText:match("%d+"))

		if not AllowNoStock and StockCount <= 0 then continue end

		SeedStock[Item.Name] = StockCount
	end

	return SeedStock
end

local function CanHarvest(Plant): boolean?
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if not Prompt then return end
    if not Prompt.Enabled then return end

    return true
end

local function CollectHarvestable(Parent, Plants)
    for _, Plant in next, Parent:GetChildren() do
        --// Fruits
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			CollectHarvestable(Fruits, Plants)
		end

        --// Collect
        if CanHarvest(Plant) then
            table.insert(Plants, Plant)
        end
	end
    return Plants
end

local function GetHarvestablePlants()
    local Plants = {}
    CollectHarvestable(PlantsPhysical, Plants)
    return Plants
end

local function HarvestPlants(Parent: Model)
	local Plants = GetHarvestablePlants()
    for _, Plant in next, Plants do
        HarvestPlant(Plant)
    end
end

local function AutoHarvestLoop()
	if not AutoHarvest.Value then return end

	HarvestPlants(PlantsPhysical)
end

local function AutoSellCheck()
    local CropCount = #GetInvCrops()

    if not AutoSell.Value then return end
    if CropCount < SellThreshold.Value then return end

    SellInventory()
end

-- local function PathfindPoint(TargetCFrame: CFrame)
--     local Character = LocalPlayer.Character

--     --// Create part for pathfinding
--     local Part = Instance.new("Part", workspace)
--     Part.Anchored = true
--     Part.CanCollide = false
--     Part:PivotTo(TargetCFrame)

--     --// Create path interface
--     local Path = SimplePath.new(Character, nil, PathSettings)
--     Path.Visualize = true

-- 	local function Run()
-- 		Path:Run(Part)
-- 	end

-- 	local function ClearUp()
-- 		Part:Destroy()
-- 		local Events = Path._events
-- 		if Events then
-- 			Events.Reached:Fire()
-- 			Path:Destroy()
-- 		end
-- 	end

--     local function Error(ErrorType)
--         Character:PivotTo(TargetCFrame)
-- 		ClearUp()
--     end
    
--     --// Connections
--     Path.Error:Connect(Error)
-- 	Path.Blocked:Connect(Run)
-- 	Path.WaypointReached:Connect(Run)
    
--     --// Run path
--     Run()
--     Path.Reached:Wait()

--    	ClearUp()
-- end

local function GetRandomFarmPoint(): Vector3
    local FarmLands = PlantLocations:GetChildren()
    local FarmLand = FarmLands[math.random(1, #FarmLands)]

    local X1, Z1, X2, Z2 = GetArea(FarmLand)
    local X = math.random(X1, X2)
    local Z = math.random(Z1, Z2)

    return Vector3.new(X, 4, Z)
end

local function AutoWalkLoop()
    if not AutoWalk.Value then return end
	if IsSelling then return end

    local Character = LocalPlayer.Character
    local Humanoid = Character.Humanoid

    local Plants = GetHarvestablePlants()
    local DoRandom = math.random(1, 3) == 2

    --// Random point
    if #Plants == 0 or DoRandom then
        local Position = GetRandomFarmPoint()
        Humanoid:MoveTo(Position)
		AutoWalkStatus.Text = "Random point"
        return
    end
   
    --// Move to each plant
    for _, Plant in next, Plants do
        local Position = Plant:GetPivot().Position
        Humanoid:MoveTo(Position)
		AutoWalkStatus.Text = Plant.Name
    end
end

local function AutoHarvestService()
	coroutine.wrap(function()
		while true do
			AutoHarvestLoop()
			wait(1)
		end
	end)()
end

local function AutoWalkService()
    coroutine.wrap(function()
		while true do
			AutoWalkLoop()
			wait(math.random(1, 10))
		end
	end)()
end

--// Window
local Window = CreateWindow()

--// Auto-Plant
local PlantNode = Window:TreeNode({Title="Auto-Plant 🥕"})
SelectedSeed = PlantNode:Combo({
	Label = "Seed",
	Selected = "",
	GetItems = GetOwnedSeeds,
})
PlantNode:Button({
	Text = "Auto plant",
	Callback = AutoPlant,
})

--// Auto-Harvest
local HarvestNode = Window:TreeNode({Title="Auto-Harvest 🚜"})
AutoHarvest = HarvestNode:Checkbox({
	Value = false,
	Label = "Enabled"
})

--// Auto-Buy
local BuyNode = Window:TreeNode({Title="Auto-Buy 🥕"})
SelectedSeedStock = BuyNode:Combo({
	Label = "Seed",
	Selected = "",
	GetItems = GetSeedStock,
})
BuyNode:Button({
	Text = "Buy all",
	Callback = function()
		local Seed = SelectedSeedStock.Selected
		local Stock = SelectedSeedStock.Value
		for i = 1, Stock do
			BuySeed(Seed)
		end
	end,
})

--// Auto-Sell
local SellNode = Window:TreeNode({Title="Auto-Sell 💰"})
SellNode:Button({
	Text = "Sell inventory",
	Callback = SellInventory, 
})
AutoSell = SellNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
SellThreshold = SellNode:SliderInt({
    Label = "Crops threshold",
    Value = 15,
    Minimum = 1,
    Maximum = 199,
})

--// Auto-Walk
local WallNode = Window:TreeNode({Title="Auto-Walk 🚶"})
AutoWalkStatus = WallNode:Label({
	Text = "None"
})
AutoWalk = WallNode:Checkbox({
	Value = false,
	Label = "Enabled"
})

AutoHarvestService()
AutoWalkService()
Backpack.ChildAdded:Connect(AutoSellCheck)
