local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local NotificationSystem = {}
NotificationSystem.__index = NotificationSystem

local CONFIG = {
    BG_COLOR = Color3.fromRGB(20, 20, 25),
    ACCENT_COLOR = Color3.fromRGB(138, 43, 226),
    TEXT_COLOR = Color3.fromRGB(255, 255, 255),
    FONT = Enum.Font.GothamBold,
    DEFAULT_DURATION = 5,
    MAX_WIDTH = 400,
    SPACING = 10
}

function NotificationSystem.new()
    local self = setmetatable({}, NotificationSystem)
    
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "NovaNotifications"
    self.gui.ResetOnSpawn = false
    self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.gui.Parent = (gethui and gethui()) or game.CoreGui
    
    self.container = Instance.new("Frame", self.gui)
    self.container.Name = "Container"
    self.container.Size = UDim2.new(0.4, 0, 0.8, 0)
    self.container.Position = UDim2.fromScale(0.5, 0.1)
    self.container.AnchorPoint = Vector2.new(0.5, 0)
    self.container.BackgroundTransparency = 1
    
    local layout = Instance.new("UIListLayout", self.container)
    layout.Padding = UDim.new(0, CONFIG.SPACING)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    self.activeNotifications = {} 
    
    return self
end

function NotificationSystem:Notify(text, duration)
    duration = duration or CONFIG.DEFAULT_DURATION
    
    if self.activeNotifications[text] then
        local notif = self.activeNotifications[text]
        notif:Refresh(duration)
        return
    end
    
    local notif = {}
    self.activeNotifications[text] = notif
    
    local frame = Instance.new("Frame", self.container)
    frame.Name = "Notification"
    frame.Size = UDim2.new(0, 0, 0, 45)
    frame.BackgroundColor3 = CONFIG.BG_COLOR
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)
    
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = CONFIG.ACCENT_COLOR
    stroke.Thickness = 2
    stroke.Transparency = 1
    
    local grad = Instance.new("UIGradient", stroke)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, CONFIG.ACCENT_COLOR),
        ColorSequenceKeypoint.new(0.5, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1, CONFIG.ACCENT_COLOR)
    })
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -20, 1, -5)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = CONFIG.TEXT_COLOR
    label.TextSize = 14
    label.Font = CONFIG.FONT
    label.TextTransparency = 1
    label.ZIndex = 2
    
    local barContainer = Instance.new("Frame", frame)
    barContainer.Name = "BarContainer"
    barContainer.Size = UDim2.new(1, 0, 0, 3)
    barContainer.Position = UDim2.fromScale(0, 1)
    barContainer.AnchorPoint = Vector2.new(0, 1)
    barContainer.BackgroundColor3 = Color3.new(0, 0, 0)
    barContainer.BackgroundTransparency = 0.8
    barContainer.BorderSizePixel = 0
    
    local progressBar = Instance.new("Frame", barContainer)
    progressBar.Size = UDim2.fromScale(1, 1)
    progressBar.BackgroundColor3 = CONFIG.ACCENT_COLOR
    progressBar.BorderSizePixel = 0
    
    local glow = Instance.new("ImageLabel", progressBar)
    glow.Size = UDim2.new(1, 10, 1, 10)
    glow.Position = UDim2.fromScale(0.5, 0.5)
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.BackgroundTransparency = 1
    glow.Image = "rbxassetid://5028857084"
    glow.ImageColor3 = CONFIG.ACCENT_COLOR
    glow.ImageTransparency = 0.5
    
    local targetWidth = math.min(label.TextBounds.X + 40, CONFIG.MAX_WIDTH)
    
    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, targetWidth, 0, 45),
        BackgroundTransparency = 0.1
    }):Play()
    
    TweenService:Create(stroke, TweenInfo.new(0.4), {Transparency = 0}):Play()
    TweenService:Create(label, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
    
    local startTime = tick()
    local timeLeft = duration
    
    function notif:Refresh(newDuration)
        startTime = tick()
        timeLeft = newDuration
        
        frame:TweenSize(UDim2.new(0, targetWidth + 10, 0, 50), "Out", "Quad", 0.1, true)
        task.delay(0.1, function()
            frame:TweenSize(UDim2.new(0, targetWidth, 0, 45), "Out", "Quad", 0.1, true)
        end)
        
        progressBar.Size = UDim2.fromScale(1, 1)
    end
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        local progress = 1 - (elapsed / timeLeft)
        
        if progress <= 0 then
            connection:Disconnect()
            self:Remove(text, frame, stroke, label)
        else
            progressBar.Size = UDim2.fromScale(progress, 1)
            grad.Rotation = (grad.Rotation + 2) % 360
        end
    end)
    
    notif.connection = connection
    notif.frame = frame
end

function NotificationSystem:Remove(text, frame, stroke, label)
    self.activeNotifications[text] = nil
    
    local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(frame, ti, {Size = UDim2.new(0, 0, 0, 45), BackgroundTransparency = 1}):Play()
    TweenService:Create(stroke, ti, {Transparency = 1}):Play()
    TweenService:Create(label, ti, {TextTransparency = 1}):Play()
    
    task.delay(0.4, function()
        frame:Destroy()
    end)
end

local UI = NotificationSystem.new()

_G.Notify = function(text, duration)
    UI:Notify(text, duration)
end

UI:Notify("Welcome to Zanexywex Project !", 10)

return UI
