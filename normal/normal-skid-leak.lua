local Players          = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TweenService     = game:GetService('TweenService')
local RunService       = game:GetService('RunService')
local HttpService      = game:GetService('HttpService')
local GuiService       = game:GetService('GuiService')
local CoreGui          = game:GetService('CoreGui')

local LocalPlayer = Players.LocalPlayer
local Env = (getgenv and getgenv()) or _G

if type(Env.Library) == 'table' and type(Env.Library.Unload) == 'function' then
    pcall(function() Env.Library:Unload() end)
end

local Toggles, Options = {}, {}
Env.Toggles = Toggles
Env.Options = Options

local Library = {
    Theme = {
        Background = Color3.fromRGB(16, 13, 17),
        Card       = Color3.fromRGB(22, 18, 23),
        Element    = Color3.fromRGB(30, 24, 31),
        Hover      = Color3.fromRGB(38, 30, 39),
        Stroke     = Color3.fromRGB(50, 39, 50),
        Text       = Color3.fromRGB(235, 236, 245),
        SubText    = Color3.fromRGB(150, 152, 172),
        DimText    = Color3.fromRGB(108, 110, 130),
        Accent     = Color3.fromRGB(206, 8, 59),
        Risk       = Color3.fromRGB(255, 85, 85),
        Knob       = Color3.fromRGB(255, 255, 255),
    },
    Font       = Enum.Font.Gotham,
    FontMedium = Enum.Font.GothamMedium,
    FontBold   = Enum.Font.GothamBold,

    Registry        = {},
    ThemeCallbacks  = {},
    Signals         = {},
    UnloadCallbacks = {},
    DependencyBoxes = {},

    ToggleKeybind = Enum.KeyCode.RightShift,
    Folder        = 'UILibrary',
    Toggles       = Toggles,
    Options       = Options,
}

local MB1, MB2 = Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2
local Touch, Move = Enum.UserInputType.Touch, Enum.UserInputType.MouseMovement

local function IsClick(Input)
    return Input.UserInputType == MB1 or Input.UserInputType == Touch
end

local function Create(Class, Props)
    local Inst = Instance.new(Class)
    local Parent
    for K, V in pairs(Props or {}) do
        if K == 'Parent' then Parent = V else Inst[K] = V end
    end
    if Parent then Inst.Parent = Parent end
    return Inst
end

function Library:AddToRegistry(Inst, Props)
    local Entry = self.Registry[Inst] or {}
    for Prop, Key in pairs(Props) do Entry[Prop] = Key end
    self.Registry[Inst] = Entry
end

function Library:RemoveFromRegistry(Inst)
    self.Registry[Inst] = nil
end

function Library:UpdateTheme(Key, Color)
    if Key and Color then self.Theme[Key] = Color end
    for Inst, Props in pairs(self.Registry) do
        if Inst.Parent then
            for Prop, K in pairs(Props) do Inst[Prop] = self.Theme[K] end
        end
    end
    for _, F in ipairs(self.ThemeCallbacks) do pcall(F) end
end

function Library:SetAccent(Color)
    self:UpdateTheme('Accent', Color)
end

local function Themed(Inst, Props)
    Library:AddToRegistry(Inst, Props)
    for Prop, Key in pairs(Props) do Inst[Prop] = Library.Theme[Key] end
    return Inst
end

local function Tween(Inst, Props, Time, Style, Direction)
    local T = TweenService:Create(Inst, TweenInfo.new(
        Time or 0.2, Style or Enum.EasingStyle.Quint, Direction or Enum.EasingDirection.Out), Props)
    T:Play()
    return T
end
local Back = Enum.EasingStyle.Back

function Library:Tween(Inst, Props, Time, Style, Direction) return Tween(Inst, Props, Time, Style, Direction) end

local function Lerp(KeyA, KeyB, Alpha)
    return Library.Theme[KeyA]:Lerp(Library.Theme[KeyB], Alpha)
end

local function Corner(Parent, Radius)
    return Create('UICorner', { CornerRadius = Radius == 'full' and UDim.new(1, 0) or UDim.new(0, Radius or 6), Parent = Parent })
end

local function Stroke(Parent, Key, Thickness)
    return Themed(Create('UIStroke', {
        Thickness = Thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = Parent,
    }), { Color = Key or 'Stroke' })
end

local function Padding(Parent, T, B, L, R)
    return Create('UIPadding', {
        PaddingTop = UDim.new(0, T or 0), PaddingBottom = UDim.new(0, B or 0),
        PaddingLeft = UDim.new(0, L or 0), PaddingRight = UDim.new(0, R or 0),
        Parent = Parent,
    })
end

local function ListLayout(Parent, Pad, Dir)
    return Create('UIListLayout', {
        Padding = UDim.new(0, Pad or 0),
        FillDirection = Dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Parent,
    })
end

local function Text(Props)
    local ColorKey = Props.ColorKey or 'Text'
    Props.ColorKey = nil
    local Defaults = {
        BackgroundTransparency = 1, BorderSizePixel = 0, Font = Library.Font, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
    }
    for K, V in pairs(Defaults) do
        if Props[K] == nil then Props[K] = V end
    end
    return Themed(Create('TextLabel', Props), { TextColor3 = ColorKey })
end

local function Blank(Props)
    Props.BackgroundTransparency = 1
    Props.BorderSizePixel = 0
    return Create('Frame', Props)
end

local function MakeFader(Host, Content)
    local Group = Create('CanvasGroup', {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
        Visible = false, ZIndex = Content.ZIndex, Parent = Host,
    })
    local Fader = { Group = Group, Token = 0 }
    function Fader:Fade(From, To, Time, Done)
        self.Token = self.Token + 1
        local Token = self.Token
        Group.GroupTransparency = From
        Group.Visible = true
        Content.Parent = Group
        Tween(Group, { GroupTransparency = To }, Time)
        task.delay(Time + 0.03, function()
            if Token ~= self.Token then return end
            pcall(function()
                Content.Parent = Host
                Group.Visible = false
            end)
            if Done then Done() end
        end)
    end
    return Fader
end

local function IconBar(Parent, W, H, X, Y, Rot, Color, ColorKey)
    local F = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, X, 0.5, Y),
        Size = UDim2.fromOffset(W, H), Rotation = Rot or 0, ZIndex = Parent.ZIndex + 1, Parent = Parent,
    })
    Corner(F, 'full')
    if ColorKey then Themed(F, { BackgroundColor3 = ColorKey }) else F.BackgroundColor3 = Color end
    return F
end

local function ChevronIcon(Parent, ColorKey, Props)
    local Holder = Blank({ Size = UDim2.fromOffset(12, 12), ZIndex = Parent.ZIndex, Parent = Parent })
    for K, V in pairs(Props or {}) do Holder[K] = V end
    local L = IconBar(Holder, 7, 2, -2, 0, 45, nil, ColorKey)
    local R = IconBar(Holder, 7, 2, 2, 0, -45, nil, ColorKey)
    local Icon = { Holder = Holder }
    function Icon:Set(Up, Animate)
        local A, B = Up and -45 or 45, Up and 45 or -45
        if Animate then
            Tween(L, { Rotation = A }, 0.35, Back); Tween(R, { Rotation = B }, 0.35, Back)
        else
            L.Rotation = A; R.Rotation = B
        end
    end
    return Icon
end

local function CheckIcon(Parent, Color, ColorKey, Props)
    local Holder = Blank({
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(16, 16), ZIndex = Parent.ZIndex, Parent = Parent,
    })
    for K, V in pairs(Props or {}) do Holder[K] = V end
    local Scale = Create('UIScale', { Parent = Holder })
    local A = IconBar(Holder, 5, 2, -3, 1.5, 45, Color, ColorKey)
    local B = IconBar(Holder, 9, 2, 1.25, -0.25, -45, Color, ColorKey)
    local Icon = { Holder = Holder, Scale = Scale, Shown = nil }
    function Icon:Set(Show, Animate)
        local T = Show and 0 or 1
        if Animate then
            Tween(A, { BackgroundTransparency = T }, 0.15); Tween(B, { BackgroundTransparency = T }, 0.15)
            if Show and not self.Shown then Scale.Scale = 0.2; Tween(Scale, { Scale = 1 }, 0.35, Back) end
        else
            A.BackgroundTransparency = T; B.BackgroundTransparency = T
        end
        self.Shown = Show
    end
    return Icon
end

local function Ripple(Button, ColorKey)
    Button.ClipsDescendants = true
    local Scale = Library.UIScale and Library.UIScale.Scale or 1
    local P, S = Button.AbsolutePosition, Button.AbsoluteSize
    local M = Library.MousePosition and Library.MousePosition() or UserInputService:GetMouseLocation()
    local X, Y = M.X - P.X, M.Y - P.Y
    if X < 0 or Y < 0 or X > S.X or Y > S.Y then X, Y = S.X / 2, S.Y / 2 end
    local Size = math.max(S.X, S.Y) * 2.2 / Scale
    local Circle = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(X / Scale, Y / Scale),
        Size = UDim2.fromOffset(0, 0), BackgroundColor3 = Library.Theme[ColorKey or 'Accent'],
        BackgroundTransparency = 0.7, ZIndex = Button.ZIndex + 1, Parent = Button,
    })
    Corner(Circle, 'full')
    Tween(Circle, { Size = UDim2.fromOffset(Size, Size), BackgroundTransparency = 1 }, 0.55, Enum.EasingStyle.Quad)
    task.delay(0.6, function() Circle:Destroy() end)
end

local function PointerPos(Input)
    local Inset = GuiService:GetGuiInset()
    return Vector2.new(Input.Position.X + Inset.X, Input.Position.Y + Inset.Y)
end

local function IsOver(Frame, Point)
    if not Frame or not Frame.Visible then return false end
    Point = Point or UserInputService:GetMouseLocation()
    local P, S = Frame.AbsolutePosition, Frame.AbsoluteSize
    return Point.X >= P.X and Point.X <= P.X + S.X and Point.Y >= P.Y and Point.Y <= P.Y + S.Y
end

function Library:Create(Class, Props) return Create(Class, Props) end

function Library:SafeCallback(F, ...)
    if type(F) ~= 'function' then return end
    local Ok, Err = pcall(F, ...)
    if not Ok then warn('[UI] Callback error: ' .. tostring(Err)) end
end

function Library:GiveSignal(Signal)
    table.insert(self.Signals, Signal)
    return Signal
end

function Library:OnUnload(Callback)
    table.insert(self.UnloadCallbacks, Callback)
end

function Library:AttemptSave()
    if self.AutoSaveConfig then self:SaveConfig(self.AutoSaveConfig) end
end

function Library:UpdateDependencyBoxes()
    for _, Box in ipairs(self.DependencyBoxes) do Box:Update() end
end

local function MakeDraggable(Handle, Target)
    local State = { Moved = false }
    local Dragging, StartPoint, StartPos

    Handle.InputBegan:Connect(function(Input)
        if not IsClick(Input) then return end
        Dragging, State.Moved = true, false
        StartPoint, StartPos = Input.Position, Target.Position
        local Conn
        Conn = Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                Dragging = false
                Conn:Disconnect()
            end
        end)
    end)

    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if Dragging and (Input.UserInputType == Move or Input.UserInputType == Touch) then
            local Delta = Input.Position - StartPoint
            if Delta.Magnitude > 4 then State.Moved = true end
            Target.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
        end
    end))

    return State
end

function Library:MakeDraggable(Handle, Target) return MakeDraggable(Handle, Target or Handle) end

local function GetPlayerNames()
    local Names = {}
    for _, Plr in ipairs(Players:GetPlayers()) do table.insert(Names, Plr.Name) end
    table.sort(Names)
    return Names
end

local function GetTeamNames()
    local Names = {}
    for _, Team in ipairs(game:GetService('Teams'):GetTeams()) do table.insert(Names, Team.Name) end
    table.sort(Names)
    return Names
end

local ScreenGui = Create('ScreenGui', {
    Name = HttpService:GenerateGUID(false),
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 999999,
})
pcall(function()
    if protectgui then protectgui(ScreenGui) elseif syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
end)
local Mounted = pcall(function() ScreenGui.Parent = (gethui and gethui()) or CoreGui end)
if not Mounted or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild('PlayerGui')
end
Library.ScreenGui = ScreenGui

local OverlayGui = Create('ScreenGui', {
    Name = HttpService:GenerateGUID(false), ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000000,
})
pcall(function()
    if protectgui then protectgui(OverlayGui) elseif syn and syn.protect_gui then syn.protect_gui(OverlayGui) end
end)
OverlayGui.Parent = ScreenGui.Parent
Library.OverlayGui = OverlayGui

local InsetProbe = Create('ScreenGui', { Name = HttpService:GenerateGUID(false), IgnoreGuiInset = false, ResetOnSpawn = false, DisplayOrder = -1 })
pcall(function()
    if protectgui then protectgui(InsetProbe) elseif syn and syn.protect_gui then syn.protect_gui(InsetProbe) end
end)
InsetProbe.Parent = ScreenGui.Parent
Library.InsetProbe = InsetProbe

local function GuiOffset()
    local A, B = ScreenGui.AbsoluteSize, InsetProbe.AbsoluteSize
    if B.Y <= 0 then
        local Inset = GuiService:GetGuiInset()
        return Vector2.new(Inset.X, Inset.Y)
    end
    return Vector2.new((A.X - B.X) / 2, A.Y - B.Y)
end

function Library.MousePosition(Input)
    local P
    if Input and Input.Position and Input.UserInputType ~= Enum.UserInputType.Keyboard then
        P = Vector2.new(Input.Position.X, Input.Position.Y)
    else
        local M, Inset = UserInputService:GetMouseLocation(), GuiService:GetGuiInset()
        P = Vector2.new(M.X - Inset.X, M.Y - Inset.Y)
    end
    return P + GuiOffset()
end

local Overlay = Blank({ Name = 'Overlay', Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = OverlayGui })
Library.Overlay = Overlay

local Catcher = Create('TextButton', {
    Name = 'DropdownCatcher', BackgroundTransparency = 1, Text = '', AutoButtonColor = false,
    Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 15, Parent = Overlay,
})
Catcher.MouseButton1Down:Connect(function() Library:CloseDropdown() end)
Catcher.MouseButton2Down:Connect(function() Library:CloseDropdown() end)

Library.PopupStack = {}

function Library:UpdateCatchers()
    local N = #self.PopupStack
    Catcher.Visible = N > 0
    self.OpenDropdown = self.PopupStack[N]
    for I, P in ipairs(self.PopupStack) do
        if P.InnerCatcher then P.InnerCatcher.Visible = I < N end
    end
end

local function PopTop(Stack)
    local Top = Stack[#Stack]
    if Top.IsOpen then Top:Close() end
    if Stack[#Stack] == Top then table.remove(Stack) end
end

function Library:PushPopup(P)
    local Keep = {}
    local A = P.ParentPopup
    while A do
        Keep[A] = true
        A = A.ParentPopup
    end
    while #self.PopupStack > 0 and not Keep[self.PopupStack[#self.PopupStack]] do PopTop(self.PopupStack) end
    table.insert(self.PopupStack, P)
    self:UpdateCatchers()
    return #self.PopupStack
end

function Library:RemovePopup(P)
    local I = table.find(self.PopupStack, P)
    if not I then return end
    while #self.PopupStack > I do PopTop(self.PopupStack) end
    I = table.find(self.PopupStack, P)
    if I then table.remove(self.PopupStack, I) end
    if P.InnerCatcher then P.InnerCatcher.Visible = false end
    self:UpdateCatchers()
end

function Library:CloseAbove(P)
    local I = table.find(self.PopupStack, P)
    if not I then return end
    while #self.PopupStack > I do PopTop(self.PopupStack) end
    self:UpdateCatchers()
end

local Tooltip = Text({
    Visible = false, BackgroundTransparency = 0, AutomaticSize = Enum.AutomaticSize.XY,
    Size = UDim2.fromOffset(0, 0), TextSize = 12, ZIndex = 200, Parent = Overlay,
})
Themed(Tooltip, { BackgroundColor3 = 'Element' })
Corner(Tooltip, 5); Stroke(Tooltip); Padding(Tooltip, 5, 5, 8, 8)

function Library:AddToolTip(Str, Hover)
    Hover.MouseEnter:Connect(function()
        Tooltip.Text = Str
        Tooltip.Visible = true
        Library.TooltipOwner = Hover
        Tooltip.TextTransparency, Tooltip.BackgroundTransparency = 1, 1
        Tween(Tooltip, { TextTransparency = 0, BackgroundTransparency = 0 }, 0.2)
    end)
    Hover.MouseLeave:Connect(function()
        if Library.TooltipOwner == Hover then
            Tooltip.Visible = false
            Library.TooltipOwner = nil
        end
    end)
end

local NotifyHolder = Blank({
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
    Size = UDim2.fromOffset(280, 500), Parent = Overlay,
})
local NotifyLayout = ListLayout(NotifyHolder, 8)
NotifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

function Library:Notify(Message, Time)
    Time = Time or 5
    if self.IslandApi and self.IslandApi.Visible and self.IslandNotifications ~= false then
        return self.IslandApi:Notify(Message, Time)
    end
    local Wrapper = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = NotifyHolder })
    local Card = Create('Frame', {
        Position = UDim2.new(1, 20, 0, 0), Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = Wrapper,
    })
    Themed(Card, { BackgroundColor3 = 'Card' }); Corner(Card, 8); Stroke(Card)
    Padding(Card, 10, 10, 12, 12); ListLayout(Card, 6)

    Text({ Text = self.Title or 'Notification', Font = self.FontBold, TextSize = 12, ColorKey = 'Accent',
        Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = Card })
    Text({ Text = tostring(Message), TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Parent = Card })
    local BarBg = Create('Frame', { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 3, Parent = Card })
    Themed(BarBg, { BackgroundColor3 = 'Element' })
    local Bar = Create('Frame', { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = BarBg })
    Themed(Bar, { BackgroundColor3 = 'Accent' })

    Tween(Card, { Position = UDim2.new(0, 0, 0, 0) }, 0.25)
    Tween(Bar, { Size = UDim2.fromScale(0, 1) }, Time)
    task.delay(Time, function()
        Tween(Card, { Position = UDim2.new(1, 20, 0, 0) }, 0.25)
        task.wait(0.27)
        Wrapper:Destroy()
    end)
end

local Funcs = {}

local function AddElement(Box, Frame, SearchName, NoSearch)
    Box.Order = Box.Order + 1
    Frame.LayoutOrder = Box.Order
    Frame.Parent = Box.Container
    if Box.Groupbox and not NoSearch then
        table.insert(Box.Groupbox.Elements, { Frame = Frame, Name = string.lower(tostring(SearchName or '')) })
    elseif Box.SearchEntry and SearchName then
        Box.SearchEntry.Name = Box.SearchEntry.Name .. ' ' .. string.lower(tostring(SearchName))
    end
end

local function KeyName(K)
    if typeof(K) == 'EnumItem' then return K.Name end
    if type(K) == 'table' then return K.Value end
    if type(K) == 'string' then return K end
end

local function MatchKey(Input, Name)
    if Name == 'MB1' then return Input.UserInputType == MB1 end
    if Name == 'MB2' then return Input.UserInputType == MB2 end
    return Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Name
end

local function PointerOf(Input)
    return Library.MousePosition(Input)
end

local TextService = game:GetService('TextService')
local CHAR_FADE = 0.22

local function SplitChars(S)
    local T = {}
    local Ok = pcall(function()
        for _, C in utf8.codes(S) do table.insert(T, utf8.char(C)) end
    end)
    if not Ok then
        T = {}
        for I = 1, #S do T[I] = string.sub(S, I, I) end
    end
    return T
end

local function EscapeRich(S)
    S = string.gsub(S, '&', '&amp;')
    S = string.gsub(S, '<', '&lt;')
    S = string.gsub(S, '>', '&gt;')
    return S
end

local function SmoothInput(Parent, Props)
    Props = Props or {}
    local TextSize = Props.TextSize or 13
    local Font = Props.Font or Library.Font
    local Z = Props.ZIndex or Parent.ZIndex
    local Censor = Props.Censor
    local DOT, GAP = 6, 3

    local Clip = Blank({
        Position = Props.Position or UDim2.new(), Size = Props.Size or UDim2.fromScale(1, 1),
        ClipsDescendants = true, ZIndex = Z, Parent = Parent,
    })
    local Ruler = Blank({ Size = UDim2.fromOffset(100, 1), ZIndex = Z, Parent = Clip })
    local Slide = Blank({ Size = UDim2.fromScale(1, 1), ZIndex = Z, Parent = Clip })
    local Mirror = Text({
        Text = '', Font = Font, TextSize = TextSize, Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X, ZIndex = Z + 1, Visible = not Censor, Parent = Slide,
    })
    local Dots = Blank({
        Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = Z + 1,
        Visible = Censor and true or false, Parent = Slide,
    })
    local DotLayout = ListLayout(Dots, GAP, Enum.FillDirection.Horizontal)
    DotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    local Placeholder = Text({
        Text = Props.Placeholder or '', ColorKey = 'DimText', Font = Font, TextSize = TextSize,
        Size = UDim2.fromScale(1, 1), RichText = false, TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Z + 1, Parent = Clip,
    })
    local Caret = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(2, TextSize + 3), BackgroundTransparency = 1, ZIndex = Z + 3, Parent = Slide,
    })
    Themed(Caret, { BackgroundColor3 = 'Accent' }); Corner(Caret, 'full')
    local Box = Create('TextBox', {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Font, TextSize = TextSize,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Text = Props.Text or '',
        PlaceholderText = '', TextTransparency = 1, ZIndex = Z + 4, Parent = Clip,
    })
    Themed(Box, { TextColor3 = 'Text' })

    local Chars, Times, DotList = {}, {}, {}
    local RenderConn, Focused, BlinkId, ScrollX = nil, false, 0, 0

    local function Render()
        local Now, Busy, Parts = os.clock(), false, {}
        for I, C in ipairs(Chars) do
            local A = math.clamp((Now - Times[I]) / CHAR_FADE, 0, 1)
            local E = EscapeRich(C)
            if A < 1 then
                Busy = true
                local Eased = 1 - (1 - A) ^ 3
                Parts[I] = string.format('<font transparency="%.2f">%s</font>', 1 - Eased, E)
            else
                Parts[I] = E
            end
        end
        Mirror.Text = table.concat(Parts)
        return Busy
    end

    local function Animate()
        if RenderConn then return end
        RenderConn = RunService.RenderStepped:Connect(function()
            if not Render() and RenderConn then
                RenderConn:Disconnect()
                RenderConn = nil
            end
        end)
    end

    local function Measure(S)
        if Censor then return #SplitChars(S) * (DOT + GAP) end
        return TextService:GetTextSize(S, TextSize, Font, Vector2.new(100000, 1000)).X
    end

    local function UpdateCaret(Instant)
        local Cursor = Box.CursorPosition
        local Prefix = Box.Text
        if Focused and Cursor and Cursor > 0 then Prefix = string.sub(Box.Text, 1, Cursor - 1) end
        local X = Measure(Prefix)
        local Scale = Ruler.AbsoluteSize.X / 100
        if Scale <= 0 then Scale = 1 end
        local Width = Clip.AbsoluteSize.X / Scale
        if not Focused then
            ScrollX = 0
        elseif X - ScrollX > Width - 6 then
            ScrollX = X - Width + 8
        elseif X < ScrollX then
            ScrollX = math.max(0, X - 8)
        end
        local CaretPos = UDim2.new(0, X + (Censor and -2 or 0), 0.5, 0)
        if Instant then
            Caret.Position = CaretPos
            Slide.Position = UDim2.fromOffset(-ScrollX, 0)
        else
            Tween(Caret, { Position = CaretPos }, 0.12)
            Tween(Slide, { Position = UDim2.fromOffset(-ScrollX, 0) }, 0.2)
        end
    end

    local function Blink()
        BlinkId = BlinkId + 1
        local Id = BlinkId
        if not Focused then return end
        Tween(Caret, { BackgroundTransparency = 0 }, 0.08)
        task.spawn(function()
            while Id == BlinkId and Focused do
                task.wait(0.55)
                if Id ~= BlinkId or not Focused then return end
                Tween(Caret, { BackgroundTransparency = 1 }, 0.3, Enum.EasingStyle.Sine)
                task.wait(0.45)
                if Id ~= BlinkId or not Focused then return end
                Tween(Caret, { BackgroundTransparency = 0 }, 0.3, Enum.EasingStyle.Sine)
            end
        end)
    end

    local function SyncDots(Count, Instant)
        while #DotList < Count do
            local D = Create('Frame', {
                BorderSizePixel = 0, Size = UDim2.fromOffset(DOT, DOT), LayoutOrder = #DotList + 1,
                ZIndex = Z + 1, Parent = Dots,
            })
            Themed(D, { BackgroundColor3 = 'Text' }); Corner(D, 'full')
            if not Instant then
                local S = Create('UIScale', { Scale = 0, Parent = D })
                Tween(S, { Scale = 1 }, 0.3, Back)
            end
            table.insert(DotList, D)
        end
        while #DotList > Count do
            local D = table.remove(DotList)
            Tween(D, { Size = UDim2.fromOffset(0, DOT), BackgroundTransparency = 1 }, 0.12)
            task.delay(0.13, function() D:Destroy() end)
        end
    end

    local function OnText(Instant)
        local New = SplitChars(Box.Text)
        local P, S = 0, 0
        while P < #New and P < #Chars and New[P + 1] == Chars[P + 1] do P = P + 1 end
        while S < #New - P and S < #Chars - P and New[#New - S] == Chars[#Chars - S] do S = S + 1 end
        local Now = (Instant or (#New - P - S) > 40) and -1000 or os.clock()
        local NewTimes = {}
        for I = 1, #New do
            if I <= P then
                NewTimes[I] = Times[I] or -1000
            elseif I > #New - S then
                NewTimes[I] = Times[#Chars - (#New - I)] or -1000
            else
                NewTimes[I] = Now
            end
        end
        Chars, Times = New, NewTimes
        if Censor then SyncDots(#New, Instant) end
        Render()
        if not Instant then Animate() end
        local Empty = Box.Text == ''
        Tween(Placeholder, {
            TextTransparency = Empty and 0 or 1, Position = UDim2.fromOffset(Empty and 0 or 12, 0),
        }, Instant and 0 or 0.22)
        UpdateCaret(Instant)
        Blink()
    end

    Box:GetPropertyChangedSignal('Text'):Connect(function() OnText(false) end)
    Box:GetPropertyChangedSignal('CursorPosition'):Connect(function()
        UpdateCaret(false)
        Blink()
    end)
    Box.Focused:Connect(function()
        Focused = true
        Caret.Size = UDim2.fromOffset(2, 0)
        Tween(Caret, { Size = UDim2.fromOffset(2, TextSize + 3) }, 0.3, Back)
        UpdateCaret(false)
        Blink()
    end)
    Box.FocusLost:Connect(function()
        Focused = false
        BlinkId = BlinkId + 1
        Tween(Caret, { BackgroundTransparency = 1 }, 0.15)
        UpdateCaret(false)
    end)
    Clip:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() UpdateCaret(true) end)
    OnText(true)

    return { Box = Box, Clip = Clip, Placeholder = Placeholder, Caret = Caret }
end
Library.SmoothInput = SmoothInput

local function CreatePopup(Anchor, Width, Height, Align)
    local Popup = { IsOpen = false, ButtonFrame = Anchor, Width = Width, Height = Height }
    local Frame = Create('Frame', {
        Visible = false, Active = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(Width, Height),
        ZIndex = 20, Parent = Overlay,
    })
    Corner(Frame, 8)
    local PopStroke = Stroke(Frame)
    local Body = Create('Frame', { BorderSizePixel = 0, Active = true, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = Frame })
    Themed(Body, { BackgroundColor3 = 'Card' }); Corner(Body, 8)
    local BodyFader = MakeFader(Frame, Body)
    local PopScale = Create('UIScale', { Parent = Frame })
    local Anim = Create('NumberValue', { Value = 1 })
    Popup.Frame, Popup.Body, Popup.ListFrame, Popup.Scale = Frame, Body, Frame, PopScale

    local Inner = Create('TextButton', {
        BackgroundTransparency = 1, Text = '', AutoButtonColor = false, Size = UDim2.fromScale(1, 1),
        Visible = false, ZIndex = 90, Parent = Frame,
    })
    Inner.MouseButton1Down:Connect(function() Library:CloseAbove(Popup) end)
    Popup.InnerCatcher = Inner

    local function BaseScale() return Library.UIScale and Library.UIScale.Scale or 1 end
    Anim:GetPropertyChangedSignal('Value'):Connect(function() PopScale.Scale = BaseScale() * Anim.Value end)

    function Popup:Reposition()
        if self.HeightFn then self.Height = self.HeightFn() end
        local Scale = BaseScale()
        local P, S = Anchor.AbsolutePosition, Anchor.AbsoluteSize
        local Screen = ScreenGui.AbsoluteSize
        local W, H = self.Width * Scale, self.Height * Scale
        local X = math.clamp(Align == 'Left' and P.X or (P.X + S.X - W), 8, math.max(8, Screen.X - W - 8))
        local Y = P.Y + S.Y + 6
        if Y + H > Screen.Y - 8 then Y = math.max(8, P.Y - 6 - H) end
        Frame.Position = UDim2.fromOffset(X, Y)
        Frame.Size = UDim2.fromOffset(self.Width, self.Height)
        PopScale.Scale = Scale * Anim.Value
    end

    function Popup:Open()
        if self.IsOpen then return end
        self.IsOpen = true
        Frame.ZIndex = 20 + Library:PushPopup(self) * 5
        if self.OnOpen then self.OnOpen() end
        Anim.Value = 0.88
        PopStroke.Transparency = 1
        Frame.Visible = true
        self:Reposition()
        BodyFader:Fade(1, 0, 0.2)
        Tween(Anim, { Value = 1 }, 0.35, Back)
        Tween(PopStroke, { Transparency = 0 }, 0.2)
    end

    function Popup:Close()
        if not self.IsOpen then return end
        self.IsOpen = false
        Library:RemovePopup(self)
        if self.OnClose then self.OnClose() end
        Tween(Anim, { Value = 0.92 }, 0.15)
        Tween(PopStroke, { Transparency = 1 }, 0.15)
        BodyFader:Fade(0, 1, 0.15, function()
            if not Popup.IsOpen then Frame.Visible = false end
        end)
    end

    function Popup:Toggle() if self.IsOpen then self:Close() else self:Open() end end
    return Popup
end

local function GetAddonHolder(Owner, Row)
    if Owner.AddonHolder then return Owner.AddonHolder end
    local Holder = Blank({
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(0, 20),
        AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3, Parent = Row,
    })
    local Layout = ListLayout(Holder, 6, Enum.FillDirection.Horizontal)
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    Layout.VerticalAlignment = Enum.VerticalAlignment.Center
    Owner.AddonHolder = Holder
    Owner.AddonCount = 0
    return Holder
end

local MODE_SHORT = { Toggle = 'T', Hold = 'H', Always = 'A' }

local function CreateKeyPicker(Owner, Row, Idx, Info)
    Info = Info or {}
    local KeyPicker = {
        Value = KeyName(Info.Default) or 'None',
        Mode = Info.Mode or 'Toggle',
        Modes = Info.Modes or { 'Toggle', 'Hold', 'Always' },
        Toggled = false,
        Type = 'KeyPicker',
        Text = Info.Text or Idx,
        SyncToggleState = Info.SyncToggleState,
        Callback = Info.Callback,
        ChangedCallback = Info.ChangedCallback,
        NoConfig = Info.NoConfig,
    }
    local Binding = false
    local Holder = GetAddonHolder(Owner, Row)
    Owner.AddonCount = Owner.AddonCount + 1

    local Button = Create('TextButton', {
        AutoButtonColor = false, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
        Font = Library.FontMedium, TextSize = 11, Text = '', RichText = true, ZIndex = 4,
        LayoutOrder = Owner.AddonCount, Visible = not Info.NoUI, Parent = Holder,
    })
    Themed(Button, { BackgroundColor3 = 'Element', TextColor3 = 'SubText' })
    Corner(Button, 4); Padding(Button, 0, 0, 7, 7)
    local BtnStroke = Stroke(Button)
    local BtnScale = Create('UIScale', { Parent = Button })

    function KeyPicker:Display()
        if Binding then return end
        if #self.Modes <= 1 then
            Button.Text = '[' .. EscapeRich(self.Value) .. ']'
        elseif self.Mode == 'Always' then
            Button.Text = '[Always]'
        else
            Button.Text = string.format('[%s] <font color="#%s">%s</font>',
                EscapeRich(self.Value), Library.Theme.DimText:ToHex(), MODE_SHORT[self.Mode] or '')
        end
    end

    function KeyPicker:GetState()
        if self.Mode == 'Always' then return true end
        if self.Mode == 'Hold' then
            local K = self.Value
            if K == 'None' then return false end
            if K == 'MB1' then return UserInputService:IsMouseButtonPressed(MB1) end
            if K == 'MB2' then return UserInputService:IsMouseButtonPressed(MB2) end
            local Ok, Code = pcall(function() return Enum.KeyCode[K] end)
            return (Ok and Code and UserInputService:IsKeyDown(Code)) or false
        end
        return self.Toggled
    end

    function KeyPicker:SetValue(Data)
        if type(Data) == 'table' then
            self.Value = KeyName(Data[1]) or self.Value
            if Data[2] then self:SetMode(Data[2], true) end
        else
            self.Value = KeyName(Data) or 'None'
        end
        self:Display()
        Library:SafeCallback(self.ChangedCallback, self.Value)
        Library:SafeCallback(self.Changed, self.Value)
    end

    function KeyPicker:OnClick(F) self.Clicked = F end
    function KeyPicker:OnChanged(F) self.Changed = F end

    local function Fire(State)
        if State == nil then State = KeyPicker:GetState() end
        Library:SafeCallback(KeyPicker.Callback, State)
        Library:SafeCallback(KeyPicker.Clicked, State)
    end

    local ITEM = 26
    local Menu = CreatePopup(Button, 124, #KeyPicker.Modes * (ITEM + 2) + 8)
    Menu.ParentPopup = Owner.Box and Owner.Box.Popup
    local MenuList = Blank({ Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 21, Parent = Menu.Body })
    ListLayout(MenuList, 2)
    local ModeRefs = {}

    local function PaintModes(Animate)
        for Mode, Ref in pairs(ModeRefs) do
            local Sel = KeyPicker.Mode == Mode
            Ref.Check:Set(Sel, Animate)
            local Color = Sel and Library.Theme.Accent or Library.Theme.SubText
            if Animate then Tween(Ref.Label, { TextColor3 = Color }, 0.15) else Ref.Label.TextColor3 = Color end
        end
    end
    Menu.OnOpen = function() PaintModes(false) end

    function KeyPicker:SetMode(Mode, Silent)
        if not table.find(self.Modes, Mode) then return end
        self.Mode = Mode
        self.Toggled = false
        PaintModes(true)
        self:Display()
        if not Silent then Library:AttemptSave() end
    end

    for I, Mode in ipairs(KeyPicker.Modes) do
        local Item = Create('TextButton', {
            AutoButtonColor = false, Text = '', BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ITEM),
            LayoutOrder = I, ZIndex = 22, Parent = MenuList,
        })
        Themed(Item, { BackgroundColor3 = 'Hover' }); Corner(Item, 5)
        local L = Create('TextLabel', {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0),
            Font = Library.FontMedium, TextSize = 12, Text = Mode, TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Library.Theme.SubText, ZIndex = 23, Parent = Item,
        })
        local Check = CheckIcon(Item, nil, 'Accent', { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0) })
        ModeRefs[Mode] = { Label = L, Check = Check }
        Item.MouseEnter:Connect(function()
            Tween(Item, { BackgroundTransparency = 0 }, 0.12)
            Tween(L, { Position = UDim2.fromOffset(14, 0) }, 0.2)
        end)
        Item.MouseLeave:Connect(function()
            Tween(Item, { BackgroundTransparency = 1 }, 0.12)
            Tween(L, { Position = UDim2.fromOffset(10, 0) }, 0.2)
        end)
        Item.MouseButton1Click:Connect(function()
            KeyPicker:SetMode(Mode)
            task.delay(0.12, function() Menu:Close() end)
        end)
    end
    PaintModes(false)

    local function StartBinding()
        Binding = true
        Library.Binding = true
        Tween(BtnStroke, { Color = Library.Theme.Accent })
        Tween(Button, { TextColor3 = Library.Theme.Accent })
        task.spawn(function()
            local N = 0
            while Binding do
                N = N % 3 + 1
                Button.Text = string.rep('.', N)
                task.wait(0.25)
            end
        end)
        local Conn
        Conn = UserInputService.InputBegan:Connect(function(Input)
            local Key
            if Input.UserInputType == Enum.UserInputType.Keyboard then
                Key = Input.KeyCode.Name
                if Key == 'Escape' or Key == 'Backspace' then Key = 'None' end
            elseif Input.UserInputType == MB1 then
                Key = 'MB1'
            elseif Input.UserInputType == MB2 then
                Key = 'MB2'
            end
            if Key then
                Conn:Disconnect()
                Binding = false
                Tween(BtnStroke, { Color = Library.Theme.Stroke })
                Tween(Button, { TextColor3 = Library.Theme.SubText })
                BtnScale.Scale = 0.8
                Tween(BtnScale, { Scale = 1 }, 0.35, Back)
                KeyPicker:SetValue(Key)
                Library:AttemptSave()
                task.defer(function() Library.Binding = false end)
            end
        end)
    end

    local Held, LongPressed, PressId = false, false, 0
    Button.MouseEnter:Connect(function() if not Binding then Tween(BtnStroke, { Color = Lerp('Stroke', 'Accent', 0.5) }) end end)
    Button.MouseLeave:Connect(function()
        Held = false
        Tween(BtnScale, { Scale = 1 }, 0.2)
        if not Binding then Tween(BtnStroke, { Color = Library.Theme.Stroke }) end
    end)
    Button.MouseButton1Down:Connect(function()
        Held, LongPressed = true, false
        PressId = PressId + 1
        local Id = PressId
        Tween(BtnScale, { Scale = 0.92 }, 0.1)
        task.delay(0.45, function()
            if Held and Id == PressId and not Binding then
                LongPressed = true
                Menu:Open()
            end
        end)
    end)
    Button.MouseButton1Up:Connect(function()
        Held = false
        Tween(BtnScale, { Scale = 1 }, 0.3, Back)
    end)
    Button.MouseButton1Click:Connect(function()
        if LongPressed or Binding then return end
        StartBinding()
    end)
    Button.MouseButton2Click:Connect(function() Menu:Toggle() end)

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input)
        if Binding or Library.Binding or KeyPicker.Value == 'None' then return end
        if UserInputService:GetFocusedTextBox() then return end
        if not MatchKey(Input, KeyPicker.Value) then return end
        local Sync = KeyPicker.SyncToggleState and Owner.Type == 'Toggle'
        if KeyPicker.Mode == 'Toggle' then
            KeyPicker.Toggled = not KeyPicker.Toggled
            if Sync then Owner:SetValue(KeyPicker.Toggled) end
            Fire()
        elseif KeyPicker.Mode == 'Hold' then
            if Sync then Owner:SetValue(true) end
            Fire(true)
        end
    end))

    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if KeyPicker.Mode == 'Hold' and KeyPicker.Value ~= 'None' and MatchKey(Input, KeyPicker.Value) then
            if KeyPicker.SyncToggleState and Owner.Type == 'Toggle' then Owner:SetValue(false) end
            Fire(false)
        end
    end))

    KeyPicker:Display()
    if Owner.Addons then table.insert(Owner.Addons, KeyPicker) end
    Options[Idx] = KeyPicker
    return Owner
end

local function CreateColorPicker(Owner, Row, Idx, Info)
    Info = Info or {}
    local Default = Info.Default or Color3.new(1, 1, 1)
    local HasTr = Info.Transparency ~= nil
    local Picker = {
        Type = 'ColorPicker', Value = Default, Transparency = Info.Transparency or 0,
        Callback = Info.Callback, NoConfig = Info.NoConfig, Title = Info.Title or Info.Text or Idx,
    }
    Picker.Hue, Picker.Sat, Picker.Vib = Default:ToHSV()

    local Holder = GetAddonHolder(Owner, Row)
    Owner.AddonCount = Owner.AddonCount + 1
    local Swatch = Create('TextButton', {
        AutoButtonColor = false, Text = '', BorderSizePixel = 0, Size = UDim2.fromOffset(28, 16),
        LayoutOrder = Owner.AddonCount, ZIndex = 4, Parent = Holder,
    })
    Corner(Swatch, 4)
    local SwStroke = Stroke(Swatch)
    local SwScale = Create('UIScale', { Parent = Swatch })

    local W = 226
    local InputY = HasTr and 204 or 184
    local Popup = CreatePopup(Swatch, W, InputY + 40)
    Popup.ParentPopup = Owner.Box and Owner.Box.Popup
    local Body = Popup.Body
    local White = Color3.new(1, 1, 1)

    Text({ Text = tostring(Picker.Title), Font = Library.FontBold, Position = UDim2.fromOffset(12, 9),
        Size = UDim2.new(1, -24, 0, 18), ZIndex = 21, Parent = Body })

    local function Ring(Parent, W2, H2)
        local R = Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(W2, H2),
            ZIndex = Parent.ZIndex + 3, Parent = Parent,
        })
        Corner(R, 'full')
        Create('UIStroke', { Color = White, Thickness = 2, Parent = R })
        return R, Create('UIScale', { Parent = R })
    end

    local Map = Create('Frame', { BorderSizePixel = 0, Position = UDim2.fromOffset(12, 36), Size = UDim2.fromOffset(170, 140), ZIndex = 21, Parent = Body })
    Corner(Map, 6)
    local WhiteFade = Create('Frame', { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = White, ZIndex = 22, Parent = Map })
    Corner(WhiteFade, 6)
    Create('UIGradient', { Transparency = NumberSequence.new(0, 1), Parent = WhiteFade })
    local BlackFade = Create('Frame', { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 23, Parent = Map })
    Corner(BlackFade, 6)
    Create('UIGradient', { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = BlackFade })
    local SVCursor, SVScale = Ring(Map, 12, 12)
    SVCursor.ZIndex = 26
    local MapHit = Create('TextButton', { BackgroundTransparency = 1, Text = '', Size = UDim2.fromScale(1, 1), ZIndex = 27, Parent = Map })

    local HueBar = Create('Frame', { BorderSizePixel = 0, BackgroundColor3 = White, Position = UDim2.fromOffset(192, 36), Size = UDim2.fromOffset(22, 140), ZIndex = 21, Parent = Body })
    Corner(HueBar, 6)
    local Keys = {}
    for I = 0, 6 do table.insert(Keys, ColorSequenceKeypoint.new(I / 6, Color3.fromHSV((I / 6) % 1, 1, 1))) end
    Create('UIGradient', { Rotation = 90, Color = ColorSequence.new(Keys), Parent = HueBar })
    local HueCursor, HueScale = Ring(HueBar, 26, 7)
    local HueHit = Create('TextButton', { BackgroundTransparency = 1, Text = '', Size = UDim2.fromScale(1, 1), ZIndex = 27, Parent = HueBar })

    local TrBar, TrCursor, TrScale, TrHit
    if HasTr then
        TrBar = Create('Frame', { BorderSizePixel = 0, Position = UDim2.fromOffset(12, 184), Size = UDim2.fromOffset(202, 12), ZIndex = 21, Parent = Body })
        Corner(TrBar, 'full')
        Create('UIGradient', { Transparency = NumberSequence.new(0, 1), Parent = TrBar })
        TrCursor, TrScale = Ring(TrBar, 7, 18)
        TrHit = Create('TextButton', { BackgroundTransparency = 1, Text = '', Size = UDim2.new(1, 0, 1, 8), Position = UDim2.fromOffset(0, -4), ZIndex = 27, Parent = TrBar })
    end

    local function Field(X, Width, Placeholder)
        local Bg = Create('Frame', { BorderSizePixel = 0, Position = UDim2.fromOffset(X, InputY), Size = UDim2.fromOffset(Width, 28), ZIndex = 21, Parent = Body })
        Themed(Bg, { BackgroundColor3 = 'Element' }); Corner(Bg, 6)
        local S = Stroke(Bg)
        local In = SmoothInput(Bg, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), TextSize = 12, ZIndex = 22, Placeholder = Placeholder })
        In.Box.Focused:Connect(function() Tween(S, { Color = Library.Theme.Accent }) end)
        In.Box.FocusLost:Connect(function() Tween(S, { Color = Library.Theme.Stroke }) end)
        return In
    end
    local HexIn = Field(12, 82, '#hex')
    local RgbIn = Field(100, 114, 'r, g, b')

    function Picker:Display(Speed)
        self.Value = Color3.fromHSV(self.Hue, self.Sat, self.Vib)
        Tween(Swatch, { BackgroundColor3 = self.Value, BackgroundTransparency = self.Transparency }, Speed or 0.2)
        Map.BackgroundColor3 = Color3.fromHSV(self.Hue, 1, 1)
        local T = Speed or 0.12
        Tween(SVCursor, { Position = UDim2.fromScale(self.Sat, 1 - self.Vib) }, T)
        Tween(HueCursor, { Position = UDim2.new(0.5, 0, self.Hue, 0) }, T)
        if TrBar then
            TrBar.BackgroundColor3 = self.Value
            Tween(TrCursor, { Position = UDim2.new(self.Transparency, 0, 0.5, 0) }, T)
        end
        if not HexIn.Box:IsFocused() then HexIn.Box.Text = '#' .. string.upper(self.Value:ToHex()) end
        if not RgbIn.Box:IsFocused() then
            RgbIn.Box.Text = string.format('%d, %d, %d',
                math.floor(self.Value.R * 255 + 0.5), math.floor(self.Value.G * 255 + 0.5), math.floor(self.Value.B * 255 + 0.5))
        end
    end

    function Picker:Commit(Speed)
        self:Display(Speed)
        Library:SafeCallback(self.Callback, self.Value)
        Library:SafeCallback(self.Changed, self.Value)
    end

    function Picker:SetValueRGB(Color, Transparency)
        self.Hue, self.Sat, self.Vib = Color:ToHSV()
        if Transparency then self.Transparency = Transparency end
        self:Commit()
    end

    function Picker:SetValue(V, Transparency)
        if typeof(V) == 'Color3' then return self:SetValueRGB(V, Transparency) end
        if type(V) == 'string' then
            local Ok, C = pcall(Color3.fromHex, V)
            if Ok then self:SetValueRGB(C, Transparency) end
            return
        end
        if type(V) == 'table' then
            if V.Hex then
                local Ok, C = pcall(Color3.fromHex, V.Hex)
                if Ok then self:SetValueRGB(C, V.Transparency) end
                return
            end
            self.Hue, self.Sat, self.Vib = V[1] or self.Hue, V[2] or self.Sat, V[3] or self.Vib
            if Transparency then self.Transparency = Transparency end
            self:Commit()
        end
    end

    function Picker:OnChanged(F)
        self.Changed = F
        Library:SafeCallback(F, self.Value)
    end

    local Drag
    local Cursors = { SV = SVScale, Hue = HueScale, Tr = TrScale }
    local function Rel(F, Pt)
        local P, S = F.AbsolutePosition, F.AbsoluteSize
        return math.clamp((Pt.X - P.X) / math.max(S.X, 1), 0, 1), math.clamp((Pt.Y - P.Y) / math.max(S.Y, 1), 0, 1)
    end
    local function Apply(Input)
        local Pt = PointerOf(Input)
        if Drag == 'SV' then
            local X, Y = Rel(Map, Pt)
            Picker.Sat, Picker.Vib = X, 1 - Y
        elseif Drag == 'Hue' then
            local _, Y = Rel(HueBar, Pt)
            Picker.Hue = math.min(Y, 0.999)
        elseif Drag == 'Tr' then
            Picker.Transparency = (Rel(TrBar, Pt))
        end
        Picker:Commit(0)
    end
    local function BindDrag(Hit, Mode)
        if not Hit then return end
        Hit.InputBegan:Connect(function(Input)
            if not IsClick(Input) then return end
            Drag = Mode
            if Cursors[Mode] then Tween(Cursors[Mode], { Scale = 1.35 }, 0.25, Back) end
            Apply(Input)
        end)
    end
    BindDrag(MapHit, 'SV'); BindDrag(HueHit, 'Hue'); BindDrag(TrHit, 'Tr')
    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if Drag and (Input.UserInputType == Move or Input.UserInputType == Touch) then Apply(Input) end
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if Drag and IsClick(Input) then
            if Cursors[Drag] then Tween(Cursors[Drag], { Scale = 1 }, 0.25, Back) end
            Drag = nil
            Library:AttemptSave()
        end
    end))

    HexIn.Box.FocusLost:Connect(function()
        local Hex = string.gsub(HexIn.Box.Text, '[^%x]', '')
        local Ok, C = pcall(Color3.fromHex, Hex)
        if Ok and #Hex == 6 then Picker:SetValueRGB(C); Library:AttemptSave() else Picker:Display() end
    end)
    RgbIn.Box.FocusLost:Connect(function()
        local R, G, B = string.match(RgbIn.Box.Text, '(%d+)%D+(%d+)%D+(%d+)')
        if R then
            Picker:SetValueRGB(Color3.fromRGB(math.clamp(tonumber(R), 0, 255), math.clamp(tonumber(G), 0, 255), math.clamp(tonumber(B), 0, 255)))
            Library:AttemptSave()
        else
            Picker:Display()
        end
    end)

    Swatch.MouseEnter:Connect(function()
        Tween(SwScale, { Scale = 1.12 }, 0.25, Back)
        Tween(SwStroke, { Color = Library.Theme.Accent })
    end)
    Swatch.MouseLeave:Connect(function()
        Tween(SwScale, { Scale = 1 }, 0.2)
        if not Popup.IsOpen then Tween(SwStroke, { Color = Library.Theme.Stroke }) end
    end)
    Swatch.MouseButton1Click:Connect(function() Popup:Toggle() end)
    Popup.OnClose = function() Tween(SwStroke, { Color = Library.Theme.Stroke }) end

    Swatch.BackgroundColor3 = Default
    Swatch.BackgroundTransparency = Picker.Transparency
    Picker:Display(0)
    Picker.Swatch = Swatch
    if Owner.Addons then table.insert(Owner.Addons, Picker) end
    Options[Idx] = Picker
    return Owner
end

local function GearIcon(Parent, ColorKey, Props)
    local Holder = Blank({
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(16, 16), ZIndex = Parent.ZIndex, Parent = Parent,
    })
    for K, V in pairs(Props or {}) do Holder[K] = V end
    local Ring = Create('Frame', {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(8, 8), ZIndex = Holder.ZIndex + 1, Parent = Holder,
    })
    Corner(Ring, 'full')
    local RingStroke = Themed(Create('UIStroke', { Thickness = 2, Parent = Ring }), { Color = ColorKey })
    local Teeth = {}
    for I = 1, 8 do
        local T = Create('Frame', {
            BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(3, 3.5),
            ZIndex = Holder.ZIndex + 1, Parent = Holder,
        })
        Themed(T, { BackgroundColor3 = ColorKey }); Corner(T, 1)
        Teeth[I] = T
    end
    local Angle = Create('NumberValue', { Value = 0 })
    local function Place()
        for I, T in ipairs(Teeth) do
            local Deg = I * 45 + Angle.Value
            local Rad = math.rad(Deg)
            T.Position = UDim2.new(0.5, math.cos(Rad) * 6, 0.5, math.sin(Rad) * 6)
            T.Rotation = Deg + 90
        end
    end
    Angle:GetPropertyChangedSignal('Value'):Connect(Place)
    Place()

    local Icon = { Holder = Holder }
    function Icon:SetColor(Color, Time)
        for _, T in ipairs(Teeth) do Tween(T, { BackgroundColor3 = Color }, Time or 0.15) end
        Tween(RingStroke, { Color = Color }, Time or 0.15)
    end
    function Icon:Spin(To, Time) Tween(Angle, { Value = To }, Time or 0.45, Back) end
    return Icon
end
Library.GearIcon = GearIcon

local NESTED_METHODS = {
    'AddToggle', 'AddSlider', 'AddDropdown', 'AddInput', 'AddTextbox', 'AddLabel', 'AddDivider', 'AddButton',
    'AddList', 'AddMultiInput', 'AddPriorityList', 'AddPriority', 'AddKeybind', 'AddColorPicker',
    'AddDependencyBox', 'AddBlank',
}

local function FindSearchEntry(Box, Frame)
    if Box.Groupbox then
        for _, E in ipairs(Box.Groupbox.Elements) do
            if E.Frame == Frame then return E end
        end
    end
    return Box.SearchEntry
end

local function EnableNesting(Owner, Box, OwnerFrame, Title, PlaceGear)
    function Owner:AddSettings(CustomTitle)
        if self.Settings then return self.Settings end

        local Gear = Create('TextButton', {
            AutoButtonColor = false, Text = '', BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 20), ZIndex = 4,
        })
        Themed(Gear, { BackgroundColor3 = 'Hover' }); Corner(Gear, 5)
        PlaceGear(Gear)
        local Icon = GearIcon(Gear, 'DimText')
        local GScale = Create('UIScale', { Scale = 0, Parent = Gear })
        Tween(GScale, { Scale = 1 }, 0.4, Back)

        local Popup = CreatePopup(Gear, 270, 120)
        Popup.ParentPopup = Box.Popup
        local Body = Popup.Body

        local HeadIcon = GearIcon(Body, 'Accent', { Position = UDim2.fromOffset(21, 20), ZIndex = 21 })
        Text({
            Text = tostring(CustomTitle or Title or 'Settings'), Font = Library.FontBold, TextSize = 13, RichText = false,
            Position = UDim2.fromOffset(36, 11), Size = UDim2.new(1, -104, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21, Parent = Body,
        })
        Text({
            Text = 'SETTINGS', TextSize = 10, Font = Library.FontMedium, ColorKey = 'DimText', AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -14, 0, 13), Size = UDim2.fromOffset(60, 14),
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 21, Parent = Body,
        })
        local Line = Create('Frame', { BorderSizePixel = 0, Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 1), ZIndex = 21, Parent = Body })
        Themed(Line, { BackgroundColor3 = 'Stroke' })

        local Scroll = Create('ScrollingFrame', {
            BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 41), Size = UDim2.new(1, 0, 1, -41),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
            ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 21, Parent = Body,
        })
        Themed(Scroll, { ScrollBarImageColor3 = 'Accent' })

        local Inner = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 21, Parent = Scroll })
        Padding(Inner, 12, 14, 14, 14)
        local Container = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 21, Parent = Inner })
        ListLayout(Container, 10)

        Popup.HeightFn = function()
            local S = Popup.Scale.Scale
            if S <= 0 then S = 1 end
            return math.clamp(41 + Inner.AbsoluteSize.Y / S, 80, Library.SettingsMaxHeight or 380)
        end

        local Settings = setmetatable({
            Container = Container, Order = 0, Popup = Popup, Owner = Owner, Gear = Gear, Column = Scroll,
            SearchEntry = FindSearchEntry(Box, OwnerFrame),
        }, { __index = Funcs })
        function Settings:Open() Popup:Open() end
        function Settings:Close() Popup:Close() end

        local Hover = false
        Gear.MouseEnter:Connect(function()
            Hover = true
            Tween(Gear, { BackgroundTransparency = 0 }, 0.15)
            if not Popup.IsOpen then
                Icon:SetColor(Library.Theme.SubText)
                Icon:Spin(45)
            end
        end)
        Gear.MouseLeave:Connect(function()
            Hover = false
            Tween(Gear, { BackgroundTransparency = 1 }, 0.15)
            Tween(GScale, { Scale = 1 }, 0.2)
            if not Popup.IsOpen then
                Icon:SetColor(Library.Theme.DimText)
                Icon:Spin(0)
            end
        end)
        Gear.MouseButton1Down:Connect(function() Tween(GScale, { Scale = 0.85 }, 0.1) end)
        Gear.MouseButton1Up:Connect(function() Tween(GScale, { Scale = 1 }, 0.3, Back) end)
        Gear.MouseButton1Click:Connect(function() Popup:Toggle() end)
        local HeadAngle = 0
        Popup.OnOpen = function()
            Icon:SetColor(Library.Theme.Accent)
            Icon:Spin(135)
            HeadAngle = HeadAngle + 90
            HeadIcon:Spin(HeadAngle, 0.6)
        end
        Popup.OnClose = function()
            Icon:SetColor(Hover and Library.Theme.SubText or Library.Theme.DimText)
            Icon:Spin(Hover and 45 or 0)
        end

        self.Settings = Settings
        return Settings
    end

    for _, Name in ipairs(NESTED_METHODS) do
        if Owner[Name] == nil then
            Owner[Name] = function(self, ...)
                local S = self:AddSettings()
                return S[Name](S, ...)
            end
        end
    end
end

function Funcs:AddBlank(Size)
    local F = Blank({ Size = UDim2.new(1, 0, 0, math.max((Size or 0) - 10, 0)) })
    AddElement(self, F)
    return F
end

function Funcs:AddLabel(Str, DoesWrap)
    local Row = Blank({ Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y })
    local L = Text({
        Text = Str or '', ColorKey = 'SubText', Size = UDim2.new(1, 0, 0, 18),
        TextWrapped = DoesWrap and true or false,
        AutomaticSize = DoesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        Parent = Row,
    })
    AddElement(self, Row, Str)

    local Label = { TextLabel = L, Row = Row, Type = 'Label', Addons = {} }
    function Label:SetText(S) L.Text = tostring(S) end
    function Label:AddKeyPicker(Idx, Info) return CreateKeyPicker(Label, Row, Idx, Info) end
    function Label:AddColorPicker(Idx, Info) return CreateColorPicker(Label, Row, Idx, Info) end
    Label.Box = self
    EnableNesting(Label, self, Row, Str, function(G)
        G.LayoutOrder = 1000
        G.Parent = GetAddonHolder(Label, Row)
    end)
    return Label
end

function Funcs:AddDivider()
    local Line = Create('Frame', { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) })
    Themed(Line, { BackgroundColor3 = 'Stroke' })
    AddElement(self, Line)
    return Line
end

function Funcs:AddButton(A, B)
    local Info = type(A) == 'table' and A or { Text = A, Func = B }
    local Func = Info.Func or Info.Callback
    local Box = self

    local Btn = Create('TextButton', { AutoButtonColor = false, Text = '', Size = UDim2.new(1, 0, 0, 30) })
    Themed(Btn, { BackgroundColor3 = 'Element' })
    Corner(Btn, 6)
    local BtnStroke = Stroke(Btn)
    local L = Text({ Text = Info.Text or 'Button', Font = Library.FontMedium, Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center, Parent = Btn })

    local BtnScale = Create('UIScale', { Parent = Btn })
    Btn.MouseEnter:Connect(function()
        Tween(Btn, { BackgroundColor3 = Library.Theme.Hover })
        Tween(BtnStroke, { Color = Library.Theme.Accent })
    end)
    Btn.MouseLeave:Connect(function()
        Tween(Btn, { BackgroundColor3 = Library.Theme.Element })
        Tween(BtnStroke, { Color = Library.Theme.Stroke })
        Tween(BtnScale, { Scale = 1 }, 0.15)
    end)
    Btn.MouseButton1Down:Connect(function()
        Tween(BtnScale, { Scale = 0.96 }, 0.1)
        Ripple(Btn)
    end)
    Btn.MouseButton1Up:Connect(function() Tween(BtnScale, { Scale = 1 }, 0.25, Back) end)

    local Pending = false
    Btn.MouseButton1Click:Connect(function()
        if Info.DoubleClick then
            if not Pending then
                Pending = true
                L.Text = 'Are you sure?'
                L.TextColor3 = Library.Theme.Accent
                task.delay(1.5, function()
                    if Pending then
                        Pending = false
                        L.Text = Info.Text
                        L.TextColor3 = Library.Theme.Text
                    end
                end)
                return
            end
            Pending = false
            L.Text = Info.Text
            L.TextColor3 = Library.Theme.Text
        end
        Library:SafeCallback(Func)
    end)

    AddElement(Box, Btn, Info.Text)
    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, Btn) end

    local Button = { Instance = Btn, Label = L }
    function Button:AddTooltip(Tip) Library:AddToolTip(Tip, Btn); return self end
    function Button:SetText(T) Info.Text = T; L.Text = T end
    function Button:AddButton(...)
        local Row, Siblings = Button.Row, Button.Siblings
        if not Row then
            Row = Blank({ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = Btn.LayoutOrder, Parent = Btn.Parent })
            ListLayout(Row, 8, Enum.FillDirection.Horizontal)
            Btn.Parent = Row
            Siblings = { Btn }
            Button.Row, Button.Siblings = Row, Siblings
        end
        local Sub = Box:AddButton(...)
        Sub.Instance.Parent = Row
        Sub.Row, Sub.Siblings = Row, Siblings
        table.insert(Siblings, Sub.Instance)
        local N = #Siblings
        for I, B in ipairs(Siblings) do
            B.LayoutOrder = I
            B.Size = UDim2.new(1 / N, -8 * (N - 1) / N, 0, 30)
        end
        return Sub
    end
    EnableNesting(Button, Box, Btn, Info.Text, function(G)
        G.AnchorPoint = Vector2.new(1, 0.5)
        G.Position = UDim2.new(1, -5, 0.5, 0)
        G.Parent = Btn
    end)
    return Button
end

function Funcs:AddInput(Idx, Info)
    Info = Info or {}
    local Input = {
        Value = tostring(Info.Default or ''), Type = 'Input', Numeric = Info.Numeric,
        Finished = Info.Finished, Callback = Info.Callback, NoConfig = Info.NoConfig,
    }

    local TitleLabel
    local Holder = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
    ListLayout(Holder, 6)
    if Info.Text then
        TitleLabel = Text({ Text = Info.Text, ColorKey = 'SubText', Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = Holder })
    end
    local Bg = Create('Frame', { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2, Parent = Holder })
    Themed(Bg, { BackgroundColor3 = 'Element' })
    Corner(Bg, 6)
    local BgStroke = Stroke(Bg)

    local Smooth = SmoothInput(Bg, {
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = Input.Value,
        Placeholder = Info.Placeholder or '', Censor = Info.Censor or Info.Password,
    })
    local Box = Smooth.Box
    Input.TextBox = Box

    function Input:SetValue(V)
        V = tostring(V or '')
        if Info.MaxLength and #V > Info.MaxLength then V = string.sub(V, 1, Info.MaxLength) end
        if self.Numeric and V ~= '' and V ~= '-' and V ~= '.' and not tonumber(V) then V = self.Value end
        if Box.Text ~= V then Box.Text = V end
        if V == self.Value then return end
        self.Value = V
        Library:SafeCallback(self.Callback, V)
        Library:SafeCallback(self.Changed, V)
    end

    function Input:OnChanged(F)
        self.Changed = F
        Library:SafeCallback(F, self.Value)
    end

    Box:GetPropertyChangedSignal('Text'):Connect(function()
        if not Input.Finished then Input:SetValue(Box.Text) end
    end)
    Box.Focused:Connect(function()
        Tween(BgStroke, { Color = Library.Theme.Accent })
        Tween(Bg, { BackgroundColor3 = Library.Theme.Hover })
    end)
    Box.FocusLost:Connect(function(Enter)
        Tween(BgStroke, { Color = Library.Theme.Stroke })
        Tween(Bg, { BackgroundColor3 = Library.Theme.Element })
        if Input.Finished then
            if Enter then Input:SetValue(Box.Text) else Box.Text = Input.Value end
        end
        Library:AttemptSave()
    end)

    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, Bg) end
    EnableNesting(Input, self, Holder, Info.Text or Idx, function(G)
        G.AnchorPoint = Vector2.new(1, 0.5)
        if TitleLabel then
            G.Position = UDim2.new(1, 0, 0.5, 0)
            G.Parent = TitleLabel
        else
            G.Position = UDim2.new(1, -30, 0.5, 0)
            G.ZIndex = 8
            G.Parent = Bg
        end
    end)
    AddElement(self, Holder, Info.Text or Idx)
    Options[Idx] = Input
    return Input
end
Funcs.AddTextbox = Funcs.AddInput

function Funcs:AddKeybind(Idx, Info)
    Info = Info or {}
    local Label = self:AddLabel(Info.Text or Idx)
    Label.Row.Size = UDim2.new(1, 0, 0, 22)
    Label.TextLabel.Size = UDim2.new(1, 0, 1, 0)
    Library.Registry[Label.TextLabel].TextColor3 = 'Text'
    Label.TextLabel.TextColor3 = Library.Theme.Text
    Label:AddKeyPicker(Idx, Info)
    return Options[Idx]
end

function Funcs:AddColorPicker(Idx, Info)
    Info = Info or {}
    local Label = self:AddLabel(Info.Text or Idx)
    Label.Row.Size = UDim2.new(1, 0, 0, 22)
    Label.TextLabel.Size = UDim2.new(1, 0, 1, 0)
    Library.Registry[Label.TextLabel].TextColor3 = 'Text'
    Label.TextLabel.TextColor3 = Library.Theme.Text
    Label:AddColorPicker(Idx, Info)
    return Options[Idx]
end

function Funcs:AddList(Idx, Info)
    Info = Info or {}
    local List = {
        Type = 'List', Value = {}, Callback = Info.Callback, NoConfig = Info.NoConfig,
        AllowDuplicates = Info.AllowDuplicates, Max = Info.Max,
    }
    local ChipObjs = {}

    local Holder = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
    ListLayout(Holder, 8)
    if Info.Text then
        Text({ Text = Info.Text, ColorKey = 'SubText', Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = Holder })
    end

    local Row = Blank({ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2, Parent = Holder })
    local Bg = Create('Frame', { BorderSizePixel = 0, Size = UDim2.new(1, -36, 1, 0), Parent = Row })
    Themed(Bg, { BackgroundColor3 = 'Element' }); Corner(Bg, 6)
    local BgStroke = Stroke(Bg)
    local In = SmoothInput(Bg, {
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
        Placeholder = Info.Placeholder or 'Type and press Enter...',
    })
    local AddBtn = Create('TextButton', {
        AutoButtonColor = false, Text = '', AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(30, 30), Parent = Row,
    })
    Themed(AddBtn, { BackgroundColor3 = 'Element' }); Corner(AddBtn, 6)
    local AddStroke = Stroke(AddBtn)
    local Plus = Blank({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Parent = AddBtn })
    IconBar(Plus, 12, 2, 0, 0, 0, nil, 'Accent')
    IconBar(Plus, 2, 12, 0, 0, 0, nil, 'Accent')

    local Chips = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Visible = false, Parent = Holder })
    local ChipLayout = ListLayout(Chips, 6, Enum.FillDirection.Horizontal)
    pcall(function() ChipLayout.Wraps = true end)

    local function Fire()
        Chips.Visible = #List.Value > 0
        Library:SafeCallback(List.Callback, List.Value)
        Library:SafeCallback(List.Changed, List.Value)
    end

    local function Shake()
        Tween(BgStroke, { Color = Library.Theme.Risk }, 0.1)
        task.spawn(function()
            for _, X in ipairs({ -6, 5, -3, 2, 0 }) do
                Tween(Bg, { Position = UDim2.fromOffset(X, 0) }, 0.05)
                task.wait(0.05)
            end
            Tween(BgStroke, { Color = In.Box:IsFocused() and Library.Theme.Accent or Library.Theme.Stroke }, 0.3)
        end)
    end

    local Order = 0
    local function MakeChip(V, Animate)
        Order = Order + 1
        local Chip = Create('TextButton', {
            AutoButtonColor = false, Text = '', Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = Order, Parent = Chips,
        })
        Themed(Chip, { BackgroundColor3 = 'Element' }); Corner(Chip, 6)
        local CStroke = Stroke(Chip)
        Padding(Chip, 0, 0, 9, 26)
        Text({ Text = V, TextSize = 12, RichText = false, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = Chip })
        local X = Blank({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 13, 0.5, 0), Size = UDim2.fromOffset(10, 10), Parent = Chip })
        local B1 = IconBar(X, 9, 2, 0, 0, 45, Library.Theme.SubText)
        local B2 = IconBar(X, 9, 2, 0, 0, -45, Library.Theme.SubText)
        local ChipScale = Create('UIScale', { Parent = Chip })
        if Animate then
            ChipScale.Scale = 0.4
            Tween(ChipScale, { Scale = 1 }, 0.35, Back)
        end
        Chip.MouseEnter:Connect(function()
            Tween(CStroke, { Color = Library.Theme.Risk }, 0.15)
            Tween(B1, { BackgroundColor3 = Library.Theme.Risk, Rotation = 135 }, 0.25)
            Tween(B2, { BackgroundColor3 = Library.Theme.Risk, Rotation = 45 }, 0.25)
        end)
        Chip.MouseLeave:Connect(function()
            Tween(CStroke, { Color = Library.Theme.Stroke }, 0.15)
            Tween(B1, { BackgroundColor3 = Library.Theme.SubText, Rotation = 45 }, 0.25)
            Tween(B2, { BackgroundColor3 = Library.Theme.SubText, Rotation = -45 }, 0.25)
        end)
        local Obj = { Value = V, Chip = Chip, Scale = ChipScale }
        Chip.MouseButton1Click:Connect(function()
            local I = table.find(ChipObjs, Obj)
            if I then List:RemoveAt(I) end
        end)
        return Obj
    end

    function List:Add(V)
        V = tostring(V or '')
        if string.match(V, '^%s*$') then Shake(); return false end
        if not self.AllowDuplicates and table.find(self.Value, V) then Shake(); return false end
        if self.Max and #self.Value >= self.Max then Shake(); return false end
        table.insert(self.Value, V)
        table.insert(ChipObjs, MakeChip(V, true))
        Fire()
        return true
    end

    function List:RemoveAt(I)
        local Obj = table.remove(ChipObjs, I)
        table.remove(self.Value, I)
        if Obj then
            Tween(Obj.Scale, { Scale = 0 }, 0.18, Enum.EasingStyle.Quad)
            task.delay(0.19, function() Obj.Chip:Destroy() end)
        end
        Fire()
        Library:AttemptSave()
    end

    function List:Remove(V)
        local I = table.find(self.Value, tostring(V))
        if I then self:RemoveAt(I) end
    end

    function List:SetValue(Values)
        for _, Obj in ipairs(ChipObjs) do Obj.Chip:Destroy() end
        ChipObjs, self.Value = {}, {}
        for _, V in ipairs(type(Values) == 'table' and Values or {}) do
            V = tostring(V)
            if self.AllowDuplicates or not table.find(self.Value, V) then
                table.insert(self.Value, V)
                table.insert(ChipObjs, MakeChip(V, true))
            end
        end
        Fire()
    end

    function List:OnChanged(F)
        self.Changed = F
        Library:SafeCallback(F, self.Value)
    end

    local function Submit()
        if List:Add(In.Box.Text) then
            In.Box.Text = ''
            Library:AttemptSave()
        end
    end
    In.Box.Focused:Connect(function() Tween(BgStroke, { Color = Library.Theme.Accent }) end)
    In.Box.FocusLost:Connect(function(Enter)
        Tween(BgStroke, { Color = Library.Theme.Stroke })
        if Enter and In.Box.Text ~= '' then
            Submit()
            if not UserInputService.TouchEnabled then task.defer(function() In.Box:CaptureFocus() end) end
        end
    end)
    local AddScale = Create('UIScale', { Parent = AddBtn })
    AddBtn.MouseEnter:Connect(function() Tween(AddStroke, { Color = Library.Theme.Accent }); Tween(Plus, { Rotation = 90 }, 0.35, Back) end)
    AddBtn.MouseLeave:Connect(function() Tween(AddStroke, { Color = Library.Theme.Stroke }); Tween(Plus, { Rotation = 0 }, 0.35, Back) end)
    AddBtn.MouseButton1Down:Connect(function() Tween(AddScale, { Scale = 0.9 }, 0.1); Ripple(AddBtn) end)
    AddBtn.MouseButton1Up:Connect(function() Tween(AddScale, { Scale = 1 }, 0.3, Back) end)
    AddBtn.MouseButton1Click:Connect(Submit)

    if type(Info.Default) == 'table' then
        for _, V in ipairs(Info.Default) do
            V = tostring(V)
            table.insert(List.Value, V)
            table.insert(ChipObjs, MakeChip(V, false))
        end
        Chips.Visible = #List.Value > 0
    end

    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, Bg) end
    AddElement(self, Holder, Info.Text or Idx)
    Options[Idx] = List
    return List
end
Funcs.AddMultiInput = Funcs.AddList

function Funcs:AddPriorityList(Idx, Info)
    Info = Info or {}
    local ROW, GAP = 36, 6
    local STEP = ROW + GAP
    local ShowArrows = UserInputService.TouchEnabled
    local PL = {
        Type = 'PriorityList', Value = {}, Values = {}, Enabled = {}, Memory = {},
        Callback = Info.Callback, NoConfig = Info.NoConfig, Listeners = {},
    }
    local Groupbox = self.Groupbox
    local Rows = {}
    local Drag, Press = nil, nil

    local Holder = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
    ListLayout(Holder, 6)
    if Info.Text then
        Text({ Text = Info.Text, ColorKey = 'SubText', Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = Holder })
    end
    local ListFrame = Blank({ Size = UDim2.new(1, 0, 0, ROW), LayoutOrder = 2, Parent = Holder })
    local Empty = Text({
        Text = Info.EmptyText or 'No items', ColorKey = 'DimText', TextSize = 12, RichText = false,
        TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, ROW), Visible = false, Parent = ListFrame,
    })

    local function SlotPos(I) return UDim2.fromOffset(0, (I - 1) * STEP) end
    local function Signature()
        local T = {}
        for I, V in ipairs(PL.Value) do T[I] = tostring(V) end
        return table.concat(T, '\0')
    end
    local function IsEnabled(V) return PL.Enabled[V] ~= false end

    local function Remember()
        local New = {}
        for _, V in ipairs(PL.Value) do table.insert(New, V) end
        for _, V in ipairs(PL.Memory) do
            if not table.find(New, V) then table.insert(New, V) end
        end
        PL.Memory = New
    end

    local function RowLook(Row)
        local T = Library.Theme
        local Top = Row.Index == 1
        local Active = Row.Hover or (Drag and Drag.Row == Row)
        return {
            Bg = Active and T.Hover or (Top and T.Element:Lerp(T.Accent, 0.12) or T.Element),
            Stroke = Active and T.Accent or (Top and T.Stroke:Lerp(T.Accent, 0.55) or T.Stroke),
        }
    end

    local function Paint(Row, I, Animate)
        local T = Library.Theme
        local Top = I == 1
        Row.Index = I
        Row.Rank.Text = tostring(I)
        local Look = RowLook(Row)
        local Props = {
            { Row.Frame, { BackgroundColor3 = Look.Bg } },
            { Row.Stroke, { Color = Look.Stroke } },
            { Row.Badge, { BackgroundColor3 = Top and T.Accent or T.Hover } },
            { Row.Rank, { TextColor3 = Top and Color3.new(1, 1, 1) or T.SubText } },
            { Row.Label, { TextColor3 = IsEnabled(Row.Value) and (Top and T.Text or T.SubText) or T.DimText } },
            { Row.Bar, { Size = UDim2.new(0, 3, 0, Top and 18 or 0) } },
        }
        for _, P in ipairs(Props) do
            if Animate then Tween(P[1], P[2], 0.25) else for K, V in pairs(P[2]) do P[1][K] = V end end
        end
        Row.Label.Font = Top and Library.FontMedium or Library.Font
    end

    local function Layout(Animate)
        local Height = math.max(#PL.Value, 1) * STEP - GAP
        if Animate then Tween(ListFrame, { Size = UDim2.new(1, 0, 0, Height) }, 0.25) else ListFrame.Size = UDim2.new(1, 0, 0, Height) end
        Empty.Visible = #PL.Value == 0
        for I, V in ipairs(PL.Value) do
            local Row = Rows[V]
            if Row then
                if not (Drag and Drag.Row == Row) then
                    if Animate then Tween(Row.Frame, { Position = SlotPos(I) }, 0.28) else Row.Frame.Position = SlotPos(I) end
                end
                Paint(Row, I, Animate)
            end
        end
    end

    local function Fire()
        Remember()
        Library:SafeCallback(PL.Callback, PL.Value, PL.Enabled)
        Library:SafeCallback(PL.Changed, PL.Value, PL.Enabled)
        for _, F in ipairs(PL.Listeners) do Library:SafeCallback(F, PL.Value) end
    end

    local function Bump(Row)
        Row.Scale.Scale = 0.96
        Tween(Row.Scale, { Scale = 1 }, 0.35, Back)
    end

    function PL:Move(V, Delta)
        local I = table.find(self.Value, V)
        if not I then return end
        local J = math.clamp(I + Delta, 1, #self.Value)
        if I == J then
            if Rows[V] then Bump(Rows[V]) end
            return
        end
        table.remove(self.Value, I)
        table.insert(self.Value, J, V)
        Layout(true)
        if Rows[V] then Bump(Rows[V]) end
        Fire()
        Library:AttemptSave()
    end

    local function MakeRow(V)
        local F = Create('TextButton', { AutoButtonColor = false, Text = '', Size = UDim2.new(1, 0, 0, ROW), ZIndex = 1, Parent = ListFrame })
        Themed(F, { BackgroundColor3 = 'Element' }); Corner(F, 8)
        local S = Stroke(F)
        local Sc = Create('UIScale', { Parent = F })

        local Bar = Create('Frame', {
            BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(3, 0), ZIndex = 2, Parent = F,
        })
        Themed(Bar, { BackgroundColor3 = 'Accent' }); Corner(Bar, 'full')

        local Grip = Blank({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(8, 12), Parent = F })
        local Dots = {}
        for R = 0, 2 do
            for C = 0, 1 do
                local D = Create('Frame', { BorderSizePixel = 0, Position = UDim2.fromOffset(C * 5, R * 4.5), Size = UDim2.fromOffset(2.5, 2.5), Parent = Grip })
                Themed(D, { BackgroundColor3 = 'DimText' }); Corner(D, 'full')
                table.insert(Dots, D)
            end
        end

        local Badge = Create('Frame', {
            BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 26, 0.5, 0),
            Size = UDim2.fromOffset(20, 20), Parent = F,
        })
        Corner(Badge, 'full')
        local Rank = Create('TextLabel', { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Library.FontBold, TextSize = 11, Text = '', Parent = Badge })

        local Label = Create('TextLabel', {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -56 - 58, 1, 0),
            Font = Library.Font, TextSize = 13, Text = tostring(V), TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = F,
        })

        local Row = { Frame = F, Stroke = S, Scale = Sc, Badge = Badge, Rank = Rank, Label = Label, Bar = Bar, Value = V, Hover = false }

        local ArrowBars = {}
        local function MiniButton(X, Up)
            local B = Create('TextButton', {
                AutoButtonColor = false, Text = '', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, X, 0.5, 0), Size = UDim2.fromOffset(24, 24), ZIndex = 3, Parent = F,
            })
            Themed(B, { BackgroundColor3 = 'Card' }); Corner(B, 6)
            local Icon = ChevronIcon(B, 'SubText', { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
            Icon:Set(Up)
            for _, Child in ipairs(Icon.Holder:GetChildren()) do
                if Child:IsA('Frame') then
                    Child.BackgroundTransparency = ShowArrows and 0 or 1
                    table.insert(ArrowBars, Child)
                end
            end
            local BScale = Create('UIScale', { Parent = B })
            B.MouseEnter:Connect(function() Tween(B, { BackgroundTransparency = 0 }, 0.12) end)
            B.MouseLeave:Connect(function() Tween(B, { BackgroundTransparency = 1 }, 0.12) end)
            B.MouseButton1Down:Connect(function() Tween(BScale, { Scale = 0.85 }, 0.1) end)
            B.MouseButton1Up:Connect(function() Tween(BScale, { Scale = 1 }, 0.3, Back) end)
            B.MouseButton1Click:Connect(function() PL:Move(V, Up and -1 or 1) end)
            return B
        end
        MiniButton(-32, true)
        MiniButton(-6, false)

        local RemoveBtn = Create('TextButton', {
            AutoButtonColor = false, Text = '', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -58, 0.5, 0), Size = UDim2.fromOffset(24, 24), ZIndex = 3,
            Visible = PL.Pool ~= nil, Parent = F,
        })
        Themed(RemoveBtn, { BackgroundColor3 = 'Card' }); Corner(RemoveBtn, 6)
        local X1 = IconBar(RemoveBtn, 10, 2, 0, 0, 45, nil, 'SubText')
        local X2 = IconBar(RemoveBtn, 10, 2, 0, 0, -45, nil, 'SubText')
        X1.BackgroundTransparency, X2.BackgroundTransparency = ShowArrows and 0 or 1, ShowArrows and 0 or 1
        table.insert(ArrowBars, X1); table.insert(ArrowBars, X2)
        RemoveBtn.MouseEnter:Connect(function()
            Tween(RemoveBtn, { BackgroundTransparency = 0 }, 0.12)
            Tween(X1, { BackgroundColor3 = Library.Theme.Risk, Rotation = 135 }, 0.25)
            Tween(X2, { BackgroundColor3 = Library.Theme.Risk, Rotation = 45 }, 0.25)
        end)
        RemoveBtn.MouseLeave:Connect(function()
            Tween(RemoveBtn, { BackgroundTransparency = 1 }, 0.12)
            Tween(X1, { BackgroundColor3 = Library.Theme.SubText, Rotation = 45 }, 0.25)
            Tween(X2, { BackgroundColor3 = Library.Theme.SubText, Rotation = -45 }, 0.25)
        end)
        RemoveBtn.MouseButton1Click:Connect(function() PL:Remove(V) end)
        Row.RemoveBtn = RemoveBtn
        if PL.Pool then Label.Size = UDim2.new(1, -56 - 84, 1, 0) end

        local function SetHover(On)
            Row.Hover = On
            if not ShowArrows then
                for I, Bar2 in ipairs(ArrowBars) do Tween(Bar2, { BackgroundTransparency = On and 0 or 1 }, 0.12 + I * 0.02) end
            end
            for _, D in ipairs(Dots) do Tween(D, { BackgroundColor3 = On and Library.Theme.Accent or Library.Theme.DimText }, 0.15) end
            Tween(Label, { Position = UDim2.fromOffset(On and 59 or 56, 0) }, 0.2)
            if Row.Index then Paint(Row, Row.Index, true) end
        end

        F.MouseEnter:Connect(function() if not Drag then SetHover(true) end end)
        F.MouseLeave:Connect(function()
            if Drag and Drag.Row == Row then return end
            SetHover(false)
        end)
        Row.SetHover = SetHover
        F.InputBegan:Connect(function(Input)
            if IsClick(Input) and not Drag then Press = { Row = Row, Pt = PointerOf(Input) } end
        end)
        return Row
    end

    local function BeginDrag(Row, Pt)
        local S = Library.UIScale and Library.UIScale.Scale or 1
        Drag = { Row = Row, Grab = (Pt.Y - Row.Frame.AbsolutePosition.Y) / S, Start = Signature() }
        Row.Frame.ZIndex = 5
        Tween(Row.Scale, { Scale = 1.04 }, 0.25, Back)
        Tween(Row.Stroke, { Color = Library.Theme.Accent }, 0.15)
        Tween(Row.Frame, { BackgroundColor3 = Library.Theme.Hover }, 0.15)
        if Groupbox and Groupbox.Column then Groupbox.Column.ScrollingEnabled = false end
    end

    local function OverPool(Pt)
        local Area = PL.Pool and PL.Pool.Area
        if not Area then return false end
        local P, Sz = Area.AbsolutePosition, Area.AbsoluteSize
        return Pt.X >= P.X and Pt.X <= P.X + Sz.X and Pt.Y >= P.Y and Pt.Y <= P.Y + Sz.Y
    end

    local function MoveDrag(Pt)
        Drag.LastPt = Pt
        if PL.Pool then PL.Pool:SetDropHighlight(OverPool(Pt)) end
        local S = Library.UIScale and Library.UIScale.Scale or 1
        local Y = math.clamp((Pt.Y - ListFrame.AbsolutePosition.Y) / S - Drag.Grab, 0, math.max(#PL.Value - 1, 0) * STEP)
        Drag.Row.Frame.Position = UDim2.fromOffset(0, Y)
        local Target = math.clamp(math.floor(Y / STEP + 0.5) + 1, 1, #PL.Value)
        local Current = table.find(PL.Value, Drag.Row.Value)
        if Current and Target ~= Current then
            table.remove(PL.Value, Current)
            table.insert(PL.Value, Target, Drag.Row.Value)
            Layout(true)
        end
    end

    local function EndDrag()
        local D = Drag
        Drag = nil
        local Row = D.Row
        if PL.Pool then
            PL.Pool:SetDropHighlight(false)
            if D.LastPt and OverPool(D.LastPt) then
                if Groupbox and Groupbox.Column then Groupbox.Column.ScrollingEnabled = true end
                Row.Frame.ZIndex = 1
                PL:Remove(Row.Value)
                Library:AttemptSave()
                return
            end
        end
        local I = table.find(PL.Value, Row.Value) or 1
        Tween(Row.Frame, { Position = SlotPos(I) }, 0.25)
        Tween(Row.Scale, { Scale = 1 }, 0.35, Back)
        Row.SetHover(false)
        task.delay(0.26, function() if not Drag or Drag.Row ~= Row then Row.Frame.ZIndex = 1 end end)
        if Groupbox and Groupbox.Column then Groupbox.Column.ScrollingEnabled = true end
        if Signature() ~= D.Start then
            Fire()
            Library:AttemptSave()
        end
    end

    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if not (Input.UserInputType == Move or Input.UserInputType == Touch) then return end
        if Drag then
            MoveDrag(PointerOf(Input))
        elseif Press then
            local Pt = PointerOf(Input)
            if (Pt - Press.Pt).Magnitude > 4 then
                local Row = Press.Row
                Press = nil
                BeginDrag(Row, Pt)
                MoveDrag(Pt)
            end
        end
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if not IsClick(Input) then return end
        Press = nil
        if Drag then EndDrag() end
    end))

    local function MemoryRank(V)
        return table.find(PL.Memory, V) or math.huge
    end

    function PL:SetValues(Values)
        Values = Values or {}
        local Present, List = {}, {}
        for I, V in ipairs(Values) do
            if not Present[V] then
                Present[V] = true
                table.insert(List, { V = V, I = I })
            end
        end
        table.sort(List, function(A, B)
            local RA, RB = MemoryRank(A.V), MemoryRank(B.V)
            if RA ~= RB then return RA < RB end
            return A.I < B.I
        end)
        for V, Row in pairs(Rows) do
            if not Present[V] then
                Rows[V] = nil
                Tween(Row.Scale, { Scale = 0 }, 0.15, Enum.EasingStyle.Quad)
                task.delay(0.16, function() Row.Frame:Destroy() end)
            end
        end
        self.Value, self.Values = {}, Values
        for I, Item in ipairs(List) do
            table.insert(self.Value, Item.V)
            if not Rows[Item.V] then
                local Row = MakeRow(Item.V)
                Rows[Item.V] = Row
                Row.Frame.Position = SlotPos(I)
                Row.Scale.Scale = 0.6
                Tween(Row.Scale, { Scale = 1 }, 0.35, Back)
            end
        end
        Layout(true)
        Fire()
    end
    PL.Refresh = PL.SetValues
    PL.ListFrame = ListFrame

    -- add an item at a position (used by a linked pool)
    function PL:Insert(V, Index)
        if table.find(self.Value, V) then return end
        Index = math.clamp(Index or (#self.Value + 1), 1, #self.Value + 1)
        local Order = {}
        for _, X in ipairs(self.Value) do table.insert(Order, X) end
        table.insert(Order, Index, V)
        for _, X in ipairs(self.Memory) do
            if not table.find(Order, X) then table.insert(Order, X) end
        end
        self.Memory = Order
        local NewValues = {}
        for _, X in ipairs(self.Values) do table.insert(NewValues, X) end
        table.insert(NewValues, V)
        self:SetValues(NewValues)
        Library:AttemptSave()
    end

    function PL:Remove(V)
        local NewValues = {}
        for _, X in ipairs(self.Values) do
            if X ~= V then table.insert(NewValues, X) end
        end
        self:SetValues(NewValues)
        Library:AttemptSave()
    end

    function PL:IndexAt(Pt)
        local S = Library.UIScale and Library.UIScale.Scale or 1
        local Y = (Pt.Y - ListFrame.AbsolutePosition.Y) / S
        return math.clamp(math.floor(Y / STEP + 0.5) + 1, 1, #self.Value + 1)
    end

    local Marker = Create('Frame', {
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), BackgroundTransparency = 1, ZIndex = 6, Parent = ListFrame,
    })
    Themed(Marker, { BackgroundColor3 = 'Accent' }); Corner(Marker, 'full')
    function PL:ShowDropMarker(Index)
        if not Index then
            Tween(Marker, { BackgroundTransparency = 1 }, 0.12)
            return
        end
        local Y = #self.Value == 0 and (ROW / 2 - 1) or ((Index - 1) * STEP - GAP / 2 - 1)
        Tween(Marker, { Position = UDim2.fromOffset(0, Y), BackgroundTransparency = 0 }, 0.1)
    end

    function PL:LinkPool(Pool)
        self.Pool = Pool
        Empty.Text = Info.EmptyText or 'Drag items here'
        for _, Row in pairs(Rows) do
            if Row.RemoveBtn then Row.RemoveBtn.Visible = true end
            Row.Label.Size = UDim2.new(1, -56 - 84, 1, 0)
        end
    end

    function PL:SetValue(Data)
        if type(Data) ~= 'table' then return end
        local Order, Disabled = Data, nil
        if Data.Order then Order, Disabled = Data.Order, Data.Disabled end
        self.Memory = {}
        for _, V in ipairs(Order) do table.insert(self.Memory, V) end
        if Disabled then
            self.Enabled = {}
            for _, V in ipairs(Disabled) do self.Enabled[V] = false end
        end
        if self.Pool then
            local Selected = {}
            for _, V in ipairs(Order) do table.insert(Selected, V) end
            self:SetValues(Selected)
        else
            self:SetValues(self.Values)
        end
    end

    function PL:SetEnabled(V, On)
        self.Enabled[V] = On and true or false
        Layout(true)
        Fire()
    end
    function PL:IsEnabled(V) return IsEnabled(V) end
    function PL:GetPriority(V) return table.find(self.Value, V) end

    function PL:GetBest(Available)
        for _, V in ipairs(self.Value) do
            if IsEnabled(V) and (Available == nil or table.find(Available, V)) then return V end
        end
    end

    function PL:Sort(Items)
        local Out = {}
        for _, V in ipairs(Items or self.Value) do
            if IsEnabled(V) then table.insert(Out, V) end
        end
        table.sort(Out, function(A, B)
            return (table.find(self.Value, A) or math.huge) < (table.find(self.Value, B) or math.huge)
        end)
        return Out
    end

    function PL:GetConfig()
        local Disabled = {}
        for V, On in pairs(self.Enabled) do
            if On == false then table.insert(Disabled, V) end
        end
        Remember()
        return { Order = self.Pool and self.Value or self.Memory, Disabled = Disabled }
    end

    function PL:OnChanged(F)
        self.Changed = F
        Library:SafeCallback(F, self.Value, self.Enabled)
    end

    if type(Info.Default) == 'table' then
        for _, V in ipairs(Info.Default) do table.insert(PL.Memory, V) end
    end
    if type(Info.Disabled) == 'table' then
        for _, V in ipairs(Info.Disabled) do PL.Enabled[V] = false end
    end
    local Initial = {}
    for _, V in ipairs(Info.Values or {}) do table.insert(Initial, V) end
    PL.Values = Initial
    local Present, List = {}, {}
    for I, V in ipairs(Initial) do
        if not Present[V] then Present[V] = true; table.insert(List, { V = V, I = I }) end
    end
    table.sort(List, function(A, B)
        local RA, RB = MemoryRank(A.V), MemoryRank(B.V)
        if RA ~= RB then return RA < RB end
        return A.I < B.I
    end)
    for I, Item in ipairs(List) do
        table.insert(PL.Value, Item.V)
        local Row = MakeRow(Item.V)
        Rows[Item.V] = Row
        Row.Frame.Position = SlotPos(I)
    end
    Remember()
    Layout(false)

    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, ListFrame) end
    AddElement(self, Holder, Info.Text or Idx)
    Options[Idx] = PL
    return PL
end
Funcs.AddPriority = Funcs.AddPriorityList

-- Pool of items that are not in a PriorityList yet. Drag a chip into the list (or click it)
-- to add it; drag a row from the list onto the pool (or press x) to take it out.
function Funcs:AddPriorityPool(Idx, Info)
    Info = Info or {}
    local Target = Info.Target
    assert(Target and Target.Type == 'PriorityList', 'AddPriorityPool: Target must be a PriorityList')
    local Pool = { Type = 'PriorityPool', Values = {}, Value = {}, NoConfig = true }
    local Groupbox = self.Groupbox
    local Press, Drag

    local Holder = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
    ListLayout(Holder, 6)
    if Info.Text then
        Text({ Text = Info.Text, ColorKey = 'SubText', Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = Holder })
    end

    local SearchBox
    if Info.Searchable ~= false then
        local Bg = Create('Frame', { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 2, Parent = Holder })
        Themed(Bg, { BackgroundColor3 = 'Element' }); Corner(Bg, 6)
        local BgStroke = Stroke(Bg)
        local In = SmoothInput(Bg, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextSize = 12, Placeholder = 'Search...' })
        SearchBox = In.Box
        SearchBox.Focused:Connect(function() Tween(BgStroke, { Color = Library.Theme.Accent }) end)
        SearchBox.FocusLost:Connect(function() Tween(BgStroke, { Color = Library.Theme.Stroke }) end)
    end

    local Area = Create('Frame', {
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = Holder,
    })
    Themed(Area, { BackgroundColor3 = 'Background' }); Corner(Area, 8)
    local AreaStroke = Stroke(Area)
    Padding(Area, 8, 8, 8, 8)
    local Chips = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = Area })
    local ChipLayout = ListLayout(Chips, 6, Enum.FillDirection.Horizontal)
    pcall(function() ChipLayout.Wraps = true end)
    local Empty = Text({
        Text = Info.EmptyText or 'Everything is in the list', ColorKey = 'DimText', TextSize = 12, RichText = false,
        TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 24), Visible = false, Parent = Area,
    })
    Pool.Area = Area

    local Highlighted = false
    function Pool:SetDropHighlight(On)
        if On == Highlighted then return end
        Highlighted = On
        Tween(AreaStroke, { Color = On and Library.Theme.Risk or Library.Theme.Stroke }, 0.15)
        Tween(Area, { BackgroundColor3 = On and Library.Theme.Background:Lerp(Library.Theme.Risk, 0.08) or Library.Theme.Background }, 0.15)
    end

    local function IsOver(Frame, Pt)
        local P, S = Frame.AbsolutePosition, Frame.AbsoluteSize
        return Pt.X >= P.X and Pt.X <= P.X + S.X and Pt.Y >= P.Y and Pt.Y <= P.Y + S.Y
    end

    local Order = 0
    local function MakeChip(V, Animate)
        Order = Order + 1
        local Chip = Create('TextButton', {
            AutoButtonColor = false, Text = tostring(V), Font = Library.Font, TextSize = 12,
            Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = Order, Parent = Chips,
        })
        Themed(Chip, { BackgroundColor3 = 'Element', TextColor3 = 'SubText' })
        Corner(Chip, 6); Padding(Chip, 0, 0, 10, 10)
        local ChipStroke = Stroke(Chip)
        local ChipScale = Create('UIScale', { Parent = Chip })
        if Animate then
            ChipScale.Scale = 0.5
            Tween(ChipScale, { Scale = 1 }, 0.35, Back)
        end
        Chip.MouseEnter:Connect(function()
            if Drag then return end
            Tween(ChipStroke, { Color = Library.Theme.Accent }, 0.15)
            Tween(Chip, { TextColor3 = Library.Theme.Text }, 0.15)
        end)
        Chip.MouseLeave:Connect(function()
            Tween(ChipStroke, { Color = Library.Theme.Stroke }, 0.15)
            Tween(Chip, { TextColor3 = Library.Theme.SubText }, 0.15)
        end)
        Chip.InputBegan:Connect(function(Input)
            if IsClick(Input) and not Drag then Press = { V = V, Chip = Chip, Pt = PointerOf(Input) } end
        end)
        Chip.MouseButton1Click:Connect(function()
            if Drag or Pool.JustDragged then return end
            Target:Insert(V)
        end)
        return Chip
    end

    function Pool:Build()
        for _, C in ipairs(Chips:GetChildren()) do
            if C:IsA('TextButton') then C:Destroy() end
        end
        local Query = SearchBox and string.lower(SearchBox.Text) or ''
        self.Value = {}
        local Shown = 0
        for _, V in ipairs(self.Values) do
            if not table.find(Target.Value, V) then
                table.insert(self.Value, V)
                if Query == '' or string.find(string.lower(tostring(V)), Query, 1, true) then
                    MakeChip(V, false)
                    Shown = Shown + 1
                end
            end
        end
        Empty.Visible = Shown == 0
        Empty.Text = (#self.Value > 0 and Query ~= '') and 'No results' or (Info.EmptyText or 'Everything is in the list')
    end

    function Pool:SetValues(Values)
        self.Values = {}
        for _, V in ipairs(Values or {}) do
            if not table.find(self.Values, V) then table.insert(self.Values, V) end
        end
        self:Build()
    end
    Pool.Refresh = Pool.SetValues

    -- dragging a chip into the list
    local function StartDrag(P, Pt)
        Library:CloseDropdown()
        local Scale = Library.UIScale and Library.UIScale.Scale or 1
        local Ghost = Create('TextLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(Pt.X, Pt.Y), Size = UDim2.fromOffset(0, 28),
            AutomaticSize = Enum.AutomaticSize.X, Text = tostring(P.V), Font = Library.FontMedium, TextSize = 12,
            ZIndex = 120, Parent = Overlay,
        })
        Themed(Ghost, { BackgroundColor3 = 'Card', TextColor3 = 'Text' })
        Corner(Ghost, 6); Padding(Ghost, 0, 0, 12, 12)
        Stroke(Ghost, 'Accent', 1.5)
        local GhostScale = Create('UIScale', { Scale = Scale * 0.8, Parent = Ghost })
        Tween(GhostScale, { Scale = Scale * 1.08 }, 0.3, Back)
        Tween(P.Chip, { TextTransparency = 0.7, BackgroundTransparency = 0.6 }, 0.15)
        Drag = { V = P.V, Chip = P.Chip, Ghost = Ghost, GhostScale = GhostScale }
        if Groupbox and Groupbox.Column then Groupbox.Column.ScrollingEnabled = false end
    end

    local function MoveDrag(Pt)
        Drag.LastPt = Pt
        Tween(Drag.Ghost, { Position = UDim2.fromOffset(Pt.X, Pt.Y) }, 0.05, Enum.EasingStyle.Linear)
        if IsOver(Target.ListFrame, Pt) or (Target.ListFrame.AbsoluteSize.Y < 40 and IsOver(Target.ListFrame.Parent, Pt)) then
            Drag.Index = Target:IndexAt(Pt)
            Target:ShowDropMarker(Drag.Index)
        else
            Drag.Index = nil
            Target:ShowDropMarker(nil)
        end
    end

    local function EndDrag()
        local D = Drag
        Drag = nil
        Target:ShowDropMarker(nil)
        if Groupbox and Groupbox.Column then Groupbox.Column.ScrollingEnabled = true end
        Pool.JustDragged = true
        task.defer(function() Pool.JustDragged = false end)
        if D.Index then
            Tween(D.GhostScale, { Scale = 0.2 }, 0.18)
            Tween(D.Ghost, { TextTransparency = 1, BackgroundTransparency = 1 }, 0.18)
            task.delay(0.2, function() D.Ghost:Destroy() end)
            Target:Insert(D.V, D.Index)
        else
            Tween(D.GhostScale, { Scale = 0.6 }, 0.2)
            Tween(D.Ghost, { TextTransparency = 1, BackgroundTransparency = 1 }, 0.2)
            task.delay(0.22, function() D.Ghost:Destroy() end)
            if D.Chip.Parent then Tween(D.Chip, { TextTransparency = 0, BackgroundTransparency = 0 }, 0.2) end
        end
    end

    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if not (Input.UserInputType == Move or Input.UserInputType == Touch) then return end
        if Drag then
            MoveDrag(PointerOf(Input))
        elseif Press then
            local Pt = PointerOf(Input)
            if (Pt - Press.Pt).Magnitude > 5 then
                local P = Press
                Press = nil
                StartDrag(P, Pt)
                MoveDrag(Pt)
            end
        end
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if not IsClick(Input) then return end
        Press = nil
        if Drag then EndDrag() end
    end))

    if SearchBox then
        SearchBox:GetPropertyChangedSignal('Text'):Connect(function() Pool:Build() end)
    end
    table.insert(Target.Listeners, function() Pool:Build() end)
    Target:LinkPool(Pool)

    Pool:SetValues(Info.Values or {})
    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, Area) end
    AddElement(self, Holder, Info.Text or Idx)
    Options[Idx] = Pool
    return Pool
end

function Funcs:AddParagraph(Idx, Info)
    Info = Info or {}
    local Height = math.clamp(tonumber(Info.Height) or 220, 120, 500)
    local Object = { Type = 'Paragraph', Value = {}, Callback = Info.Callback, NoConfig = Info.NoConfig }
    local Groupbox = self.Groupbox
    local Chips, Pills = {}, {}

    local Holder = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
    ListLayout(Holder, 8)
    local TitleLabel = Text({ Text = tostring(Info.Title or Info.Text or Idx), Font = Library.FontMedium, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = Holder })
    local ContentLabel = Text({
        Text = Info.Content or 'Drag the labels to position them', ColorKey = 'DimText', TextSize = 12,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Parent = Holder,
    })

    local Preview = Create('Frame', { BorderSizePixel = 0, ClipsDescendants = true, Size = UDim2.new(1, 0, 0, Height), LayoutOrder = 3, Parent = Holder })
    Themed(Preview, { BackgroundColor3 = 'Background' }); Corner(Preview, 8)
    local PreviewStroke = Stroke(Preview)
    for I = 1, 3 do
        local V = Create('Frame', { BorderSizePixel = 0, BackgroundTransparency = 0.65, Position = UDim2.fromScale(I / 4, 0), Size = UDim2.new(0, 1, 1, 0), Parent = Preview })
        Themed(V, { BackgroundColor3 = 'Stroke' })
        local H = Create('Frame', { BorderSizePixel = 0, BackgroundTransparency = 0.65, Position = UDim2.fromScale(0, I / 4), Size = UDim2.new(1, 0, 0, 1), Parent = Preview })
        Themed(H, { BackgroundColor3 = 'Stroke' })
    end

    local Viewport = Create('ViewportFrame', {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(190, 190, 190),
        LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 2, Parent = Preview,
    })
    local Camera = Create('Camera', { FieldOfView = 40, CFrame = CFrame.new(Vector3.new(0, 1, 9), Vector3.new(0, 1, 0)), Parent = Viewport })
    Viewport.CurrentCamera = Camera
    local Model = Create('Model', { Name = 'Preview', Parent = Viewport })
    for _, P in ipairs({ { 'Head', 0, 2.5, 1.2, 1.2 }, { 'Torso', 0, 1, 1.8, 1.8 }, { 'LeftArm', -1.35, 1, 0.7, 1.8 },
        { 'RightArm', 1.35, 1, 0.7, 1.8 }, { 'LeftLeg', -0.48, -0.9, 0.8, 1.8 }, { 'RightLeg', 0.48, -0.9, 0.8, 1.8 } }) do
        Create('Part', {
            Name = P[1], Anchored = true, CanCollide = false, Size = Vector3.new(P[4], P[5], 0.8),
            Position = Vector3.new(P[2], P[3], 0), Color = Info.CharacterColor or Color3.fromRGB(170, 180, 195),
            Material = Enum.Material.SmoothPlastic, Parent = Model,
        })
    end

    local Box = Blank({
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, Height * 0.04),
        Size = UDim2.fromOffset(Height * 0.56, Height * 0.8), ZIndex = 3, Parent = Preview,
    })
    Corner(Box, 4)
    local BoxStroke = Stroke(Box, 'Accent')
    BoxStroke.Transparency = 0.55

    local GuideV = Create('Frame', { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Size = UDim2.new(0, 1, 1, 0), ZIndex = 4, Parent = Preview })
    local GuideH = Create('Frame', { BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 1), ZIndex = 4, Parent = Preview })
    Themed(GuideV, { BackgroundColor3 = 'Accent' }); Themed(GuideH, { BackgroundColor3 = 'Accent' })

    local PillRow = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = Holder })
    local PillLayout = ListLayout(PillRow, 6, Enum.FillDirection.Horizontal)
    pcall(function() PillLayout.Wraps = true end)

    local Definitions = Info.Items or { Name = { Text = 'Player Name' }, Health = { Text = '100 HP' }, Distance = { Text = '25 m' }, Weapon = { Text = 'Weapon' } }
    local Defaults = { Name = Vector2.new(0.5, 0.12), Health = Vector2.new(0.18, 0.5), Distance = Vector2.new(0.5, 0.88), Weapon = Vector2.new(0.8, 0.5) }
    local Names = {}
    for Name in pairs(Definitions) do table.insert(Names, Name) end
    table.sort(Names)

    local function CopyLayout(Layout)
        local Result = {}
        for Name, E in pairs(Layout) do
            Result[Name] = { Enabled = E.Enabled, Position = { X = E.Position.X, Y = E.Position.Y } }
        end
        return Result
    end

    local function Fire()
        local Layout = CopyLayout(Object.Value)
        Library:SafeCallback(Object.Callback, Layout)
        Library:SafeCallback(Object.Changed, Layout)
    end

    local function PaintPill(Name, Animate)
        local P = Pills[Name]
        if not P then return end
        local On = Object.Value[Name].Enabled
        local T = Library.Theme
        local Props = {
            { P.Button, { BackgroundColor3 = On and T.Accent or T.Element, TextColor3 = On and Color3.new(1, 1, 1) or T.SubText } },
            { P.Stroke, { Color = On and T.Accent or T.Stroke } },
        }
        for _, X in ipairs(Props) do
            if Animate then Tween(X[1], X[2], 0.2) else for K, V in pairs(X[2]) do X[1][K] = V end end
        end
    end

    local function PaintChip(Name, Animate)
        local C = Chips[Name]
        local E = Object.Value[Name]
        if not C then return end
        local Pos = UDim2.fromScale(E.Position.X, E.Position.Y)
        if E.Enabled then
            C.Button.Visible = true
            if Animate then
                Tween(C.Scale, { Scale = 1 }, 0.3, Back)
                Tween(C.Button, { TextTransparency = 0, BackgroundTransparency = 0.12, Position = Pos }, 0.2)
                Tween(C.Stroke, { Transparency = 0 }, 0.2)
            else
                C.Scale.Scale, C.Button.TextTransparency, C.Button.BackgroundTransparency, C.Stroke.Transparency = 1, 0, 0.12, 0
                C.Button.Position = Pos
            end
        else
            C.Button.Position = Pos
            if Animate then
                Tween(C.Scale, { Scale = 0.6 }, 0.18)
                Tween(C.Button, { TextTransparency = 1, BackgroundTransparency = 1 }, 0.18)
                Tween(C.Stroke, { Transparency = 1 }, 0.18)
                task.delay(0.19, function() if not Object.Value[Name].Enabled then C.Button.Visible = false end end)
            else
                C.Button.Visible = false
            end
        end
    end

    function Object:Refresh(Animate)
        for _, Name in ipairs(Names) do
            PaintChip(Name, Animate)
            PaintPill(Name, Animate)
        end
    end

    function Object:GetLayout() return CopyLayout(self.Value) end

    function Object:SetValue(Layout)
        if type(Layout) ~= 'table' then return end
        for Name, E in pairs(Layout) do
            local Cur = self.Value[Name]
            if Cur and type(E) == 'table' then
                if type(E.Enabled) == 'boolean' then Cur.Enabled = E.Enabled end
                local P = E.Position
                if type(P) == 'table' and tonumber(P.X) and tonumber(P.Y) then
                    Cur.Position = { X = math.clamp(tonumber(P.X), 0, 1), Y = math.clamp(tonumber(P.Y), 0, 1) }
                end
            end
        end
        self:Refresh(true)
        Fire()
    end

    function Object:SetEnabled(Name, Enabled)
        if not self.Value[Name] then return end
        self.Value[Name].Enabled = Enabled == true
        PaintChip(Name, true)
        PaintPill(Name, true)
        Fire()
    end

    function Object:SetPosition(Name, Position)
        if not self.Value[Name] then return end
        self.Value[Name].Position = { X = math.clamp(Position.X, 0, 1), Y = math.clamp(Position.Y, 0, 1) }
        PaintChip(Name, true)
        Fire()
    end

    function Object:SetText(Name, Str) if Chips[Name] then Chips[Name].Button.Text = tostring(Str) end end
    function Object:SetTitle(Str) TitleLabel.Text = tostring(Str) end
    function Object:SetContent(Str) ContentLabel.Text = tostring(Str) end
    function Object:OnChanged(F)
        self.Changed = F
        Library:SafeCallback(F, self:GetLayout())
    end

    local Drag
    local function ShowGuide(Guide, Pos, On)
        if Pos then Guide.Position = Pos end
        Tween(Guide, { BackgroundTransparency = On and 0.3 or 1 }, 0.12)
    end

    local function Snap(Value, Targets, Range)
        for _, T in ipairs(Targets) do
            if math.abs(Value - T) <= Range then return T, true end
        end
        return Value, false
    end

    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if not Drag or not (Input.UserInputType == Move or Input.UserInputType == Touch) then return end
        local Pt = PointerOf(Input)
        local Size, Origin = Preview.AbsoluteSize, Preview.AbsolutePosition
        local C = Chips[Drag.Name]
        local Half = C.Button.AbsoluteSize / 2
        local X = (Pt.X - Origin.X - Drag.Offset.X)
        local Y = (Pt.Y - Origin.Y - Drag.Offset.Y)

        local BP, BS = Box.AbsolutePosition - Origin, Box.AbsoluteSize
        local SnappedX, SnappedY
        X, SnappedX = Snap(X, { Size.X / 2, BP.X - Half.X - 4, BP.X + BS.X + Half.X + 4 }, 6)
        Y, SnappedY = Snap(Y, { BP.Y - Half.Y - 4, BP.Y + BS.Y / 2, BP.Y + BS.Y + Half.Y + 4 }, 6)
        X = math.clamp(X, Half.X, Size.X - Half.X)
        Y = math.clamp(Y, Half.Y, Size.Y - Half.Y)
        ShowGuide(GuideV, SnappedX and UDim2.fromScale(X / math.max(Size.X, 1), 0), SnappedX)
        ShowGuide(GuideH, SnappedY and UDim2.fromScale(0, Y / math.max(Size.Y, 1)), SnappedY)

        local FX, FY = X / math.max(Size.X, 1), Y / math.max(Size.Y, 1)
        Object.Value[Drag.Name].Position = { X = FX, Y = FY }
        Tween(C.Button, { Position = UDim2.fromScale(FX, FY) }, 0.06, Enum.EasingStyle.Linear)
        Fire()
    end))

    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if not Drag or not IsClick(Input) then return end
        local C = Chips[Drag.Name]
        Drag = nil
        Tween(C.Scale, { Scale = 1 }, 0.3, Back)
        Tween(C.Stroke, { Color = Library.Theme.Stroke }, 0.2)
        C.Button.ZIndex = 6
        ShowGuide(GuideV, nil, false)
        ShowGuide(GuideH, nil, false)
        Tween(PreviewStroke, { Color = Library.Theme.Stroke }, 0.2)
        if Groupbox and Groupbox.Column then Groupbox.Column.ScrollingEnabled = true end
        Library:AttemptSave()
    end))

    for I, Name in ipairs(Names) do
        local Item = Definitions[Name]
        if type(Item) == 'string' then Item = { Text = Item } end
        local Pos = Item.Position or Defaults[Name] or Vector2.new(0.5, 0.5)
        Object.Value[Name] = { Enabled = Item.Enabled ~= false, Position = { X = math.clamp(Pos.X, 0, 1), Y = math.clamp(Pos.Y, 0, 1) } }

        local Chip = Create('TextButton', {
            AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 22),
            AutomaticSize = Enum.AutomaticSize.X, Text = Item.Text or Name, Font = Library.FontMedium, TextSize = 12,
            BackgroundTransparency = 0.12, ZIndex = 6, Parent = Preview,
        })
        Themed(Chip, { BackgroundColor3 = 'Card' })
        if Item.Color then Chip.TextColor3 = Item.Color else Themed(Chip, { TextColor3 = 'Accent' }) end
        Corner(Chip, 5); Padding(Chip, 0, 0, 8, 8)
        local ChipStroke = Stroke(Chip)
        local ChipScale = Create('UIScale', { Parent = Chip })
        Chips[Name] = { Button = Chip, Stroke = ChipStroke, Scale = ChipScale }

        Chip.MouseEnter:Connect(function() if not Drag then Tween(ChipStroke, { Color = Lerp('Stroke', 'Accent', 0.6) }, 0.15) end end)
        Chip.MouseLeave:Connect(function() if not Drag then Tween(ChipStroke, { Color = Library.Theme.Stroke }, 0.15) end end)
        Chip.InputBegan:Connect(function(Input)
            if not IsClick(Input) or Drag then return end
            local Pt = PointerOf(Input)
            local E = Object.Value[Name].Position
            local Size, Origin = Preview.AbsoluteSize, Preview.AbsolutePosition
            Drag = { Name = Name, Offset = Vector2.new(Pt.X - Origin.X - E.X * Size.X, Pt.Y - Origin.Y - E.Y * Size.Y) }
            Chip.ZIndex = 7
            Tween(ChipScale, { Scale = 1.12 }, 0.25, Back)
            Tween(ChipStroke, { Color = Library.Theme.Accent }, 0.15)
            Tween(PreviewStroke, { Color = Lerp('Stroke', 'Accent', 0.5) }, 0.2)
            if Groupbox and Groupbox.Column then Groupbox.Column.ScrollingEnabled = false end
        end)

        local Pill = Create('TextButton', {
            AutoButtonColor = false, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
            Text = Name, Font = Library.FontMedium, TextSize = 12, LayoutOrder = I, Parent = PillRow,
        })
        Corner(Pill, 'full'); Padding(Pill, 0, 0, 12, 12)
        local PillStroke = Create('UIStroke', { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Pill })
        local PillScale = Create('UIScale', { Parent = Pill })
        Pills[Name] = { Button = Pill, Stroke = PillStroke }
        Pill.MouseButton1Down:Connect(function() Tween(PillScale, { Scale = 0.92 }, 0.1) end)
        Pill.MouseButton1Up:Connect(function() Tween(PillScale, { Scale = 1 }, 0.3, Back) end)
        Pill.MouseLeave:Connect(function() Tween(PillScale, { Scale = 1 }, 0.2) end)
        Pill.MouseButton1Click:Connect(function()
            Object:SetEnabled(Name, not Object.Value[Name].Enabled)
            Library:AttemptSave()
        end)
    end

    table.insert(Library.ThemeCallbacks, function() Object:Refresh(false) end)
    Object:Refresh(false)
    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, Preview) end
    AddElement(self, Holder, Info.Title or Info.Text or Idx)
    Options[Idx] = Object
    return Object
end
Funcs.AddPreview = Funcs.AddParagraph

function Funcs:AddToggle(Idx, Info)
    Info = Info or {}
    local Toggle = {
        Value = Info.Default or false, Type = 'Toggle', Callback = Info.Callback,
        Addons = {}, Risky = Info.Risky, NoConfig = Info.NoConfig, Text = Info.Text or Idx,
    }

    local Row = Create('TextButton', { AutoButtonColor = false, BackgroundTransparency = 1, Text = '', Size = UDim2.new(1, 0, 0, 22) })
    local Box = Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0, Parent = Row,
    })
    Corner(Box, 4)
    local BoxScale = Create('UIScale', { Parent = Box })
    local BoxStroke = Create('UIStroke', { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Box })
    local Check = CheckIcon(Box, Color3.new(1, 1, 1))
    local Label = Create('TextLabel', {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -26, 1, 0),
        Font = Library.Font, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
        Text = Toggle.Text, Parent = Row,
    })
    Toggle.TextLabel = Label

    local Hovering = false
    function Toggle:UpdateColors(Instant)
        local T = Library.Theme
        local BoxProps = { BackgroundColor3 = self.Value and T.Accent or T.Element }
        local StrokeProps = { Color = (self.Value or Hovering) and T.Accent or T.Stroke }
        local LabelProps = { TextColor3 = self.Risky and T.Risk or ((self.Value or Hovering) and T.Text or T.SubText) }
        Check:Set(self.Value, not Instant)
        if Instant then
            for K, V in pairs(BoxProps) do Box[K] = V end
            for K, V in pairs(StrokeProps) do BoxStroke[K] = V end
            for K, V in pairs(LabelProps) do Label[K] = V end
        else
            Tween(Box, BoxProps); Tween(BoxStroke, StrokeProps); Tween(Label, LabelProps)
            Tween(Label, { Position = UDim2.fromOffset(Hovering and 29 or 26, 0) }, 0.2)
        end
    end
    Toggle.Display = Toggle.UpdateColors
    table.insert(Library.ThemeCallbacks, function() Toggle:UpdateColors(true) end)

    function Toggle:SetValue(Bool)
        Bool = not not Bool
        self.InitialCallbackPending = false
        local Changed = self.Value ~= Bool
        self.Value = Bool
        self:UpdateColors()
        if Changed then
            BoxScale.Scale = 0.75
            Tween(BoxScale, { Scale = 1 }, 0.35, Back)
        end
        for _, Addon in ipairs(self.Addons) do
            if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then Addon.Toggled = Bool end
        end
        Library:SafeCallback(self.Callback, Bool)
        Library:SafeCallback(self.Changed, Bool)
        Library:UpdateDependencyBoxes()
    end

    function Toggle:OnChanged(F)
        self.Changed = F
        Library:SafeCallback(F, self.Value)
    end

    function Toggle:AddKeyPicker(KIdx, KInfo) return CreateKeyPicker(Toggle, Row, KIdx, KInfo) end
    function Toggle:AddColorPicker(CIdx, CInfo) return CreateColorPicker(Toggle, Row, CIdx, CInfo) end
    Toggle.Box = self
    EnableNesting(Toggle, self, Row, Toggle.Text, function(G)
        G.LayoutOrder = 1000
        G.Parent = GetAddonHolder(Toggle, Row)
    end)
    function Toggle:AddTooltip(Tip) Library:AddToolTip(Tip, Row); return self end

    Row.MouseEnter:Connect(function() Hovering = true; Toggle:UpdateColors() end)
    Row.MouseLeave:Connect(function() Hovering = false; Toggle:UpdateColors() end)
    Row.MouseButton1Click:Connect(function()
        Toggle:SetValue(not Toggle.Value)
        Library:AttemptSave()
    end)

    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, Row) end
    Toggle:UpdateColors(true)
    AddElement(self, Row, Toggle.Text)
    Toggles[Idx] = Toggle

    if Toggle.Value then
        Toggle.InitialCallbackPending = true
        task.defer(function()
            if Toggle.InitialCallbackPending and Toggle.Value then
                Toggle.InitialCallbackPending = false
                Library:SafeCallback(Toggle.Callback, true)
            end
        end)
    end
    Library:UpdateDependencyBoxes()
    return Toggle
end

function Funcs:AddSlider(Idx, Info)
    Info = Info or {}
    local Slider = {
        Min = Info.Min or 0, Max = Info.Max or 100, Rounding = Info.Rounding or 0,
        Suffix = Info.Suffix or '', Type = 'Slider', Callback = Info.Callback, NoConfig = Info.NoConfig,
        AllowOutOfRange = Info.AllowOutOfRange,
    }
    Slider.Value = Info.Default or Slider.Min
    local Groupbox = self.Groupbox

    local Holder = Blank({ Size = UDim2.new(1, 0, 0, 36) })
    local TitleLabel = Text({ Text = Info.Text or Idx, Size = UDim2.new(1, -80, 0, 16), Parent = Holder })

    local ValueBox = Create('TextBox', {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -3),
        Size = UDim2.fromOffset(70, 20), ZIndex = 4, Active = true, TextEditable = true,
        BackgroundTransparency = 1, BorderSizePixel = 0, Font = Library.FontMedium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right, ClearTextOnFocus = false, Text = '', Parent = Holder,
    })
    Themed(ValueBox, { TextColor3 = 'Accent', BackgroundColor3 = 'Element' })
    Corner(ValueBox, 4); Padding(ValueBox, 0, 0, 6, 6)
    local ValueStroke = Stroke(ValueBox)
    ValueStroke.Transparency = 1

    local Track = Create('Frame', { BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 26), Size = UDim2.new(1, -12, 0, 4), Parent = Holder })
    Themed(Track, { BackgroundColor3 = 'Element' }); Corner(Track, 'full')
    local Fill = Create('Frame', { BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = Track })
    Themed(Fill, { BackgroundColor3 = 'Accent' }); Corner(Fill, 'full')
    local Knob = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(12, 12), ZIndex = 2, Parent = Track,
    })
    Themed(Knob, { BackgroundColor3 = 'Knob' }); Corner(Knob, 'full')
    local KnobStroke = Stroke(Knob, 'Accent', 2)

    local Glow = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 1, Parent = Knob,
    })
    Themed(Glow, { BackgroundColor3 = 'Accent' }); Corner(Glow, 'full')

    local Hit = Create('TextButton', {
        BackgroundTransparency = 1, Text = '', Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 18),
        ZIndex = 3, Parent = Holder,
    })

    local function Round(V)
        if Slider.Rounding == 0 then return math.floor(V + 0.5) end
        local M = 10 ^ Slider.Rounding
        return math.floor(V * M + 0.5) / M
    end

    local function Format(V)
        return string.format('%.' .. Slider.Rounding .. 'f', V)
    end

    function Slider:Display(Instant)
        local Range = self.Max - self.Min
        local Pct = Range == 0 and 0 or math.clamp((self.Value - self.Min) / Range, 0, 1)
        if Instant then
            Fill.Size = UDim2.fromScale(Pct, 1)
            Knob.Position = UDim2.fromScale(Pct, 0.5)
        else
            Tween(Fill, { Size = UDim2.fromScale(Pct, 1) }, 0.18)
            Tween(Knob, { Position = UDim2.fromScale(Pct, 0.5) }, 0.18)
        end
        if not ValueBox:IsFocused() then
            ValueBox.Text = Format(self.Value) .. self.Suffix
        end
    end

    function Slider:SetValue(N, Instant)
        N = tonumber(N)
        if not N then self:Display(); return end
        if not self.AllowOutOfRange then N = math.clamp(N, self.Min, self.Max) end
        N = Round(N)
        if N == self.Value then self:Display(Instant); return end
        self.Value = N
        self:Display(Instant)
        Library:SafeCallback(self.Callback, N)
        Library:SafeCallback(self.Changed, N)
    end

    function Slider:SetMin(V) self.Min = V; self:SetValue(math.max(self.Value, V)); self:Display() end
    function Slider:SetMax(V) self.Max = V; self:SetValue(math.min(self.Value, V)); self:Display() end

    function Slider:OnChanged(F)
        self.Changed = F
        Library:SafeCallback(F, self.Value)
    end

    ValueBox.MouseEnter:Connect(function()
        if not ValueBox:IsFocused() then Tween(ValueBox, { BackgroundTransparency = 0.4 }, 0.15) end
    end)
    ValueBox.MouseLeave:Connect(function()
        if not ValueBox:IsFocused() then Tween(ValueBox, { BackgroundTransparency = 1 }, 0.15) end
    end)
    ValueBox.Focused:Connect(function()
        ValueBox.Text = Format(Slider.Value)
        ValueBox.CursorPosition = #ValueBox.Text + 1
        Tween(ValueBox, { BackgroundTransparency = 0 })
        Tween(ValueStroke, { Transparency = 0, Color = Library.Theme.Accent })
    end)
    ValueBox.FocusLost:Connect(function()
        Tween(ValueBox, { BackgroundTransparency = 1 })
        Tween(ValueStroke, { Transparency = 1, Color = Library.Theme.Stroke })
        local Cleaned = string.gsub(ValueBox.Text, '[^%d%.%-]', '')
        local N = tonumber(Cleaned)
        if N then
            Slider:SetValue(N)
            Library:AttemptSave()
        end
        Slider:Display()
    end)

    local Dragging, Hovering = false, false
    local function SetKnobState()
        local Active = Dragging or Hovering
        Tween(Knob, { Size = UDim2.fromOffset(Active and 15 or 12, Active and 15 or 12) }, 0.25, Back)
        Tween(Glow, {
            Size = UDim2.fromOffset(Dragging and 26 or (Hovering and 20 or 12), Dragging and 26 or (Hovering and 20 or 12)),
            BackgroundTransparency = Dragging and 0.75 or (Hovering and 0.85 or 1),
        }, 0.25)
    end

    local function Update(X)
        local Pct = math.clamp((X - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
        Slider:SetValue(Slider.Min + (Slider.Max - Slider.Min) * Pct)
    end

    Hit.MouseEnter:Connect(function() Hovering = true; SetKnobState() end)
    Hit.MouseLeave:Connect(function() Hovering = false; SetKnobState() end)
    Hit.InputBegan:Connect(function(Input)
        if not IsClick(Input) then return end
        Dragging = true
        if Groupbox and Groupbox.Column then Groupbox.Column.ScrollingEnabled = false end
        SetKnobState()
        Update(PointerOf(Input).X)
    end)
    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if Dragging and (Input.UserInputType == Move or Input.UserInputType == Touch) then Update(PointerOf(Input).X) end
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if Dragging and IsClick(Input) then
            Dragging = false
            if Groupbox and Groupbox.Column then Groupbox.Column.ScrollingEnabled = true end
            SetKnobState()
            Library:AttemptSave()
        end
    end))

    if not Slider.AllowOutOfRange then Slider.Value = math.clamp(Slider.Value, Slider.Min, Slider.Max) end
    Slider.Value = Round(Slider.Value)
    Slider:Display(true)
    EnableNesting(Slider, self, Holder, Info.Text or Idx, function(G)
        G.AnchorPoint = Vector2.new(1, 0)
        G.Position = UDim2.new(1, -72, 0, -3)
        G.Parent = Holder
        TitleLabel.Size = UDim2.new(1, -100, 0, 16)
    end)
    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, Holder) end
    AddElement(self, Holder, Info.Text or Idx)
    Options[Idx] = Slider
    return Slider
end

function Funcs:AddDropdown(Idx, Info)
    Info = Info or {}
    if Info.SpecialType == 'Player' then
        Info.Values = GetPlayerNames(); Info.AllowNull = true
    elseif Info.SpecialType == 'Team' then
        Info.Values = GetTeamNames(); Info.AllowNull = true
    end
    assert(Info.Values, 'AddDropdown: Missing `Values` table.')

    local Dropdown = {
        Values = Info.Values, Multi = Info.Multi, Type = 'Dropdown', SpecialType = Info.SpecialType,
        Callback = Info.Callback, AllowNull = Info.AllowNull, NoConfig = Info.NoConfig, IsOpen = false,
    }
    Dropdown.Value = Info.Multi and {} or nil
    local ITEM_H, MAX_ITEMS = 28, Info.MaxVisible or 7

    local TitleLabel
    local Holder = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
    ListLayout(Holder, 6)
    if Info.Text then
        TitleLabel = Text({ Text = Info.Text, ColorKey = 'SubText', Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = Holder })
    end

    local Button = Create('TextButton', { AutoButtonColor = false, Text = '', Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2, Parent = Holder })
    Themed(Button, { BackgroundColor3 = 'Element' }); Corner(Button, 6)
    local ButtonStroke = Stroke(Button)
    local ValueLabel = Text({
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd, RichText = false, Parent = Button,
    })
    local Arrow = ChevronIcon(Button, 'SubText', { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0) })
    Arrow:Set(false)

    Button.MouseEnter:Connect(function()
        Tween(Button, { BackgroundColor3 = Library.Theme.Hover })
        if not Dropdown.IsOpen then Tween(ButtonStroke, { Color = Lerp('Stroke', 'Accent', 0.5) }) end
    end)
    Button.MouseLeave:Connect(function()
        Tween(Button, { BackgroundColor3 = Library.Theme.Element })
        if not Dropdown.IsOpen then Tween(ButtonStroke, { Color = Library.Theme.Stroke }) end
    end)

    local ListFrame = Create('Frame', { Visible = false, Active = true, ClipsDescendants = true, ZIndex = 20, Parent = Overlay })
    Themed(ListFrame, { BackgroundColor3 = 'Element' }); Corner(ListFrame, 6)
    local ListStroke = Stroke(ListFrame, 'Accent')
    local ListScale = Create('UIScale', { Parent = ListFrame })
    local AnimHeight = Create('NumberValue', { Value = 0 })

    local TopOffset = 0
    local SearchBox
    if Info.Searchable ~= false then
        TopOffset = 32
        local SearchIn = SmoothInput(ListFrame, {
            Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 28), TextSize = 12, ZIndex = 21,
            Placeholder = Info.AllowAdd and 'Search or add...' or 'Search...',
        })
        SearchBox = SearchIn.Box
        local Sep = Create('Frame', { BorderSizePixel = 0, Position = UDim2.fromOffset(0, 31), Size = UDim2.new(1, 0, 0, 1), ZIndex = 21, Parent = ListFrame })
        Themed(Sep, { BackgroundColor3 = 'Stroke' })
    end

    local Scroll = Create('ScrollingFrame', {
        BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, TopOffset),
        Size = UDim2.new(1, 0, 0, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ZIndex = 21, Parent = ListFrame,
    })
    Themed(Scroll, { ScrollBarImageColor3 = 'Accent' })
    ListLayout(Scroll, 2); Padding(Scroll, 4, 4, 4, 4)

    Dropdown.ListFrame = ListFrame
    Dropdown.ButtonFrame = Button
    Dropdown.ParentPopup = self.Popup

    local function IsSelected(V)
        if Dropdown.Multi then return Dropdown.Value[V] == true end
        return Dropdown.Value == V
    end

    function Dropdown:GetActiveValues()
        if self.Multi then
            local T = {}
            for _, V in ipairs(self.Values) do if self.Value[V] then table.insert(T, V) end end
            return T
        end
        return self.Value and 1 or 0
    end

    function Dropdown:Display()
        local Str
        if self.Multi then
            local Active = self:GetActiveValues()
            for I, V in ipairs(Active) do Active[I] = tostring(V) end
            Str = table.concat(Active, ', ')
        else
            Str = self.Value ~= nil and tostring(self.Value) or ''
        end
        ValueLabel.Text = Str == '' and '--' or Str
    end

    local function Fire()
        Dropdown:Display()
        Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
        Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
        Library:UpdateDependencyBoxes()
    end

    local ItemRefs = {}

    local function PaintItem(Ref, Animate)
        local T = Library.Theme
        local Sel = IsSelected(Ref.Value)
        local Props = { TextColor3 = Sel and T.Accent or (Ref.Hover and T.Text or T.SubText) }
        if Animate then Tween(Ref.Label, Props, 0.15) else Ref.Label.TextColor3 = Props.TextColor3 end
        Ref.Label.Font = Sel and Library.FontMedium or Library.Font
        Ref.Check:Set(Sel, Animate)
        Tween(Ref.Bar, { Size = UDim2.fromOffset(2, Sel and 14 or 0) }, 0.2)
    end

    local function RepaintAll(Animate)
        for _, Ref in ipairs(ItemRefs) do PaintItem(Ref, Animate) end
    end

    function Dropdown:BuildDropdownList()
        for _, Child in ipairs(Scroll:GetChildren()) do
            if Child:IsA('TextButton') then Child:Destroy() end
        end
        ItemRefs = {}
        local Query = SearchBox and string.lower(SearchBox.Text) or ''
        local Count = 0
        local T = Library.Theme

        for _, V in ipairs(self.Values) do
            local Name = tostring(V)
            if Query == '' or string.find(string.lower(Name), Query, 1, true) then
                Count = Count + 1
                local Item = Create('TextButton', {
                    AutoButtonColor = false, Text = '', BackgroundColor3 = T.Hover, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, ITEM_H), LayoutOrder = Count, ZIndex = 22, Parent = Scroll,
                })
                Corner(Item, 4)
                local Bar = Create('Frame', {
                    BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
                    Size = UDim2.fromOffset(2, 0), BackgroundColor3 = T.Accent, ZIndex = 23, Parent = Item,
                })
                Corner(Bar, 'full')
                local Label = Create('TextLabel', {
                    BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -36, 1, 0),
                    Font = Library.Font, TextSize = 13, Text = Name,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                    TextColor3 = T.SubText, ZIndex = 23, Parent = Item,
                })
                local Check = CheckIcon(Item, T.Accent, nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0) })
                local Ref = { Value = V, Item = Item, Label = Label, Check = Check, Bar = Bar, Hover = false }
                table.insert(ItemRefs, Ref)
                PaintItem(Ref, false)

                Item.MouseEnter:Connect(function()
                    Ref.Hover = true
                    Tween(Item, { BackgroundTransparency = 0 }, 0.12)
                    Tween(Label, { Position = UDim2.fromOffset(16, 0) }, 0.2)
                    PaintItem(Ref, true)
                end)
                Item.MouseLeave:Connect(function()
                    Ref.Hover = false
                    Tween(Item, { BackgroundTransparency = 1 }, 0.12)
                    Tween(Label, { Position = UDim2.fromOffset(12, 0) }, 0.2)
                    PaintItem(Ref, true)
                end)
                Item.MouseButton1Click:Connect(function()
                    if Dropdown.Multi then
                        if Dropdown.Value[V] then Dropdown.Value[V] = nil else Dropdown.Value[V] = true end
                        RepaintAll(true)
                    else
                        if Dropdown.Value == V then
                            if Dropdown.AllowNull then Dropdown.Value = nil end
                        else
                            Dropdown.Value = V
                        end
                        RepaintAll(true)
                        Dropdown:Close()
                    end
                    Fire()
                    Library:AttemptSave()
                end)
            end
        end

        if Count == 0 then
            local Raw = SearchBox and SearchBox.Text or ''
            Create('TextButton', {
                AutoButtonColor = false, Active = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ITEM_H),
                Font = Library.Font, TextSize = 12, TextColor3 = T.DimText, ZIndex = 22, Parent = Scroll,
                Text = (Raw ~= '' and Info.AllowAdd) and ('Press Enter to add "' .. Raw .. '"') or 'No results',
            })
        end
        self.ListHeight = math.max(math.min(Count, MAX_ITEMS), 1) * (ITEM_H + 2) + 8 + TopOffset
        Scroll.Size = UDim2.new(1, 0, 0, self.ListHeight - TopOffset)
        if self.IsOpen then Tween(AnimHeight, { Value = self.ListHeight }, 0.2) end
    end

    function Dropdown:Reposition()
        local Scale = Library.UIScale and Library.UIScale.Scale or 1
        local P, S = Button.AbsolutePosition, Button.AbsoluteSize
        local Full = (self.ListHeight or 0) * Scale
        local Below = P.Y + S.Y + 4
        ListScale.Scale = Scale
        if Below + Full > ScreenGui.AbsoluteSize.Y - 8 then
            ListFrame.AnchorPoint = Vector2.new(0, 1)
            ListFrame.Position = UDim2.fromOffset(P.X, P.Y - 4)
        else
            ListFrame.AnchorPoint = Vector2.new(0, 0)
            ListFrame.Position = UDim2.fromOffset(P.X, Below)
        end
        ListFrame.Size = UDim2.fromOffset(S.X / Scale, AnimHeight.Value)
    end
    AnimHeight:GetPropertyChangedSignal('Value'):Connect(function() Dropdown:Reposition() end)

    function Dropdown:Open()
        if self.IsOpen then return end
        self.IsOpen = true
        ListFrame.ZIndex = 20 + Library:PushPopup(Dropdown) * 5
        if SearchBox then SearchBox.Text = '' end
        self:BuildDropdownList()
        if SearchBox and not UserInputService.TouchEnabled then
            task.delay(0.05, function() if Dropdown.IsOpen then SearchBox:CaptureFocus() end end)
        end
        AnimHeight.Value = 0
        ListStroke.Transparency = 1
        ListFrame.Visible = true
        self:Reposition()
        Tween(AnimHeight, { Value = self.ListHeight }, 0.3)
        Tween(ListStroke, { Transparency = 0 }, 0.2)
        Arrow:Set(true, true)
        Tween(ButtonStroke, { Color = Library.Theme.Accent })
    end

    function Dropdown:Close()
        if not self.IsOpen then return end
        self.IsOpen = false
        Library:RemovePopup(Dropdown)
        Arrow:Set(false, true)
        Tween(ButtonStroke, { Color = Library.Theme.Stroke })
        Tween(ListStroke, { Transparency = 1 }, 0.15)
        local T = Tween(AnimHeight, { Value = 0 }, 0.18)
        T.Completed:Connect(function()
            if not Dropdown.IsOpen then ListFrame.Visible = false end
        end)
    end

    function Dropdown:SetValues(NewValues)
        if NewValues then self.Values = NewValues end
        if self.IsOpen then self:BuildDropdownList() end
    end

    function Dropdown:SetValue(Val)
        if self.Multi then
            local New = {}
            if type(Val) == 'table' then
                for K, V in pairs(Val) do
                    if V == true and table.find(self.Values, K) then New[K] = true
                    elseif type(K) == 'number' and table.find(self.Values, V) then New[V] = true end
                end
            end
            self.Value = New
        else
            if Val ~= nil and table.find(self.Values, Val) then self.Value = Val else self.Value = nil end
        end
        if self.IsOpen then RepaintAll(true) end
        Fire()
    end

    function Dropdown:Refresh(Values)
        self.Values = Values or {}
        if self.Multi then
            for K in pairs(self.Value) do if not table.find(self.Values, K) then self.Value[K] = nil end end
        end
        if self.IsOpen then self:BuildDropdownList() end
        self:SetValue(self.Value)
        return self
    end

    function Dropdown:Add(V)
        if not table.find(self.Values, V) then
            local Copy = {}
            for I, Item in ipairs(self.Values) do Copy[I] = Item end
            table.insert(Copy, V)
            self:SetValues(Copy)
        end
        return self
    end

    function Dropdown:OnChanged(F)
        self.Changed = F
        Library:SafeCallback(F, self.Value)
    end

    Button.MouseButton1Click:Connect(function()
        Ripple(Button)
        if Dropdown.IsOpen then Dropdown:Close() else Dropdown:Open() end
    end)
    if SearchBox then
        SearchBox:GetPropertyChangedSignal('Text'):Connect(function()
            if Dropdown.IsOpen then Dropdown:BuildDropdownList() end
        end)
        SearchBox.FocusLost:Connect(function(Enter)
            if not Enter or not Dropdown.IsOpen then return end
            local Raw = SearchBox.Text
            if string.match(Raw, '^%s*$') then return end
            if Info.AllowAdd and not table.find(Dropdown.Values, Raw) then Dropdown:Add(Raw) end
            if not table.find(Dropdown.Values, Raw) then return end
            if Dropdown.Multi then
                Dropdown.Value[Raw] = true
                Dropdown:SetValue(Dropdown.Value)
                SearchBox.Text = ''
            else
                Dropdown:SetValue(Raw)
                Dropdown:Close()
            end
            Library:AttemptSave()
        end)
    end

    local function Resolve(D)
        if type(D) == 'number' and not table.find(Dropdown.Values, D) then return Dropdown.Values[D] end
        return D
    end
    if Dropdown.Multi then
        local Defaults = type(Info.Default) == 'table' and Info.Default or { Info.Default }
        for K, D in pairs(Defaults) do
            if D == true and type(K) ~= 'number' then D = K end
            D = Resolve(D)
            if D ~= nil and table.find(Dropdown.Values, D) then Dropdown.Value[D] = true end
        end
    elseif Info.Default ~= nil then
        local D = Resolve(Info.Default)
        if table.find(Dropdown.Values, D) then Dropdown.Value = D end
    end

    Dropdown:Display()
    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, Button) end
    EnableNesting(Dropdown, self, Holder, Info.Text or Idx, function(G)
        G.AnchorPoint = Vector2.new(1, 0.5)
        if TitleLabel then
            G.Position = UDim2.new(1, 0, 0.5, 0)
            G.Parent = TitleLabel
        else
            G.Position = UDim2.new(1, -30, 0.5, 0)
            G.ZIndex = 8
            G.Parent = Button
        end
    end)
    AddElement(self, Holder, Info.Text or Idx)
    Options[Idx] = Dropdown
    return Dropdown
end

function Funcs:AddDependencyBox()
    local Frame = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
    ListLayout(Frame, 10)
    AddElement(self, Frame, nil, true)

    local Dep = setmetatable({
        Container = Frame, Groupbox = self.Groupbox, Order = 0, Dependencies = {},
        Popup = self.Popup, SearchEntry = self.SearchEntry,
    }, { __index = Funcs })

    function Dep:SetupDependencies(Deps)
        self.Dependencies = Deps or {}
        self:Update()
    end

    function Dep:Update()
        local Ok = true
        for _, D in ipairs(self.Dependencies) do
            local Obj, Want = D[1], D[2]
            if Obj then
                if Obj.Type == 'Toggle' and Obj.Value ~= Want then Ok = false end
                if Obj.Type == 'Dropdown' then
                    if Obj.Multi then
                        if not Obj.Value[Want] then Ok = false end
                    elseif Obj.Value ~= Want then
                        Ok = false
                    end
                end
            end
        end
        Frame.Visible = Ok
    end

    table.insert(Library.DependencyBoxes, Dep)
    return Dep
end

function Library:CloseDropdown()
    while #self.PopupStack > 0 do PopTop(self.PopupStack) end
    self:UpdateCatchers()
end

-- Open / close animation. The real window only shows or hides; a light "ghost" card
-- (a few instances) does the morph to / from the island, so big UIs don't drop FPS.
function Library:GetGhost()
    if self.Ghost then return self.Ghost end
    local Frame = Create('Frame', {
        Name = 'Ghost', AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false,
        ClipsDescendants = true, ZIndex = 5, Parent = ScreenGui,
    })
    Themed(Frame, { BackgroundColor3 = 'Background' })
    local GCorner = Corner(Frame, 12)
    local GStroke = Stroke(Frame)
    local Logo = Text({
        Text = self.Title or '', Font = self.FontBold, TextSize = 26, ColorKey = 'Accent', RichText = false,
        TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 0, 34), ZIndex = 6, Parent = Frame,
    })
    self.Ghost = { Frame = Frame, Corner = GCorner, Stroke = GStroke, Logo = Logo, Token = 0 }
    return self.Ghost
end

function Library:Toggle(State)
    local Main = self.Main
    if not Main then return end
    if State == nil then State = not self.Opened end
    self.Opened = State
    local Ghost = self:GetGhost()
    Ghost.Token = Ghost.Token + 1
    local Token = Ghost.Token
    local G, T = Ghost.Frame, self.Theme
    Ghost.Logo.Text = self.Title or ''

    local P, S = Main.AbsolutePosition, Main.AbsoluteSize
    local WinPos, WinSize = UDim2.fromOffset(P.X + S.X / 2, P.Y + S.Y / 2), UDim2.fromOffset(S.X, S.Y)
    local IslandPos, IslandSize
    local Island = self.IslandApi
    if Island and Island.Visible and Island.Frame.Visible then
        local IP, IS = Island.Frame.AbsolutePosition, Island.Frame.AbsoluteSize
        IslandPos, IslandSize = UDim2.fromOffset(IP.X + IS.X / 2, IP.Y + IS.Y / 2), UDim2.fromOffset(IS.X, IS.Y)
    end
    local IslandBg = Color3.fromRGB(8, 8, 11)

    if State then
        G.Visible = true
        G.Position = IslandPos or WinPos
        G.Size = IslandSize or UDim2.fromOffset(S.X * 0.92, S.Y * 0.92)
        G.BackgroundColor3 = IslandPos and IslandBg or T.Background
        G.BackgroundTransparency = IslandPos and 0 or 1
        Ghost.Corner.CornerRadius = UDim.new(0, IslandPos and 16 or 12)
        Ghost.Stroke.Transparency = IslandPos and 0.35 or 1
        Ghost.Logo.TextTransparency = 1
        Tween(G, { Position = WinPos, Size = WinSize, BackgroundColor3 = T.Background, BackgroundTransparency = 0 }, 0.45, Enum.EasingStyle.Quint)
        Tween(Ghost.Corner, { CornerRadius = UDim.new(0, 12) }, 0.45, Enum.EasingStyle.Quint)
        Tween(Ghost.Stroke, { Transparency = 0 }, 0.3)
        Tween(Ghost.Logo, { TextTransparency = 0 }, 0.3)
        task.delay(0.4, function()
            if Token ~= Ghost.Token then return end
            Main.Visible = true
            Tween(G, { BackgroundTransparency = 1 }, 0.22)
            Tween(Ghost.Stroke, { Transparency = 1 }, 0.22)
            Tween(Ghost.Logo, { TextTransparency = 1 }, 0.15)
            task.delay(0.24, function()
                if Token == Ghost.Token then G.Visible = false end
            end)
        end)
    else
        self:CloseDropdown()
        Tooltip.Visible = false
        G.Visible = true
        G.Position, G.Size = WinPos, WinSize
        G.BackgroundColor3, G.BackgroundTransparency = T.Background, 0
        Ghost.Corner.CornerRadius = UDim.new(0, 12)
        Ghost.Stroke.Transparency = 0
        Ghost.Logo.TextTransparency = 0
        Main.Visible = false
        if IslandPos then
            local Info = { Position = IslandPos, Size = IslandSize, BackgroundColor3 = IslandBg }
            Tween(G, Info, 0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            Tween(Ghost.Corner, { CornerRadius = UDim.new(0, 16) }, 0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            Tween(Ghost.Logo, { TextTransparency = 1 }, 0.2)
            task.delay(0.42, function()
                if Token ~= Ghost.Token then return end
                Tween(G, { BackgroundTransparency = 1 }, 0.12)
                Tween(Ghost.Stroke, { Transparency = 1 }, 0.12)
            end)
        else
            Tween(G, { Size = UDim2.fromOffset(S.X * 0.92, S.Y * 0.92), BackgroundTransparency = 1 }, 0.25)
            Tween(Ghost.Stroke, { Transparency = 1 }, 0.25)
            Tween(Ghost.Logo, { TextTransparency = 1 }, 0.15)
        end
        task.delay(0.56, function()
            if Token == Ghost.Token then G.Visible = false end
        end)
    end
    if Island then Island:OnToggle(State) end
end

function Library:CreateWindow(...)
    local Args = { ... }
    local Config = type(Args[1]) == 'table' and Args[1] or { Title = Args[1], AutoShow = Args[2] }
    Config.Title = tostring(Config.Title or 'UI')
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(860, 500) end
    if Config.ToggleKeybind then Library.ToggleKeybind = Config.ToggleKeybind end
    Library.Title = Config.Title

    local SIDEBAR_W = 190

    local Outer = Create('Frame', {
        Name = 'Main', Active = true, BackgroundTransparency = 1, Size = Config.Size, Visible = false,
        ZIndex = 1, Parent = ScreenGui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    })
    if typeof(Config.Position) == 'UDim2' and not Config.Center then
        Outer.AnchorPoint = Vector2.new(0, 0)
        Outer.Position = Config.Position
    end
    Corner(Outer, 12)
    local MainStroke = Stroke(Outer)
    local Main = Create('Frame', { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = Outer })
    Themed(Main, { BackgroundColor3 = 'Background' }); Corner(Main, 12)
    local Scale = Create('UIScale', { Parent = Outer })
    Library.Main, Library.Body, Library.UIScale, Library.MainStroke = Outer, Main, Scale, MainStroke

    local Camera = workspace.CurrentCamera
    local Viewport = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
    Library.BaseScale = Config.Scale or math.clamp(math.min(
        Viewport.X / (Config.Size.X.Offset + 40), Viewport.Y / (Config.Size.Y.Offset + 40)), 0.45, 1)
    Scale.Scale = Library.BaseScale
    Library.AutoScale = Library.BaseScale

    local Sidebar = Blank({ Size = UDim2.new(0, SIDEBAR_W, 1, 0), Parent = Main })
    local Logo = Text({
        Text = Config.Title, Font = Library.FontBold, TextSize = 30, ColorKey = 'Accent', TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16),
        Size = UDim2.new(1, -28, 0, 36), Parent = Sidebar,
    })
    Create('UITextSizeConstraint', { MaxTextSize = 30, MinTextSize = 14, Parent = Logo })
    local Underline = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60),
        Size = UDim2.new(0.8, 0, 0, 2), Parent = Sidebar,
    })
    Themed(Underline, { BackgroundColor3 = 'Accent' })
    Create('UIGradient', {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = Underline,
    })
    local LogoDrag = Blank({ Size = UDim2.new(1, 0, 0, 70), ZIndex = 5, Parent = Sidebar })
    MakeDraggable(LogoDrag, Outer)

    local Nav = Create('ScrollingFrame', {
        BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 80),
        Size = UDim2.new(1, -20, 1, -80 - 34), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, Parent = Sidebar,
    })
    ListLayout(Nav, 8); Padding(Nav, 1, 1, 1, 1)

    local Footer = Text({
        Text = Config.Footer or '', TextSize = 11, ColorKey = 'DimText',
        TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, -12), Size = UDim2.new(1, 0, 0, 14), Parent = Sidebar,
    })

    local Divider = Create('Frame', { BorderSizePixel = 0, Position = UDim2.fromOffset(SIDEBAR_W, 0), Size = UDim2.new(0, 1, 1, 0), Parent = Main })
    Themed(Divider, { BackgroundColor3 = 'Stroke' })

    local Content = Blank({ Position = UDim2.fromOffset(SIDEBAR_W + 1, 0), Size = UDim2.new(1, -SIDEBAR_W - 1, 1, 0), Parent = Main })
    local Header = Blank({ Size = UDim2.new(1, 0, 0, 66), Parent = Content })

    local Avatar = Create('ImageLabel', {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(36, 33),
        Size = UDim2.fromOffset(44, 44), BorderSizePixel = 0, ZIndex = 7,
        Image = 'rbxthumb://type=AvatarHeadShot&id=' .. tostring(LocalPlayer.UserId) .. '&w=150&h=150',
        Parent = Header,
    })
    Themed(Avatar, { BackgroundColor3 = 'Element' }); Corner(Avatar, 'full')
    local AvatarStroke = Stroke(Avatar, 'Accent', 2)
    local AvatarScale = Create('UIScale', { Parent = Avatar })

    local Greeting = Text({
        Text = (Config.Greeting or 'Hello, ') .. LocalPlayer.DisplayName, Font = Library.FontBold, TextSize = 17,
        Position = UDim2.fromOffset(68, 13), Size = UDim2.new(1, -380, 0, 20),
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, Parent = Header,
    })
    local Subtitle = Text({
        Text = Config.Subtitle or 'Welcome Back!', TextSize = 12, ColorKey = 'SubText',
        Position = UDim2.fromOffset(68, 35), Size = UDim2.new(1, -380, 0, 16), ZIndex = 7, Parent = Header,
    })
    local HeaderDrag = Blank({ Size = UDim2.new(1, -310, 1, 0), ZIndex = 5, Parent = Header })
    MakeDraggable(HeaderDrag, Outer)

    local SearchBg = Create('Frame', {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14),
        Size = UDim2.fromOffset(290, 36), Parent = Header,
    })
    Themed(SearchBg, { BackgroundColor3 = 'Background' }); Corner(SearchBg, 8)
    local SearchStroke = Stroke(SearchBg)
    local Glass = Blank({ Position = UDim2.fromOffset(14, 11), Size = UDim2.fromOffset(10, 10), Parent = SearchBg })
    Corner(Glass, 'full'); Stroke(Glass, 'SubText', 1.5)
    local GlassHandle = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(25, 23),
        Size = UDim2.fromOffset(2, 6), Rotation = -45, Parent = SearchBg,
    })
    Themed(GlassHandle, { BackgroundColor3 = 'SubText' })
    local SearchBox = SmoothInput(SearchBg, {
        Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -46, 1, 0), Placeholder = 'Search...',
    }).Box
    SearchBox.Focused:Connect(function() Tween(SearchStroke, { Color = Library.Theme.Accent }) end)
    SearchBox.FocusLost:Connect(function() Tween(SearchStroke, { Color = Library.Theme.Stroke }) end)

    local Pages = Blank({ Position = UDim2.fromOffset(12, 70), Size = UDim2.new(1, -24, 1, -82), Parent = Content })

    local Window = { Tabs = {}, Main = Outer, Body = Main, Config = Config, LockLayout = Config.LockLayout, Sidebar = Sidebar, Nav = Nav }
    Window.PageCover = Create('Frame', { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20, Parent = Pages })
    Themed(Window.PageCover, { BackgroundColor3 = 'Background' })
    local NavOrder = 0

    function Window:SetWindowTitle(T) Logo.Text = T; Library.Title = T end
    function Window:SetSubtitle(T) Subtitle.Text = T end
    function Window:SetFooter(T) Footer.Text = T end
    function Window:SetScale(N) Library.BaseScale = N; Scale.Scale = N end

    local ProtectedName = Config.ProtectedName or 'Normal Hub'
    local GreetingPrefix = Config.Greeting or 'Hello, '
    local Profile = { Hide = false, Protect = false }
    Window.Profile = Profile
    Library.NameHidden, Library.NameProtected = false, false

    local ProfileBtn = Create('TextButton', {
        AutoButtonColor = false, Text = '', BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 7),
        Size = UDim2.fromOffset(56, 52), ZIndex = 6, Parent = Header,
    })
    Themed(ProfileBtn, { BackgroundColor3 = 'Hover' }); Corner(ProfileBtn, 10)

    local function FitProfileButton()
        local W = 56
        if not Profile.Hide then
            W = 68 + math.max(Greeting.TextBounds.X, Subtitle.TextBounds.X)
        end
        Tween(ProfileBtn, { Size = UDim2.fromOffset(math.min(W, math.max(56, Header.AbsoluteSize.X / Scale.Scale - 330)), 52) }, 0.25)
    end
    Greeting:GetPropertyChangedSignal('TextBounds'):Connect(FitProfileButton)

    ProfileBtn.MouseEnter:Connect(function()
        Tween(ProfileBtn, { BackgroundTransparency = 0.6 }, 0.2)
        Tween(AvatarScale, { Scale = 1.06 }, 0.3, Back)
        Tween(AvatarStroke, { Thickness = 3 }, 0.2)
    end)
    ProfileBtn.MouseLeave:Connect(function()
        Tween(ProfileBtn, { BackgroundTransparency = 1 }, 0.2)
        Tween(AvatarScale, { Scale = 1 }, 0.25)
        Tween(AvatarStroke, { Thickness = 2 }, 0.2)
    end)
    ProfileBtn.MouseButton1Down:Connect(function() Tween(AvatarScale, { Scale = 0.94 }, 0.1) end)
    ProfileBtn.MouseButton1Up:Connect(function() Tween(AvatarScale, { Scale = 1.06 }, 0.3, Back) end)

    local NameToken = 0
    local function UpdateName(Animate)
        NameToken = NameToken + 1
        local Token = NameToken
        local Name = Profile.Protect and ProtectedName or LocalPlayer.DisplayName
        local NewText = GreetingPrefix .. Name
        local Hidden = Profile.Hide
        Library.NameHidden, Library.NameProtected = Hidden, Profile.Protect

        if not Animate then
            Greeting.Text = NewText
            Greeting.TextTransparency = Hidden and 1 or 0
            Subtitle.TextTransparency = Hidden and 1 or 0
            Greeting.Visible, Subtitle.Visible = not Hidden, not Hidden
            FitProfileButton()
            return
        end

        local NeedsSwap = Greeting.Text ~= NewText
        if NeedsSwap or Hidden then
            Tween(Greeting, { TextTransparency = 1, Position = UDim2.fromOffset(Hidden and 56 or 74, 13) }, 0.15)
        end
        if Hidden then Tween(Subtitle, { TextTransparency = 1, Position = UDim2.fromOffset(56, 35) }, 0.18) end

        task.delay((NeedsSwap or Hidden) and 0.16 or 0, function()
            if Token ~= NameToken then return end
            Greeting.Text = NewText
            Greeting.Visible, Subtitle.Visible = not Hidden, not Hidden
            if not Hidden then
                if Greeting.TextTransparency > 0 then Greeting.Position = UDim2.fromOffset(60, 13) end
                if Subtitle.TextTransparency > 0 then Subtitle.Position = UDim2.fromOffset(60, 35) end
                Tween(Greeting, { TextTransparency = 0, Position = UDim2.fromOffset(68, 13) }, 0.3)
                Tween(Subtitle, { TextTransparency = 0, Position = UDim2.fromOffset(68, 35) }, 0.3)
            end
            FitProfileButton()
        end)
    end

    local ProfilePopup = CreatePopup(ProfileBtn, 230, 128, 'Left')
    local PBody = ProfilePopup.Body
    local MiniAvatar = Create('ImageLabel', {
        Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(22, 22), BorderSizePixel = 0,
        Image = Avatar.Image, ZIndex = 21, Parent = PBody,
    })
    Themed(MiniAvatar, { BackgroundColor3 = 'Element' }); Corner(MiniAvatar, 'full')
    Text({ Text = 'Profile', Font = Library.FontBold, TextSize = 13, Position = UDim2.fromOffset(42, 10),
        Size = UDim2.new(1, -54, 0, 22), ZIndex = 21, Parent = PBody })

    local Switches = {}
    local function MakeSwitch(Y, Title, Desc, Key)
        local Row = Create('TextButton', {
            AutoButtonColor = false, Text = '', BackgroundTransparency = 1, Position = UDim2.fromOffset(6, Y),
            Size = UDim2.new(1, -12, 0, 40), ZIndex = 21, Parent = PBody,
        })
        Themed(Row, { BackgroundColor3 = 'Hover' }); Corner(Row, 6)
        local TitleLabel = Text({ Text = Title, Font = Library.FontMedium, Position = UDim2.fromOffset(8, 5),
            Size = UDim2.new(1, -60, 0, 16), ZIndex = 22, Parent = Row })
        Text({ Text = Desc, TextSize = 11, ColorKey = 'DimText', Position = UDim2.fromOffset(8, 21),
            Size = UDim2.new(1, -60, 0, 14), ZIndex = 22, Parent = Row })
        local Track = Create('Frame', {
            BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.fromOffset(34, 18), ZIndex = 22, Parent = Row,
        })
        Corner(Track, 'full')
        local TrackStroke = Create('UIStroke', { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Track })
        local Knob = Create('Frame', {
            BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
            Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 23, Parent = Track,
        })
        Corner(Knob, 'full')

        local Switch = {}
        function Switch:Set(On, Animate)
            local T = Library.Theme
            local Props = {
                Track = { BackgroundColor3 = On and T.Accent or T.Element },
                Stroke = { Color = On and T.Accent or T.Stroke },
                Knob = { Position = On and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                         BackgroundColor3 = On and Color3.new(1, 1, 1) or T.SubText },
                Title = { TextColor3 = On and T.Text or T.SubText },
            }
            if Animate then
                Tween(Track, Props.Track, 0.2); Tween(TrackStroke, Props.Stroke, 0.2)
                Tween(TitleLabel, Props.Title, 0.2)

                Tween(Knob, { Size = UDim2.fromOffset(19, 14) }, 0.1)
                Tween(Knob, Props.Knob, 0.3, Back)
                task.delay(0.12, function() Tween(Knob, { Size = UDim2.fromOffset(14, 14) }, 0.2) end)
            else
                for K, V in pairs(Props.Track) do Track[K] = V end
                for K, V in pairs(Props.Stroke) do TrackStroke[K] = V end
                for K, V in pairs(Props.Knob) do Knob[K] = V end
                for K, V in pairs(Props.Title) do TitleLabel[K] = V end
            end
        end
        Row.MouseEnter:Connect(function() Tween(Row, { BackgroundTransparency = 0 }, 0.12) end)
        Row.MouseLeave:Connect(function() Tween(Row, { BackgroundTransparency = 1 }, 0.12) end)
        Row.MouseButton1Click:Connect(function()
            Window:SetProfile({ [Key] = not Profile[Key] })
        end)
        Switches[Key] = Switch
        return Switch
    end
    MakeSwitch(38, 'Hide name', 'Only show the profile picture', 'Hide')
    MakeSwitch(80, 'Protect name', 'Show as "' .. ProtectedName .. '"', 'Protect')
    ProfilePopup.OnOpen = function()
        for Key, Sw in pairs(Switches) do Sw:Set(Profile[Key], false) end
    end
    ProfileBtn.MouseButton1Click:Connect(function() ProfilePopup:Toggle() end)

    function Window:SetProfile(Data, Silent)
        if type(Data) ~= 'table' then return end
        if Data.Hide ~= nil then Profile.Hide = Data.Hide and true or false end
        if Data.Protect ~= nil then Profile.Protect = Data.Protect and true or false end
        for Key, Sw in pairs(Switches) do Sw:Set(Profile[Key], not Silent) end
        UpdateName(not Silent)
        if Library.OnProfileChanged then Library:SafeCallback(Library.OnProfileChanged, Profile.Hide, Profile.Protect) end
        if not Silent then self:SaveLayout() end
    end
    function Window:SetProtectedName(Name)
        ProtectedName = tostring(Name)
        UpdateName(true)
    end
    UpdateName(false)

    function Window:ApplySearch()
        local Tab = self.ActiveTab
        if not Tab then return end
        local Query = string.lower(SearchBox.Text)
        for _, Group in ipairs(Tab.Groupboxes) do
            local TitleMatch = Query == '' or string.find(string.lower(Group.Name), Query, 1, true) ~= nil
            local Any = false
            for _, El in ipairs(Group.Elements) do
                local Show = TitleMatch or string.find(El.Name, Query, 1, true) ~= nil
                El.Frame.Visible = Show
                if Show then Any = true end
            end
            Group.Card.Visible = TitleMatch or Any
        end
    end
    SearchBox:GetPropertyChangedSignal('Text'):Connect(function() Window:ApplySearch() end)

    local function LayoutFile() return Library.Folder .. '/' .. tostring(Config.LayoutName or 'layout') .. '.json' end

    function Window:GetLayout()
        local L = { Tabs = {}, Size = { Outer.Size.X.Offset, Outer.Size.Y.Offset },
            Profile = { Hide = Profile.Hide, Protect = Profile.Protect } }
        for _, Tab in ipairs(self.Tabs) do
            local T = { Left = {}, Right = {} }
            for _, Side in ipairs({ 'Left', 'Right' }) do
                for _, G in ipairs(Tab.Cols[Side]) do table.insert(T[Side], G.Key) end
            end
            L.Tabs[Tab.Name] = T
        end
        return L
    end

    function Window:ApplyLayout(L)
        if type(L) ~= 'table' then return end
        if type(L.Profile) == 'table' then self:SetProfile(L.Profile, true) end
        if type(L.Size) == 'table' and tonumber(L.Size[1]) and tonumber(L.Size[2]) and self.SetSize then
            self:SetSize(tonumber(L.Size[1]), tonumber(L.Size[2]))
        end
        for _, Tab in ipairs(self.Tabs) do
            local T = type(L.Tabs) == 'table' and L.Tabs[Tab.Name]
            if type(T) == 'table' then
                local Pool, Placed, New = {}, {}, { Left = {}, Right = {} }
                for _, Side in ipairs({ 'Left', 'Right' }) do
                    for _, G in ipairs(Tab.Cols[Side]) do Pool[G.Key] = G end
                end
                for _, Side in ipairs({ 'Left', 'Right' }) do
                    for _, Key in ipairs(type(T[Side]) == 'table' and T[Side] or {}) do
                        local G = Pool[Key]
                        if G and not Placed[G] then
                            Placed[G] = true
                            table.insert(New[Side], G)
                        end
                    end
                end
                for _, Side in ipairs({ 'Left', 'Right' }) do
                    for _, G in ipairs(Tab.Cols[Side]) do
                        if not Placed[G] then table.insert(New[Side], G) end
                    end
                end
                Tab.Cols.Left, Tab.Cols.Right = New.Left, New.Right
                Tab:Relayout()
            end
        end
    end

    function Window:SaveLayout()
        if Config.SaveLayout == false or not writefile then return false end
        local Ok = pcall(function()
            if makefolder and isfolder and not isfolder(Library.Folder) then makefolder(Library.Folder) end
            writefile(LayoutFile(), HttpService:JSONEncode(self:GetLayout()))
        end)
        return Ok
    end

    function Window:LoadLayout()
        if Config.SaveLayout == false or not readfile then return false end
        local Ok, Data = pcall(function()
            if isfile and not isfile(LayoutFile()) then return nil end
            return HttpService:JSONDecode(readfile(LayoutFile()))
        end)
        if Ok and Data then
            self:ApplyLayout(Data)
            return true
        end
        return false
    end

    function Window:ResetLayout()
        for _, Tab in ipairs(self.Tabs) do
            local New = { Left = {}, Right = {} }
            for _, G in ipairs(Tab.Groupboxes) do table.insert(New[G.DefaultSide], G) end
            Tab.Cols.Left, Tab.Cols.Right = New.Left, New.Right
            Tab:Relayout()
        end
        if self.SetSize then self:SetSize(Config.Size.X.Offset, Config.Size.Y.Offset) end
        self:SaveLayout()
    end

    local function MakeColumn(Pos)
        local Column = Create('ScrollingFrame', {
            BackgroundTransparency = 1, BorderSizePixel = 0, Position = Pos, Size = UDim2.new(0.5, -6, 1, 0),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        })
        Themed(Column, { ScrollBarImageColor3 = 'Accent' })
        ListLayout(Column, 12); Padding(Column, 1, 6, 1, 4)
        return Column
    end

    function Window:_AddTab(Name, Parent, Indent)
        local Tab = { Name = Name, Groupboxes = {}, Window = Window }
        NavOrder = NavOrder + 1

        local Btn = Create('TextButton', {
            AutoButtonColor = false, Text = '', BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30),
            LayoutOrder = NavOrder, Parent = Parent,
        })
        Themed(Btn, { BackgroundColor3 = 'Hover' }); Corner(Btn, 6)
        local Label = Text({
            Text = Name, Font = Library.FontMedium, ColorKey = 'DimText',
            Position = UDim2.fromOffset(Indent, 0), Size = UDim2.new(1, -Indent - 12, 1, 0), Parent = Btn,
        })
        local Bar = Create('Frame', {
            BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0),
            Size = UDim2.fromOffset(3, 0), Parent = Btn,
        })
        Themed(Bar, { BackgroundColor3 = 'Accent' }); Corner(Bar, 'full')

        local Page = Blank({ Size = UDim2.fromScale(1, 1), Visible = false, Parent = Pages })
        local Left = MakeColumn(UDim2.fromScale(0, 0)); Left.Parent = Page
        local Right = MakeColumn(UDim2.new(0.5, 6, 0, 0)); Right.Parent = Page
        Tab.Page, Tab.Left, Tab.Right = Page, Left, Right
        Tab.Button, Tab.Label = Btn, Label

        local function SetLabel(Key)
            Library.Registry[Label].TextColor3 = Key
            Tween(Label, { TextColor3 = Library.Theme[Key] })
        end

        function Tab:ShowTab()
            if Window.ActiveTab == Tab then return end
            for _, Other in ipairs(Window.Tabs) do
                if Other ~= Tab then Other:HideTab() end
            end
            Window.ActiveTab = Tab
            Library:CloseDropdown()
            Window:ApplySearch()

            Page.Visible = true
            Page.Position = UDim2.fromOffset(0, 18)
            Window.PageCover.Visible = true
            Window.PageCover.BackgroundTransparency = 0
            Tween(Window.PageCover, { BackgroundTransparency = 1 }, 0.3)
            local CoverToken = (Window.CoverToken or 0) + 1
            Window.CoverToken = CoverToken
            task.delay(0.31, function()
                if Window.CoverToken == CoverToken then Window.PageCover.Visible = false end
            end)
            Tween(Page, { Position = UDim2.fromOffset(0, 0) }, 0.35)

            Tween(Bar, { Size = UDim2.fromOffset(3, 16) }, 0.35, Back)
            Tween(Label, { Position = UDim2.fromOffset(Indent + 6, 0) }, 0.25)
            Tween(Btn, { BackgroundTransparency = 0.35 }, 0.25)
            SetLabel('Text')
            if Tab.OnShow then Tab.OnShow() end
        end

        function Tab:HideTab()
            Page.Visible = false
            Tween(Bar, { Size = UDim2.fromOffset(3, 0) }, 0.2)
            Tween(Label, { Position = UDim2.fromOffset(Indent, 0) }, 0.25)
            Tween(Btn, { BackgroundTransparency = 1 }, 0.25)
            SetLabel('DimText')
            if Tab.OnHide then Tab.OnHide() end
        end

        Btn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                SetLabel('SubText')
                Tween(Label, { Position = UDim2.fromOffset(Indent + 3, 0) }, 0.2)
                Tween(Btn, { BackgroundTransparency = 0.7 }, 0.2)
            end
        end)
        Btn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                SetLabel('DimText')
                Tween(Label, { Position = UDim2.fromOffset(Indent, 0) }, 0.2)
                Tween(Btn, { BackgroundTransparency = 1 }, 0.2)
            end
        end)
        Btn.MouseButton1Click:Connect(function() Tab:ShowTab() end)

        local Cols = { Left = {}, Right = {} }
        local ColFrames = { Left = Left, Right = Right }
        local KeyCount = {}
        Tab.Cols = Cols

        function Tab:Relayout()
            for Side, List in pairs(Cols) do
                for I, G in ipairs(List) do
                    G.Card.Parent = ColFrames[Side]
                    G.Card.LayoutOrder = I * 2
                    G.Column, G.Side = ColFrames[Side], Side
                end
            end
        end

        local DragLayer = Blank({ Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = Page })
        local Placeholder = Create('Frame', { BorderSizePixel = 0, BackgroundTransparency = 0.9, Size = UDim2.new(1, 0, 0, 0) })
        Themed(Placeholder, { BackgroundColor3 = 'Accent' }); Corner(Placeholder, 10)
        local PhStroke = Stroke(Placeholder, 'Accent')
        PhStroke.Transparency = 0.35

        local Drag, Dropping, Press = nil, false, nil

        local function PlaceholderAt(Side, Index)
            if Drag.Side == Side and Drag.Index == Index then return end
            Drag.Side, Drag.Index = Side, Index
            for I, G in ipairs(Cols[Side]) do G.Card.LayoutOrder = I * 2 end
            Placeholder.LayoutOrder = Index * 2 - 1
            Placeholder.Parent = ColFrames[Side]
            Placeholder.Size = UDim2.new(1, 0, 0, Drag.Height * 0.5)
            Tween(Placeholder, { Size = UDim2.new(1, 0, 0, Drag.Height) }, 0.25)
        end

        local function DragTarget(Pt)
            local Side = Pt.X < Right.AbsolutePosition.X and 'Left' or 'Right'
            local Index = #Cols[Side] + 1
            for I, G in ipairs(Cols[Side]) do
                if G.Card.Visible then
                    local P, S = G.Card.AbsolutePosition, G.Card.AbsoluteSize
                    if Pt.Y < P.Y + S.Y / 2 then Index = I break end
                end
            end
            return Side, Index
        end

        local function MoveDrag(Pt)
            local S = Library.UIScale.Scale
            local Rel = (Pt - DragLayer.AbsolutePosition) / S - Drag.Grab
            Tween(Drag.G.Card, { Position = UDim2.fromOffset(Rel.X, Rel.Y) }, 0.08, Enum.EasingStyle.Linear)
            local Side, Index = DragTarget(Pt)
            PlaceholderAt(Side, Index)

            local Col = ColFrames[Side]
            local Top, Bottom = Col.AbsolutePosition.Y, Col.AbsolutePosition.Y + Col.AbsoluteSize.Y
            if Pt.Y > Bottom - 30 then
                Col.CanvasPosition = Col.CanvasPosition + Vector2.new(0, 8)
            elseif Pt.Y < Top + 30 then
                Col.CanvasPosition = Vector2.new(0, math.max(0, Col.CanvasPosition.Y - 8))
            end
        end

        local function BeginDrag(G, Pt)
            Library:CloseDropdown()
            local S = Library.UIScale.Scale
            local Card = G.Card
            local Abs, Size = Card.AbsolutePosition, Card.AbsoluteSize
            local List = Cols[G.Side]
            table.remove(List, table.find(List, G))
            Drag = { G = G, Grab = (Pt - Abs) / S, Height = Size.Y / S }
            local Start = (Abs - DragLayer.AbsolutePosition) / S
            Card.Parent = DragLayer
            Card.Size = UDim2.fromOffset(Size.X / S, 0)
            Card.Position = UDim2.fromOffset(Start.X, Start.Y)
            Tween(G.CardScale, { Scale = 1.03 }, 0.25, Back)
            Tween(G.CardStroke, { Color = Library.Theme.Accent }, 0.2)
            Tween(Card, { BackgroundColor3 = Library.Theme.Hover }, 0.2)
            Tab:Relayout()
            Placeholder.Visible = true
            PlaceholderAt(DragTarget(Pt))
            Left.ScrollingEnabled, Right.ScrollingEnabled = false, false
        end

        local function EndDrag()
            local D = Drag
            Drag, Dropping = nil, true
            local S = Library.UIScale.Scale
            local Target = (Placeholder.AbsolutePosition - DragLayer.AbsolutePosition) / S
            Tween(D.G.Card, { Position = UDim2.fromOffset(Target.X, Target.Y), BackgroundColor3 = Library.Theme.Card }, 0.25)
            Tween(D.G.CardScale, { Scale = 1 }, 0.3, Back)
            Tween(D.G.CardStroke, { Color = Library.Theme.Stroke }, 0.3)
            task.delay(0.26, function()
                local List = Cols[D.Side]
                table.insert(List, math.min(D.Index, #List + 1), D.G)
                Placeholder.Visible = false
                Placeholder.Parent = nil
                D.G.Card.Position = UDim2.new()
                D.G.Card.Size = UDim2.new(1, 0, 0, 0)
                Tab:Relayout()
                Left.ScrollingEnabled, Right.ScrollingEnabled = true, true
                Dropping = false
                Window:SaveLayout()
            end)
        end

        Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
            if not (Input.UserInputType == Move or Input.UserInputType == Touch) then return end
            if Drag then
                MoveDrag(PointerOf(Input))
            elseif Press then
                local Pt = PointerOf(Input)
                if (Pt - Press.Pt).Magnitude > 6 then
                    local G = Press.G
                    Press = nil
                    BeginDrag(G, Pt)
                end
            end
        end))
        Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
            if not IsClick(Input) then return end
            Press = nil
            if Drag then EndDrag() end
        end))

        function Tab:AddGroupbox(Info)
            local Side = Info.Side == 2 and 'Right' or 'Left'
            local Column = ColFrames[Side]
            local Card = Create('Frame', { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = Column })
            Themed(Card, { BackgroundColor3 = 'Card' }); Corner(Card, 10)
            local CardStroke = Stroke(Card)
            local CardScale = Create('UIScale', { Parent = Card })
            Padding(Card, 10, 14, 14, 14); ListLayout(Card, 0)

            local Head = Blank({ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = Card })
            local TitleX = 14
            if Info.Icon then
                local Icon = Create('ImageLabel', {
                    BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(16, 16), Image = Info.Icon, Parent = Head,
                })
                Themed(Icon, { ImageColor3 = 'Accent' })
                TitleX = 26
            else
                local Dot = Create('Frame', {
                    BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(4, 14), Parent = Head,
                })
                Themed(Dot, { BackgroundColor3 = 'Accent' }); Corner(Dot, 'full')
            end
            Text({
                Text = Info.Name, Font = Library.FontBold, TextSize = 15,
                Position = UDim2.fromOffset(TitleX, 0), Size = UDim2.new(1, -TitleX - 20, 1, 0), Parent = Head,
            })

            local Grip = Blank({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(9, 14), Parent = Head })
            local GripDots = {}
            for R = 0, 2 do
                for C = 0, 1 do
                    local D = Create('Frame', {
                        BorderSizePixel = 0, BackgroundTransparency = 1, Position = UDim2.fromOffset(C * 6, R * 5 + 1),
                        Size = UDim2.fromOffset(3, 3), Parent = Grip,
                    })
                    Themed(D, { BackgroundColor3 = 'DimText' }); Corner(D, 'full')
                    table.insert(GripDots, D)
                end
            end
            local GrabBtn = Create('TextButton', { BackgroundTransparency = 1, Text = '', Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = Head })

            Card.MouseEnter:Connect(function()
                Tween(CardStroke, { Color = Lerp('Stroke', 'Accent', 0.35) }, 0.3)
                for I, D in ipairs(GripDots) do Tween(D, { BackgroundTransparency = 0 }, 0.15 + I * 0.03) end
            end)
            Card.MouseLeave:Connect(function()
                if Drag and Drag.G.Card == Card then return end
                Tween(CardStroke, { Color = Library.Theme.Stroke }, 0.3)
                for _, D in ipairs(GripDots) do Tween(D, { BackgroundTransparency = 1 }, 0.2) end
            end)
            GrabBtn.MouseEnter:Connect(function()
                for _, D in ipairs(GripDots) do Tween(D, { BackgroundColor3 = Library.Theme.Accent }, 0.15) end
            end)
            GrabBtn.MouseLeave:Connect(function()
                for _, D in ipairs(GripDots) do Tween(D, { BackgroundColor3 = Library.Theme.DimText }, 0.15) end
            end)

            local Line = Create('Frame', { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, Parent = Card })
            Themed(Line, { BackgroundColor3 = 'Stroke' })
            Blank({ Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 3, Parent = Card })
            local Container = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = Card })
            ListLayout(Container, 10)

            local Key = tostring(Info.Name)
            KeyCount[Key] = (KeyCount[Key] or 0) + 1
            if KeyCount[Key] > 1 then Key = Key .. '#' .. KeyCount[Key] end

            local Groupbox = setmetatable({
                Name = Info.Name, Key = Key, Card = Card, CardStroke = CardStroke, CardScale = CardScale,
                Container = Container, Column = Column, Side = Side, DefaultSide = Side,
                Elements = {}, Order = 0, Tab = Tab,
            }, { __index = Funcs })
            Groupbox.Groupbox = Groupbox
            function Groupbox:Resize() end

            GrabBtn.InputBegan:Connect(function(Input)
                if not IsClick(Input) or Drag or Dropping or Window.LockLayout then return end
                Press = { G = Groupbox, Pt = PointerOf(Input) }
            end)

            table.insert(Tab.Groupboxes, Groupbox)
            table.insert(Cols[Side], Groupbox)
            Card.LayoutOrder = #Cols[Side] * 2

            if not Window.LayoutScheduled then
                Window.LayoutScheduled = true
                task.delay(0.15, function() Window:LoadLayout() end)
            end
            return Groupbox
        end

        function Tab:AddLeftGroupbox(N, Icon) return Tab:AddGroupbox({ Side = 1, Name = N, Icon = Icon }) end
        function Tab:AddRightGroupbox(N, Icon) return Tab:AddGroupbox({ Side = 2, Name = N, Icon = Icon }) end

        local function Tabbox(Side)
            local TB = {}
            function TB:AddTab(N) return Tab:AddGroupbox({ Side = Side, Name = N }) end
            return TB
        end
        function Tab:AddLeftTabbox() return Tabbox(1) end
        function Tab:AddRightTabbox() return Tabbox(2) end

        table.insert(Window.Tabs, Tab)
        if #Window.Tabs == 1 then Tab:ShowTab() end
        return Tab
    end

    function Window:AddCategory(Name, Icon)
        local Category = { Open = true }
        NavOrder = NavOrder + 1
        local Holder = Blank({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = NavOrder, Parent = Nav })
        ListLayout(Holder, 4)

        local Head = Create('TextButton', { AutoButtonColor = false, Text = '', Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = Holder })
        Themed(Head, { BackgroundColor3 = 'Card' }); Corner(Head, 8)
        local HeadStroke = Stroke(Head)
        Head.MouseEnter:Connect(function()
            Tween(Head, { BackgroundColor3 = Library.Theme.Hover })
            Tween(HeadStroke, { Color = Lerp('Stroke', 'Accent', 0.4) })
        end)
        Head.MouseLeave:Connect(function()
            Tween(Head, { BackgroundColor3 = Library.Theme.Card })
            Tween(HeadStroke, { Color = Library.Theme.Stroke })
        end)

        if Icon then
            local Img = Create('ImageLabel', {
                BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
                Size = UDim2.fromOffset(14, 14), Image = Icon, Parent = Head,
            })
            Themed(Img, { ImageColor3 = 'Accent' })
        else
            local Ring = Blank({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 13, 0.5, 0), Size = UDim2.fromOffset(11, 11), Parent = Head })
            Corner(Ring, 'full'); Stroke(Ring, 'Accent', 1.5)
            local Dot = Create('Frame', { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3), Parent = Ring })
            Themed(Dot, { BackgroundColor3 = 'Accent' }); Corner(Dot, 'full')
        end
        Text({ Text = Name, Font = Library.FontBold, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -60, 1, 0), Parent = Head })
        local Arrow = ChevronIcon(Head, 'SubText', { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0) })
        Arrow:Set(true)

        local Items = Blank({ Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, LayoutOrder = 2, Parent = Holder })
        local ItemsLayout = ListLayout(Items, 2); Padding(Items, 2, 2, 0, 0)
        local function FullHeight() return ItemsLayout.AbsoluteContentSize.Y + 4 end
        ItemsLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            if Category.Open then Items.Size = UDim2.new(1, 0, 0, FullHeight()) end
        end)

        function Category:SetOpen(Bool)
            self.Open = Bool
            Tween(Items, { Size = UDim2.new(1, 0, 0, Bool and FullHeight() or 0) }, 0.3)
            Arrow:Set(Bool, true)
        end
        Head.MouseButton1Click:Connect(function() Category:SetOpen(not Category.Open) end)

        function Category:AddTab(TabName) return Window:_AddTab(TabName, Items, 28) end
        return Category
    end

    function Window:AddTab(Name) return Window:_AddTab(Name, Nav, 14) end

    local MinSize = typeof(Config.MinSize) == 'Vector2' and Config.MinSize or Vector2.new(680, 420)
    local Grip = Create('TextButton', {
        AutoButtonColor = false, Text = '', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(20, 20), ZIndex = 10, Parent = Main,
    })
    local GripDots = {}
    for _, P in ipairs({ { 15, 15 }, { 10, 15 }, { 15, 10 }, { 5, 15 }, { 10, 10 }, { 15, 5 } }) do
        local D = Create('Frame', {
            BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(P[1], P[2]),
            Size = UDim2.fromOffset(3, 3), ZIndex = 11, Parent = Grip,
        })
        Themed(D, { BackgroundColor3 = 'DimText' }); Corner(D, 'full')
        table.insert(GripDots, D)
    end
    local Resizing, StartPoint, StartSize, StartPos = false, nil, nil, nil
    local function PaintGrip(Active)
        for I, D in ipairs(GripDots) do
            Tween(D, {
                BackgroundColor3 = Active and Library.Theme.Accent or Library.Theme.DimText,
                Size = UDim2.fromOffset(Active and 4 or 3, Active and 4 or 3),
            }, 0.12 + I * 0.04)
        end
    end
    Grip.MouseEnter:Connect(function() PaintGrip(true) end)
    Grip.MouseLeave:Connect(function() if not Resizing then PaintGrip(false) end end)
    Grip.InputBegan:Connect(function(Input)
        if not IsClick(Input) then return end
        Resizing = true
        PaintGrip(true)
        StartPoint = Input.Position
        StartSize = Vector2.new(Outer.Size.X.Offset, Outer.Size.Y.Offset)
        StartPos = Outer.Position
    end)
    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if not Resizing or not (Input.UserInputType == Move or Input.UserInputType == Touch) then return end
        local S = Scale.Scale
        local Delta = Input.Position - StartPoint
        local Screen = ScreenGui.AbsoluteSize
        local W = math.clamp(StartSize.X + Delta.X / S, MinSize.X, math.max(MinSize.X, Screen.X / S))
        local H = math.clamp(StartSize.Y + Delta.Y / S, MinSize.Y, math.max(MinSize.Y, Screen.Y / S))
        local DW, DH = W - StartSize.X, H - StartSize.Y
        Outer.Size = UDim2.fromOffset(W, H)
        Outer.Position = UDim2.new(
            StartPos.X.Scale, StartPos.X.Offset + DW * S * Outer.AnchorPoint.X,
            StartPos.Y.Scale, StartPos.Y.Offset + DH * S * Outer.AnchorPoint.Y)
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if Resizing and IsClick(Input) then
            Resizing = false
            PaintGrip(false)
            Window:SaveLayout()
        end
    end))
    function Window:SetSize(W, H) Outer.Size = UDim2.fromOffset(math.max(W, MinSize.X), math.max(H, MinSize.Y)) end

    if Config.Island ~= false then Library:CreateIsland() end
    if Config.MobileButton ~= false and UserInputService.TouchEnabled and Config.Island == false then
        local MobileBtn = Create('TextButton', {
            AutoButtonColor = false, Position = UDim2.fromOffset(16, 120), Size = UDim2.fromOffset(46, 46),
            Font = Library.FontBold, TextSize = 18, Text = string.sub(Config.Title, 1, 1), ZIndex = 2, Parent = ScreenGui,
        })
        Themed(MobileBtn, { BackgroundColor3 = 'Background', TextColor3 = 'Accent' })
        Corner(MobileBtn, 'full'); Stroke(MobileBtn, 'Accent', 1.5)
        local DragState = MakeDraggable(MobileBtn, MobileBtn)
        MobileBtn.MouseButton1Click:Connect(function()
            if not DragState.Moved then Library:Toggle() end
        end)
    end

    Library.Window = Window
    if Config.AutoShow ~= false then task.defer(function() Library:Toggle(true) end) end
    if Config.BuiltinSettings ~= false then

        task.defer(function()
            Library:AddSettingsTab(Window)
            Library:LoadAutoload()
        end)
    end
    return Window
end

Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input)
    if Input.KeyCode == Enum.KeyCode.Escape and #Library.PopupStack > 0 then
        PopTop(Library.PopupStack)
        Library:UpdateCatchers()
        return
    end
    if Input.UserInputType == Enum.UserInputType.Keyboard and not Library.Binding
        and not UserInputService:GetFocusedTextBox() then
        local K = KeyName(Library.ToggleKeybind)
        if K and K ~= 'None' and Input.KeyCode.Name == K then Library:Toggle() end
    end
end))

Library:GiveSignal(RunService.RenderStepped:Connect(function()
    if #Library.PopupStack > 0 then
        if not Library.Opened then
            Library:CloseDropdown()
        else
            for _, P in ipairs(Library.PopupStack) do
                if P.ButtonFrame.Parent then P:Reposition() end
            end
        end
    end
    if Tooltip.Visible then
        local Owner = Library.TooltipOwner
        if not Owner or not Owner.Parent or not Owner.Visible then
            Tooltip.Visible = false
        else
            local M = Library.MousePosition()
            Tooltip.Position = UDim2.fromOffset(M.X + 14, M.Y + 12)
        end
    end
end))

local function RefreshPlayerDropdowns()
    local Names = GetPlayerNames()
    for _, Opt in pairs(Options) do
        if Opt.Type == 'Dropdown' and Opt.SpecialType == 'Player' then Opt:Refresh(Names) end
    end
end
Library:GiveSignal(Players.PlayerAdded:Connect(RefreshPlayerDropdowns))
Library:GiveSignal(Players.PlayerRemoving:Connect(function() task.defer(RefreshPlayerDropdowns) end))

function Library:GetConfigData()
    local Data = { Toggles = {}, Options = {} }
    if self.Window then Data.Layout = self.Window:GetLayout() end
    Data.Theme = { Preset = self.ThemePresetName, Accent = self.Theme.Accent:ToHex() }
    Data.Menu = { Key = KeyName(self.ToggleKeybind) }
    for Idx, T in pairs(Toggles) do
        if not T.NoConfig then Data.Toggles[Idx] = T.Value end
    end
    for Idx, O in pairs(Options) do
        if not O.NoConfig then
            if O.Type == 'KeyPicker' then
                Data.Options[Idx] = { O.Value, O.Mode }
            elseif O.Type == 'PriorityList' then
                Data.Options[Idx] = O:GetConfig()
            elseif O.Type == 'ColorPicker' then
                Data.Options[Idx] = { Hex = O.Value:ToHex(), Transparency = O.Transparency }
            elseif O.Type == 'Dropdown' and O.Multi then
                Data.Options[Idx] = O:GetActiveValues()
            elseif O.Value ~= nil then
                Data.Options[Idx] = O.Value
            end
        end
    end
    return Data
end

function Library:ApplyConfigData(Data)
    if type(Data.Menu) == 'table' and type(Data.Menu.Key) == 'string' and Options.__MenuKeybind then
        Options.__MenuKeybind:SetValue(Data.Menu.Key)
    end
    if type(Data.Theme) == 'table' then
        if Data.Theme.Preset then
            if Options.__ThemePreset then Options.__ThemePreset:SetValue(Data.Theme.Preset) else self:SetThemePreset(Data.Theme.Preset) end
        end
        local Ok, Accent = pcall(Color3.fromHex, tostring(Data.Theme.Accent or ''))
        if Ok and Accent then
            if Options.__AccentColor then Options.__AccentColor:SetValueRGB(Accent) else self:SetAccent(Accent) end
        end
    end
    if Data.Layout and self.Window then self.Window:ApplyLayout(Data.Layout) end
    for Idx, V in pairs(Data.Toggles or {}) do
        if Toggles[Idx] then Toggles[Idx]:SetValue(V) end
    end
    for Idx, V in pairs(Data.Options or {}) do
        if Options[Idx] and Options[Idx].SetValue then Options[Idx]:SetValue(V) end
    end
end

function Library:SaveConfig(Name)
    if not writefile then return false, 'writefile is not supported' end
    Name = tostring(Name or 'default')
    local Ok, Err = pcall(function()
        if makefolder and isfolder and not isfolder(self.Folder) then makefolder(self.Folder) end
        writefile(self.Folder .. '/' .. Name .. '.json', HttpService:JSONEncode(self:GetConfigData()))
    end)
    return Ok, Ok and Name or tostring(Err)
end

function Library:LoadConfig(Name)
    if not readfile then return false, 'readfile is not supported' end
    local Path = self.Folder .. '/' .. tostring(Name or 'default') .. '.json'
    if isfile and not isfile(Path) then return false, 'config not found' end
    local Ok, Err = pcall(function()
        self:ApplyConfigData(HttpService:JSONDecode(readfile(Path)))
    end)
    return Ok, Ok and Name or tostring(Err)
end

function Library:GetConfigs()
    local List = {}
    if not listfiles then return List end
    pcall(function()
        for _, File in ipairs(listfiles(self.Folder)) do
            local N = string.match(File, '([^/\\]+)%.json$')
            if N then table.insert(List, N) end
        end
    end)
    table.sort(List)
    return List
end

Library.DefaultAccent = Library.Theme.Accent
Library.ThemePresetName = 'Normal'
Library.ThemePresetOrder = { 'Normal', 'Dark', 'Midnight', 'Black', 'Slate' }
Library.ThemePresets = {
    Normal   = { Background = Color3.fromRGB(16, 13, 17), Card = Color3.fromRGB(22, 18, 23), Element = Color3.fromRGB(30, 24, 31), Hover = Color3.fromRGB(38, 30, 39), Stroke = Color3.fromRGB(50, 39, 50) },
    Dark     = { Background = Color3.fromRGB(15, 15, 22), Card = Color3.fromRGB(20, 20, 30), Element = Color3.fromRGB(27, 27, 40), Hover = Color3.fromRGB(32, 32, 47), Stroke = Color3.fromRGB(40, 40, 58) },
    Midnight = { Background = Color3.fromRGB(10, 12, 24), Card = Color3.fromRGB(15, 18, 34), Element = Color3.fromRGB(22, 26, 46), Hover = Color3.fromRGB(28, 33, 56), Stroke = Color3.fromRGB(38, 44, 72) },
    Black    = { Background = Color3.fromRGB(6, 6, 8), Card = Color3.fromRGB(12, 12, 15), Element = Color3.fromRGB(20, 20, 24), Hover = Color3.fromRGB(28, 28, 33), Stroke = Color3.fromRGB(36, 36, 42) },
    Slate    = { Background = Color3.fromRGB(22, 24, 30), Card = Color3.fromRGB(28, 31, 39), Element = Color3.fromRGB(36, 40, 50), Hover = Color3.fromRGB(44, 48, 60), Stroke = Color3.fromRGB(54, 59, 73) },
}
Library.AccentPresets = {
    { 'Normal', Color3.fromRGB(206, 8, 59) },
    { 'Blue', Color3.fromRGB(59, 130, 246) }, { 'Purple', Color3.fromRGB(139, 92, 246) },
    { 'Pink', Color3.fromRGB(236, 72, 153) }, { 'Red', Color3.fromRGB(239, 68, 68) },
    { 'Orange', Color3.fromRGB(249, 115, 22) }, { 'Green', Color3.fromRGB(34, 197, 94) },
    { 'Cyan', Color3.fromRGB(6, 182, 212) },
}

function Library:SetThemePreset(Name)
    local Preset = self.ThemePresets[Name]
    if not Preset then return end
    self.ThemePresetName = Name
    for Key, Color in pairs(Preset) do self.Theme[Key] = Color end
    self:UpdateTheme()
end

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local CODE_PREFIX = 'NH1-'

local function Base64Encode(Data)
    return ((string.gsub(string.gsub(Data, '.', function(X)
        local R, B = '', string.byte(X)
        for I = 8, 1, -1 do R = R .. ((B % 2 ^ I - B % 2 ^ (I - 1) > 0) and '1' or '0') end
        return R
    end) .. '0000', '%d%d%d?%d?%d?%d?', function(X)
        if #X < 6 then return '' end
        local C = 0
        for I = 1, 6 do C = C + ((string.sub(X, I, I) == '1') and 2 ^ (6 - I) or 0) end
        return string.sub(B64, C + 1, C + 1)
    end)) .. ({ '', '==', '=' })[#Data % 3 + 1])
end

local function Base64Decode(Data)
    Data = string.gsub(Data, '[^%w%+/=]', '')
    return (string.gsub(string.gsub(Data, '.', function(X)
        if X == '=' then return '' end
        local R, F = '', (string.find(B64, X, 1, true) or 1) - 1
        for I = 6, 1, -1 do R = R .. ((F % 2 ^ I - F % 2 ^ (I - 1) > 0) and '1' or '0') end
        return R
    end), '%d%d%d?%d?%d?%d?%d?%d?', function(X)
        if #X ~= 8 then return '' end
        local C = 0
        for I = 1, 8 do C = C + ((string.sub(X, I, I) == '1') and 2 ^ (8 - I) or 0) end
        return string.char(C)
    end))
end
Library.Base64Encode, Library.Base64Decode = Base64Encode, Base64Decode

local function CountSettings(Data)
    local N = 0
    for _ in pairs(Data.Toggles or {}) do N = N + 1 end
    for _ in pairs(Data.Options or {}) do N = N + 1 end
    return N
end

function Library:ExportConfigCode()
    local Data = self:GetConfigData()
    Data.Layout = nil
    Data.Menu = nil
    return CODE_PREFIX .. Base64Encode(HttpService:JSONEncode(Data))
end

function Library:ImportConfigCode(Code)
    Code = string.gsub(tostring(Code or ''), '%s', '')
    if string.sub(Code, 1, #CODE_PREFIX) ~= CODE_PREFIX then return false, 'invalid code' end
    local Ok, Data = pcall(function()
        return HttpService:JSONDecode(Base64Decode(string.sub(Code, #CODE_PREFIX + 1)))
    end)
    if not Ok or type(Data) ~= 'table' then return false, 'code is damaged' end
    local Applied, Err = pcall(function() self:ApplyConfigData(Data) end)
    if not Applied then return false, tostring(Err) end
    return true, CountSettings(Data)
end

function Library:DeleteConfig(Name)
    if not delfile then return false, 'delfile is not supported' end
    local Path = self.Folder .. '/' .. tostring(Name) .. '.json'
    if isfile and not isfile(Path) then return false, 'config not found' end
    local Ok, Err = pcall(delfile, Path)
    return Ok, Ok and Name or tostring(Err)
end

function Library:SetAutoload(Name)
    if not writefile then return false end
    return pcall(function()
        if makefolder and isfolder and not isfolder(self.Folder) then makefolder(self.Folder) end
        writefile(self.Folder .. '/autoload.txt', tostring(Name or ''))
    end)
end

function Library:GetAutoload()
    if not readfile then return nil end
    local Ok, Name = pcall(function()
        local Path = self.Folder .. '/autoload.txt'
        if isfile and not isfile(Path) then return nil end
        return readfile(Path)
    end)
    if Ok and type(Name) == 'string' and Name ~= '' then return Name end
end

function Library:CreateIsland()
    if self.IslandApi then return self.IslandApi end
    local Api = { Queue = {}, Showing = false }
    local IslandBg = Color3.fromRGB(8, 8, 11)
    local White = Color3.fromRGB(240, 241, 248)

    local Frame = Create('TextButton', {
        AutoButtonColor = false, Text = '', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -40),
        Size = UDim2.fromOffset(36, 32), BackgroundColor3 = IslandBg, ClipsDescendants = true, ZIndex = 40, Parent = Overlay,
    })
    Corner(Frame, 'full')
    local FStroke = Stroke(Frame)
    FStroke.Transparency = 0.35
    local FScale = Create('UIScale', { Parent = Frame })
    Api.Frame = Frame

    local Glow = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(19, 16),
        Size = UDim2.fromOffset(8, 8), BackgroundTransparency = 0.4, ZIndex = 41, Parent = Frame,
    })
    Themed(Glow, { BackgroundColor3 = 'Accent' }); Corner(Glow, 'full')
    TweenService:Create(Glow, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1),
        { Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1 }):Play()
    local Dot = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(19, 16),
        Size = UDim2.fromOffset(8, 8), ZIndex = 42, Parent = Frame,
    })
    Themed(Dot, { BackgroundColor3 = 'Accent' }); Corner(Dot, 'full')

    local function Label(Props)
        local L = Create('TextLabel', {
            BackgroundTransparency = 1, Font = Library.Font, TextSize = 12, TextColor3 = White,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43, Parent = Frame,
        })
        for K, V in pairs(Props) do L[K] = V end
        return L
    end
    local TitleL = Label({ Font = Library.FontBold, TextSize = 13, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(0, 220, 0, 32) })
    local HintL = Label({
        TextSize = 11, TextColor3 = Color3.fromRGB(140, 142, 160), AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 200, 0, 32), TextXAlignment = Enum.TextXAlignment.Right,
    })
    local MsgTitle = Label({ Font = Library.FontBold, Position = UDim2.fromOffset(32, 9), Size = UDim2.new(1, -48, 0, 14), TextTransparency = 1 })
    Themed(MsgTitle, { TextColor3 = 'Accent' })
    local MsgText = Label({
        Position = UDim2.fromOffset(32, 26), Size = UDim2.new(1, -48, 0, 14), TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, TextTransparency = 1, TextColor3 = Color3.fromRGB(215, 217, 228),
    })
    local Bar = Create('Frame', {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -6),
        Size = UDim2.new(1, -32, 0, 2), BackgroundTransparency = 1, ZIndex = 43, Parent = Frame,
    })
    Themed(Bar, { BackgroundColor3 = 'Accent' }); Corner(Bar, 'full')

    local function Width(S, Size, Font)
        return TextService:GetTextSize(S, Size, Font, Vector2.new(1000, 100)).X
    end

    function Api:Compact()
        if self.Showing then return end
        local Key = KeyName(Library.ToggleKeybind) or 'None'
        local Hint
        if Library.Opened then
            Hint = Key ~= 'None' and Key or ''
        elseif UserInputService.TouchEnabled then
            Hint = 'Tap to open'
        else
            Hint = Key ~= 'None' and ('Press ' .. Key) or 'Click to open'
        end
        TitleL.Text = Library.Title or 'UI'
        HintL.Text = Hint
        local W = 32 + Width(TitleL.Text, 13, Library.FontBold) + 16
        if Hint ~= '' then W = W + 14 + Width(Hint, 11, Library.Font) end
        Tween(Frame, { Size = UDim2.fromOffset(W, 32) }, 0.55, Back)
        Tween(TitleL, { TextTransparency = 0 }, 0.25)
        Tween(HintL, { TextTransparency = 0 }, 0.25)
        Tween(MsgTitle, { TextTransparency = 1 }, 0.12)
        Tween(MsgText, { TextTransparency = 1 }, 0.12)
        Tween(Bar, { BackgroundTransparency = 1 }, 0.12)
    end

    local function ShowNext()
        local Item = table.remove(Api.Queue, 1)
        if not Item then
            Api.Showing = false
            Api:Compact()
            return
        end
        Api.Showing = true
        local Msg, Time = Item[1], Item[2]
        MsgTitle.Text = Item[3] or Library.Title or 'Notification'
        MsgText.Text = Msg
        local W = math.clamp(math.max(Width(Msg, 12, Library.Font), Width(MsgTitle.Text, 12, Library.FontBold)) + 64, 230, 380)
        local TextH = TextService:GetTextSize(Msg, 12, Library.Font, Vector2.new(W - 48, 1000)).Y
        MsgText.Size = UDim2.new(1, -48, 0, TextH)
        local H = math.max(54, 26 + TextH + 18)

        Tween(TitleL, { TextTransparency = 1 }, 0.12)
        Tween(HintL, { TextTransparency = 1 }, 0.12)
        Tween(Frame, { Size = UDim2.fromOffset(W, H) }, 0.6, Back)
        FScale.Scale = 0.94
        Tween(FScale, { Scale = 1 }, 0.5, Back)
        task.delay(0.14, function()
            Tween(MsgTitle, { TextTransparency = 0 }, 0.25)
            Tween(MsgText, { TextTransparency = 0 }, 0.25)
        end)
        Bar.Size = UDim2.new(1, -32, 0, 2)
        Bar.BackgroundTransparency = 0.25
        Tween(Bar, { Size = UDim2.new(0, 0, 0, 2) }, Time, Enum.EasingStyle.Linear)
        task.delay(Time, function()
            Tween(MsgTitle, { TextTransparency = 1 }, 0.15)
            Tween(MsgText, { TextTransparency = 1 }, 0.15)
            task.wait(0.16)
            ShowNext()
        end)
    end

    function Api:Notify(Msg, Time, Title)
        table.insert(self.Queue, { tostring(Msg), Time or 4, Title })
        if not self.Showing then ShowNext() end
    end

    function Api:OnToggle(State)
        FScale.Scale = State and 1.14 or 0.88
        Tween(FScale, { Scale = 1 }, 0.6, Back)
        Frame.BackgroundColor3 = IslandBg:Lerp(Library.Theme.Accent, 0.4)
        Tween(Frame, { BackgroundColor3 = IslandBg }, 0.7)
        self:Compact()
    end

    function Api:SetVisible(On)
        self.Visible = On
        if On then Frame.Visible = true end
        local T = Tween(Frame, { Position = UDim2.new(0.5, 0, 0, On and 10 or -60) }, 0.5, On and Back or Enum.EasingStyle.Quint)
        if not On then
            task.delay(0.5, function() if not Api.Visible then Frame.Visible = false end end)
        end
    end

    Frame.MouseEnter:Connect(function()
        Tween(FScale, { Scale = 1.06 }, 0.35, Back)
        Tween(FStroke, { Color = Library.Theme.Accent, Transparency = 0.2 }, 0.2)
    end)
    Frame.MouseLeave:Connect(function()
        Tween(FScale, { Scale = 1 }, 0.3)
        Tween(FStroke, { Color = Library.Theme.Stroke, Transparency = 0.35 }, 0.2)
    end)
    Frame.MouseButton1Down:Connect(function() Tween(FScale, { Scale = 0.95 }, 0.1) end)
    Frame.MouseButton1Click:Connect(function() Library:Toggle() end)

    self.IslandApi = Api

    Api:SetVisible(true)
    task.delay(0.15, function() Api:Compact() end)
    return Api
end

function Library:AddSettingsTab(Window)
    Window = Window or self.Window
    if not Window or Window.SettingsTab then return Window and Window.SettingsTab end
    local Tab
    if Window.Sidebar and Window.Nav then

        Window.Nav.Size = UDim2.new(1, -20, 1, -80 - 34 - 58)
        local Line = Create('Frame', {
            BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -34 - 46),
            Size = UDim2.new(1, -28, 0, 1), Parent = Window.Sidebar,
        })
        Themed(Line, { BackgroundColor3 = 'Stroke' })
        local Plate = Create('Frame', {
            BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -34),
            Size = UDim2.new(1, -20, 0, 36), Parent = Window.Sidebar,
        })
        Themed(Plate, { BackgroundColor3 = 'Card' }); Corner(Plate, 8)
        local PlateStroke = Stroke(Plate)
        Tab = Window:_AddTab(Window.Config.SettingsName or 'Settings', Plate, 34)
        local Btn, Label = Tab.Button, Tab.Label
        Btn.Size = UDim2.fromScale(1, 1)
        Corner(Btn, 8)
        Label.Font = Library.FontBold
        local Gear = GearIcon(Btn, 'Accent', { Position = UDim2.new(0, 19, 0.5, 0), ZIndex = 2 })
        local Spin = 0
        Btn.MouseEnter:Connect(function()
            Spin = Spin + 60
            Gear:Spin(Spin)
            if Window.ActiveTab ~= Tab then Tween(PlateStroke, { Color = Lerp('Stroke', 'Accent', 0.4) }, 0.2) end
        end)
        Btn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then Tween(PlateStroke, { Color = Library.Theme.Stroke }, 0.2) end
        end)
        Tab.OnShow = function()
            Spin = Spin + 180
            Gear:Spin(Spin, 0.7)
            Tween(PlateStroke, { Color = Library.Theme.Accent }, 0.25)
        end
        Tab.OnHide = function() Tween(PlateStroke, { Color = Library.Theme.Stroke }, 0.25) end
    else
        Tab = Window:AddTab(Window.Config.SettingsName or 'Settings')
    end
    Window.SettingsTab = Tab

    local ThemeBox = Tab:AddLeftGroupbox('Theme')
    local AccentNames, AccentByName, CurrentAccent = {}, {}, 'Custom'
    for _, A in ipairs(self.AccentPresets) do
        table.insert(AccentNames, A[1])
        AccentByName[A[1]] = A[2]
        if A[2] == self.Theme.Accent then CurrentAccent = A[1] end
    end
    table.insert(AccentNames, 'Custom')

    ThemeBox:AddDropdown('__AccentPreset', {
        Text = 'Accent', Values = AccentNames, Default = CurrentAccent, NoConfig = true, Searchable = false,
        Callback = function(Name)
            local C = AccentByName[Name]
            if C and Options.__AccentColor then Options.__AccentColor:SetValueRGB(C) end
        end,
    })
    ThemeBox:AddColorPicker('__AccentColor', {
        Text = 'Accent color', Default = self.Theme.Accent, NoConfig = true,
        Callback = function(C) Library:SetAccent(C) end,
    })
    ThemeBox:AddDropdown('__ThemePreset', {
        Text = 'Background', Values = self.ThemePresetOrder, Default = self.ThemePresetName, NoConfig = true, Searchable = false,
        Callback = function(Name) if Name then Library:SetThemePreset(Name) end end,
    })
    ThemeBox:AddSlider('__UIScale', {
        Text = 'UI scale', Min = 50, Max = 150, Default = 100, Suffix = '%', NoConfig = true,
        Callback = function(V) Window:SetScale((Library.AutoScale or 1) * V / 100) end,
    })
    ThemeBox:AddButton({ Text = 'Reset theme', Func = function()
        Options.__ThemePreset:SetValue('Normal')
        Options.__AccentPreset:SetValue('Normal')
        Options.__AccentColor:SetValueRGB(Library.DefaultAccent)
        Options.__UIScale:SetValue(100)
    end })

    local MenuBox = Tab:AddLeftGroupbox('Menu')
    MenuBox:AddKeybind('__MenuKeybind', {
        Text = 'Open / close UI', Default = KeyName(self.ToggleKeybind) or 'RightShift', Modes = { 'Toggle' }, NoConfig = true,
        ChangedCallback = function() if Library.IslandApi then Library.IslandApi:Compact() end end,
    })
    self.ToggleKeybind = Options.__MenuKeybind
    if self.IslandApi then
        MenuBox:AddToggle('__Island', {
            Text = 'Dynamic island', Default = true, NoConfig = true,
            Callback = function(V) Library.IslandApi:SetVisible(V) end,
        })
        MenuBox:AddToggle('__IslandNotify', {
            Text = 'Notifications in island', Default = true, NoConfig = true,
            Callback = function(V) Library.IslandNotifications = V end,
        })
    end
    MenuBox:AddButton({ Text = 'Unload', DoubleClick = true, Func = function() Library:Unload() end })

    local ConfigBox = Tab:AddRightGroupbox('Configs')
    local NameIn = ConfigBox:AddInput('__ConfigName', { Text = 'Config name', Default = 'default', Placeholder = 'name...', NoConfig = true })
    local List = ConfigBox:AddDropdown('__ConfigList', {
        Text = 'Saved configs', Values = self:GetConfigs(), AllowNull = true, NoConfig = true,
        Callback = function(V) if V then NameIn:SetValue(V) end end,
    })
    local function RefreshList(Select)
        List:Refresh(Library:GetConfigs())
        if Select then List:SetValue(Select) end
    end
    local AutoLabel
    ConfigBox:AddButton({ Text = 'Save config', Func = function()
        local Ok, R = Library:SaveConfig(NameIn.Value)
        Library:Notify(Ok and ('Saved config "' .. R .. '"') or ('Save failed: ' .. R), 3)
        if Ok then RefreshList(R) end
    end })
    ConfigBox:AddButton({ Text = 'Load config', Func = function()
        local Ok, R = Library:LoadConfig(List.Value or NameIn.Value)
        Library:Notify(Ok and ('Loaded config "' .. R .. '"') or ('Load failed: ' .. R), 3)
    end })
    ConfigBox:AddButton({ Text = 'Delete config', DoubleClick = true, Func = function()
        local Ok, R = Library:DeleteConfig(List.Value or NameIn.Value)
        Library:Notify(Ok and ('Deleted config "' .. R .. '"') or ('Delete failed: ' .. R), 3)
        RefreshList()
    end })
    ConfigBox:AddButton({ Text = 'Refresh list', Func = function() RefreshList(List.Value) end })
    ConfigBox:AddDivider()
    AutoLabel = ConfigBox:AddLabel('Autoload: ' .. (self:GetAutoload() or 'none'))
    ConfigBox:AddButton({ Text = 'Set as autoload', Func = function()
        local Name = List.Value or NameIn.Value
        Library:SetAutoload(Name)
        AutoLabel:SetText('Autoload: ' .. tostring(Name))
        Library:Notify('"' .. tostring(Name) .. '" will load automatically', 3)
    end })
    ConfigBox:AddButton({ Text = 'Clear autoload', Func = function()
        Library:SetAutoload('')
        AutoLabel:SetText('Autoload: none')
    end })

    local CodeBox = Tab:AddRightGroupbox('Private code')
    local CodeIn = CodeBox:AddInput('__PrivateCode', { Text = 'Code', Placeholder = 'Paste a code here...', NoConfig = true })
    CodeBox:AddButton({ Text = 'Export (copy code)', Func = function()
        local Code = Library:ExportConfigCode()
        CodeIn:SetValue(Code)
        local Copied = setclipboard and pcall(setclipboard, Code)
        Library:Notify(Copied and 'Private code copied to clipboard' or 'Code created, copy it from the box', 3)
    end })
    CodeBox:AddButton({ Text = 'Import code', Func = function()
        local Ok, R = Library:ImportConfigCode(CodeIn.Value)
        Library:Notify(Ok and ('Imported ' .. R .. ' settings') or ('Import failed: ' .. R), 3)
    end })
    CodeBox:AddLabel('The code holds every toggle, slider, dropdown, keybind, color and list. Importing applies and runs them right away.', true)

    return Tab
end

function Library:LoadAutoload()
    local Name = self:GetAutoload()
    if not Name then return false end
    local Ok = self:LoadConfig(Name)
    if Ok then self:Notify('Autoloaded config "' .. Name .. '"', 3) end
    return Ok
end

function Library:Unload()
    if self.Unloaded then return end
    self.Unloaded = true
    for _, S in ipairs(self.Signals) do pcall(function() S:Disconnect() end) end
    for _, F in ipairs(self.UnloadCallbacks) do self:SafeCallback(F) end
    ScreenGui:Destroy()
    OverlayGui:Destroy()
    pcall(function() InsetProbe:Destroy() end)
end

return Library
