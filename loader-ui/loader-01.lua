
if not getgenv().LoaderMiniMal then
    getgenv().LoaderMiniMal = {}
end

local MinimalLoader = getgenv().LoaderMiniMal

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local loaderGui
local rotateConnection


local function createLoader(parent)
    if parent:FindFirstChild("MinimalLoader") then
        parent:FindFirstChild("MinimalLoader"):Destroy()
    end

    loaderGui = Instance.new("ScreenGui")
    loaderGui.Name = "MinimalLoader"
    loaderGui.ResetOnSpawn = false
    loaderGui.Parent = parent

    local bgSize = UDim2.new(0,170,0,170)
    local loaderBg = Instance.new("Frame")
    loaderBg.Size = bgSize
    loaderBg.Position = UDim2.new(0.5,0,0.5,0)
    loaderBg.AnchorPoint = Vector2.new(0.5,0.5)
    loaderBg.BackgroundColor3 = Color3.fromRGB(0,0,0)
    loaderBg.BorderSizePixel = 0
    loaderBg.BackgroundTransparency = 0.1
    loaderBg.Parent = loaderGui

    local loaderSize = UDim2.new(0,150,0,150)
    local loader = Instance.new("Frame")
    loader.Size = loaderSize
    loader.Position = UDim2.new(0.5,0,0.5,0)
    loader.AnchorPoint = Vector2.new(0.5,0.5)
    loader.BackgroundTransparency = 1
    loader.Parent = loaderBg

    local rotatingO = Instance.new("TextLabel")
    rotatingO.Size = UDim2.new(0,40,0,40)
    rotatingO.Position = UDim2.new(0.5,0,0.4,0)
    rotatingO.AnchorPoint = Vector2.new(0.5,0.5)
    rotatingO.BackgroundTransparency = 1
    rotatingO.Text = "O"
    rotatingO.TextColor3 = Color3.fromRGB(255,255,255)
    rotatingO.Font = Enum.Font.Gotham
    rotatingO.TextSize = 30
    rotatingO.Parent = loader

    local progressBar = Instance.new("Frame")
    progressBar.Size = UDim2.new(0,0,0,10)
    progressBar.Position = UDim2.new(0.5,0,0.7,0)
    progressBar.AnchorPoint = Vector2.new(0.5,0.5)
    progressBar.BackgroundColor3 = Color3.fromRGB(255,255,255)
    progressBar.BorderSizePixel = 0
    progressBar.Parent = loader

    local percentText = Instance.new("TextLabel")
    percentText.Size = UDim2.new(1,0,0,30)
    percentText.Position = UDim2.new(0,0,0.8,0)
    percentText.BackgroundTransparency = 1
    percentText.TextColor3 = Color3.fromRGB(255,255,255)
    percentText.Font = Enum.Font.Gotham
    percentText.TextSize = 20
    percentText.Text = "0%"
    percentText.Parent = loader

    local angle = 0
    rotateConnection = RunService.RenderStepped:Connect(function(delta)
        angle = angle + 180 * delta
        rotatingO.Rotation = angle
    end)

    return {
        progressBar = progressBar,
        percentText = percentText
    }
end


function MinimalLoader.Load(parent)
    local guiObjects = createLoader(parent or gethui())
    local progressBar = guiObjects.progressBar
    local percentText = guiObjects.percentText

    local success, err = pcall(function()
        for i = 0,100 do
            progressBar.Size = UDim2.new(i/100,0,0,10)
            percentText.Text = i.."%"
            RunService.RenderStepped:Wait()
        end
    end)

    if rotateConnection then
        rotateConnection:Disconnect()
    end

    if success then
        TweenService:Create(progressBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(0,255,0)}):Play()
    else
        TweenService:Create(progressBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(255,0,0)}):Play()
        warn("Loading failed:", err)
    end

    delay(1, function()
        MinimalLoader.Destroy()
    end)
end

function MinimalLoader.Destroy()
    if loaderGui then
        loaderGui:Destroy()
        loaderGui = nil
    end
    if rotateConnection then
        rotateConnection:Disconnect()
        rotateConnection = nil
    end
end



--getgenv().LoaderMiniMal.Load(gethui())


