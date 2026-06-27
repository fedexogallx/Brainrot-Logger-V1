local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local GUI_NAME = "BrainrotLogger"
local BAR_HEIGHT = 44
local MAX_LOGS_PER_CATEGORY = 100
local MAX_POPUPS = 5
local REFRESH_RATE = 0.2

local PRESETS = {
	Big = Vector2.new(1600, 950),
	Medium = Vector2.new(1320, 820),
	Baby = Vector2.new(1024, 650),
	Lil = Vector2.new(860, 560),
}

local DEFAULT_PRESET = "Baby"

local expandedSize =
	PRESETS[DEFAULT_PRESET]
	or PRESETS.Baby
	or Vector2.new(1024, 650)
local MIN_WINDOW_SIZE = PRESETS.Lil
local MAX_WINDOW_SIZE = PRESETS.Big

local RARITY_ORDER = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythical",
	"Cosmic",
	"Secret",
	"Celestial",
	"Divine",
	"Infinity",
}

local RARITY_COLORS: {[string]: Color3} = {
	Common = Color3.fromRGB(140, 140, 140),
	Uncommon = Color3.fromRGB(0, 150, 70),
	Rare = Color3.fromRGB(0, 110, 255),
	Epic = Color3.fromRGB(115, 0, 180),
	Legendary = Color3.fromRGB(255, 145, 0),
	Mythical = Color3.fromRGB(190, 0, 255),
	Cosmic = Color3.fromRGB(70, 0, 120),
	Secret = Color3.fromRGB(255, 35, 35),
	Celestial = Color3.fromRGB(255, 70, 180),
	Divine = Color3.fromRGB(255, 230, 0),
	Infinity = Color3.fromRGB(255, 255, 255),
}

local RARITY_ICONS: {[string]: string} = {
	Common = "●",
	Uncommon = "●",
	Rare = "●",
	Epic = "●",
	Legendary = "●",
	Mythical = "●",
	Cosmic = "●",
	Secret = "●",
	Celestial = "●",
	Divine = "●",
	Infinity = "∞",
}

local rootFolder = workspace:WaitForChild("ActiveBrainrots")

local function fmtValue(v: any): string
	if v == nil then
		return "Unknown"
	end
	local s = tostring(v)
	if s == "" then
		return "Unknown"
	end
	return s
end

local function escapeRichText(text: any): string
	local s = tostring(text or "")
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function lowerNoSpace(text: any): string
	return tostring(text or ""):lower():gsub("%s+", "")
end

local function isTextCarrier(inst: Instance): boolean
	return inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")
end

local function readNodeValue(inst: Instance?): any
	if not inst then
		return nil
	end

	if inst:IsA("ValueBase") then
		return (inst :: any).Value
	end

	if isTextCarrier(inst) then
		return (inst :: any).Text
	end

	if inst:IsA("ObjectValue") then
		local ov = inst :: ObjectValue
		return ov.Value and ov.Value.Name or nil
	end

	return nil
end

local function getAttributeInsensitive(inst: Instance, wantedNames: {string}): any
	local attrs = inst:GetAttributes()
	for _, wanted in ipairs(wantedNames) do
		local target = lowerNoSpace(wanted)
		for key, value in pairs(attrs) do
			if lowerNoSpace(key) == target then
				return value
			end
		end
	end
	return nil
end

local function findDescendantByNames(inst: Instance, wantedNames: {string}): Instance?
	local targetSet: {[string]: boolean} = {}
	for _, wanted in ipairs(wantedNames) do
		targetSet[lowerNoSpace(wanted)] = true
	end

	for _, obj in ipairs(inst:GetDescendants()) do
		if targetSet[lowerNoSpace(obj.Name)] then
			return obj
		end
	end

	for _, obj in ipairs(inst:GetChildren()) do
		if targetSet[lowerNoSpace(obj.Name)] then
			return obj
		end
	end

	return nil
end

local function readNamedValue(inst: Instance, wantedNames: {string}): (any, Instance?)
	local attr = getAttributeInsensitive(inst, wantedNames)
	if attr ~= nil then
		return attr, nil
	end

	local node = findDescendantByNames(inst, wantedNames)
	if node then
		return readNodeValue(node), node
	end

	return nil, nil
end

local function readTimerGuiTimeLeft(source: Instance): string?
	local root = source:FindFirstChild("Root")
	if not root then
		return nil
	end

	local timerGui = root:FindFirstChild("TimerGui")
	if not timerGui then
		return nil
	end

	local timeLeftContainer = timerGui:FindFirstChild("TimeLeft")
	if not timeLeftContainer then
		return nil
	end

	local label = timeLeftContainer:FindFirstChild("TimeLeft")
	if label and label:IsA("TextLabel") then
		local text = label.Text
		if text ~= nil and text ~= "" then
			return text
		end
	end

	for _, obj in ipairs(timeLeftContainer:GetDescendants()) do
		if obj:IsA("TextLabel") and lowerNoSpace(obj.Name) == "timeleft" then
			local text = obj.Text
			if text ~= nil and text ~= "" then
				return text
			end
		end
	end

	return nil
end

local function getLiveTimeLeft(source: Instance): any
	local timerText = readTimerGuiTimeLeft(source)
	if timerText ~= nil then
		return timerText
	end

	return readNamedValue(source, {"TimeLeft", "Time Left", "Countdown", "Timer", "TimeRemaining"})
end


local function getLiveBrainrotPosition(source: Instance): string?
	local function formatPos(v: Vector3): string
		return string.format("%.0f, %.0f, %.0f", v.X, v.Y, v.Z)
	end

	if source:IsA("BasePart") then
		return formatPos(source.Position)
	end

	if source:IsA("Model") then
		local ok, pivot = pcall(function()
			return source:GetPivot()
		end)
		if ok and typeof(pivot) == "CFrame" then
			return formatPos(pivot.Position)
		end
	end

	local directRoot = source:FindFirstChild("Root")
	if directRoot then
		if directRoot:IsA("BasePart") then
			return formatPos(directRoot.Position)
		end
		if directRoot:IsA("Model") then
			local ok, pivot = pcall(function()
				return directRoot:GetPivot()
			end)
			if ok and typeof(pivot) == "CFrame" then
				return formatPos(pivot.Position)
			end
		end
	end

	local commonNames = {"HumanoidRootPart", "PrimaryPart", "Body", "Torso"}
	for _, wanted in ipairs(commonNames) do
		local node = source:FindFirstChild(wanted, true)
		if node and node:IsA("BasePart") then
			return formatPos(node.Position)
		end
	end

	return nil
end

local function parseTimeLeftToSeconds(value: any): number?
	if value == nil then
		return nil
	end

	if typeof(value) == "number" then
		return math.max(0, math.floor(value))
	end

	local s = tostring(value):lower():gsub("%s+", "")
	if s == "" then
		return nil
	end

	if s == "inf" or s == "infinite" or s == "infinity" then
		return nil
	end

	do
		local h, m, sec = s:match("^(%d+):(%d+):(%d+)$")
		if h then
			return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
		end
	end

	do
		local m, sec = s:match("^(%d+):(%d+)$")
		if m then
			return tonumber(m) * 60 + tonumber(sec)
		end
	end

	do
		local sec = s:match("^(%d+)s$")
		if sec then
			return tonumber(sec)
		end
	end

	do
		local sec = s:match("^(%d+)$")
		if sec then
			return tonumber(sec)
		end
	end

	return nil
end

local function formatSeconds(seconds: number?): string
	if not seconds then
		return "Unknown"
	end

	seconds = math.max(0, math.ceil(seconds))
	return string.format("%ds", seconds)
end

local function formatElapsed(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return string.format("Hace %ds", seconds)
	end
	if seconds < 3600 then
		return string.format("Hace %dm %ds", math.floor(seconds / 60), seconds % 60)
	end
	return string.format("Hace %dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
end

local function makeRoundedCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function makeStroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function makeFillBorder(parent: Instance, size: UDim2, pos: UDim2?, borderColor: Color3, borderSize: number, radius: number, bgColor: Color3)
	local outer = Instance.new("Frame")
	outer.Name = "Border"
	outer.BackgroundColor3 = borderColor
	outer.BorderSizePixel = 0
	outer.Size = size
	outer.Position = pos or UDim2.new()
	outer.ClipsDescendants = true
	outer.Parent = parent
	makeRoundedCorner(outer, radius)

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundColor3 = bgColor
	inner.BorderSizePixel = 0
	inner.Position = UDim2.fromOffset(borderSize, borderSize)
	inner.Size = UDim2.new(1, -borderSize * 2, 1, -borderSize * 2)
	inner.ClipsDescendants = true
	inner.Parent = outer
	makeRoundedCorner(inner, math.max(0, radius - borderSize))

	return outer, inner
end

local function makeLabel(parent: Instance, props: {[string]: any})
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = props.Font or Enum.Font.Gotham
	label.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	label.TextSize = props.TextSize or 14
	label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	label.RichText = props.RichText or false
	label.TextWrapped = props.TextWrapped or false
	label.TextTruncate = props.TextTruncate or Enum.TextTruncate.None
	label.Text = props.Text or ""
	label.Size = props.Size or UDim2.new(1, 0, 0, 20)
	label.Position = props.Position or UDim2.new()
	label.AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, props: {[string]: any})
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(15, 15, 20)
	button.BorderSizePixel = 0
	button.Font = props.Font or Enum.Font.GothamSemibold
	button.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	button.TextSize = props.TextSize or 14
	button.TextWrapped = props.TextWrapped or false
	button.Text = props.Text or ""
	button.Size = props.Size or UDim2.new(0, 140, 0, 38)
	button.Position = props.Position or UDim2.new()
	button.Parent = parent
	return button
end

local function tryDestroyExisting()
	local existing = PlayerGui:FindFirstChild(GUI_NAME)
	if existing then
		existing:Destroy()
	end
end

local function animateRainbowStroke(stroke: UIStroke)
	task.spawn(function()
		while stroke.Parent do
			local hue = (tick() * 0.12) % 1
			stroke.Color = Color3.fromHSV(hue, 1, 1)
			task.wait(0.03)
		end
	end)
end

tryDestroyExisting()

local DEFAULT_ENABLED: {[string]: boolean} = {
	Common = false,
	Uncommon = false,
	Rare = false,
	Epic = false,
	Legendary = false,
	Mythical = false,
	Cosmic = false,
	Secret = false,
	Celestial = true,
	Divine = true,
	Infinity = true,
}

local Settings: {[string]: boolean} = {}
for _, rarity in ipairs(RARITY_ORDER) do
	Settings[rarity] = DEFAULT_ENABLED[rarity] == true
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local NotificationStack = Instance.new("Frame")
NotificationStack.Name = "NotificationStack"
NotificationStack.AnchorPoint = Vector2.new(1, 1)
NotificationStack.Position = UDim2.new(1, -18, 1, -18)
NotificationStack.Size = UDim2.new(0, 380, 0, 520)
NotificationStack.BackgroundTransparency = 1
NotificationStack.BorderSizePixel = 0
NotificationStack.Parent = ScreenGui

local NotificationLayout = Instance.new("UIListLayout")
NotificationLayout.Padding = UDim.new(0, 8)
NotificationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotificationLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotificationLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotificationLayout.Parent = NotificationStack

local MainBorder, Main = makeFillBorder(
	ScreenGui,
	UDim2.fromOffset(expandedSize.X, expandedSize.Y),
	UDim2.new(0.5, 0, 0.5, 0),
	Color3.fromRGB(60, 55, 85),
	2,
	16,
	Color3.fromRGB(10, 10, 14)
)
MainBorder.AnchorPoint = Vector2.new(0.5, 0.5)

local WindowBar = Instance.new("Frame")
WindowBar.Name = "WindowBar"
WindowBar.BackgroundColor3 = Color3.fromRGB(11, 11, 16)
WindowBar.BorderSizePixel = 0
WindowBar.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
WindowBar.Position = UDim2.new(0, 0, 0, 0)
WindowBar.Active = true
WindowBar.Parent = Main
makeRoundedCorner(WindowBar, 14)
makeStroke(WindowBar, Color3.fromRGB(45, 45, 60), 1)

local WindowBarFill = Instance.new("Frame")
WindowBarFill.Name = "Fill"
WindowBarFill.BackgroundColor3 = Color3.fromRGB(11, 11, 16)
WindowBarFill.BorderSizePixel = 0
WindowBarFill.Size = UDim2.new(1, 0, 1, 0)
WindowBarFill.Parent = WindowBar
makeRoundedCorner(WindowBarFill, 14)

local WindowBarPadding = Instance.new("UIPadding")
WindowBarPadding.PaddingLeft = UDim.new(0, 12)
WindowBarPadding.PaddingRight = UDim.new(0, 12)
WindowBarPadding.PaddingTop = UDim.new(0, 6)
WindowBarPadding.PaddingBottom = UDim.new(0, 6)
WindowBarPadding.Parent = WindowBarFill

local TitleIcon = makeLabel(WindowBarFill, {
	Text = "◫",
	Font = Enum.Font.GothamBold,
	TextSize = 30,
	TextColor3 = Color3.fromRGB(220, 150, 255),
	Size = UDim2.new(0, 32, 1, 0),
})

local Title = makeLabel(WindowBarFill, {
	Text = "BRAINROT LOGGER",
	Font = Enum.Font.GothamBold,
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	Position = UDim2.new(0, 36, 0, 0),
	Size = UDim2.new(0, 200, 1, 0),
})

local PresetHolder = Instance.new("Frame")
PresetHolder.Name = "PresetHolder"
PresetHolder.BackgroundTransparency = 1
PresetHolder.Size = UDim2.new(0, 250, 0, 30)
PresetHolder.Position = UDim2.new(0, 236, 0.5, -15)
PresetHolder.Parent = WindowBarFill

local PresetLayout = Instance.new("UIListLayout")
PresetLayout.FillDirection = Enum.FillDirection.Horizontal
PresetLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
PresetLayout.VerticalAlignment = Enum.VerticalAlignment.Center
PresetLayout.SortOrder = Enum.SortOrder.LayoutOrder
PresetLayout.Padding = UDim.new(0, 6)
PresetLayout.Parent = PresetHolder

local ControlHolder = Instance.new("Frame")
ControlHolder.Name = "ControlHolder"
ControlHolder.BackgroundTransparency = 1
ControlHolder.AnchorPoint = Vector2.new(1, 0.5)
ControlHolder.Size = UDim2.new(0, 242, 0, 30)
ControlHolder.Position = UDim2.new(1, 0, 0.5, 0)
ControlHolder.Parent = WindowBarFill

local ControlLayout = Instance.new("UIListLayout")
ControlLayout.FillDirection = Enum.FillDirection.Horizontal
ControlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ControlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ControlLayout.SortOrder = Enum.SortOrder.LayoutOrder
ControlLayout.Padding = UDim.new(0, 6)
ControlLayout.Parent = ControlHolder

local ResolutionBox = Instance.new("TextBox")
ResolutionBox.Name = "ResolutionBox"
ResolutionBox.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
ResolutionBox.BorderSizePixel = 0
ResolutionBox.TextColor3 = Color3.new(1, 1, 1)
ResolutionBox.Font = Enum.Font.GothamSemibold
ResolutionBox.TextSize = 14
ResolutionBox.TextXAlignment = Enum.TextXAlignment.Center
ResolutionBox.TextYAlignment = Enum.TextYAlignment.Center
ResolutionBox.ClearTextOnFocus = false
ResolutionBox.PlaceholderText = "Resolution"
ResolutionBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 160)
ResolutionBox.Size = UDim2.new(0, 132, 0, 30)
ResolutionBox.Text = string.format("%dx%d", expandedSize.X, expandedSize.Y)
ResolutionBox.Parent = ControlHolder
makeRoundedCorner(ResolutionBox, 10)
makeStroke(ResolutionBox, Color3.fromRGB(70, 70, 80), 1)

local MinButton = makeButton(ControlHolder, {
	Text = "—",
	Size = UDim2.new(0, 48, 0, 30),
	BackgroundColor3 = Color3.fromRGB(20, 20, 25),
})
makeRoundedCorner(MinButton, 10)
makeStroke(MinButton, Color3.fromRGB(70, 70, 80), 1)

local CloseButton = makeButton(ControlHolder, {
	Text = "X",
	Size = UDim2.new(0, 48, 0, 30),
	BackgroundColor3 = Color3.fromRGB(20, 20, 25),
})
makeRoundedCorner(CloseButton, 10)
makeStroke(CloseButton, Color3.fromRGB(70, 70, 80), 1)

local PresetButtons: {[string]: TextButton} = {}

local function stylePresetButton(button: TextButton, active: boolean, color: Color3)
	button.BackgroundColor3 = active and Color3.fromRGB(22, 22, 30) or Color3.fromRGB(14, 14, 18)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = active and 0 or 0.2
		stroke.Thickness = active and 3 or 2
		stroke.Color = color
	end
end

local function updatePresetButtons()
	for name, button in pairs(PresetButtons) do
		local active = (name == CurrentPreset)
		local color = active and Color3.fromRGB(220, 220, 255) or Color3.fromRGB(80, 80, 95)
		stylePresetButton(button, active, color)
	end
end

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.BackgroundTransparency = 1
ContentFrame.Position = UDim2.new(0, 0, 0, BAR_HEIGHT + 8)
ContentFrame.Size = UDim2.new(1, 0, 1, -(BAR_HEIGHT + 12))
ContentFrame.Parent = Main

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingLeft = UDim.new(0, 12)
ContentPadding.PaddingRight = UDim.new(0, 12)
ContentPadding.PaddingTop = UDim.new(0, 0)
ContentPadding.PaddingBottom = UDim.new(0, 12)
ContentPadding.Parent = ContentFrame

local TabPanel = Instance.new("Frame")
TabPanel.Name = "TabPanel"
TabPanel.BackgroundColor3 = Color3.fromRGB(11, 11, 16)
TabPanel.BorderSizePixel = 0
TabPanel.Position = UDim2.new(0, 0, 0, 0)
TabPanel.Size = UDim2.new(1, 0, 0, 132)
TabPanel.Parent = ContentFrame
makeRoundedCorner(TabPanel, 14)
makeStroke(TabPanel, Color3.fromRGB(45, 45, 60), 1)

local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingTop = UDim.new(0, 12)
TabPadding.PaddingBottom = UDim.new(0, 12)
TabPadding.PaddingLeft = UDim.new(0, 12)
TabPadding.PaddingRight = UDim.new(0, 12)
TabPadding.Parent = TabPanel

local TabGrid = Instance.new("ScrollingFrame")
TabGrid.Name = "TabGrid"
TabGrid.BackgroundTransparency = 1
TabGrid.BorderSizePixel = 0
TabGrid.Size = UDim2.new(1, 0, 1, 0)
TabGrid.Active = true
TabGrid.ScrollingEnabled = true
TabGrid.ScrollingDirection = Enum.ScrollingDirection.Y
TabGrid.ScrollBarThickness = 6
TabGrid.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95)
TabGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabGrid.CanvasSize = UDim2.new(0, 0, 0, 0)
TabGrid.Parent = TabPanel

local TabLayout = Instance.new("UIGridLayout")
TabLayout.CellSize = UDim2.new(0, 176, 0, 42)
TabLayout.CellPadding = UDim2.new(0, 12, 0, 14)
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.FillDirectionMaxCells = 5
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Top
TabLayout.Parent = TabGrid

TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	TabGrid.CanvasSize = UDim2.fromOffset(0, TabLayout.AbsoluteContentSize.Y + 20)
end)

local PageHost = Instance.new("Frame")
PageHost.Name = "PageHost"
PageHost.BackgroundTransparency = 1
PageHost.Position = UDim2.new(0, 0, 0, 144)
PageHost.Size = UDim2.new(1, 0, 1, -156)
PageHost.Parent = ContentFrame

local Pages: {[string]: any} = {}
local TabButtons: {[string]: TextButton} = {}
local ActiveEntries: {[Instance]: any} = {}
local PopupFrames: {Frame} = {}
local CurrentPageName = "Infinity"

local minimized = false

local dragActive = false
local dragStart: Vector2? = nil
local dragStartPos: UDim2? = nil

local resizeActive = false
local resizeStart: Vector2? = nil
local resizeStartSize = Vector2.new(1320, 820)
local resizeStartPos: UDim2? = nil

local function syncResolutionBox()
	ResolutionBox.Text = string.format("%dx%d", math.floor(expandedSize.X), math.floor(expandedSize.Y))
end

local function applyWindowSize(size: Vector2)
	size = Vector2.new(
		math.clamp(math.floor(size.X + 0.5), MIN_WINDOW_SIZE.X, MAX_WINDOW_SIZE.X),
		math.clamp(math.floor(size.Y + 0.5), MIN_WINDOW_SIZE.Y, MAX_WINDOW_SIZE.Y)
	)

	expandedSize = size
	syncResolutionBox()

	if not minimized then
		MainBorder.Size = UDim2.fromOffset(size.X, size.Y)
	end
end

local function applyPreset(name: string)
	if PRESETS[name] then
		CurrentPreset = name
		applyWindowSize(PRESETS[name])
		updatePresetButtons()
	end
end

local function setWindowPosition(pos: UDim2)
	MainBorder.Position = pos
end

local function setPageVisible(rarity: string)
	CurrentPageName = rarity
	for name, page in pairs(Pages) do
		page.Frame.Visible = (name == rarity)
	end

	for name, button in pairs(TabButtons) do
		local active = name == rarity
		local borderColor = RARITY_COLORS[name] or Color3.fromRGB(120, 120, 120)

		button.BackgroundColor3 = active and Color3.fromRGB(22, 22, 30) or Color3.fromRGB(14, 14, 18)
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = active and 3 or 2
			stroke.Transparency = active and 0 or 0.15
			if name ~= "Infinity" then
				stroke.Color = borderColor
			end
		end
	end
end

local function makeDetailField(parent: Instance, titleText: string, rowOrder: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 52)
	row.LayoutOrder = rowOrder
	row.Parent = parent

	makeLabel(row, {
		Text = titleText,
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(150, 150, 160),
		Size = UDim2.new(1, 0, 0, 18),
	})

	local valueLabel = makeLabel(row, {
		Text = "Unknown",
		Font = Enum.Font.GothamSemibold,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 24),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	return valueLabel
end

local function createPage(rarity: string)
	local page = Instance.new("Frame")
	page.Name = rarity .. "Page"
	page.BackgroundTransparency = 1
	page.Size = UDim2.new(1, 0, 1, 0)
	page.Visible = false
	page.Parent = PageHost

	local headerBorderColor = RARITY_COLORS[rarity] or Color3.fromRGB(110, 110, 110)
	local headerOuter, header = makeFillBorder(
		page,
		UDim2.new(1, 0, 0, 46),
		nil,
		headerBorderColor,
		2,
		12,
		Color3.fromRGB(12, 12, 16)
	)

	if rarity == "Infinity" then
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 170, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(0, 100, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255)),
		})
		grad.Rotation = 0
		grad.Parent = headerOuter

		task.spawn(function()
			while headerOuter.Parent do
				local tween = TweenService:Create(grad, TweenInfo.new(2.5, Enum.EasingStyle.Linear), {Rotation = grad.Rotation + 180})
				tween:Play()
				tween.Completed:Wait()
			end
		end)
	end

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, 14)
	headerPadding.PaddingRight = UDim.new(0, 14)
	headerPadding.Parent = header

	local rarityIcon = makeLabel(header, {
		Text = RARITY_ICONS[rarity] or "●",
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextColor3 = headerBorderColor,
		Size = UDim2.new(0, 28, 1, 0),
	})

	local rarityTitle = makeLabel(header, {
		Text = string.upper(rarity),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 34, 0, 0),
		Size = UDim2.new(0, 220, 1, 0),
	})

	local enabledButton = makeButton(header, {
		Text = "Enabled",
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		Size = UDim2.new(0, 102, 0, 30),
		Position = UDim2.new(1, -210, 0.5, -15),
	})
	makeRoundedCorner(enabledButton, 10)
	makeStroke(enabledButton, Color3.fromRGB(90, 90, 100), 1)

	local clearButton = makeButton(header, {
		Text = "Clear",
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		Size = UDim2.new(0, 92, 0, 30),
		Position = UDim2.new(1, -102, 0.5, -15),
	})
	makeRoundedCorner(clearButton, 10)
	makeStroke(clearButton, Color3.fromRGB(90, 90, 100), 1)

	local bodyOuter, body = makeFillBorder(
		page,
		UDim2.new(1, 0, 1, -58),
		UDim2.new(0, 0, 0, 58),
		Color3.fromRGB(45, 45, 55),
		2,
		14,
		Color3.fromRGB(11, 11, 15)
	)

	local bodyPadding = Instance.new("UIPadding")
	bodyPadding.PaddingTop = UDim.new(0, 10)
	bodyPadding.PaddingBottom = UDim.new(0, 10)
	bodyPadding.PaddingLeft = UDim.new(0, 10)
	bodyPadding.PaddingRight = UDim.new(0, 10)
	bodyPadding.Parent = body

	local split = Instance.new("Frame")
	split.Name = "Split"
	split.BackgroundTransparency = 1
	split.Size = UDim2.new(1, 0, 1, -24)
	split.Parent = body

	local leftPane = Instance.new("Frame")
	leftPane.Name = "LogPane"
	leftPane.BackgroundTransparency = 1
	leftPane.Size = UDim2.new(0.67, -6, 1, 0)
	leftPane.Parent = split

	local rightPane = Instance.new("ScrollingFrame")
	rightPane.Name = "DetailsPane"
	rightPane.BackgroundTransparency = 1
	rightPane.Position = UDim2.new(0.67, 6, 0, 0)
	rightPane.Size = UDim2.new(0.33, -6, 1, 0)
	rightPane.Active = true
	rightPane.ScrollingEnabled = true
	rightPane.ScrollingDirection = Enum.ScrollingDirection.Y
	rightPane.ScrollBarThickness = 6
	rightPane.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95)
	rightPane.AutomaticCanvasSize = Enum.AutomaticSize.None
	rightPane.CanvasSize = UDim2.new(0, 0, 0, 0)
	rightPane.Parent = split

	local logBorder, logInner = makeFillBorder(
		leftPane,
		UDim2.new(1, 0, 1, 0),
		nil,
		Color3.fromRGB(30, 30, 38),
		2,
		12,
		Color3.fromRGB(9, 9, 13)
	)

	local detailsOuter = Instance.new("Frame")
	detailsOuter.Name = "DetailsOuter"
	detailsOuter.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	detailsOuter.BorderSizePixel = 0
	detailsOuter.Size = UDim2.new(1, 0, 1, 0)
	detailsOuter.Parent = rightPane
	makeRoundedCorner(detailsOuter, 12)
	makeStroke(detailsOuter, Color3.fromRGB(45, 45, 55), 2, 0)

	local detailsInner = Instance.new("Frame")
	detailsInner.Name = "DetailsInner"
	detailsInner.BackgroundColor3 = Color3.fromRGB(9, 9, 13)
	detailsInner.BorderSizePixel = 0
	detailsInner.Position = UDim2.fromOffset(2, 2)
	detailsInner.Size = UDim2.new(1, -4, 0, 0)
	detailsInner.AutomaticSize = Enum.AutomaticSize.Y
	detailsInner.Parent = detailsOuter
	makeRoundedCorner(detailsInner, 10)

	local logPadding = Instance.new("UIPadding")
	logPadding.PaddingTop = UDim.new(0, 10)
	logPadding.PaddingBottom = UDim.new(0, 10)
	logPadding.PaddingLeft = UDim.new(0, 10)
	logPadding.PaddingRight = UDim.new(0, 10)
	logPadding.Parent = logInner

	local detailsPadding = Instance.new("UIPadding")
	detailsPadding.PaddingTop = UDim.new(0, 10)
	detailsPadding.PaddingBottom = UDim.new(0, 10)
	detailsPadding.PaddingLeft = UDim.new(0, 10)
	detailsPadding.PaddingRight = UDim.new(0, 10)
	detailsPadding.Parent = detailsInner

	local logScroll = Instance.new("ScrollingFrame")
	logScroll.Name = "LogScroll"
	logScroll.BackgroundTransparency = 1
	logScroll.BorderSizePixel = 0
	logScroll.Size = UDim2.new(1, 0, 1, 0)
	logScroll.CanvasSize = UDim2.new()
	logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logScroll.ScrollBarThickness = 6
	logScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 95)
	logScroll.Parent = logInner

	local logLayout = Instance.new("UIListLayout")
	logLayout.Padding = UDim.new(0, 8)
	logLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logLayout.Parent = logScroll

	local logScrollPad = Instance.new("UIPadding")
	logScrollPad.PaddingBottom = UDim.new(0, 4)
	logScrollPad.Parent = logScroll

	local detailsTitle = makeLabel(detailsInner, {
		Text = "SELECTED DATA",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = headerBorderColor,
		Size = UDim2.new(1, 0, 0, 24),
	})

	local detailsLine = Instance.new("Frame")
	detailsLine.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	detailsLine.BorderSizePixel = 0
	detailsLine.Position = UDim2.new(0, 0, 0, 28)
	detailsLine.Size = UDim2.new(1, 0, 0, 1)
	detailsLine.Parent = detailsInner

	local detailsFields = Instance.new("Frame")
	detailsFields.Name = "DetailsFields"
	detailsFields.BackgroundTransparency = 1
	detailsFields.BorderSizePixel = 0
	detailsFields.Position = UDim2.new(0, 0, 0, 38)
	detailsFields.Size = UDim2.new(1, 0, 0, 0)
	detailsFields.AutomaticSize = Enum.AutomaticSize.Y
	detailsFields.Parent = detailsInner

	local detailsLayout = Instance.new("UIListLayout")
	detailsLayout.Padding = UDim.new(0, 10)
	detailsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	detailsLayout.Parent = detailsFields

	local detailsScrollPad = Instance.new("UIPadding")
	detailsScrollPad.PaddingBottom = UDim.new(0, 18)
	detailsScrollPad.Parent = detailsFields

	detailsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		rightPane.CanvasSize = UDim2.fromOffset(0, detailsLayout.AbsoluteContentSize.Y + 160)
	end)

	local detailName = makeDetailField(detailsFields, "Name", 1)
	local detailTrait = makeDetailField(detailsFields, "Trait", 2)
	local detailMutation = makeDetailField(detailsFields, "Mutation", 3)
	local detailLevel = makeDetailField(detailsFields, "Level", 4)
	local detailPosition = makeDetailField(detailsFields, "Position", 5)
	local detailRarity = makeDetailField(detailsFields, "Rarity", 6)
	local detailSpawnTime = makeDetailField(detailsFields, "Spawn Time", 7)
	local detailTimeLeft = makeDetailField(detailsFields, "Time Left", 8)
	local detailElapsed = makeDetailField(detailsFields, "Elapsed", 9)

	local footer = makeLabel(body, {
		Text = "Logs per category: " .. tostring(MAX_LOGS_PER_CATEGORY),
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(180, 180, 190),
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
	})

	local pageData = {
		Frame = page,
		Rarity = rarity,
		EnabledButton = enabledButton,
		ClearButton = clearButton,
		LogScroll = logScroll,
		LogLayout = logLayout,
		LogEntries = {},
		SelectedEntry = nil,
		DetailName = detailName,
		DetailTrait = detailTrait,
		DetailMutation = detailMutation,
		DetailLevel = detailLevel,
		DetailPosition = detailPosition,
		DetailRarity = detailRarity,
		DetailSpawnTime = detailSpawnTime,
		DetailTimeLeft = detailTimeLeft,
		DetailElapsed = detailElapsed,
		Footer = footer,
	}

	function pageData:SetEnabled(enabled: boolean)
		Settings[self.Rarity] = enabled
		if enabled then
			self.EnabledButton.Text = "Enabled"
			self.EnabledButton.BackgroundColor3 = Color3.fromRGB(16, 55, 28)
		else
			self.EnabledButton.Text = "Disabled"
			self.EnabledButton.BackgroundColor3 = Color3.fromRGB(70, 18, 18)
		end
	end

	function pageData:ClearLogs()
		for _, entry in ipairs(self.LogEntries) do
			if entry.Row and entry.Row.Parent then
				entry.Row:Destroy()
			end
		end

		self.LogEntries = {}
		self.SelectedEntry = nil

		self.DetailName.Text = "Unknown"
		self.DetailTrait.Text = "Unknown"
		self.DetailMutation.Text = "Unknown"
		self.DetailLevel.Text = "Unknown"
		self.DetailPosition.Text = "Unknown"
		self.DetailRarity.Text = self.Rarity
		self.DetailSpawnTime.Text = "Unknown"
		self.DetailTimeLeft.Text = "Unknown"
		self.DetailElapsed.Text = "Unknown"
		self:UpdateFooter()
	end

	function pageData:UpdateFooter()
		self.Footer.Text = string.format("%d / %d logs", #self.LogEntries, MAX_LOGS_PER_CATEGORY)
	end

	function pageData:SelectEntry(entry: any)
		self.SelectedEntry = entry
		self.DetailName.Text = fmtValue(entry.Name)
		self.DetailTrait.Text = fmtValue(entry.Trait)
		self.DetailMutation.Text = fmtValue(entry.Mutation)
		self.DetailLevel.Text = fmtValue(entry.Level)
		self.DetailPosition.Text = fmtValue(entry.Position)
		self.DetailRarity.Text = fmtValue(entry.Rarity)
		self.DetailSpawnTime.Text = fmtValue(entry.SpawnTime)
		self.DetailTimeLeft.Text = fmtValue(entry.TimeLeftText)
		self.DetailElapsed.Text = fmtValue(entry.ElapsedText)
	end

	pageData:SetEnabled(DEFAULT_ENABLED[rarity] == true)
	pageData:UpdateFooter()

	Pages[rarity] = pageData
	return pageData
end

local function updatePopupText(entry: any)
	if not entry.Popup or not entry.Popup.Frame or not entry.Popup.Frame.Parent then
		return
	end

	entry.Popup.Title.Text = string.upper(entry.Rarity) .. " SPAWNED"
	entry.Popup.Body.Text = table.concat({
		("Name: %s"):format(fmtValue(entry.Name)),
		("Trait: %s"):format(fmtValue(entry.Trait)),
		("Mutation: %s"):format(fmtValue(entry.Mutation)),
		("Level: %s"):format(fmtValue(entry.Level)),
		("Position: %s"):format(fmtValue(entry.Position)),
		("Time Left: %s"):format(fmtValue(entry.TimeLeftText)),
	}, "\n")
end

local function createPopup(entry: any)
	local rarity = entry.Rarity
	local color = RARITY_COLORS[rarity] or Color3.fromRGB(150, 150, 150)

	local outer = Instance.new("Frame")
	outer.Name = "Popup_" .. rarity
	outer.Size = UDim2.new(0, 370, 0, 170)
	outer.BackgroundColor3 = color
	outer.BorderSizePixel = 0
	outer.ClipsDescendants = true
	outer.Parent = NotificationStack
	makeRoundedCorner(outer, 14)

	local inner = Instance.new("Frame")
	inner.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	inner.BorderSizePixel = 0
	inner.Position = UDim2.fromOffset(2, 2)
	inner.Size = UDim2.new(1, -4, 1, -4)
	inner.Parent = outer
	makeRoundedCorner(inner, 12)

	local innerPad = Instance.new("UIPadding")
	innerPad.PaddingTop = UDim.new(0, 10)
	innerPad.PaddingBottom = UDim.new(0, 10)
	innerPad.PaddingLeft = UDim.new(0, 12)
	innerPad.PaddingRight = UDim.new(0, 12)
	innerPad.Parent = inner

	local title = makeLabel(inner, {
		Text = string.upper(rarity) .. " SPAWNED",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = color,
		Size = UDim2.new(1, 0, 0, 22),
	})

	local body = makeLabel(inner, {
		Text = "",
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.new(0, 0, 0, 26),
		Size = UDim2.new(1, 0, 1, -42),
	})

	local stroke = makeStroke(outer, color, 2, 0)
	if rarity == "Infinity" then
		animateRainbowStroke(stroke)
	end

	entry.Popup = {
		Frame = outer,
		Title = title,
		Body = body,
	}

	updatePopupText(entry)
	return entry.Popup
end

local function closePopup(entry: any)
	if entry.Popup and entry.Popup.Frame and entry.Popup.Frame.Parent then
		entry.Popup.Frame:Destroy()
	end
	entry.Popup = nil
	entry.PopupClosed = true
end

local function createLogRow(page: any, entry: any)
	local rarity = entry.Rarity
	local color = RARITY_COLORS[rarity] or Color3.fromRGB(150, 150, 150)

	if #page.LogEntries >= MAX_LOGS_PER_CATEGORY then
		page:ClearLogs()
	end

	local row = Instance.new("TextButton")
	row.Name = "LogRow"
	row.AutoButtonColor = false
	row.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -4, 0, 68)
	row.Text = ""
	row.Parent = page.LogScroll
	makeRoundedCorner(row, 10)

	local stroke = makeStroke(row, color, 1, 0.18)
	if rarity == "Infinity" then
		animateRainbowStroke(stroke)
	end

	local left = makeLabel(row, {
		Text = "",
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0.62, -16, 0.58, 0),
	})

	local rightTop = makeLabel(row, {
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.62, 0, 0, 0),
		Size = UDim2.new(0.38, -12, 0.58, 0),
	})

	local rightBottom = makeLabel(row, {
		Text = "",
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(170, 170, 185),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.62, 0, 0.58, 0),
		Size = UDim2.new(0.38, -12, 0.42, 0),
	})

	left.Text = string.format(
		"[%s] <font color=\"#FFD700\"><b>SPAWNED:</b></font> %s",
		escapeRichText(entry.SpawnTime),
		escapeRichText(entry.Name)
	)

	rightTop.Text = string.format(
		"Trait: %s | Mutation: %s | Lv.%s",
		fmtValue(entry.Trait),
		fmtValue(entry.Mutation),
		fmtValue(entry.Level)
	)

	rightBottom.Text = "Hace 0s"

	row.MouseEnter:Connect(function()
		row.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	end)

	row.MouseLeave:Connect(function()
		row.BackgroundColor3 = (page.SelectedEntry == entry) and Color3.fromRGB(24, 24, 32) or Color3.fromRGB(14, 14, 18)
	end)

	row.MouseButton1Click:Connect(function()
		if page.SelectedEntry and page.SelectedEntry.Row and page.SelectedEntry.Row.Parent then
			local prev = page.SelectedEntry.Row
			local prevStroke = prev:FindFirstChildOfClass("UIStroke")
			if prevStroke then
				prevStroke.Thickness = 1
			end
			prev.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
		end

		page.SelectedEntry = entry
		page:SelectEntry(entry)
		row.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
		stroke.Thickness = 2
	end)

	entry.Row = row
	entry.RowLeft = left
	entry.RowRightTop = rightTop
	entry.RowRightBottom = rightBottom

	table.insert(page.LogEntries, entry)
	page:UpdateFooter()

	if not page.SelectedEntry then
		page:SelectEntry(entry)
		row.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
		stroke.Thickness = 2
	end
end


local function getSnapshot(source: Instance, rarity: string)
	local name = readNamedValue(source, {"BrainrotName", "DisplayName", "Title", "NameText", "CreatureName"})
	local trait = readNamedValue(source, {"Trait", "Traits"})
	local mutation = readNamedValue(source, {"Mutation", "Muation"})
	local level = readNamedValue(source, {"Level", "Lvl", "LevelValue"})
	local timeLeft = getLiveTimeLeft(source)
	local positionText = getLiveBrainrotPosition(source)

	local secs = parseTimeLeftToSeconds(timeLeft)
	local endsAt = secs and (os.clock() + secs) or nil

	return {
		Source = source,
		Rarity = rarity,
		Name = fmtValue(name),
		Trait = fmtValue(trait),
		Mutation = fmtValue(mutation),
		Level = fmtValue(level),
		Position = fmtValue(positionText),
		SpawnUnix = os.time(),
		SpawnTime = os.date("%H:%M:%S"),
		TimeLeftRaw = timeLeft,
		TimeLeftSeconds = secs,
		TimeLeftEndsAt = endsAt,
		TimeLeftText = secs and formatSeconds(secs) or fmtValue(timeLeft),
		ElapsedText = "Hace 0s",
		Popup = nil,
		PopupClosed = false,
		Row = nil,
		Page = nil,
	}
end


local function refreshEntry(entry: any)
	local source = entry.Source
	if not source or source.Parent == nil then
		return false
	end

	entry.ElapsedText = formatElapsed(os.time() - entry.SpawnUnix)

	if entry.RowRightBottom and entry.RowRightBottom.Parent then
		entry.RowRightBottom.Text = entry.ElapsedText
	end

	local currentPosition = getLiveBrainrotPosition(source)
	if currentPosition ~= nil then
		entry.Position = currentPosition
	end

	local timeValue = getLiveTimeLeft(source)
	if timeValue ~= nil then
		entry.TimeLeftRaw = timeValue
		local secs = parseTimeLeftToSeconds(timeValue)
		if secs then
			entry.TimeLeftSeconds = secs
			entry.TimeLeftEndsAt = os.clock() + secs
			entry.TimeLeftText = formatSeconds(secs)
		else
			entry.TimeLeftSeconds = nil
			entry.TimeLeftEndsAt = nil
			entry.TimeLeftText = fmtValue(timeValue)
		end
	elseif entry.TimeLeftEndsAt ~= nil then
		local remaining = math.max(0, math.ceil(entry.TimeLeftEndsAt - os.clock()))
		entry.TimeLeftSeconds = remaining
		entry.TimeLeftText = formatSeconds(remaining)
	end

	return true
end

local function createBrainrotEntry(source: Instance, rarity: string)
	if not Settings[rarity] then
		return
	end

	if ActiveEntries[source] then
		return
	end

	local page = Pages[rarity]
	if not page then
		return
	end

	local entry = getSnapshot(source, rarity)
	ActiveEntries[source] = entry
	entry.Page = page

	createLogRow(page, entry)

	if page.LogScroll then
		task.defer(function()
			page.LogScroll.CanvasPosition = Vector2.new(0, math.max(0, page.LogScroll.AbsoluteCanvasSize.Y))
		end)
	end

	if not entry.TimeLeftSeconds or entry.TimeLeftSeconds > 0 then
		createPopup(entry)
		updatePopupText(entry)

		if entry.Popup and entry.Popup.Frame then
			table.insert(PopupFrames, entry.Popup.Frame)
			if #PopupFrames > MAX_POPUPS then
				local oldest = table.remove(PopupFrames, 1)
				if oldest and oldest.Parent then
					oldest:Destroy()
				end
			end
		end
	end

	source.Destroying:Connect(function()
		closePopup(entry)
	end)
end

local function connectRarityFolder(rarity: string)
	local folder = rootFolder:WaitForChild(rarity)

	for _, child in ipairs(folder:GetChildren()) do
		if child.Name == "RenderedBrainrot" then
			task.defer(function()
				createBrainrotEntry(child, rarity)
			end)
		end
	end

	folder.ChildAdded:Connect(function(child)
		if child.Name == "RenderedBrainrot" then
			task.defer(function()
				createBrainrotEntry(child, rarity)
			end)
		end
	end)
end

for _, rarity in ipairs(RARITY_ORDER) do
	local page = createPage(rarity)

	local button = makeButton(TabGrid, {
		Text = rarity,
		Font = Enum.Font.GothamSemibold,
		TextSize = 16,
		Size = UDim2.new(0, 176, 0, 42),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
	})
	button.LayoutOrder = table.find(RARITY_ORDER, rarity) or 1
	button.Parent = TabGrid
	makeRoundedCorner(button, 10)

	local strokeColor = RARITY_COLORS[rarity] or Color3.fromRGB(120, 120, 120)
	local stroke = makeStroke(button, strokeColor, 2, 0.05)
	if rarity == "Infinity" then
		animateRainbowStroke(stroke)
	end

	TabButtons[rarity] = button

	button.MouseButton1Click:Connect(function()
		setPageVisible(rarity)
	end)

	page.EnabledButton.MouseButton1Click:Connect(function()
		page:SetEnabled(not Settings[rarity])
	end)

	page.ClearButton.MouseButton1Click:Connect(function()
		page:ClearLogs()
	end)
end

local presetOrder = {"Big", "Medium", "Baby", "Lil"}
for _, presetName in ipairs(presetOrder) do
	local presetButton = makeButton(PresetHolder, {
		Text = presetName,
		Font = Enum.Font.GothamSemibold,
		TextSize = 15,
		Size = UDim2.new(0, 58, 0, 30),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
	})
	presetButton.Parent = PresetHolder
	makeRoundedCorner(presetButton, 10)
	makeStroke(presetButton, Color3.fromRGB(80, 80, 95), 2, 0.2)
	PresetButtons[presetName] = presetButton
	presetButton.MouseButton1Click:Connect(function()
		CurrentPreset = presetName
		applyWindowSize(PRESETS[presetName])
		updatePresetButtons()
	end)
end

setPageVisible("Infinity")
updatePresetButtons()

for _, rarity in ipairs(RARITY_ORDER) do
	connectRarityFolder(rarity)
end

task.spawn(function()
	while ScreenGui.Parent do
		for source, entry in pairs(ActiveEntries) do
			if not source or source.Parent == nil then
				closePopup(entry)
				ActiveEntries[source] = nil
			else
				local ok = refreshEntry(entry)
				if not ok then
					closePopup(entry)
					ActiveEntries[source] = nil
				else
					if entry.Popup and not entry.PopupClosed then
						if entry.TimeLeftSeconds and entry.TimeLeftSeconds <= 0 then
							closePopup(entry)
						else
							updatePopupText(entry)
						end
					end

					if entry.Page and entry.Page.SelectedEntry == entry then
						entry.Page:SelectEntry(entry)
					end
				end
			end
		end

		task.wait(REFRESH_RATE)
	end
end)

local function updateDrag(input: InputObject)
	if not dragActive or not dragStart or not dragStartPos then
		return
	end

	local delta = input.Position - dragStart
	MainBorder.Position = UDim2.new(
		dragStartPos.X.Scale,
		dragStartPos.X.Offset + delta.X,
		dragStartPos.Y.Scale,
		dragStartPos.Y.Offset + delta.Y
	)
end

local function updateResize(input: InputObject)
	if not resizeActive or not resizeStart or not resizeStartPos or minimized then
		return
	end

	local delta = input.Position - resizeStart

	local newSize = Vector2.new(
		math.clamp(resizeStartSize.X + delta.X, MIN_WINDOW_SIZE.X, MAX_WINDOW_SIZE.X),
		math.clamp(resizeStartSize.Y + delta.Y, MIN_WINDOW_SIZE.Y, MAX_WINDOW_SIZE.Y)
	)

	local appliedDelta = Vector2.new(newSize.X - resizeStartSize.X, newSize.Y - resizeStartSize.Y)

	MainBorder.Size = UDim2.fromOffset(newSize.X, newSize.Y)
	MainBorder.Position = UDim2.new(
		resizeStartPos.X.Scale,
		resizeStartPos.X.Offset + (appliedDelta.X * 0.5),
		resizeStartPos.Y.Scale,
		resizeStartPos.Y.Offset + (appliedDelta.Y * 0.5)
	)

	expandedSize = newSize
	syncResolutionBox()
end

WindowBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragActive = true
		dragStart = input.Position
		dragStartPos = MainBorder.Position
	end
end)

WindowBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragActive = false
		dragStart = nil
		dragStartPos = nil
	end
end)

local ResizeGrip = Instance.new("TextButton")
ResizeGrip.Name = "ResizeGrip"
ResizeGrip.AutoButtonColor = false
ResizeGrip.BackgroundTransparency = 1
ResizeGrip.Text = ""
ResizeGrip.Size = UDim2.new(0, 22, 0, 22)
ResizeGrip.AnchorPoint = Vector2.new(1, 1)
ResizeGrip.Position = UDim2.new(1, -6, 1, -6)
ResizeGrip.Parent = Main

local GripLine1 = Instance.new("Frame")
GripLine1.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
GripLine1.BorderSizePixel = 0
GripLine1.Size = UDim2.new(0, 12, 0, 2)
GripLine1.Position = UDim2.new(0, 8, 0, 13)
GripLine1.Rotation = -45
GripLine1.Parent = ResizeGrip

local GripLine2 = Instance.new("Frame")
GripLine2.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
GripLine2.BorderSizePixel = 0
GripLine2.Size = UDim2.new(0, 8, 0, 2)
GripLine2.Position = UDim2.new(0, 11, 0, 9)
GripLine2.Rotation = -45
GripLine2.Parent = ResizeGrip

ResizeGrip.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not minimized then
		resizeActive = true
		resizeStart = input.Position
		resizeStartSize = expandedSize
		resizeStartPos = MainBorder.Position
	end
end)

ResizeGrip.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		resizeActive = false
		resizeStart = nil
		resizeStartPos = nil
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		updateDrag(input)
		updateResize(input)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragActive = false
		dragStart = nil
		dragStartPos = nil
		resizeActive = false
		resizeStart = nil
		resizeStartPos = nil
	end
end)

local COLLAPSED_HEIGHT = BAR_HEIGHT + 10

local function setMinimized(state: boolean)
	local currentHeight = minimized and COLLAPSED_HEIGHT or expandedSize.Y
	minimized = state
	local newHeight = minimized and COLLAPSED_HEIGHT or expandedSize.Y
	local delta = newHeight - currentHeight

	ContentFrame.Visible = not minimized
	ResizeGrip.Visible = not minimized

	local pos = MainBorder.Position
	MainBorder.Position = UDim2.new(
		pos.X.Scale,
		pos.X.Offset,
		pos.Y.Scale,
		pos.Y.Offset + (delta / 2)
	)

	MainBorder.Size = UDim2.fromOffset(expandedSize.X, newHeight)
end

MinButton.MouseButton1Click:Connect(function()
	setMinimized(not minimized)
end)

CloseButton.MouseButton1Click:Connect(function()
	ScreenGui:Destroy()
end)

ResolutionBox.FocusLost:Connect(function(enterPressed)
	local w, h = ResolutionBox.Text:match("(%d+)%s*[xX]%s*(%d+)")
	if enterPressed and w and h then
		local width = tonumber(w)
		local height = tonumber(h)
		if width and height then
			local target = Vector2.new(width, height)
			local matchedPreset: string? = nil
			for presetName, presetSize in pairs(PRESETS) do
				if presetSize.X == target.X and presetSize.Y == target.Y then
					matchedPreset = presetName
					break
				end
			end

			if matchedPreset then
				applyPreset(matchedPreset)
			else
				CurrentPreset = "Custom"
				applyWindowSize(target)
				updatePresetButtons()
			end

			return
		end
	end

	syncResolutionBox()
end)

applyWindowSize(PRESETS[DEFAULT_PRESET])
setWindowPosition(UDim2.new(0.5, 0, 0.5, 0))
setMinimized(false)
CurrentPreset = DEFAULT_PRESET
updatePresetButtons()
syncResolutionBox()

print("[BrainrotLogger] Running")
