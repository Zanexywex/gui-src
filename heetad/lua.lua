local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LogService = game:GetService("LogService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Library = {}

function Library:CreateWindow(config)
	config = config or {}
	local initialLevel = config.Level or 1
	local initialMaxLevel = config.MaxLevel or 100
	local initialMoney = config.Money or 0
	local initialName = config.Name or player.DisplayName or player.Name

	-- ลบ UI เก่าออกก่อน
	local oldUI = playerGui:FindFirstChild("ModernDashboardUI")
	if oldUI then
		oldUI:Destroy()
	end

	-- สร้าง ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModernDashboardUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- ===== Main Frame =====
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
	mainFrame.BorderSizePixel = 0
	mainFrame.Size = UDim2.new(0, 650, 0, 560)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.Parent = screenGui

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = mainFrame

	-- Rounded corners
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 16)
	mainCorner.Parent = mainFrame

	-- Subtle border
	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Color3.fromRGB(35, 38, 50)
	mainStroke.Thickness = 1.5
	mainStroke.Parent = mainFrame

	-- ===== Close Button =====
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Text = "X"
	closeBtn.TextSize = 16
	closeBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.BackgroundTransparency = 1
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -34, 0, 14)
	closeBtn.ZIndex = 10
	closeBtn.Parent = mainFrame

	-- ===== HEADER SECTION =====
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "HeaderFrame"
	headerFrame.BackgroundTransparency = 1
	headerFrame.Size = UDim2.new(1, -40, 0, 90)
	headerFrame.Position = UDim2.new(0, 20, 0, 20)
	headerFrame.Parent = mainFrame

	-- Profile Picture (Avatar)
	local avatarFrame = Instance.new("Frame")
	avatarFrame.Name = "AvatarFrame"
	avatarFrame.Size = UDim2.new(0, 75, 0, 75)
	avatarFrame.Position = UDim2.new(0, 0, 0, 5)
	avatarFrame.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
	avatarFrame.Parent = headerFrame

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0.5, 0)
	avatarCorner.Parent = avatarFrame

	local avatarStroke = Instance.new("UIStroke")
	avatarStroke.Color = Color3.fromRGB(130, 80, 250)
	avatarStroke.Thickness = 2
	avatarStroke.Parent = avatarFrame

	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Name = "AvatarImage"
	avatarImage.Size = UDim2.new(1, -4, 1, -4)
	avatarImage.Position = UDim2.new(0, 2, 0, 2)
	avatarImage.BackgroundTransparency = 1
	avatarImage.ScaleType = Enum.ScaleType.Crop
	avatarImage.Parent = avatarFrame

	local avatarImgCorner = Instance.new("UICorner")
	avatarImgCorner.CornerRadius = UDim.new(0.5, 0)
	avatarImgCorner.Parent = avatarImage

	-- Load Local Player Thumbnail
	task.spawn(function()
		local userId = player.UserId
		local thumbType = Enum.ThumbnailType.HeadShot
		local thumbSize = Enum.ThumbnailSize.Size100x100
		local content, isReady = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
		if isReady then
			avatarImage.Image = content
		end
	end)

	-- Player Info (Name, Level, Exp)
	local infoFrame = Instance.new("Frame")
	infoFrame.Name = "InfoFrame"
	infoFrame.BackgroundTransparency = 1
	infoFrame.Size = UDim2.new(0, 300, 1, 0)
	infoFrame.Position = UDim2.new(0, 90, 0, 5)
	infoFrame.Parent = headerFrame

	local obscuredName = "*****"
	local nameVisible = false

	local nameContainer = Instance.new("Frame")
	nameContainer.Name = "NameContainer"
	nameContainer.BackgroundTransparency = 1
	nameContainer.Size = UDim2.new(1, 0, 0, 26)
	nameContainer.Parent = infoFrame

	local nameLayout = Instance.new("UIListLayout")
	nameLayout.FillDirection = Enum.FillDirection.Horizontal
	nameLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	nameLayout.Padding = UDim.new(0, 8)
	nameLayout.Parent = nameContainer

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Text = obscuredName
	nameLabel.TextSize = 22
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(0, 0, 1, 0)
	nameLabel.AutomaticSize = Enum.AutomaticSize.X
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = nameContainer

	local eyeBtn = Instance.new("TextButton")
	eyeBtn.Name = "EyeBtn"
	eyeBtn.Text = "👁"
	eyeBtn.TextSize = 16
	eyeBtn.Font = Enum.Font.GothamBold
	eyeBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
	eyeBtn.BackgroundTransparency = 1
	eyeBtn.Size = UDim2.new(0, 20, 0, 20)
	eyeBtn.Parent = nameContainer

	eyeBtn.MouseButton1Click:Connect(function()
		nameVisible = not nameVisible
		if nameVisible then
			nameLabel.Text = initialName
			eyeBtn.TextColor3 = Color3.fromRGB(160, 100, 255)
		else
			nameLabel.Text = obscuredName
			eyeBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
		end
	end)

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Text = "Level " .. initialLevel
	levelLabel.TextSize = 14
	levelLabel.TextColor3 = Color3.fromRGB(160, 100, 255)
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.BackgroundTransparency = 1
	levelLabel.Size = UDim2.new(0.5, 0, 0, 20)
	levelLabel.Position = UDim2.new(0, 0, 0, 28)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = infoFrame

	local levelProgressLabel = Instance.new("TextLabel")
	levelProgressLabel.Name = "LevelProgressLabel"
	levelProgressLabel.Text = initialLevel .. " / " .. initialMaxLevel
	levelProgressLabel.TextSize = 11
	levelProgressLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	levelProgressLabel.Font = Enum.Font.Gotham
	levelProgressLabel.BackgroundTransparency = 1
	levelProgressLabel.Size = UDim2.new(0.5, 0, 0, 20)
	levelProgressLabel.Position = UDim2.new(0.5, 0, 0, 28)
	levelProgressLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelProgressLabel.Parent = infoFrame

	-- Level Progress Bar
	local levelProgressBg = Instance.new("Frame")
	levelProgressBg.Name = "LevelProgressBg"
	levelProgressBg.BackgroundColor3 = Color3.fromRGB(28, 30, 42)
	levelProgressBg.BorderSizePixel = 0
	levelProgressBg.Size = UDim2.new(1, 0, 0, 10)
	levelProgressBg.Position = UDim2.new(0, 0, 0, 52)
	levelProgressBg.Parent = infoFrame

	local levelProgressBgCorner = Instance.new("UICorner")
	levelProgressBgCorner.CornerRadius = UDim.new(0, 5)
	levelProgressBgCorner.Parent = levelProgressBg

	local levelProgressFill = Instance.new("Frame")
	levelProgressFill.Name = "LevelProgressFill"
	levelProgressFill.BackgroundColor3 = Color3.fromRGB(130, 80, 250)
	levelProgressFill.BorderSizePixel = 0
	levelProgressFill.Size = UDim2.new(0, 0, 1, 0)
	levelProgressFill.Parent = levelProgressBg

	local levelProgressFillCorner = Instance.new("UICorner")
	levelProgressFillCorner.CornerRadius = UDim.new(0, 5)
	levelProgressFillCorner.Parent = levelProgressFill

	-- Init progress bar fill size
	local initPct = math.clamp(initialLevel / initialMaxLevel, 0, 1)
	levelProgressFill.Size = UDim2.new(initPct, 0, 1, 0)

	-- ===== MONEY CARD (Right Side) =====
	local moneyCard = Instance.new("Frame")
	moneyCard.Name = "MoneyCard"
	moneyCard.BackgroundColor3 = Color3.fromRGB(20, 24, 25)
	moneyCard.Size = UDim2.new(0, 200, 0, 75)
	moneyCard.Position = UDim2.new(1, -200, 0, 5)
	moneyCard.Parent = headerFrame

	local moneyCardCorner = Instance.new("UICorner")
	moneyCardCorner.CornerRadius = UDim.new(0, 12)
	moneyCardCorner.Parent = moneyCard

	local moneyCardStroke = Instance.new("UIStroke")
	moneyCardStroke.Color = Color3.fromRGB(35, 120, 80)
	moneyCardStroke.Thickness = 1.5
	moneyCardStroke.Parent = moneyCard

	local moneyTitle = Instance.new("TextLabel")
	moneyTitle.Name = "MoneyTitle"
	moneyTitle.Text = "MONEY"
	moneyTitle.TextSize = 11
	moneyTitle.TextColor3 = Color3.fromRGB(80, 220, 120)
	moneyTitle.Font = Enum.Font.GothamBold
	moneyTitle.BackgroundTransparency = 1
	moneyTitle.Size = UDim2.new(1, -30, 0, 20)
	moneyTitle.Position = UDim2.new(0, 15, 0, 12)
	moneyTitle.TextXAlignment = Enum.TextXAlignment.Left
	moneyTitle.Parent = moneyCard

	local moneyValue = Instance.new("TextLabel")
	moneyValue.Name = "MoneyValue"
	moneyValue.Text = "$ 0"
	moneyValue.TextSize = 22
	moneyValue.TextColor3 = Color3.fromRGB(80, 250, 120)
	moneyValue.Font = Enum.Font.GothamBold
	moneyValue.BackgroundTransparency = 1
	moneyValue.Size = UDim2.new(1, -30, 0, 30)
	moneyValue.Position = UDim2.new(0, 15, 0, 32)
	moneyValue.TextXAlignment = Enum.TextXAlignment.Left
	moneyValue.Parent = moneyCard

	-- Format initial money
	local function formatMoney(amount)
		local formatted = tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
		return "$ " .. formatted
	end
	moneyValue.Text = formatMoney(initialMoney)

	local moneyIcon = Instance.new("TextLabel")
	moneyIcon.Name = "MoneyIcon"
	moneyIcon.Text = "💵"
	moneyIcon.TextSize = 26
	moneyIcon.BackgroundTransparency = 1
	moneyIcon.Size = UDim2.new(0, 35, 0, 35)
	moneyIcon.Position = UDim2.new(1, -45, 0.5, -17.5)
	moneyIcon.TextXAlignment = Enum.TextXAlignment.Center
	moneyIcon.Parent = moneyCard

	-- ===== INVENTORY SECTION =====
	local inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "InventoryFrame"
	inventoryFrame.BackgroundTransparency = 1
	inventoryFrame.Size = UDim2.new(1, -40, 0, 200)
	inventoryFrame.Position = UDim2.new(0, 20, 0, 130)
	inventoryFrame.Parent = mainFrame

	-- Title
	local invTitle = Instance.new("TextLabel")
	invTitle.Name = "InvTitle"
	invTitle.Text = "INVENTORY"
	invTitle.TextSize = 13
	invTitle.TextColor3 = Color3.fromRGB(150, 150, 160)
	invTitle.Font = Enum.Font.GothamBold
	invTitle.BackgroundTransparency = 1
	invTitle.Size = UDim2.new(0.5, 0, 0, 20)
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.Parent = inventoryFrame

	-- Scrolling Frame
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.Size = UDim2.new(1, 0, 1, -30)
	scrollFrame.Position = UDim2.new(0, 0, 0, 30)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(130, 80, 250)
	scrollFrame.Parent = inventoryFrame

	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingLeft = UDim.new(0, 4)
	scrollPadding.PaddingRight = UDim.new(0, 4)
	scrollPadding.PaddingTop = UDim.new(0, 4)
	scrollPadding.PaddingBottom = UDim.new(0, 4)
	scrollPadding.Parent = scrollFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 140, 0, 45)
	gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scrollFrame

	-- Auto Canvas Size
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y)
	end)

	-- ===== CREATE ITEM FUNCTION =====
	local function createItem(name, count, rarity)
		rarity = rarity or "common"
		count = count or 1

		local rarityData = {
			common = {color = Color3.fromRGB(150, 150, 160)},
			uncommon = {color = Color3.fromRGB(100, 220, 100)},
			rare = {color = Color3.fromRGB(80, 170, 255)},
			epic = {color = Color3.fromRGB(200, 100, 255)},
			legendary = {color = Color3.fromRGB(255, 180, 50)}
		}

		local rData = rarityData[rarity] or rarityData.common

		local itemFrame = Instance.new("Frame")
		itemFrame.Name = name
		itemFrame.BackgroundColor3 = Color3.fromRGB(20, 21, 28)
		itemFrame.BorderSizePixel = 0
		itemFrame.Parent = scrollFrame

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 8)
		itemCorner.Parent = itemFrame

		-- Subtle border
		local itemStroke = Instance.new("UIStroke")
		itemStroke.Color = Color3.fromRGB(38, 41, 55)
		itemStroke.Thickness = 1
		itemStroke.Parent = itemFrame

		-- Content container
		local content = Instance.new("Frame")
		content.Size = UDim2.new(1, 0, 1, 0)
		content.BackgroundTransparency = 1
		content.Parent = itemFrame

		-- Item Name (Text Only)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ItemName"
		nameLabel.Text = name
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = rData.color
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, -40, 1, 0)
		nameLabel.Position = UDim2.new(0, 12, 0, 0)
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		nameLabel.Parent = content

		-- Quantity Count
		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "CountLabel"
		countLabel.Text = "x" .. count
		countLabel.TextSize = 11
		countLabel.TextColor3 = Color3.fromRGB(130, 130, 140)
		countLabel.Font = Enum.Font.GothamBold
		countLabel.BackgroundTransparency = 1
		countLabel.Size = UDim2.new(0, 30, 1, 0)
		countLabel.Position = UDim2.new(1, -42, 0, 0)
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.TextYAlignment = Enum.TextYAlignment.Center
		countLabel.Parent = content

		-- Hover Animation
		itemFrame.MouseEnter:Connect(function()
			TweenService:Create(itemFrame, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(26, 28, 38)
			}):Play()
			TweenService:Create(itemStroke, TweenInfo.new(0.2), {
				Color = rData.color
			}):Play()
		end)

		itemFrame.MouseLeave:Connect(function()
			TweenService:Create(itemFrame, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(20, 21, 28)
			}):Play()
			TweenService:Create(itemStroke, TweenInfo.new(0.2), {
				Color = Color3.fromRGB(38, 41, 55)
			}):Play()
		end)

		return itemFrame
	end

	-- ===== CONSOLE SECTION =====
	local consoleFrame = Instance.new("Frame")
	consoleFrame.Name = "ConsoleFrame"
	consoleFrame.BackgroundTransparency = 1
	consoleFrame.Size = UDim2.new(1, -40, 0, 180)
	consoleFrame.Position = UDim2.new(0, 20, 0, 350)
	consoleFrame.Parent = mainFrame

	local consoleTitle = Instance.new("TextLabel")
	consoleTitle.Name = "ConsoleTitle"
	consoleTitle.Text = "CONSOLE"
	consoleTitle.TextSize = 13
	consoleTitle.TextColor3 = Color3.fromRGB(150, 150, 160)
	consoleTitle.Font = Enum.Font.GothamBold
	consoleTitle.BackgroundTransparency = 1
	consoleTitle.Size = UDim2.new(0.5, 0, 0, 20)
	consoleTitle.TextXAlignment = Enum.TextXAlignment.Left
	consoleTitle.Parent = consoleFrame

	-- Console Box Background
	local consoleBox = Instance.new("Frame")
	consoleBox.Name = "ConsoleBox"
	consoleBox.BackgroundColor3 = Color3.fromRGB(10, 11, 16)
	consoleBox.Size = UDim2.new(1, 0, 1, -25)
	consoleBox.Position = UDim2.new(0, 0, 0, 25)
	consoleBox.Parent = consoleFrame

	local consoleBoxCorner = Instance.new("UICorner")
	consoleBoxCorner.CornerRadius = UDim.new(0, 8)
	consoleBoxCorner.Parent = consoleBox

	local consoleBoxStroke = Instance.new("UIStroke")
	consoleBoxStroke.Color = Color3.fromRGB(32, 35, 45)
	consoleBoxStroke.Thickness = 1
	consoleBoxStroke.Parent = consoleBox

	-- Console Scrolling Frame
	local consoleScroll = Instance.new("ScrollingFrame")
	consoleScroll.Name = "ConsoleScroll"
	consoleScroll.BackgroundTransparency = 1
	consoleScroll.BorderSizePixel = 0
	consoleScroll.Size = UDim2.new(1, -16, 1, -16)
	consoleScroll.Position = UDim2.new(0, 8, 0, 8)
	consoleScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	consoleScroll.ScrollBarThickness = 4
	consoleScroll.ScrollBarImageColor3 = Color3.fromRGB(130, 80, 250)
	consoleScroll.Parent = consoleBox

	local consoleLayout = Instance.new("UIListLayout")
	consoleLayout.FillDirection = Enum.FillDirection.Vertical
	consoleLayout.Padding = UDim.new(0, 4)
	consoleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	consoleLayout.Parent = consoleScroll

	-- Auto Canvas Size and Auto Scroll
	consoleLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		consoleScroll.CanvasSize = UDim2.new(0, 0, 0, consoleLayout.AbsoluteContentSize.Y)
		consoleScroll.CanvasPosition = Vector2.new(0, math.max(0, consoleLayout.AbsoluteContentSize.Y - consoleScroll.AbsoluteWindowSize.Y))
	end)

	-- Function to add log messages
	local function addLog(message, messageType)
		local logText = Instance.new("TextLabel")
		logText.BackgroundTransparency = 1
		logText.Size = UDim2.new(1, 0, 0, 0)
		logText.AutomaticSize = Enum.AutomaticSize.Y
		logText.Text = "  " .. message
		logText.TextSize = 11
		logText.Font = Enum.Font.Code
		logText.TextWrapped = true
		logText.TextXAlignment = Enum.TextXAlignment.Left

		-- Color coding by log type
		if messageType == Enum.MessageType.MessageError then
			logText.TextColor3 = Color3.fromRGB(255, 85, 85)
		elseif messageType == Enum.MessageType.MessageWarning then
			logText.TextColor3 = Color3.fromRGB(255, 176, 50)
		elseif messageType == Enum.MessageType.MessageInfo then
			logText.TextColor3 = Color3.fromRGB(80, 180, 255)
		else
			logText.TextColor3 = Color3.fromRGB(220, 220, 230)
		end

		logText.Parent = consoleScroll
		
		-- Max 100 messages to prevent lag
		local children = consoleScroll:GetChildren()
		if #children > 100 then
			for i = 1, #children - 100 do
				if children[i]:IsA("TextLabel") then
					children[i]:Destroy()
				end
			end
		end
	end

	-- Connect to LogService
	for _, log in ipairs(LogService:GetLogHistory()) do
		addLog(log.message, log.messageType)
	end
	local logConnection = LogService.MessageOut:Connect(addLog)

	-- ===== TOGGLE BUTTON =====
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "ToggleBtn"
	toggleBtn.Text = "X"
	toggleBtn.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
	toggleBtn.Size = UDim2.new(0, 50, 0, 50)
	toggleBtn.Position = UDim2.new(0, 20, 1, -70)
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextColor3 = Color3.fromRGB(160, 100, 255)
	toggleBtn.TextSize = 22
	toggleBtn.Parent = screenGui

	local toggleBtnCorner = Instance.new("UICorner")
	toggleBtnCorner.CornerRadius = UDim.new(0, 12)
	toggleBtnCorner.Parent = toggleBtn

	local toggleBtnStroke = Instance.new("UIStroke")
	toggleBtnStroke.Color = Color3.fromRGB(130, 80, 250)
	toggleBtnStroke.Thickness = 1.5
	toggleBtnStroke.Transparency = 0.4
	toggleBtnStroke.Parent = toggleBtn

	local toggleLabelHint = Instance.new("TextLabel")
	toggleLabelHint.Name = "ToggleHint"
	toggleLabelHint.Text = "Press RightShift\nto toggle UI"
	toggleLabelHint.TextSize = 12
	toggleLabelHint.TextColor3 = Color3.fromRGB(150, 150, 160)
	toggleLabelHint.Font = Enum.Font.GothamBold
	toggleLabelHint.BackgroundTransparency = 1
	toggleLabelHint.Size = UDim2.new(0, 120, 0, 30)
	toggleLabelHint.Position = UDim2.new(0, 80, 1, -80)
	toggleLabelHint.TextXAlignment = Enum.TextXAlignment.Left
	toggleLabelHint.Parent = screenGui

	-- Toggle Logic
	local isVisible = true
	local isTweening = false

	local function toggleUI()
		if isTweening then return end
		isTweening = true
		
		isVisible = not isVisible
		
		if isVisible then
			mainFrame.Visible = true
			uiScale.Scale = 0.5
			mainFrame.BackgroundTransparency = 1
			local stroke = mainFrame:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Transparency = 1 end
			
			local t1 = TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
			local t2 = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.01})
			t1:Play()
			t2:Play()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
			end
			t1.Completed:Connect(function()
				isTweening = false
			end)
		else
			local t1 = TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0.5})
			local t2 = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
			t1:Play()
			t2:Play()
			local stroke = mainFrame:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
			end
			t1.Completed:Connect(function()
				mainFrame.Visible = false
				isTweening = false
			end)
		end
	end

	toggleBtn.MouseButton1Click:Connect(toggleUI)
	closeBtn.MouseButton1Click:Connect(toggleUI)

	-- Keybind Toggle
	local keybindConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
			toggleUI()
		end
	end)

	-- ===== API RETURN =====
	local API = {}

	function API:UpdateLevel(nowlevel, maxlevel)
		maxlevel = maxlevel or 100
		levelLabel.Text = "Level " .. nowlevel
		levelProgressLabel.Text = nowlevel .. " / " .. maxlevel
		
		local pct = math.clamp(nowlevel / maxlevel, 0, 1)
		TweenService:Create(levelProgressFill, TweenInfo.new(0.4), {
			Size = UDim2.new(pct, 0, 1, 0)
		}):Play()
	end

	function API:UpdateMoney(amount)
		moneyValue.Text = formatMoney(amount)
	end

	function API:AddItem(name, qty, rarity)
		qty = qty or 1
		rarity = rarity or "common"
		createItem(name, qty, rarity)
	end

	function API:ClearItems()
		for _, child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	function API:Destroy()
		logConnection:Disconnect()
		keybindConnection:Disconnect()
		screenGui:Destroy()
	end

	return API
end

return Library
