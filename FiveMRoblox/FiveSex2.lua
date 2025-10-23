-- CKPV Library
local CKPV = {}
CKPV.__index = CKPV

function CKPV.new(name)
	local self = setmetatable({}, CKPV)

	local guiparent = gethui()
	if guiparent:FindFirstChild(name) then
		guiparent:FindFirstChild(name):Destroy()
	end

	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local player = Players.LocalPlayer

	-- ScreenGui
	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = name
	self.ScreenGui.Parent = guiparent
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.IgnoreGuiInset = true

	-- Main Frame
	self.MainFrame = Instance.new("Frame")
	self.MainFrame.Size = UDim2.new(0, 650, 0, 500)
	self.MainFrame.Position = UDim2.new(0.5, -325, 0.5, -250)
	self.MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	self.MainFrame.BorderSizePixel = 0
	self.MainFrame.ClipsDescendants = true
	self.MainFrame.Parent = self.ScreenGui

	local corner = Instance.new("UICorner", self.MainFrame)
	corner.CornerRadius = UDim.new(0, 10)

	local stroke = Instance.new("UIStroke", self.MainFrame)
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(0, 255, 200)
	stroke.Transparency = 0.2

	local gradient = Instance.new("UIGradient", stroke)
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 200))
	}
	gradient.Rotation = 0
	task.spawn(function()
		while task.wait(0.05) do
			gradient.Rotation = (gradient.Rotation + 1) % 360
		end
	end)

	-- Dragging
	local dragging, dragInput, mousePos, framePos
	self.MainFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			mousePos = input.Position
			framePos = self.MainFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	self.MainFrame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - mousePos
			self.MainFrame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
		end
	end)

	-- ScrollingFrame
	self.Content = Instance.new("ScrollingFrame")
	self.Content.Size = UDim2.new(1, -20, 1, -20)
	self.Content.Position = UDim2.new(0, 10, 0, 10)
	self.Content.BackgroundTransparency = 1
	self.Content.BorderSizePixel = 0
	self.Content.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.Content.ScrollBarThickness = 0
	self.Content.Parent = self.MainFrame

	self.Layout = Instance.new("UIListLayout", self.Content)
	self.Layout.Padding = UDim.new(0, 8)
	self.Layout.SortOrder = Enum.SortOrder.LayoutOrder

	self.Elements = {}

	local function updateCanvas()
		local totalSize = self.Layout.AbsoluteContentSize.Y
		self.Content.CanvasSize = UDim2.new(0, 0, 0, totalSize + self.Layout.Padding.Offset)
	end
	self.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

	return self
end

function CKPV:Reorder()
	local order = 0
	for _, data in ipairs(self.Elements) do
		if data.Frame.Visible then
			data.Frame.LayoutOrder = order
			order += 1
		end
	end
end

function CKPV:AddHeader(text, width, height)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, width or 400, 0, height or 36)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = self.Content

	local hue = 0
	local RunService = game:GetService("RunService")
	RunService.RenderStepped:Connect(function(dt)
		hue = (hue + dt * 0.25) % 1
		label.TextColor3 = Color3.fromHSV(hue, 1, 1)
	end)

	table.insert(self.Elements, {Frame = label})
	self:Reorder()
	return label
end

function CKPV:AddToggle(name, text, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 32)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.Parent = self.Content
	frame.Visible = true
	local corner = Instance.new("UICorner", frame)
	corner.CornerRadius = UDim.new(0, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextScaled = true
	label.Text = text
	label.Parent = frame

	local switch = Instance.new("Frame")
	switch.Size = UDim2.new(0, 50, 0, 22)
	switch.Position = UDim2.new(1, -60, 0.5, -11)
	switch.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
	switch.Parent = frame
	local scorner = Instance.new("UICorner", switch)
	scorner.CornerRadius = UDim.new(1, 0)

	local circle = Instance.new("Frame")
	circle.Size = UDim2.new(0, 18, 0, 18)
	circle.Position = UDim2.new(0, 2, 0, 2)
	circle.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	circle.Parent = switch
	local cc = Instance.new("UICorner", circle)
	cc.CornerRadius = UDim.new(1, 0)

	local state = default or false
	local TweenService = game:GetService("TweenService")
	local function updateState(s)
		state = s
		local goal = {
			Position = s and UDim2.new(1, -20, 0, 2) or UDim2.new(0, 2, 0, 2),
			BackgroundColor3 = s and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 200, 200)
		}
		TweenService:Create(circle, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	end
	updateState(state)

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			updateState(not state)
			if callback then callback(state) end
		end
	end)

	local toggle = {}
	function toggle:Show()
		frame.Visible = true
		self:Reorder()
	end
	function toggle:Close()
		frame.Visible = false
		self:Reorder()
	end
	function toggle:State() return state end

	table.insert(self.Elements, {Frame = frame, Type = "Toggle", Name = name, Object = toggle})
	self:Reorder()
	return toggle
end

function CKPV:AddButton(name, text, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = text
	btn.Font = Enum.Font.Gotham
	btn.TextScaled = true
	btn.Parent = self.Content
	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 6)

	local effect = Instance.new("Frame")
	effect.Size = UDim2.new(0, 0, 1, 0)
	effect.Position = UDim2.new(0.5, 0, 0, 0)
	effect.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	effect.BackgroundTransparency = 0.5
	effect.ZIndex = btn.ZIndex + 1
	effect.ClipsDescendants = true
	effect.Parent = btn

	local effectCorner = Instance.new("UICorner", effect)
	effectCorner.CornerRadius = UDim.new(0, 6)

	local TweenService = game:GetService("TweenService")
	btn.MouseButton1Click:Connect(function()
		effect.Size = UDim2.new(0, 0, 1, 0)
		effect.Position = UDim2.new(0.5, 0, 0, 0)
		effect.BackgroundTransparency = 0.5

		TweenService:Create(effect, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1
		}):Play()

		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
		task.wait(0.2)
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()

		if callback then callback() end
	end)

	table.insert(self.Elements, {Frame = btn})
	self:Reorder()
	return btn
end

function CKPV:AddDropdown(name, text, default, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	btn.TextColor3 = Color3.fromRGB(230, 230, 230)
	btn.Font = Enum.Font.Gotham
	btn.TextScaled = true
	btn.Text = text
	btn.Parent = contentFrame
	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 6)

	local dropFrame = Instance.new("Frame")
	dropFrame.Size = UDim2.new(0, 160, 0, 0)
	dropFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	dropFrame.ClipsDescendants = true
	dropFrame.Visible = false
	dropFrame.ZIndex = 50
	dropFrame.Parent = screenGui

	local uiStroke = Instance.new("UIStroke", dropFrame)
	uiStroke.Thickness = 1
	uiStroke.Color = Color3.fromRGB(80, 80, 80)
	uiStroke.Transparency = 0.3

	local dropCorner = Instance.new("UICorner", dropFrame)
	dropCorner.CornerRadius = UDim.new(0, 8)

	local layout = Instance.new("UIListLayout", dropFrame)
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local padding = Instance.new("UIPadding", dropFrame)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)

	local items = {}
	local dropdown = {}

	function dropdown:Add(opt)
		local optBtn = Instance.new("TextButton")
		optBtn.Size = UDim2.new(1, 0, 0, 28)
		optBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		optBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
		optBtn.Font = Enum.Font.Gotham
		optBtn.TextScaled = true
		optBtn.Text = opt
		optBtn.TextXAlignment = Enum.TextXAlignment.Center
		optBtn.TextYAlignment = Enum.TextYAlignment.Center
		optBtn.ZIndex = 51
		optBtn.Parent = dropFrame

		local pad = Instance.new("UIPadding", optBtn)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)

		local oc = Instance.new("UICorner", optBtn)
		oc.CornerRadius = UDim.new(0, 6)

		optBtn.MouseEnter:Connect(function()
			TweenService:Create(optBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
		end)
		optBtn.MouseLeave:Connect(function()
			TweenService:Create(optBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
		end)

		optBtn.MouseButton1Click:Connect(function()
			btn.Text = text .. ": " .. opt
			TweenService:Create(dropFrame, TweenInfo.new(0.25), {Size = UDim2.new(0, 160, 0, 0)}):Play()
			task.delay(0.25, function()
				dropFrame.Visible = false
			end)
			if callback then callback(opt) end
		end)

		table.insert(items, optBtn)
	end

	btn.MouseButton1Click:Connect(function()
		local absPos = btn.AbsolutePosition
		local guiRightEdge = mainFrame.AbsolutePosition.X + mainFrame.AbsoluteSize.X
		local offset = 18

		if not dropFrame.Visible then
			dropFrame.Visible = true
			local newHeight = math.clamp(#items * 32 + 10, 0, 200)
			dropFrame.Position = UDim2.fromOffset(guiRightEdge + offset, absPos.Y)
			TweenService:Create(dropFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 160, 0, newHeight)
			}):Play()
		else
			TweenService:Create(dropFrame, TweenInfo.new(0.25), {Size = UDim2.new(0, 160, 0, 0)}):Play()
			task.delay(0.25, function()
				dropFrame.Visible = false
			end)
		end
	end)

	if typeof(default) == "table" then
		for _, opt in ipairs(default) do
			dropdown:Add(opt)
		end
		btn.Text = text
	else
		btn.Text = default or text
	end

	GUI.Elements[#GUI.Elements+1] = {Frame = btn}
	GUI:Reorder()
	return dropdown
end



return CKPV
