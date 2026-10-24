-- Leosihii traitfarm - Anchor + Auto Buy.
if shared and shared.TraitFarm then
	shared.TraitFarm.destroy()
end

local TraitFarm = {}

-- Constants.
local ACCENT = Color3.fromRGB(150, 70, 255)
local ACCENT_DARK = Color3.fromRGB(60, 20, 110)
local BACKGROUND = Color3.fromRGB(12, 8, 20)
local PANEL = Color3.fromRGB(26, 16, 44)
local TEXT = Color3.fromRGB(240, 235, 255)
local MUTED = Color3.fromRGB(160, 140, 200)
local FULL_SIZE = UDim2.fromOffset(340, 232)

-- Config. If nothing gets bought, check the folder name and the prompt text of a brainrot.
local CONFIG = {
	animalsFolder = "RenderedMovingAnimals",
	buyRadius = 12,
	buyKeywords = { "purchase", "buy" },
	buyCooldown = 1,
}

-- Services.
local playersService = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local proximityPromptService = game:GetService("ProximityPromptService")

-- State.
local localPlayer = playersService.LocalPlayer
local connections = {}
local cooldowns = {}
local attempts = {}
local shownPrompts = {}
local anchorEnabled = false
local autoBuyEnabled = false
local alive = true
local collapsed = false

---Create an instance with properties and optional parent.
local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

---Round the corners of a gui object.
local function round(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

---Tween helper.
local function tween(inst, time, props)
	local info = TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local t = tweenService:Create(inst, info, props)
	t:Play()
	return t
end

-- Anchor.

---Apply the anchor state to the character.
local function applyAnchor()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root.Anchored ~= anchorEnabled then
		root.Anchored = anchorEnabled
	end
end

-- Auto buy.

---Check if a prompt looks like a purchase prompt.
local function isBuyPrompt(prompt)
	local text = (prompt.ActionText .. " " .. prompt.ObjectText):lower()
	for _, keyword in ipairs(CONFIG.buyKeywords) do
		if text:find(keyword, 1, true) then
			return true
		end
	end
	return false
end

---Buy through a prompt, alternating between firing it and holding it.
local function buyPrompt(prompt)
	if os.clock() - (cooldowns[prompt] or 0) < CONFIG.buyCooldown then
		return
	end
	cooldowns[prompt] = os.clock()
	attempts[prompt] = (attempts[prompt] or 0) + 1
	if attempts[prompt] % 2 == 1 then
		fireproximityprompt(prompt)
	else
		task.spawn(function()
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.1)
			prompt:InputHoldEnd()
		end)
	end
end

---Buy every brainrot prompt the character is standing next to.
local function buyNearby()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild(CONFIG.animalsFolder)
	if not root or not folder then
		return
	end

	for _, prompt in ipairs(folder:GetDescendants()) do
		if not prompt:IsA("ProximityPrompt") or not prompt.Enabled or not isBuyPrompt(prompt) then
			continue
		end

		local holder = prompt.Parent
		local position = holder:IsA("Attachment") and holder.WorldPosition or (holder:IsA("BasePart") and holder.Position)
		if not position or (position - root.Position).Magnitude > CONFIG.buyRadius then
			continue
		end

		buyPrompt(prompt)
	end
end

---Buy every purchase prompt the game is currently showing to the player.
local function buyShown()
	for prompt in pairs(shownPrompts) do
		if prompt.Parent and prompt.Enabled and isBuyPrompt(prompt) then
			buyPrompt(prompt)
		end
	end
end

-- UI.
local screenGui = create("ScreenGui", {
	Name = "LeosihiiTraitFarm",
	ResetOnSpawn = false,
	DisplayOrder = 9999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, gethui and gethui() or game:GetService("CoreGui"))

local main = create("Frame", {
	Size = FULL_SIZE,
	Position = UDim2.new(0, 40, 0.5, -116),
	BackgroundColor3 = BACKGROUND,
	ClipsDescendants = true,
	Active = true,
	Draggable = true,
}, screenGui)
round(main, 14)
create("UIStroke", { Color = ACCENT, Thickness = 1.5 }, main)

local content = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, main)

local collapseButton = create("TextButton", {
	Text = "-",
	Size = UDim2.fromOffset(26, 26),
	Position = UDim2.fromOffset(10, 10),
	BackgroundColor3 = ACCENT,
	TextColor3 = TEXT,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
}, content)
round(collapseButton, 6)

create("TextLabel", {
	Text = "Leosihii traitfarm",
	Position = UDim2.fromOffset(42, 10),
	Size = UDim2.new(1, -52, 0, 26),
	BackgroundTransparency = 1,
	TextColor3 = TEXT,
	Font = Enum.Font.GothamBlack,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
}, content)

---Create a labeled on/off switch that starts off.
local function makeToggle(text, y, onChange)
	local row = create("Frame", {
		Position = UDim2.fromOffset(10, y),
		Size = UDim2.new(1, -20, 0, 48),
		BackgroundColor3 = PANEL,
	}, content)
	round(row, 10)
	create("TextLabel", {
		Text = text,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -90, 1, 0),
		BackgroundTransparency = 1,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local pill = create("TextButton", {
		Text = "",
		Size = UDim2.fromOffset(46, 24),
		Position = UDim2.new(1, -60, 0.5, -12),
		BackgroundColor3 = ACCENT_DARK,
		AutoButtonColor = false,
	}, row)
	round(pill, 12)
	local knob = create("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = MUTED,
	}, pill)
	round(knob, 9)

	local state = false
	pill.MouseButton1Click:Connect(function()
		state = not state
		tween(pill, 0.25, { BackgroundColor3 = state and ACCENT or ACCENT_DARK })
		tween(knob, 0.25, {
			Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or MUTED,
		})
		onChange(state)
	end)
end

makeToggle("Anchor", 52, function(state)
	anchorEnabled = state
	applyAnchor()
end)
makeToggle("Auto Buy", 110, function(state)
	autoBuyEnabled = state
end)

-- Footer: bright purple gradient that moves left to right, with a dark outline.
local footerBar = create("Frame", {
	Position = UDim2.new(0, 10, 1, -42),
	Size = UDim2.new(1, -20, 0, 32),
	BackgroundColor3 = Color3.fromRGB(20, 8, 40),
}, content)
round(footerBar, 8)
create("UIStroke", { Color = ACCENT, Thickness = 1 }, footerBar)
local footer = create("TextLabel", {
	Text = "Discord.gg/3EpQRujdze",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBlack,
	TextSize = 17,
}, footerBar)
create("UIStroke", {
	Color = Color3.new(0, 0, 0),
	Thickness = 1.5,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
}, footer)
local footerGradient = create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 45, 210)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(225, 180, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 45, 210)),
	}),
}, footer)

-- Collapsed circle button.
local circle = create("TextButton", {
	Text = "L",
	Size = UDim2.fromOffset(46, 46),
	BackgroundColor3 = ACCENT,
	TextColor3 = TEXT,
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	Visible = false,
	Active = true,
	Draggable = true,
}, screenGui)
round(circle, 100)

---Collapse the UI into a circle.
local function collapse()
	collapsed = true
	content.Visible = false
	tween(main, 0.35, { Size = UDim2.fromOffset(46, 46) })
	task.delay(0.36, function()
		if not collapsed then
			return
		end
		circle.Position = main.Position
		circle.Visible = true
		main.Visible = false
	end)
end

---Expand the circle back into the UI.
local function expand()
	collapsed = false
	main.Position = circle.Position
	main.Size = UDim2.fromOffset(46, 46)
	main.Visible = true
	circle.Visible = false
	tween(main, 0.35, { Size = FULL_SIZE })
	task.delay(0.2, function()
		content.Visible = true
	end)
end

collapseButton.MouseButton1Click:Connect(collapse)
circle.MouseButton1Click:Connect(expand)

-- Footer gradient animation (left to right).
table.insert(connections, runService.RenderStepped:Connect(function()
	footerGradient.Offset = Vector2.new(((os.clock() * 0.5) % 2) - 1, 0)
end))

-- Re-apply the anchor after respawning.
table.insert(connections, localPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	applyAnchor()
end))

-- Track the prompts the game shows to us, wherever they live.
table.insert(connections, proximityPromptService.PromptShown:Connect(function(prompt)
	shownPrompts[prompt] = true
end))
table.insert(connections, proximityPromptService.PromptHidden:Connect(function(prompt)
	shownPrompts[prompt] = nil
	attempts[prompt] = nil
end))

-- Main loop.
task.spawn(function()
	while alive do
		if anchorEnabled then
			applyAnchor()
		end
		if autoBuyEnabled then
			pcall(buyShown)
			pcall(buyNearby)
		end
		task.wait(0.2)
	end
end)

---Clean up the whole script.
function TraitFarm.destroy()
	alive = false
	anchorEnabled = false
	applyAnchor()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	screenGui:Destroy()
end

if shared then
	shared.TraitFarm = TraitFarm
end
