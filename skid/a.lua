if game.CoreGui:FindFirstChild('ScreenGui') then
    game.CoreGui.ScreenGui:Destroy()
end
local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.DisplayOrder = 2147483647;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(0, 85, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    RainbowPickers = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
        for Picker in pairs(Library.RainbowPickers) do
            Picker.Hue, Picker.Sat, Picker.Vib = Hue, 0.8, 1;
            Picker:Display();
        end;
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.ApplyingConfig then return; end;
    if Library.SaveManager then
        local Success, Error = pcall(function() Library.SaveManager:Save(); end);
        if not Success then Library:Notify(tostring(Error), 3); end;
    end;
end;

local HttpService = game:GetService('HttpService');
Library.ConfigRegistry = {};
Library.ConfigFolder = 'Linoria_Configs';

local function ConfigValue(Object)
    if Object.Value == nil then return {__type = 'Nil'}; end;
    if Object.Type == 'ColorPicker' then
        return {__type = 'Color3', R = Object.Value.R, G = Object.Value.G, B = Object.Value.B, Transparency = Object.Transparency or 0, Rainbow = Object.Rainbow or false};
    elseif Object.Type == 'KeyPicker' then
        return {Key = Object.Value, Mode = Object.Mode};
    elseif type(Object.Value) == 'table' then
        local Value = {};
        for Key, Item in pairs(Object.Value) do Value[Key] = Item; end;
        return Value;
    end;
    return Object.Value;
end;

function Library:RegisterConfig(Idx, Object, Info)
    Object.NoConfig = Info.NoConfig;
    if not Info.NoConfig then
        self.ConfigRegistry[tostring(Info.Flag or Idx)] = {Object = Object, Default = ConfigValue(Object)};
    end;
end;

function Library:GetConfigData()
    local Data = {};
    for Flag, Entry in pairs(self.ConfigRegistry) do
        Data[Flag] = ConfigValue(Entry.Object);
    end;
    return Data;
end;

local function ConfigSetter(Object, Value)
    if type(Value) == 'table' and Value.__type == 'Nil' then Value = nil; end;
    if Object.Type == 'Toggle' then
        assert(type(Value) == 'boolean', 'Invalid toggle value');
    elseif Object.Type == 'Slider' then
        assert(type(Value) == 'number' and Value == Value and math.abs(Value) < math.huge, 'Invalid slider value');
    elseif Object.Type == 'Input' then
        assert(type(Value) == 'string', 'Invalid textbox value');
        return function()
            Object:SetValue(Value);
            Library:SafeCallback(Object.ConfigCallback, Object.Value);
        end;
    elseif Object.Type == 'Paragraph' then
        assert(type(Value) == 'table', 'Invalid ESP layout');
    elseif Object.Type == 'Dropdown' then
        assert(Object.Multi and type(Value) == 'table' or not Object.Multi and (Value == nil or type(Value) == 'string' or type(Value) == 'number'), 'Invalid dropdown value');
    elseif Object.Type == 'ColorPicker' then
        assert(type(Value) == 'table' and Value.__type == 'Color3', 'Invalid color value');
        for _, Key in ipairs({'R', 'G', 'B', 'Transparency'}) do
            local Number = Value[Key] or (Key == 'Transparency' and 0);
            assert(type(Number) == 'number' and Number >= 0 and Number <= 1, 'Invalid color component');
        end;
        local Color = Color3.new(Value.R, Value.G, Value.B);
        return function() Object:SetValueRGB(Color, Value.Transparency or 0); Object:SetRainbow(Value.Rainbow == true); end;
    elseif Object.Type == 'KeyPicker' then
        if type(Value) == 'string' then Value = {Key = Value, Mode = Object.Mode}; end;
        if type(Value) == 'table' and Value.__type == 'EnumItem' then
            Value = {Key = tostring(Value.Value):match('^Enum%.[^.]+%.(.+)$'), Mode = Object.Mode};
        end;
        assert(type(Value) == 'table' and type(Value.Key) == 'string', 'Invalid keybind value');
        assert(Value.Key == 'MB1' or Value.Key == 'MB2' or Enum.KeyCode[Value.Key], 'Invalid key');
        assert(table.find(Object.ConfigModes, Value.Mode), 'Invalid keybind mode');
        return function() Object:SetValue({Value.Key, Value.Mode}); end;
    else
        error('Unsupported config control');
    end;
    return function() Object:SetValue(Value); end;
end;

function Library:ApplyConfigData(Data)
    if type(Data) ~= 'table' then return false, 'Invalid config'; end;
    local Pending = {};
    local Valid, Reason = pcall(function()
        for Flag, Value in pairs(Data) do
            local Entry = self.ConfigRegistry[Flag];
            if Entry then
                table.insert(Pending, {Object = Entry.Object, Apply = ConfigSetter(Entry.Object, Value)});
            end;
        end;
    end);
    if not Valid then return false, tostring(Reason); end;
    self.ApplyingConfig = true;
    local Success, Error = pcall(function()
        for _, Item in ipairs(Pending) do
            if Item.Object.Type ~= 'Toggle' then Item.Apply(); end;
        end;
        for _, Item in ipairs(Pending) do
            if Item.Object.Type == 'Toggle' then Item.Apply(); end;
        end;
    end);
    self.ApplyingConfig = false;
    return Success, Error;
end;

local function ConfigName(Name)
    Name = tostring(Name or 'default'):gsub('[^%w%-%_]', '_');
    return Name ~= '' and Name or 'default';
end;

function Library:SaveConfig(Name)
    if not (writefile and isfolder and makefolder) then return false, 'File saving unavailable'; end;
    Name = ConfigName(Name);
    local Success, Error = pcall(function()
        if not isfolder(self.ConfigFolder) then makefolder(self.ConfigFolder); end;
        writefile(self.ConfigFolder .. '/' .. Name .. '.json', HttpService:JSONEncode(self:GetConfigData()));
    end);
    return Success, Success and Name or tostring(Error);
end;

function Library:LoadConfig(Name)
    if not (readfile and isfile) then return false, 'File loading unavailable'; end;
    local Success, Data = pcall(function()
        local Path = self.ConfigFolder .. '/' .. ConfigName(Name) .. '.json';
        assert(isfile(Path), 'Config not found');
        return HttpService:JSONDecode(readfile(Path));
    end);
    if not Success then return false, tostring(Data); end;
    return self:ApplyConfigData(Data);
end;

function Library:GetConfigs()
    local Names = {};
    if listfiles and isfolder then
        pcall(function()
            if not isfolder(self.ConfigFolder) then return; end;
            for _, Path in ipairs(listfiles(self.ConfigFolder)) do
                local Name = Path:match('([^/\\]+)%.json$');
                if Name then table.insert(Names, Name); end;
            end;
        end);
    end;
    table.sort(Names);
    return Names;
end;

function Library:SetDefaultConfig()
    local Defaults = {};
    for Flag, Entry in pairs(self.ConfigRegistry) do Defaults[Flag] = Entry.Default; end;
    return self:ApplyConfigData(Defaults);
end;

function Library:ExportConfigCode()
    local Json = HttpService:JSONEncode(self:GetConfigData());
    return 'WEX1-' .. Json:gsub('.', function(Character) return string.format('%02X', string.byte(Character)); end);
end;

function Library:ImportConfigCode(Code)
    local Hex = tostring(Code or ''):match('^%s*WEX1%-(%x+)%s*$');
    if not Hex or #Hex % 2 ~= 0 then return false, 'Invalid config code'; end;
    local Json = Hex:gsub('%x%x', function(Pair) return string.char(tonumber(Pair, 16)); end);
    local Success, Data = pcall(HttpService.JSONDecode, HttpService, Json);
    if not Success then return false, 'Invalid config code'; end;
    return self:ApplyConfigData(Data);
end;

function Library:GetConfigSummary()
    local Lines = {};
    for Flag, Value in pairs(self:GetConfigData()) do
        table.insert(Lines, Flag .. ' = ' .. (type(Value) == 'table' and HttpService:JSONEncode(Value) or tostring(Value)));
    end;
    table.sort(Lines);
    return table.concat(Lines, '\n');
end;

Library.Animations = setmetatable({}, {__mode = 'k'});
Library.PopupStates = setmetatable({}, {__mode = 'k'});

function Library:Tween(Object, Properties, Duration)
    local Active = self.Animations[Object] or {};
    self.Animations[Object] = Active;
    for Property, Value in pairs(Properties) do
        local Previous = Active[Property];
        if not Previous or Previous.Value ~= Value or Previous.Tween.PlaybackState ~= Enum.PlaybackState.Playing then
            if Previous then Previous.Tween:Cancel(); end;
            Active[Property] = nil;
            if Object[Property] ~= Value then
                local Tween = TweenService:Create(Object, TweenInfo.new(Duration or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {[Property] = Value});
                Active[Property] = {Value = Value, Tween = Tween};
                Tween:Play();
            end;
        end;
    end;
end;

function Library:SetPopupVisible(Frame, Visible)
    local State = self.PopupStates[Frame];
    if not State then
        State = {Scale = self:Create('UIScale', {Scale = 1, Parent = Frame}), Token = 0};
        self.PopupStates[Frame] = State;
    end;
    if State.Visible == Visible and (not Visible or Frame.Visible) then return; end;
    State.Visible = Visible;
    State.Token = State.Token + 1;
    local Token = State.Token;
    if Visible then
        if not Frame.Visible then
            State.Scale.Scale = 0.94;
            if Frame:IsA('CanvasGroup') then Frame.GroupTransparency = 1; end;
        end;
        Frame.Visible = true;
    end;
    self:Tween(State.Scale, {Scale = Visible and 1 or 0.94}, 0.18);
    if Frame:IsA('CanvasGroup') then self:Tween(Frame, {GroupTransparency = Visible and 0 or 1}, 0.16); end;
    if not Visible then
        task.delay(0.18, function()
            if State.Token == Token and Frame.Parent then Frame.Visible = false; end;
        end);
    end;
end;

function Library:AnimateEntrance(Frame)
    local State = self.PopupStates[Frame];
    if not State then
        State = {Scale = self:Create('UIScale', {Scale = 1, Parent = Frame}), Token = 0};
        self.PopupStates[Frame] = State;
    end;
    local Active = self.Animations[State.Scale];
    if Active and Active.Scale then Active.Scale.Tween:Cancel(); Active.Scale = nil; end;
    State.Scale.Scale = 0.98;
    self:Tween(State.Scale, {Scale = 1}, 0.18);
end;

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;

    if Class == 'TextButton' then
        local Scale = Instance.new('UIScale');
        Scale.Parent = _Instance;
        local Hovered = false;
        self:GiveSignal(_Instance.MouseEnter:Connect(function() Hovered = true; self:Tween(Scale, {Scale = 1.025}); end));
        self:GiveSignal(_Instance.MouseLeave:Connect(function() Hovered = false; self:Tween(Scale, {Scale = 1}); end));
        self:GiveSignal(_Instance.MouseButton1Down:Connect(function() self:Tween(Scale, {Scale = 0.96}, 0.08); end));
        self:GiveSignal(_Instance.MouseButton1Up:Connect(function() self:Tween(Scale, {Scale = Hovered and 1.025 or 1}, 0.12); end));
    elseif Class == 'TextBox' then
        local Stroke = Instance.new('UIStroke');
        Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        Stroke.Color = self.AccentColor;
        Stroke.Transparency = 1;
        Stroke.Parent = _Instance;
        self:GiveSignal(_Instance.Focused:Connect(function()
            Stroke.Color = self.AccentColor;
            self:Tween(Stroke, {Transparency = 0.25});
        end));
        self:GiveSignal(_Instance.FocusLost:Connect(function() self:Tween(Stroke, {Transparency = 1}); end));
    end;

    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:FormatTitle(Text, Tag)
    if not Tag then return Text; end;
    Tag = tostring(Tag);
    if Tag:sub(1, 1) ~= '[' then Tag = '[' .. Tag .. ']'; end;
    return tostring(Text) .. ' ' .. Tag;
end;

local function ColorTitleTags(Text, RichText)
    local Colors = {Risk = '#FF5050', Beta = '#FFD84D', WIP = '#FF9A3C'};
    Text = Text:gsub('<font%s+color="(#%x+)"%s*>%[([%a]+)%]</font>', function(Color, Tag)
        return Colors[Tag] and '[' .. Tag .. ']' or '<font color="' .. Color .. '">[' .. Tag .. ']</font>';
    end);
    if Text:find('<font%s') then RichText = true; end;
    if not (Text:find('[Risk]', 1, true) or Text:find('[Beta]', 1, true) or Text:find('[WIP]', 1, true)) then return Text, RichText; end;
    if not RichText then Text = Text:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'); end;
    return Text:gsub('%[([%a]+)%]', function(Tag)
        return Colors[Tag] and '<font color="' .. Colors[Tag] .. '">[' .. Tag .. ']</font>' or '[' .. Tag .. ']';
    end), true;
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    Library:Create(_Instance, Properties);
    local RichText, Rendered = _Instance.RichText;
    local function UpdateTags()
        if _Instance.Text == Rendered then return; end;
        local Text, Enabled = ColorTitleTags(_Instance.Text, RichText);
        Rendered = Text;
        _Instance.RichText = Enabled;
        _Instance.Text = Text;
    end;
    Library:GiveSignal(_Instance:GetPropertyChangedSignal('Text'):Connect(UpdateTags));
    UpdateTags();
    return _Instance;
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;
    local DragInput, DragStart, StartPosition;
    Library:GiveSignal(Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return; end;
        if Input.Position.Y - Instance.AbsolutePosition.Y > (Cutoff or 40) then return; end;
        DragInput, DragStart, StartPosition = Input, Input.Position, Instance.Position;
    end));
    Library:GiveSignal(InputService.InputChanged:Connect(function(Input)
        if not DragInput or not Instance.Parent then return; end;
        if Input ~= DragInput and not (DragInput.UserInputType == Enum.UserInputType.MouseButton1 and Input.UserInputType == Enum.UserInputType.MouseMovement) then return; end;
        local Delta = Input.Position - DragStart;
        local Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y);
        if Instance.Position ~= Position then Instance.Position = Position; end;
    end));
    Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
        if Input == DragInput then DragInput = nil; end;
    end));
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,

        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Library:Tween(Instance, {[Property] = Library[ColorIdx] or ColorIdx});

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, PropertiesDefault do
            Library:Tween(Instance, {[Property] = Library[ColorIdx] or ColorIdx});

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateTheme(Key, Color)
    local Keys = {Accent = 'AccentColor', Background = 'BackgroundColor', Main = 'MainColor', Text = 'FontColor', Outline = 'OutlineColor', Risk = 'RiskColor'};
    Key = Keys[Key] or Key;
    assert(Keys[Key] or Key == 'AccentColor' or Key == 'BackgroundColor' or Key == 'MainColor' or Key == 'FontColor' or Key == 'OutlineColor' or Key == 'RiskColor', 'Invalid theme color');
    assert(typeof(Color) == 'Color3', 'Invalid color');
    self[Key] = Color;
    if Key == 'AccentColor' then self.AccentColorDark = self:GetDarkerColor(Color); end;
    self:UpdateColorsUsingRegistry();
end;

function Library:UpdateColorsUsingRegistry()
    -- TODO: Could have an 'active' list of objects
    -- where the active list only contains Visible objects.

    -- IMPL: Could setup .Changed events on the AddToRegistry function
    -- that listens for the 'Visible' propert being changed.
    -- Visible: true => Add to active list, and call UpdateColors function
    -- Visible: false => Remove from active list.

    -- The above would be especially efficient for a rainbow menu color or live color-changing.

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            local Active = Library.Animations[Object.Instance];
            if Active and Active[Property] then Active[Property].Tween:Cancel(); Active[Property] = nil; end;
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    -- Only used for signals not attached to library instances, as those should be cleaned up on object destruction by Roblox
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    InputService.MouseIconEnabled = true;
    -- Unload all of the signals
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

    -- Call our unload callback, maybe to undo some hooks etc
    if Library.OnUnload then
        Library.OnUnload()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        -- local Container = self.Container;

        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);

            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        -- Transparency image taken from https://github.com/matas3535/SplixPrivateDrawingLibrary/blob/main/Library.lua cus i'm lazy
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        -- 1/16/23
        -- Rewrote this to be placed inside the Library ScreenGui
        -- There was some issue which caused RelativeOffset to be way off
        -- Thus the color picker would never show

        local PickerFrameOuter = Library:Create('CanvasGroup', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 295 or 277);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            if not PickerFrameOuter.Visible then return; end;
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,--Info.Default;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });


        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('CanvasGroup', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                if not ContextMenu.Container.Visible then return; end;
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                Library:SetPopupVisible(self.Container, true)
                updateMenuPosition()
            end

            function ContextMenu:Hide()
                Library:SetPopupVisible(self.Container, false)
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)


            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            Library:SetPopupVisible(PickerFrameOuter, true);
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            Library:SetPopupVisible(PickerFrameOuter, false);
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                while (Input.UserInputType == Enum.UserInputType.Touch and Input.UserInputState ~= Enum.UserInputState.End and Input.UserInputState ~= Enum.UserInputState.Cancel) or (Input.UserInputType == Enum.UserInputType.MouseButton1 and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) do
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Input.UserInputType == Enum.UserInputType.Touch and Input.Position.X or Mouse.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Input.UserInputType == Enum.UserInputType.Touch and Input.Position.Y or Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                while (Input.UserInputType == Enum.UserInputType.Touch and Input.UserInputState ~= Enum.UserInputState.End and Input.UserInputState ~= Enum.UserInputState.Cancel) or (Input.UserInputType == Enum.UserInputType.MouseButton1 and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Input.UserInputType == Enum.UserInputType.Touch and Input.Position.Y or Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                    while (Input.UserInputType == Enum.UserInputType.Touch and Input.UserInputState ~= Enum.UserInputState.End and Input.UserInputState ~= Enum.UserInputState.Cancel) or (Input.UserInputType == Enum.UserInputType.MouseButton1 and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Input.UserInputType == Enum.UserInputType.Touch and Input.Position.X or Mouse.X, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    end;

                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        local RainbowButton = Library:Create('TextButton', {
            Position = UDim2.new(0, 4, 1, -24);
            Size = UDim2.new(1, -8, 0, 20);
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            TextColor3 = Library.FontColor;
            Font = Library.Font;
            TextSize = 13;
            Text = 'Rainbow: OFF';
            ZIndex = 18;
            Parent = PickerFrameInner;
        });
        Library:AddToRegistry(RainbowButton, {BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor', TextColor3 = 'FontColor'});
        function ColorPicker:SetRainbow(Enabled)
            self.Rainbow = Enabled == true;
            Library.RainbowPickers[self] = self.Rainbow and true or nil;
            RainbowButton.Text = self.Rainbow and 'Rainbow: ON' or 'Rainbow: OFF';
        end;
        Library:GiveSignal(RainbowButton.MouseButton1Click:Connect(function()
            ColorPicker:SetRainbow(not ColorPicker.Rainbow);
            Library:AttemptSave();
        end));
        ColorPicker:SetRainbow(Info.Rainbow == true);
        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;
        Library:RegisterConfig(Idx, ColorPicker, Info);

        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle'; -- Always, Toggle, Hold
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('CanvasGroup', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            if not ModeSelectOuter.Visible then return; end;
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        },  true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                Library:SetPopupVisible(ModeSelectOuter, false);
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;

                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI or not ScreenGui.Parent or not ContainerLabel.Parent then
                return;
            end;

            local State = KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            local Registry = Library.RegistryMap[ContainerLabel];
            local ColorKey = State and 'AccentColor' or 'FontColor';
            if Registry then Registry.Properties.TextColor3 = ColorKey;
            else Library:AddToRegistry(ContainerLabel, {TextColor3 = ColorKey}, true); end;

            local YSize = 0
            local XSize = 0

            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then
                        XSize = Label.TextBounds.X
                    end
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                local Key = KeyPicker.Value;

                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;

                DisplayLabel.Text = '';

                local Break;
                local Text = '';

                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then
                            Text = '';
                        end;

                        Text = Text .. '.';
                        DisplayLabel.Text = Text;

                        wait(0.4);
                    end;
                end);

                wait(0.2);

                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;

                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
                Library:SetPopupVisible(ModeSelectOuter, true);
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;

                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();

        Options[Idx] = KeyPicker;
        KeyPicker.ConfigModes = Info.Modes or {'Always', 'Toggle', 'Hold'};
        Library:RegisterConfig(Idx, KeyPicker, Info);

        return self;
    end;

    function Funcs:AddKeybind(Idx, Info)
        if type(Idx) == 'table' then Info, Idx = Idx, nil; end;
        Info = Info or {};
        local Settings = {};
        for Key, Value in pairs(Info) do Settings[Key] = Value; end;
        Settings.Default = Settings.Default or 'Unknown';
        if typeof(Settings.Default) == 'EnumItem' then Settings.Default = Settings.Default.Name; end;
        Settings.SyncToggleState = self.Type == 'Toggle';
        return self:AddKeyPicker(Idx or self.TextLabel.Text .. ' Keybind', Settings);
    end;

    for _, Name in ipairs({'AddColorPicker', 'AddKeyPicker'}) do
        local Method = Funcs[Name];
        Funcs[Name] = function(self, Idx, Info)
            local Group = Library:GetAddonGroup(self);
            local Label = Group:AddLabel(Info.Text or Info.Title or tostring(Idx));
            local Parent = setmetatable({TextLabel = Label.TextLabel, Container = Group.Container}, {__index = self});
            Method(Parent, Idx, Info);
            return self;
        end;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        if type(DoesWrap) == 'table' then
            Text = Library:FormatTitle(Text, DoesWrap.Tag);
            DoesWrap = DoesWrap.Wrap or false;
        end;
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;

    function Funcs:AddButton(...)
        -- TODO: Eventually redo this
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Library:FormatTitle(Props.Text, Props.Tag)
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
                ZIndex = 5;
            });

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });

            Library:AddToRegistry(Outer, {
                BorderColor3 = 'Black';
            });

            Library:AddToRegistry(Inner, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)

                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end


        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5);
            ZIndex = 5;
            Parent = Container;
        });

        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DividerOuter;
        });

        Library:AddToRegistry(DividerOuter, {
            BorderColor3 = 'Black';
        });

        Library:AddToRegistry(DividerInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Library:FormatTitle(Info.Text, Info.Tag);
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });
        Textbox.TextLabel = InputLabel;

        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });

        local Container = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            ZIndex = 7;
            Parent = Container;
        });

        Library:ApplyTextStroke(Box);
        Textbox.Box = Box;

        if Info.Sensor or Info.sensor then
            Box.TextTransparency = 1;
            Box.TextStrokeTransparency = 1;
            local Mask = Library:CreateLabel({
                BackgroundTransparency = 1;
                Size = UDim2.fromScale(1, 1);
                Text = '';
                TextSize = Box.TextSize;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = Box.ZIndex + 1;
                Parent = Box;
            });
            local function UpdateMask()
                Mask.Text = Box.Text == '' and Box.PlaceholderText or string.rep('*', utf8.len(Box.Text) or #Box.Text);
            end;
            Box:GetPropertyChangedSignal('Text'):Connect(UpdateMask);
            UpdateMask();
        end;

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;
            Box.Text = Text;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        -- https://devforum.roblox.com/t/how-to-make-textboxes-follow-current-cursor-position/1368429/6
        -- thank you nicemike40 :)

        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                -- we aren't focused, or we fit so be normal
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                -- we are focused and don't fit, so adjust position
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    -- calculate pixel width of text from start to cursor
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    -- check if we're inside the box with the cursor
                    local currentCursorPos = Box.Position.X.Offset + width

                    -- adjust if necessary
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;
        Library:RegisterConfig(Idx, Textbox, Info);

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        Info = Info or {};
        Info.Text = Info.Text or Idx;
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = 'Black';
        });

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 216, 1, 0);
            Position = UDim2.new(1, 6, 0, 0);
            TextSize = 14;
            Text = Library:FormatTitle(Info.Text, Info.Tag);
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleInner;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display()
            Library:Tween(ToggleInner, {
                BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
                BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;
            });

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Toggle.InitialCallbackPending = false;
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value) -- Why was it not like this from the start?
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;
        Library:RegisterConfig(Idx, Toggle, Info);
        if Toggle.Value then
            Toggle.InitialCallbackPending = true;
            task.defer(function()
                if ScreenGui.Parent and Toggle.Value and Toggle.InitialCallbackPending then
                    Toggle.InitialCallbackPending = false;
                    Library:SafeCallback(Toggle.Callback, true);
                end;
            end);
        end;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        Info = Info or {};
        Info.Text = Info.Text or Idx;
        Info.Min = Info.Min or 0;
        Info.Max = Info.Max or 100;
        Info.Default = Info.Default or Info.Min;
        Info.Rounding = Info.Rounding or 0;
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local SliderLabel;
        if not Info.Compact then
            SliderLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Library:FormatTitle(Info.Text, Info.Tag);
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end
        Slider.TextLabel = SliderLabel;

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black';
        });

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        });

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'AccentColorDark';
        });

        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        });

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = 'AccentColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });
        Slider.TextLabel = Slider.TextLabel or DisplayLabel;

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Library:FormatTitle(Info.Text, Info.Tag) .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s%s', Slider.Value, Slider.Max, Suffix);
            end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            if Slider.Dragging then Fill.Size = UDim2.new(0, X, 1, 0);
            else Library:Tween(Fill, {Size = UDim2.new(0, X, 1, 0)}, 0.12); end;

            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;


            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        if SliderLabel then
            SliderLabel.Active = true;
            local Editor = Library:Create('TextBox', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.AccentColor;
                Position = UDim2.fromOffset(0, -4);
                Size = UDim2.new(1, 0, 0, 18);
                Font = Library.Font;
                TextColor3 = Library.FontColor;
                TextSize = 14;
                Text = '';
                ClearTextOnFocus = false;
                Visible = false;
                ZIndex = 10;
                Parent = SliderLabel;
            });
            Library:AddToRegistry(Editor, {BackgroundColor3 = 'MainColor', BorderColor3 = 'AccentColor', TextColor3 = 'FontColor'});
            Library:GiveSignal(SliderLabel.InputBegan:Connect(function(Input)
                if Slider.AddonGear and Library:IsMouseOverFrame(Slider.AddonGear) then return; end;
                if Editor.Visible or Library:MouseIsOverOpenedFrame() then return; end;
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return; end;
                Editor.Text = tostring(Slider.Value);
                Editor.Visible = true;
                Editor:CaptureFocus();
                Editor.SelectionStart = 1;
                Editor.CursorPosition = #Editor.Text + 1;
            end));
            Library:GiveSignal(Editor.FocusLost:Connect(function(Enter)
                Editor.Visible = false;
                local Value = tonumber(Editor.Text);
                if Enter and Value and Value == Value and math.abs(Value) < math.huge then
                    Slider:SetValue(Round(Value));
                    Library:AttemptSave();
                end;
            end));
            Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
                if Input.KeyCode == Enum.KeyCode.Escape and Editor:IsFocused() then Editor:ReleaseFocus(false); end;
            end));
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Slider.AddonGear and Library:IsMouseOverFrame(Slider.AddonGear) then return; end;
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                local Active = Library.Animations[Fill];
                if Active and Active.Size then Active.Size.Tween:Cancel(); Active.Size = nil; end;
                Slider.Dragging = true;
                while (Input.UserInputType == Enum.UserInputType.Touch and Input.UserInputState ~= Enum.UserInputState.End and Input.UserInputState ~= Enum.UserInputState.Cancel) or (Input.UserInputType == Enum.UserInputType.MouseButton1 and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) do
                    local PointerX = Input.UserInputType == Enum.UserInputType.Touch and Input.Position.X or Mouse.X;
                    local nX = math.clamp((PointerX - SliderInner.AbsolutePosition.X) / math.max(1, SliderInner.AbsoluteSize.X) * Slider.MaxSize, 0, Slider.MaxSize);

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;

                    RenderStepped:Wait();
                end;

                Slider.Dragging = false;
                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;
        Library:RegisterConfig(Idx, Slider, Info);

        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType; -- can be either 'Player' or 'Team'
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            Dropdown.TextLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Library:FormatTitle(Info.Text, Info.Tag);
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = 'Black';
        });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 7;
            Parent = DropdownInner;
        });
        Dropdown.TextLabel = Dropdown.TextLabel or ItemList;

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = Library:Create('CanvasGroup', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;

        RecalculateListPosition();
        RecalculateListSize();

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            if ListOuter.Visible then RecalculateListPosition(); end;
        end);

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Scrolling = Library:Create('ScrollingFrame', {
            Active = true;
            ScrollingEnabled = true;
            ScrollingDirection = Enum.ScrollingDirection.Y;
            ElasticBehavior = Enum.ElasticBehavior.WhenScrollable;
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        if Dropdown.Multi then
            Scrolling.Size = UDim2.new(1, 0, 1, -30);
            for Index, Text in ipairs({'Add All', 'Remove All'}) do
                local Action = Library:Create('TextButton', {
                    BackgroundColor3 = Library.MainColor;
                    BorderSizePixel = 0;
                    AutoButtonColor = false;
                    Position = UDim2.new((Index - 1) * 0.5, 4, 1, -26);
                    Size = UDim2.new(0.5, -8, 0, 22);
                    Font = Library.Font;
                    Text = Text;
                    TextColor3 = Library.FontColor;
                    TextSize = 13;
                    ZIndex = 24;
                    Parent = ListInner;
                });
                Library:Create('UICorner', {CornerRadius = UDim.new(0, 4), Parent = Action});
                local Stroke = Library:Create('UIStroke', {
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
                    Color = Library.OutlineColor;
                    Thickness = 1;
                    Parent = Action;
                });
                Library:AddToRegistry(Stroke, {Color = 'OutlineColor'});
                Library:AddToRegistry(Action, {BackgroundColor3 = 'MainColor', TextColor3 = 'FontColor'});
                Library:OnHighlight(Action, Action, {BackgroundColor3 = 'AccentColorDark', TextColor3 = 'AccentColor'}, {BackgroundColor3 = 'MainColor', TextColor3 = 'FontColor'});
                Library:OnHighlight(Action, Stroke, {Color = 'AccentColor'}, {Color = 'OutlineColor'});
                Library:GiveSignal(Action.MouseButton1Click:Connect(function()
                    if Index == 1 then Dropdown:AddAll(); else Dropdown:RemoveAll(); end;
                    Library:AttemptSave();
                end));
            end;
        end;

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};

                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                    BorderColor3 = 'OutlineColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    Library:Tween(ButtonLabel, {TextColor3 = Selected and Library.AccentColor or Library.FontColor});
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                        if Input.UserInputType == Enum.UserInputType.Touch then
                            local Start, Moved = Input.Position, false;
                            while Input.UserInputState ~= Enum.UserInputState.End and Input.UserInputState ~= Enum.UserInputState.Cancel do
                                if (Input.Position - Start).Magnitude > 10 then Moved = true; end;
                                Input.Changed:Wait();
                            end;
                            if Moved or (Input.Position - Start).Magnitude > 10 or Input.UserInputState == Enum.UserInputState.Cancel or not ButtonLabel.Parent then return; end;
                        end;
                        local Try = not Selected;

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;

                            Table:UpdateButton();
                            Dropdown:Display();

                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                            Library:AttemptSave();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y + (Dropdown.Multi and 30 or 0));
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:Refresh(Values)
            self:SetValues(Values or {});
            local Value = self.Value;
            if not self.Multi and not table.find(self.Values, Value) then Value = nil; end;
            self:SetValue(Value);
            return self;
        end;

        function Dropdown:Add(Value)
            if not table.find(self.Values, Value) then
                local Values = {};
                for Index, Item in ipairs(self.Values) do Values[Index] = Item; end;
                table.insert(Values, Value);
                self:SetValues(Values);
            end;
            return self;
        end;

        function Dropdown:AddAutoRefresh()
            self.SpecialType = 'Player';
            self:SetValues(GetPlayersString());
            return self;
        end;

        function Dropdown:OpenDropdown()
            RecalculateListPosition();
            Library:SetPopupVisible(ListOuter, true);
            Library.OpenedFrames[ListOuter] = true;
            Library:Tween(DropdownArrow, {Rotation = 180});
        end;

        function Dropdown:CloseDropdown()
            Library:SetPopupVisible(ListOuter, false);
            Library.OpenedFrames[ListOuter] = nil;
            Library:Tween(DropdownArrow, {Rotation = 0});
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};

                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();
            Dropdown:Display();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        function Dropdown:AddAll()
            if self.Multi then
                local Values = {};
                for _, Value in ipairs(self.Values) do Values[Value] = true; end;
                self:SetValue(Values);
            end;
            return self;
        end;

        function Dropdown:RemoveAll()
            if self.Multi then self:SetValue({}); end;
            return self;
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Dropdown.AddonGear and Library:IsMouseOverFrame(Dropdown.AddonGear) then return; end;
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;
        Library:RegisterConfig(Idx, Dropdown, Info);

        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };
        
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    function Funcs:AddColorPicker(Idx, Info)
        Info = Info or {};
        return self:AddLabel(Library:FormatTitle(Info.Text or Idx, Info.Tag)):AddColorPicker(Idx, Info);
    end;

    function Funcs:AddParagraph(Idx, Info)
        Info = Info or {};
        local Groupbox = self;
        local Title = self:AddLabel(Library:FormatTitle(Info.Title or Info.Text or Idx, Info.Tag));
        local Content = self:AddLabel(Info.Content or 'Drag labels to position ESP', true);
        local Height = math.clamp(tonumber(Info.Height) or 220, 120, 500);
        local Preview = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(1, -4, 0, Height);
            ClipsDescendants = true;
            ZIndex = 5;
            Parent = self.Container;
        });
        Library:AddToRegistry(Preview, {BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor'});
        local Viewport = Library:Create('ViewportFrame', {
            BackgroundTransparency = 1;
            Size = UDim2.fromScale(1, 1);
            Ambient = Color3.fromRGB(190, 190, 190);
            LightColor = Color3.new(1, 1, 1);
            LightDirection = Vector3.new(-1, -1, -1);
            ZIndex = 6;
            Parent = Preview;
        });
        local Camera = Library:Create('Camera', {FieldOfView = 40, CFrame = CFrame.new(Vector3.new(0, 1, 9), Vector3.new(0, 1, 0)), Parent = Viewport});
        Viewport.CurrentCamera = Camera;
        local Model = Library:Create('Model', {Name = 'ESP Preview', Parent = Viewport});
        for _, Part in ipairs({{'Head', 0, 2.5, 1.2, 1.2}, {'Torso', 0, 1, 1.8, 1.8}, {'LeftArm', -1.35, 1, 0.7, 1.8}, {'RightArm', 1.35, 1, 0.7, 1.8}, {'LeftLeg', -0.48, -0.9, 0.8, 1.8}, {'RightLeg', 0.48, -0.9, 0.8, 1.8}}) do
            Library:Create('Part', {Name = Part[1], Anchored = true, CanCollide = false, Size = Vector3.new(Part[4], Part[5], 0.8), Position = Vector3.new(Part[2], Part[3], 0), Color = Info.CharacterColor or Color3.fromRGB(170, 180, 195), Material = Enum.Material.SmoothPlastic, Parent = Model});
        end;
        local Object = {Type = 'Paragraph', Value = {}, TextLabel = Title.TextLabel};
        local Labels, Buttons = {}, {};
        local Definitions = Info.Items or {Name = {Text = 'Player Name'}, Health = {Text = '100 HP'}, Distance = {Text = '25 m'}, Weapon = {Text = 'Weapon'}};
        local Positions = {Name = Vector2.new(0.5, 0.12), Health = Vector2.new(0.18, 0.5), Distance = Vector2.new(0.5, 0.88), Weapon = Vector2.new(0.8, 0.5)};
        local Names = {};
        for Name in pairs(Definitions) do table.insert(Names, Name); end;
        table.sort(Names);
        local function CopyLayout(Layout)
            local Result = {};
            for Name, Entry in pairs(Layout) do Result[Name] = {Enabled = Entry.Enabled, Position = {X = Entry.Position.X, Y = Entry.Position.Y}}; end;
            return Result;
        end;
        function Object:GetLayout() return CopyLayout(self.Value); end;
        function Object:Refresh()
            for Name, Label in pairs(Labels) do
                local Entry = self.Value[Name];
                Label.Visible = Entry.Enabled;
                Label.Position = UDim2.fromScale(Entry.Position.X, Entry.Position.Y);
                Buttons[Name].Text = (Entry.Enabled and '[ON] ' or '[OFF] ') .. Name;
            end;
        end;
        function Object:SetValue(Layout)
            local Value = CopyLayout(self.Value);
            for Name, Entry in pairs(Layout) do
                if Value[Name] then
                    assert(type(Entry) == 'table' and type(Entry.Enabled) == 'boolean' and type(Entry.Position) == 'table', 'Invalid ESP item');
                    local X, Y = Entry.Position.X, Entry.Position.Y;
                    assert(type(X) == 'number' and X >= 0 and X <= 1 and type(Y) == 'number' and Y >= 0 and Y <= 1, 'Invalid ESP position');
                    Value[Name] = {Enabled = Entry.Enabled, Position = {X = X, Y = Y}};
                end;
            end;
            self.Value = Value;
            self:Refresh();
            Library:SafeCallback(Info.Callback, self:GetLayout());
            Library:SafeCallback(self.Changed, self:GetLayout());
        end;
        function Object:SetEnabled(Name, Enabled)
            assert(self.Value[Name], 'Unknown ESP item');
            local Layout = self:GetLayout();
            Layout[Name].Enabled = Enabled == true;
            self:SetValue(Layout);
        end;
        function Object:SetPosition(Name, Position)
            assert(self.Value[Name], 'Unknown ESP item');
            local Layout = self:GetLayout();
            Layout[Name].Position = {X = math.clamp(Position.X, 0, 1), Y = math.clamp(Position.Y, 0, 1)};
            self:SetValue(Layout);
        end;
        function Object:OnChanged(Callback) self.Changed = Callback; Callback(self:GetLayout()); end;
        function Object:SetTitle(Text) Title:SetText(Text); end;
        function Object:SetContent(Text) Content:SetText(Text); end;
        local DragInput, DragName, DragOffset;
        for _, Name in ipairs(Names) do
            local Item = Definitions[Name];
            if type(Item) == 'string' then Item = {Text = Item}; end;
            local Position = Item.Position or Positions[Name] or Vector2.new(0.5, 0.5);
            Object.Value[Name] = {Enabled = Item.Enabled ~= false, Position = {X = math.clamp(Position.X, 0, 1), Y = math.clamp(Position.Y, 0, 1)}};
            local Label = Library:Create('TextButton', {
                AnchorPoint = Vector2.new(0.5, 0.5);
                Size = UDim2.fromOffset(90, 20);
                BackgroundColor3 = Library.MainColor;
                BackgroundTransparency = 0.15;
                BorderColor3 = Library.OutlineColor;
                Text = Item.Text or Name;
                TextColor3 = Item.Color or Library.AccentColor;
                Font = Library.Font;
                TextSize = 13;
                ZIndex = 8;
                Parent = Preview;
            });
            Labels[Name] = Label;
            local Colors = {BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor'};
            if not Item.Color then Colors.TextColor3 = 'AccentColor'; end;
            Library:AddToRegistry(Label, Colors);
            Library:GiveSignal(Label.InputBegan:Connect(function(Input)
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return; end;
                DragInput, DragName = Input, Name;
                local Entry = Object.Value[Name].Position;
                DragOffset = Vector2.new(Input.Position.X - Preview.AbsolutePosition.X - Entry.X * Preview.AbsoluteSize.X, Input.Position.Y - Preview.AbsolutePosition.Y - Entry.Y * Preview.AbsoluteSize.Y);
            end));
            local Button = Library:Create('TextButton', {Size = UDim2.new(1, -4, 0, 22), BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor, TextColor3 = Library.FontColor, Text = '', TextSize = 13, Font = Library.Font, ZIndex = 5, Parent = Groupbox.Container});
            Buttons[Name] = Button;
            Library:AddToRegistry(Button, {BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor', TextColor3 = 'FontColor'});
            Library:GiveSignal(Button.MouseButton1Click:Connect(function() Object:SetEnabled(Name, not Object.Value[Name].Enabled); Library:AttemptSave(); end));
        end;
        Library:GiveSignal(InputService.InputChanged:Connect(function(Input)
            if not DragInput or not Preview.Parent then return; end;
            if Input ~= DragInput and not (DragInput.UserInputType == Enum.UserInputType.MouseButton1 and Input.UserInputType == Enum.UserInputType.MouseMovement) then return; end;
            local Size, Origin = Preview.AbsoluteSize, Preview.AbsolutePosition;
            local Label = Labels[DragName];
            local X = math.clamp((Input.Position.X - Origin.X - DragOffset.X) / math.max(1, Size.X), Label.AbsoluteSize.X / 2 / math.max(1, Size.X), 1 - Label.AbsoluteSize.X / 2 / math.max(1, Size.X));
            local Y = math.clamp((Input.Position.Y - Origin.Y - DragOffset.Y) / math.max(1, Size.Y), Label.AbsoluteSize.Y / 2 / math.max(1, Size.Y), 1 - Label.AbsoluteSize.Y / 2 / math.max(1, Size.Y));
            Object:SetPosition(DragName, Vector2.new(X, Y));
        end));
        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if Input == DragInput then DragInput, DragName = nil, nil; Library:AttemptSave(); end;
        end));
        Object:Refresh();
        Groupbox:AddBlank(5);
        Groupbox:Resize();
        Options[Idx] = Object;
        Library:RegisterConfig(Idx, Object, Info);
        return Object;
    end;

    function Funcs:AddTextbox(Idx, Info)
        Info = Info or {};
        local Settings = {};
        for Key, Value in pairs(Info) do Settings[Key] = Value; end;
        Settings.Text = Settings.Text or Idx;
        Settings.Default = tostring(Settings.Default or '');
        Settings.Finished = false;
        Settings.Callback = function(Value)
            if Settings.Live then Library:SafeCallback(Info.Callback, Value); end;
        end;
        local Input = self:AddInput(Idx, Settings);
        if not Info.Live then Input.ConfigCallback = Info.Callback; end;
        if not Info.Live then
            Input.Box.FocusLost:Connect(function(Enter)
                Library:SafeCallback(Info.Callback, Input.Value, Enter);
            end);
        end;
        return Input;
    end;

    function Funcs:AddKeybind(Idx, Info)
        Info = Info or {};
        local Settings = {};
        for Key, Value in pairs(Info) do Settings[Key] = Value; end;
        Settings.Default = Settings.Default or 'Unknown';
        if typeof(Settings.Default) == 'EnumItem' then Settings.Default = Settings.Default.Name; end;
        Settings.Text = Settings.Text or Idx;
        return self:AddLabel(Library:FormatTitle(Settings.Text, Settings.Tag)):AddKeyPicker(Idx, Settings);
    end;

    function Funcs:AddDoubleButton(Name1, Name2, Info1, Info2)
        Info1, Info2 = Info1 or {}, Info2 or {};
        return self:AddButton({Text = Info1.Text or Name1; Func = Info1.Callback or Info1.Func;}):AddButton({Text = Info2.Text or Name2; Func = Info2.Callback or Info2.Func;});
    end;

    function Library:GetAddonGroup(Object)
        if Object.AddonGroup then return Object.AddonGroup; end;
        local Groupbox = Object.ParentGroup;
        assert(Groupbox and Object.TextLabel, 'Nested controls require a heading');
        local PopupWindow = Groupbox.PopupWindow;
        if not PopupWindow then
            local Parent = Object.TextLabel;
            while Parent and Parent ~= ScreenGui do
                if Parent:IsA('GuiObject') then PopupWindow = Parent; end;
                Parent = Parent.Parent;
            end;
        end;
        local Holder = Library:Create('CanvasGroup', {
            Name = 'AddonPopup';
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.fromOffset(240, 0);
            Visible = false;
            ZIndex = 10;
            Parent = ScreenGui;
        });
        Library:AddToRegistry(Holder, {BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor'});
        local Container = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Position = UDim2.fromOffset(6, 4);
            Size = UDim2.new(1, -12, 1, -8);
            ZIndex = 11;
            Parent = Holder;
        });
        Library:GiveSignal(Container.DescendantAdded:Connect(function(Child)
            task.defer(function()
                if Child.Parent and Child:IsA('GuiObject') then Child.ZIndex = math.max(11, Child.ZIndex + 6); end;
            end);
        end));
        Library:Create('UIListLayout', {SortOrder = Enum.SortOrder.LayoutOrder, Parent = Container});
        local Group = setmetatable({Container = Container, PopupWindow = PopupWindow, ParentGroup = Groupbox, SearchTab = Groupbox.SearchTab, SearchSubTab = Groupbox.SearchSubTab, SearchWindow = Groupbox.SearchWindow}, BaseGroupbox);
        function Group:Resize()
            local Height = 8;
            for _, Child in ipairs(Container:GetChildren()) do
                if Child:IsA('GuiObject') and Child.Visible then Height = Height + Child.Size.Y.Offset; end;
            end;
            Holder.Size = UDim2.fromOffset(240, Height);
        end;
        local Gear = Library:Create('TextButton', {
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -18, 0, -2);
            Size = UDim2.fromOffset(18, 14);
            Text = '⚙';
            Font = Enum.Font.SourceSans;
            TextSize = 18;
            TextColor3 = Library.FontColor;
            ZIndex = 14;
            Parent = Object.TextLabel;
        });
        Library:AddToRegistry(Gear, {TextColor3 = 'FontColor'});
        Library.AddonPopups = Library.AddonPopups or {};
        Library.AddonPopups[Holder] = true;
        local function PositionPopup()
            if not Holder.Visible then return; end;
            local Position = Gear.AbsolutePosition;
            local Camera = workspace.CurrentCamera;
            local Viewport = Camera and Camera.ViewportSize or Vector2.new(1920, 1080);
            local X = Position.X + Gear.AbsoluteSize.X + 6;
            if X + 240 > Viewport.X then X = Position.X - 246; end;
            Holder.Position = UDim2.fromOffset(math.clamp(X, 0, math.max(0, Viewport.X - 240)), math.clamp(Position.Y, 0, math.max(0, Viewport.Y - Holder.Size.Y.Offset)));
        end;
        local function HidePopup()
            Library:SetPopupVisible(Holder, false);
            Library:Tween(Gear, {Rotation = 0});
        end;
        Library:GiveSignal(PopupWindow:GetPropertyChangedSignal('AbsolutePosition'):Connect(PositionPopup));
        Library:GiveSignal(PopupWindow:GetPropertyChangedSignal('AbsoluteSize'):Connect(PositionPopup));
        Library:GiveSignal(Gear:GetPropertyChangedSignal('AbsolutePosition'):Connect(PositionPopup));
        Library:GiveSignal(Holder:GetPropertyChangedSignal('Size'):Connect(PositionPopup));
        local Ancestor = Gear.Parent;
        while Ancestor and Ancestor ~= ScreenGui do
            if Ancestor:IsA('GuiObject') then
                local Frame = Ancestor;
                Library:GiveSignal(Frame:GetPropertyChangedSignal('Visible'):Connect(function()
                    if not Frame.Visible then HidePopup(); end;
                end));
            end;
            Ancestor = Ancestor.Parent;
        end;
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if not Holder.Visible then return; end;
            if Input.KeyCode == Enum.KeyCode.Escape then HidePopup(); return; end;
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return; end;
            if Library:IsMouseOverFrame(Holder) or Library:IsMouseOverFrame(Gear) then return; end;
            for Frame in pairs(Library.OpenedFrames) do
                if Frame.Visible and Library:IsMouseOverFrame(Frame) then return; end;
            end;
            for Frame in pairs(Library.AddonPopups) do
                if Frame.Visible and Library:IsMouseOverFrame(Frame) then return; end;
            end;
            HidePopup();
        end));
        Library:GiveSignal(Gear.MouseButton1Click:Connect(function()
            local State = Library.PopupStates[Holder];
            local Open = not (State and State.Visible);
            Library:SetPopupVisible(Holder, Open);
            Library:Tween(Gear, {Rotation = Open and 90 or 0}, 0.2);
            if not Open then
                for Frame in pairs(Library.OpenedFrames) do Frame.Visible = false; Library.OpenedFrames[Frame] = nil; end;
            end;
            Group:Resize();
            PositionPopup();
        end));
        function Group:Show()
            Library:SetPopupVisible(Holder, true);
            Library:Tween(Gear, {Rotation = 90}, 0.2);
            self:Resize();
            PositionPopup();
        end;
        Object.AddonGroup, Object.AddonGear = Group, Gear;
        return Group;
    end;

    for Name, Method in pairs(Funcs) do
        if Name:sub(1, 3) == 'Add' then
            Funcs[Name] = function(self, ...)
                local Object = Method(self, ...);
                if type(Object) == 'table' then
                    if Object ~= self and not Object.ParentGroup then Object.ParentGroup = self; end;
                    local SearchLabel = Object.TextLabel or Object.Label;
                    if Object ~= self and SearchLabel and not Object.SearchEntry then
                        local Idx, Info = ...;
                        local Text = type(Info) == 'table' and (Info.Text or Info.Title) or type(Idx) == 'table' and Idx.Text or type(Idx) == 'string' and Idx or SearchLabel.ContentText;
                        Object.SearchEntry = {Text = tostring(Text or ''), Label = SearchLabel, Group = self};
                        Library.SearchEntries = Library.SearchEntries or {};
                        table.insert(Library.SearchEntries, Object.SearchEntry);
                    end;
                    if Object.Value ~= nil and not Object.GetValue then
                        function Object:GetValue() return self.Value; end;
                    end;
                    local Previous = getmetatable(Object);
                    setmetatable(Object, {__index = function(Target, Key)
                        local Existing = Previous and Previous.__index;
                        local Value = type(Existing) == 'table' and Existing[Key] or type(Existing) == 'function' and Existing(Target, Key);
                        if Value then return Value; end;
                        if Funcs[Key] then
                            return function(_, ...)
                                local Group = Key:sub(1, 3) == 'Add' and Target.TextLabel and Library:GetAddonGroup(Target) or self;
                                return Funcs[Key](Group, ...);
                            end;
                        end;
                    end;});
                end;
                return Object;
            end;
        end;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

-- < Create other UI elements >
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });

    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });

    Library:AddToRegistry(WatermarkInner, {
        BorderColor3 = 'AccentColor';
    });

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = InnerFrame;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);



    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });

    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });

    Library:AddToRegistry(KeybindInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    });

    Library:AddToRegistry(ColorFrame, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = 'Keybinds';
        ZIndex = 104;
        Parent = KeybindInner;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    Library:SetWatermarkVisibility(true)

    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);

    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });

    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(NotifyInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 102;
        Parent = NotifyInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        ZIndex = 103;
        Parent = InnerFrame;
    });

    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -1, 0, -1);
        Size = UDim2.new(0, 3, 1, 2);
        ZIndex = 104;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(LeftColor, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 8 + 4, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        wait(Time or 5);

        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);

        wait(0.4);

        NotifyOuter:Destroy();
    end);
end;

function Library:ScrambleText(Frame, Duration)
    if not Frame then return; end;
    self.ScrambleStates = self.ScrambleStates or setmetatable({}, {__mode = 'k'});
    local Previous = self.ScrambleStates[Frame];
    for _, Entry in ipairs(Previous or {}) do
        if Entry.Label.Parent and Entry.Label.Text == Entry.Rendered then Entry.Label.Text = Entry.Source; end;
    end;
    local Characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$%&';
    local Entries = {};
    for _, Label in ipairs(Frame:GetDescendants()) do
        if Label:IsA('TextLabel') and Label.Text ~= '' then
            table.insert(Entries, {Label = Label, Source = Label.Text});
        end;
    end;
    self.ScrambleStates[Frame] = Entries;
    task.spawn(function()
        local Started = os.clock();
        repeat
            if self.ScrambleStates[Frame] ~= Entries then return; end;
            for _, Entry in ipairs(Entries) do
                local Label = Entry.Label;
                if Label.Parent then
                    if Entry.Rendered and Label.Text ~= Entry.Rendered then Entry.Source = Label.Text; end;
                    local Plain = Entry.Source:gsub('<[^>]->', '');
                    local Text = {};
                    for _, Code in utf8.codes(Plain) do
                        local Character = utf8.char(Code);
                        local Index = math.random(1, #Characters);
                        table.insert(Text, Character:match('%s') and Character or Characters:sub(Index, Index));
                    end;
                    Entry.Rendered = table.concat(Text);
                    Label.Text = Entry.Rendered;
                end;
            end;
            task.wait(0.045);
        until os.clock() - Started >= (Duration or 0.45) or not Frame.Parent or not Frame.Visible;
        if self.ScrambleStates[Frame] ~= Entries then return; end;
        for _, Entry in ipairs(Entries) do
            if Entry.Label.Parent and Entry.Label.Text == Entry.Rendered then Entry.Label.Text = Entry.Source; end;
        end;
        self.ScrambleStates[Frame] = nil;
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = {
        Tabs = {};
    };

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderSizePixel = 0;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    Library:MakeDraggable(Outer, 25);

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = Outer;
    });

    Library:AddToRegistry(Inner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'AccentColor';
    });

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0);
        Size = UDim2.new(1, -42, 0, 25);
        TextTruncate = Enum.TextTruncate.AtEnd;
        Text = Config.Title or '';
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 1;
        Parent = Inner;
    });

    local SearchButton = Library:Create('TextButton', {BackgroundTransparency = 1, Text = '', Position = UDim2.new(1, -29, 0, 1), Size = UDim2.fromOffset(24, 22), ZIndex = 8, Parent = Inner});
    local SearchRing = Library:Create('Frame', {BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(9, 9), ZIndex = 9, Parent = SearchButton});
    Library:Create('UICorner', {CornerRadius = UDim.new(1, 0), Parent = SearchRing});
    local SearchStroke = Library:Create('UIStroke', {Color = Library.FontColor, Thickness = 1.5, Parent = SearchRing});
    local SearchHandle = Library:Create('Frame', {BackgroundColor3 = Library.FontColor, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 13), Size = UDim2.fromOffset(6, 2), Rotation = 45, ZIndex = 9, Parent = SearchButton});
    Library:AddToRegistry(SearchStroke, {Color = 'FontColor'});
    Library:AddToRegistry(SearchHandle, {BackgroundColor3 = 'FontColor'});
    local SearchPopup = Library:Create('CanvasGroup', {BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.AccentColor, Size = UDim2.fromOffset(300, 270), Visible = false, ZIndex = 80, Parent = ScreenGui});
    Library:AddToRegistry(SearchPopup, {BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'AccentColor'});
    local SearchInput = Library:Create('TextBox', {BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 28), Text = '', PlaceholderText = 'Search functions...', ClearTextOnFocus = false, TextColor3 = Library.FontColor, Font = Library.Font, TextSize = 14, ZIndex = 81, Parent = SearchPopup});
    Library:AddToRegistry(SearchInput, {BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor', TextColor3 = 'FontColor'});
    local SearchResults = Library:Create('ScrollingFrame', {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -16, 1, -50), CanvasSize = UDim2.fromOffset(0, 0), ScrollBarThickness = 3, ScrollBarImageColor3 = Library.AccentColor, ScrollingDirection = Enum.ScrollingDirection.Y, Active = true, ZIndex = 81, Parent = SearchPopup});
    Library:AddToRegistry(SearchResults, {ScrollBarImageColor3 = 'AccentColor'});
    Library:Create('UIListLayout', {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = SearchResults});
    local function PositionSearch()
        if not SearchPopup.Visible then return; end;
        local Position = SearchButton.AbsolutePosition;
        SearchPopup.Position = UDim2.fromOffset(math.max(0, Position.X + SearchButton.AbsoluteSize.X - 300), Position.Y + SearchButton.AbsoluteSize.Y + 5);
    end;
    local function CloseSearch()
        SearchInput:ReleaseFocus();
        Library:SetPopupVisible(SearchPopup, false);
    end;
    local function NavigateSearch(Entry)
        CloseSearch();
        local Group = Entry.Group;
        if Group.SearchTab then Group.SearchTab:ShowTab(); end;
        if Group.SearchSubTab then Group.SearchSubTab:Show(); end;
        local Groups = {};
        while Group do table.insert(Groups, 1, Group); Group = Group.ParentGroup; end;
        for _, Parent in ipairs(Groups) do if Parent.Show and Parent.SearchSubTab ~= Parent then Parent:Show(); end; end;
        task.spawn(function()
            RunService.RenderStepped:Wait();
            local Label = Entry.Label;
            if not Label.Parent then return; end;
            local Parent = Label.Parent;
            while Parent and Parent ~= ScreenGui do
                if Parent:IsA('ScrollingFrame') then
                    local Scale = Outer.AbsoluteSize.X / math.max(1, Outer.Size.X.Offset);
                    local Y = Parent.CanvasPosition.Y + (Label.AbsolutePosition.Y - Parent.AbsolutePosition.Y) / math.max(0.01, Scale) - 30;
                    Library:Tween(Parent, {CanvasPosition = Vector2.new(Parent.CanvasPosition.X, math.max(0, Y))}, 0.2);
                    break;
                end;
                Parent = Parent.Parent;
            end;
            local Stroke = Library:Create('UIStroke', {ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Library.AccentColor, Transparency = 1, Thickness = 1.5, Parent = Label});
            Library:Tween(Stroke, {Transparency = 0}, 0.12);
            task.delay(0.8, function()
                if not Stroke.Parent then return; end;
                Library:Tween(Stroke, {Transparency = 1}, 0.2);
                task.delay(0.2, function() Stroke:Destroy(); end);
            end);
        end);
    end;
    local function RefreshSearch()
        for _, Child in ipairs(SearchResults:GetChildren()) do if Child:IsA('GuiObject') then Child:Destroy(); end; end;
        local Query = SearchInput.Text:lower();
        local Matches, Seen = {}, {};
        for _, Entry in ipairs(Library.SearchEntries or {}) do
            if Entry.Label.Parent and not Seen[Entry.Label] and Entry.Group.SearchWindow == Window and Entry.Text:lower():find(Query, 1, true) then
                Seen[Entry.Label] = true;
                table.insert(Matches, Entry);
            end;
        end;
        table.sort(Matches, function(A, B) return A.Text:lower() < B.Text:lower(); end);
        for Index, Entry in ipairs(Matches) do
            local Button = Library:Create('TextButton', {BackgroundColor3 = Library.MainColor, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 26), Text = '  ' .. Entry.Text:gsub('<[^>]->', ''), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = Library.FontColor, Font = Library.Font, TextSize = 13, LayoutOrder = Index, ZIndex = 82, Parent = SearchResults});
            Library:AddToRegistry(Button, {BackgroundColor3 = 'MainColor', TextColor3 = 'FontColor'});
            Library:OnHighlight(Button, Button, {BackgroundColor3 = 'AccentColorDark', TextColor3 = 'AccentColor'}, {BackgroundColor3 = 'MainColor', TextColor3 = 'FontColor'});
            Library:GiveSignal(Button.MouseButton1Click:Connect(function() NavigateSearch(Entry); end));
        end;
        if #Matches == 0 then Library:CreateLabel({Text = 'No functions found', TextSize = 13, Size = UDim2.new(1, 0, 0, 26), ZIndex = 82, Parent = SearchResults}); end;
        SearchResults.CanvasPosition = Vector2.new(0, 0);
        SearchResults.CanvasSize = UDim2.fromOffset(0, math.max(1, #Matches) * 29);
    end;
    Library:GiveSignal(SearchInput:GetPropertyChangedSignal('Text'):Connect(RefreshSearch));
    Library:GiveSignal(SearchButton:GetPropertyChangedSignal('AbsolutePosition'):Connect(PositionSearch));
    Library:GiveSignal(SearchButton.MouseButton1Click:Connect(function()
        local State = Library.PopupStates[SearchPopup];
        if State and State.Visible then CloseSearch(); return; end;
        RefreshSearch();
        Library:SetPopupVisible(SearchPopup, true);
        PositionSearch();
        SearchInput:CaptureFocus();
    end));
    Library:GiveSignal(Outer:GetPropertyChangedSignal('Visible'):Connect(function() if not Outer.Visible then CloseSearch(); end; end));
    Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
        if not SearchPopup.Visible then return; end;
        if Input.KeyCode == Enum.KeyCode.Escape then CloseSearch();
        elseif Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            local Point = Input.Position;
            local function Inside(Frame)
                local P, S = Frame.AbsolutePosition, Frame.AbsoluteSize;
                return Point.X >= P.X and Point.X <= P.X + S.X and Point.Y >= P.Y and Point.Y <= P.Y + S.Y;
            end;
            if not Inside(SearchPopup) and not Inside(SearchButton) then CloseSearch(); end;
        end;
    end));

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 25);
        Size = UDim2.new(1, -16, 1, -33);
        ZIndex = 1;
        Parent = Inner;
    });

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = 'BackgroundColor';
        BorderColor3 = 'OutlineColor';
    });

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    });

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8, 0, 8);
        Size = UDim2.new(1, -16, 0, 21);
        ZIndex = 1;
        Parent = MainSectionInner;
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 30);
        Size = UDim2.new(1, -16, 1, -38);
        ZIndex = 2;
        Parent = MainSectionInner;
    });
    

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    function Window:AddTab(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 1, 0);
            ZIndex = 1;
            Parent = TabArea;
        });

        Library:AddToRegistry(TabButton, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, -1);
            Text = Name;
            ZIndex = 1;
            Parent = TabButton;
        });

        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        });

        Library:AddToRegistry(Blocker, {
            BackgroundColor3 = 'MainColor';
        });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);
        end;

        function Tab:ShowTab()
            Library:ScrambleText(TabButton, 0.25);
            for _, Tab in next, Window.Tabs do
                Tab:HideTab();
            end;

            Library:Tween(Blocker, {BackgroundTransparency = 0});
            Library:Tween(TabButton, {BackgroundColor3 = Library.MainColor});
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
            Window.FocusedTab = TabFrame;
            Library:AnimateEntrance(TabFrame);
        end;

        function Tab:HideTab()
            Library:Tween(Blocker, {BackgroundTransparency = 1});
            Library:Tween(TabButton, {BackgroundColor3 = Library.BackgroundColor});
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                ZIndex = 1;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if Element:IsA('GuiObject') and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            Groupbox.SearchTab, Groupbox.SearchWindow = Tab, Window;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            Tabbox.SearchTab = Tab;
            function Tabbox:AddTab(Name)
                local Tab = {};

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });

                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = 'BackgroundColor';
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 20);
                    Size = UDim2.new(1, -4, 1, -20);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    Library:ScrambleText(Button, 0.25);
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide();
                    end;

                    Container.Visible = true;
                    Library:AnimateEntrance(Container);
                    Block.Visible = true;

                    Library:Tween(Button, {BackgroundColor3 = Library.BackgroundColor});
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;

                    Library:Tween(Button, {BackgroundColor3 = Library.MainColor});
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Tab.Container:GetChildren() do
                        if Element:IsA('GuiObject') and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end;

                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
                end;

                Button.InputBegan:Connect(function(Input)
                    if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tab.SearchTab, Tab.SearchSubTab, Tab.SearchWindow = Tabbox.SearchTab, Tab, Window;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                -- Show first tab (number is 2 cus of the UIListLayout that also sits in that instance)
                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                Tab:ShowTab();
            end;
        end);

        -- This was the first tab added, so we show it by default.
        if #TabContainer:GetChildren() == 1 then
            Tab:ShowTab();
        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local TransparencyCache = {};
    local Toggled = false;
    local Fading = false;
    local Loaded, PlayEntrance, LoadUI = false;
    local Loading, LoadingReady = false, false;

    function Library:Toggle()
        if not Loaded and not LoadingReady then
            if not Loading and LoadUI then LoadUI(); end;
            return;
        end;
        if Fading then
            return;
        end;

        local FadeTime = Loaded and Config.MenuFadeTime or 0.35;
        Fading = true;
        Toggled = (not Toggled);
        ModalElement.Modal = Toggled;
        if not Toggled and Library.AddonPopups then
            for Frame in pairs(Library.AddonPopups) do Frame.Visible = false; end;
            for Frame in pairs(Library.OpenedFrames) do Frame.Visible = false; Library.OpenedFrames[Frame] = nil; end;
        end;

        if Toggled then
            -- A bit scuffed, but if we're going from not toggled -> toggled we want to show the frame immediately so that the fade is visible.
            Outer.Visible = true;
            if not Loaded and PlayEntrance then PlayEntrance(); end;

            task.spawn(function()
                -- TODO: add cursor fade?
                local Cursor = Drawing.new('Triangle');
                Cursor.Thickness = 1;
                Cursor.Filled = true;
                Cursor.Visible = true;

                local CursorOutline = Drawing.new('Triangle');
                CursorOutline.Thickness = 1;
                CursorOutline.Filled = false;
                CursorOutline.Color = Color3.new(0, 0, 0);
                CursorOutline.Visible = true;

                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false;

                    local mPos = InputService:GetMouseLocation();

                    Cursor.Color = Library.AccentColor;

                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y);
                    Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
                    Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);

                    CursorOutline.PointA = Cursor.PointA;
                    CursorOutline.PointB = Cursor.PointB;
                    CursorOutline.PointC = Cursor.PointC;

                    RenderStepped:Wait();
                end;

                InputService.MouseIconEnabled = true;

                Cursor:Remove();
                CursorOutline:Remove();
            end);
        else
            InputService.MouseIconEnabled = true;
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};

            if Desc:IsA('ImageLabel') then
                table.insert(Properties, 'ImageTransparency');
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then
                table.insert(Properties, 'Transparency');
            end;

            local Cache = TransparencyCache[Desc];

            if (not Cache) then
                Cache = {};
                TransparencyCache[Desc] = Cache;
            end;

            for _, Prop in next, Properties do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop];
                end;

                if Cache[Prop] == 1 then
                    continue;
                end;

                if Toggled and not Loaded then Desc[Prop] = 1; end;
                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime);

        Outer.Visible = Toggled;
        if Toggled then Loaded = true; end;

        Fading = false;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))


    Window.Holder = Outer;
    local ResponsiveScale = Library:Create('UIScale', {Scale = 1, Parent = Outer});
    local PreferredScale, CameraConnection = 1;
    local function UpdateResponsive()
        local Camera = workspace.CurrentCamera;
        if not Camera then return; end;
        local CameraSize, GuiSize = Camera.ViewportSize, ScreenGui.AbsoluteSize;
        local Viewport = Vector2.new(math.min(CameraSize.X, GuiSize.X), math.min(CameraSize.Y, GuiSize.Y));
        local Width = math.max(1, Config.Size.X.Offset + Config.Size.X.Scale * Viewport.X);
        local Height = math.max(1, Config.Size.Y.Offset + Config.Size.Y.Scale * Viewport.Y);
        local Active = Library.Animations[ResponsiveScale];
        if Active and Active.Scale then Active.Scale.Tween:Cancel(); Active.Scale = nil; end;
        ResponsiveScale.Scale = math.min(PreferredScale, math.max(1, Viewport.X * 0.88 - 24) / Width, math.max(1, Viewport.Y * 0.82 - 36) / Height);
        Outer.AnchorPoint = Vector2.new(0.5, 0.5);
        Outer.Position = UDim2.fromScale(0.5, 0.5);
    end;
    function Window:SetUIScale(Value)
        PreferredScale = math.clamp(tonumber(Value) or 1, 0.6, 1.4);
        UpdateResponsive();
    end;
    local function BindCamera()
        if CameraConnection then CameraConnection:Disconnect(); end;
        local Camera = workspace.CurrentCamera;
        if Camera then
            CameraConnection = Camera:GetPropertyChangedSignal('ViewportSize'):Connect(UpdateResponsive);
            Library:GiveSignal(CameraConnection);
        end;
        UpdateResponsive();
    end;
    Library:GiveSignal(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(BindCamera));
    Library:GiveSignal(ScreenGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(UpdateResponsive));
    BindCamera();
    LoadUI = function()
        if Loading or LoadingReady then return; end;
        Loading = true;
        local Items, Assets, Seen = ScreenGui:GetDescendants(), {}, {};
        for _, Item in ipairs(Items) do
            if Item:IsA('ImageLabel') or Item:IsA('ImageButton') then
                local Asset = Item.Image;
                if Asset ~= '' and not Seen[Asset] then Seen[Asset] = true; table.insert(Assets, Asset); end;
            end;
        end;
        local Total, Completed, Failed = #Items + #Assets + 1, 0, 0;
        local Overlay = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.fromScale(1, 1);
            Active = true;
            ZIndex = 1000;
            Parent = ScreenGui;
        });
        local Card = Library:Create('CanvasGroup', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Position = UDim2.fromScale(0.5, 0.5);
            Size = UDim2.fromOffset(320, 126);
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel = 0;
            Visible = false;
            ZIndex = 1001;
            Parent = Overlay;
        });
        Library:Create('UICorner', {CornerRadius = UDim.new(0, 10), Parent = Card});
        Library:Create('UIStroke', {Color = Library.AccentColor, Transparency = 0.35, Parent = Card});
        Library:Create('UIGradient', {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180)), Parent = Card});
        Library:CreateLabel({Text = Config.Title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(18, 16), Size = UDim2.new(1, -36, 0, 24), ZIndex = 1002, Parent = Card});
        local Status = Library:CreateLabel({Text = 'Preparing UI', TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -80, 0, 20), ZIndex = 1002, Parent = Card});
        local Percent = Library:CreateLabel({Text = '0%', TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(240, 48), Size = UDim2.fromOffset(62, 20), ZIndex = 1002, Parent = Card});
        local Track = Library:Create('Frame', {BackgroundColor3 = Library.MainColor, BorderSizePixel = 0, Position = UDim2.fromOffset(18, 82), Size = UDim2.new(1, -36, 0, 8), ZIndex = 1002, Parent = Card});
        Library:Create('UICorner', {CornerRadius = UDim.new(0, 4), Parent = Track});
        local Bar = Library:Create('Frame', {BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 1003, Parent = Track});
        Library:Create('UICorner', {CornerRadius = UDim.new(0, 4), Parent = Bar});
        local function Progress(Text)
            if not Overlay.Parent then return; end;
            Status.Text = Text;
            Percent.Text = tostring(math.floor(Completed / Total * 100)) .. '%';
            Library:Tween(Bar, {Size = UDim2.fromScale(Completed / Total, 1)}, 0.12);
        end;
        Library:SetPopupVisible(Card, true);
        task.spawn(function()
            for Index, Item in ipairs(Items) do
                if not ScreenGui.Parent then return; end;
                if Item:IsA('GuiObject') and Item.Parent then local Size = Item.AbsoluteSize; end;
                Completed = Completed + 1;
                if Index % 32 == 0 or Index == #Items then Progress('Preparing UI'); RunService.RenderStepped:Wait(); end;
            end;
            Progress('Loading images');
            local Reported = {};
            local Success = pcall(function()
                game:GetService('ContentProvider'):PreloadAsync(Assets, function(Asset, Result)
                    if not Reported[Asset] then
                        Reported[Asset] = true;
                        if Result ~= Enum.AssetFetchStatus.Success then Failed = Failed + 1; end;
                        Completed = math.min(Total - 1, Completed + 1);
                        Progress('Loading images');
                    end;
                end);
            end);
            if not Success then Failed = Failed + 1; end;
            if not ScreenGui.Parent then return; end;
            RunService.RenderStepped:Wait();
            Completed = Total;
            Progress(Failed == 0 and 'UI ready' or 'UI ready — some images unavailable');
            task.wait(0.18);
            if not ScreenGui.Parent then return; end;
            Library:SetPopupVisible(Card, false);
            task.wait(0.18);
            if not ScreenGui.Parent then return; end;
            Overlay:Destroy();
            Loading, LoadingReady = false, true;
            Library:Toggle();
        end);
    end;

    PlayEntrance = function()
        local Target = ResponsiveScale.Scale;
        ResponsiveScale.Scale = Target * 0.94;
        Library:Tween(ResponsiveScale, {Scale = Target}, 0.35);
        if not Loaded then Library:ScrambleText(Window.FocusedTab, 0.45); end;
    end;
    function Window:ShowEntrance()
        if not Outer.Visible then Library:Toggle(); else PlayEntrance(); end;
    end;

    function Window:AddBuiltinSettingsTab()
        if self.SettingsTab then return self.SettingsTab; end;
        local Settings = self:AddTab('Settings');
        self.SettingsTab = Settings;
        local Menu = Settings:AddLeftGroupbox('Menu');
        local Themes = Settings:AddRightGroupbox('Themes');
        local Configs = Settings:AddLeftGroupbox('Configs');
        local Sharing = Settings:AddRightGroupbox('Import / Export');
        local function Result(Success, Reason)
            Library:Notify(Success and 'Done' or tostring(Reason), 3);
        end;
        local QuickToggle = Library:Create('TextButton', {
            Visible = InputService.TouchEnabled;
            Text = 'UI';
            Font = Library.Font;
            TextSize = 16;
            TextColor3 = Library.FontColor;
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.AccentColor;
            Position = UDim2.new(0, 12, 0.5, -24);
            Size = UDim2.fromOffset(48, 48);
            ZIndex = 100;
            Parent = ScreenGui;
        });
        Library:AddToRegistry(QuickToggle, {TextColor3 = 'FontColor', BackgroundColor3 = 'MainColor', BorderColor3 = 'AccentColor'});
        Library:GiveSignal(QuickToggle.MouseButton1Click:Connect(function() Library:Toggle(); end));
        local Dim = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BackgroundTransparency = 0.75;
            BorderSizePixel = 0;
            Size = UDim2.fromScale(1, 1);
            Visible = false;
            ZIndex = 0;
            Parent = ScreenGui;
        });
        local DimEnabled = false;
        Library:GiveSignal(Outer:GetPropertyChangedSignal('Visible'):Connect(function()
            Dim.Visible = DimEnabled and Outer.Visible;
        end));
        Menu:AddLabel('Toggle UI'):AddKeyPicker('__Settings_MenuKey', {
            Default = 'RightControl';
            Text = 'Toggle UI';
            Mode = 'Toggle';
            Modes = {'Toggle'};
            NoUI = true;
        });
        Library.ToggleKeybind = Options.__Settings_MenuKey;
        Menu:AddDropdown('__Settings_ToggleButton', {
            Text = 'Toggle button';
            Values = {'Always', 'Mobile only', 'Hidden'};
            Default = 'Mobile only';
            Callback = function(Value)
                QuickToggle.Visible = Value == 'Always' or Value == 'Mobile only' and InputService.TouchEnabled;
            end;
        });
        Menu:AddSlider('__Settings_ToggleSize', {
            Text = 'Toggle size'; Min = 36; Max = 64; Default = 48;
            Callback = function(Value) QuickToggle.Size = UDim2.fromOffset(Value, Value); end;
        });
        Menu:AddButton({Text = 'Unload', Func = function() Library:Unload(); end});
        local Presets = {
            Sakura = Color3.fromRGB(255, 153, 204);
            Violet = Color3.fromRGB(130, 82, 255);
            Rose = Color3.fromRGB(235, 99, 151);
            Blue = Color3.fromRGB(91, 163, 255);
        };
        local function SetAccent(Color)
            Library:UpdateTheme('Accent', Color);
        end;
        Themes:AddColorPicker('__Settings_Accent', {
            Text = 'Accent color'; Default = Library.AccentColor; Callback = SetAccent;
        });
        for _, Entry in ipairs({{'MainColor', 'Main color'}, {'BackgroundColor', 'Background color'}, {'FontColor', 'Text color'}, {'OutlineColor', 'Outline color'}, {'RiskColor', 'Risk color'}}) do
            local Key = Entry[1];
            Themes:AddColorPicker('__Settings_' .. Key, {
                Text = Entry[2]; Default = Library[Key];
                Callback = function(Color) Library:UpdateTheme(Key, Color); end;
            });
        end;
        Themes:AddDropdown('__Settings_Preset', {
            Text = 'Preset'; Values = {'Sakura', 'Violet', 'Rose', 'Blue'}; AllowNull = true;
            NoConfig = true;
            Callback = function(Value)
                if Presets[Value] then Options.__Settings_Accent:SetValueRGB(Presets[Value]); end;
            end;
        });
        Themes:AddToggle('__Settings_Dim', {
            Text = 'Dim'; Default = false;
            Callback = function(Value) DimEnabled = Value; Dim.Visible = Value and Outer.Visible; end;
        });
        Themes:AddToggle('__Settings_Transparent', {
            Text = 'Transparent'; Default = false;
            Callback = function(Value)
                if Value then Outer.BackgroundTransparency = 0.55;
                else Outer.BackgroundTransparency = 1 - Options.__Settings_Opacity.Value / 100; end;
            end;
        });
        Themes:AddSlider('__Settings_Scale', {
            Text = 'UI Scale'; Min = 60; Max = 140; Default = 100; Suffix = '%';
            Callback = function(Value) Window:SetUIScale(Value / 100); end;
        });
        Themes:AddDropdown('__Settings_Density', {
            Text = 'Density'; Values = {'Compact', 'Default', 'Spacious'}; Default = 'Default';
            Callback = function(Value)
                local Padding = Value == 'Compact' and 0 or Value == 'Spacious' and 16 or Config.TabPadding;
                TabListLayout.Padding = UDim.new(0, Padding);
            end;
        });
        Themes:AddDropdown('__Settings_Background', {
            Text = 'Background'; Values = {'Dark', 'Plum', 'Black'}; Default = 'Dark';
            NoConfig = true;
            Callback = function(Value)
                Options.__Settings_BackgroundColor:SetValueRGB(Value == 'Plum' and Color3.fromRGB(36, 19, 35) or Value == 'Black' and Color3.fromRGB(4, 4, 7) or Color3.fromRGB(20, 20, 20));
            end;
        });
        Themes:AddSlider('__Settings_Opacity', {
            Text = 'Background Opacity'; Min = 0; Max = 100; Default = 100; Suffix = '%';
            Callback = function(Value)
                if not Toggles.__Settings_Transparent.Value then Outer.BackgroundTransparency = 1 - Value / 100; end;
            end;
        });
        local Name = Configs:AddTextbox('__Settings_ConfigName', {Text = 'Config Name', Default = 'default', NoConfig = true});
        local List = Configs:AddDropdown('__Settings_ConfigList', {
            Text = 'Saved Configs'; Values = Library:GetConfigs(); AllowNull = true; NoConfig = true;
            Callback = function(Value) if Value then Name:SetValue(tostring(Value)); end; end;
        });
        local Code = Sharing:AddTextbox('__Settings_Code', {Text = 'Private Code', Placeholder = 'Paste WEX1 code', NoConfig = true});
        local State = Sharing:AddLabel('Current State', true);
        local function RefreshState() State:SetText(Library:GetConfigSummary()); end;
        local function RefreshConfigs(Selected)
            List:Refresh(Library:GetConfigs());
            if Selected then List:SetValue(Selected); end;
            RefreshState();
        end;
        Configs:AddButton({Text = 'Save Config', Func = function()
            local Success, Saved = Library:SaveConfig(Name.Value);
            Result(Success, Saved);
            if Success then RefreshConfigs(Saved); end;
        end});
        Configs:AddButton({Text = 'Load Selected', Func = function()
            Result(Library:LoadConfig(List.Value or Name.Value));
            RefreshState();
        end});
        Configs:AddButton({Text = 'Refresh List', Func = function() RefreshConfigs(List.Value); end});
        Configs:AddButton({Text = 'Reset Config', Func = function()
            Result(Library:SetDefaultConfig());
            RefreshState();
        end});
        Sharing:AddButton({Text = 'Export Private Code', Func = function()
            local Exported = Library:ExportConfigCode();
            Code:SetValue(Exported);
            if setclipboard then pcall(setclipboard, Exported); end;
            Library:Notify('Code exported', 3);
        end});
        Sharing:AddButton({Text = 'Import Private Code', Func = function()
            Result(Library:ImportConfigCode(Code.Value));
            RefreshState();
        end});
        Sharing:AddButton({Text = 'Refresh State', Func = RefreshState});
        return Settings;
    end;

    if Config.BuiltinSettings ~= false then Window:AddBuiltinSettingsTab(); end;
    if Config.AutoShow then task.defer(Library.Toggle); end;

    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();

    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Library:GiveSignal(Players.PlayerAdded:Connect(OnPlayerChange));
Library:GiveSignal(Players.PlayerRemoving:Connect(function()
    task.defer(OnPlayerChange);
end));

getgenv().Library = Library



return Library
