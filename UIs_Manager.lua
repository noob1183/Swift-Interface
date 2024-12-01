export type Datas = {
	AnimateDatas: {ButtonToAnimate: GuiButton, BackgroundToAnimate: GuiObject?, ButtonEventType: string};
	ButtonDatas: {AnimationType: string, AnimationIntensity: number, BorderEffect: any, BorderColor: Color3, BorderSize: number, RotateEffect: any, RotateIntensity: number, ClickSound: string, HoverSound: string}
}

local TweenService = game:GetService('TweenService')

local Packages = script.Parent.Parent:WaitForChild('Packages')

local Spring = require(Packages:WaitForChild('Spring'))

local BorderInfo = TweenInfo.new(
	.25,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out,
	0,
	false,
	0
)
local RotateInfo = TweenInfo.new(
	.25,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out,
	0,
	false,
	0
)

local Events = {
	'Activated';
	'MouseEnter';
	'MouseLeave';
}

local InitialUIsValuesList = {
	Size = {};
	Position = {};
	Rotation = {};
	AnimateTypes = {}
}

local ButtonEventsCallback = {
	Activated = {};
	MouseLeave = {};
	MouseEnter = {};
}

local BordersList = {}
local IsHoveringList = {}
local LoadedUIsList = {}
local SectionFramesList = {}
local SectionScreenGuisList = {}
local OpenableFramesList = {}

local UIsManager = {}

local function GetButtonDatas(Button: GuiButton)
	return {
		AnimationIntensity = tonumber(Button:GetAttribute('AnimationIntensity')) or .015,
		BorderEffect = Button:GetAttribute('BorderEffect'),
		BorderSize = tonumber(Button:GetAttribute('BorderSize')) or 2,
		BorderColor = Button:GetAttribute('BorderColor') or Color3.fromRGB(255, 255, 255),
		RotateEffect = Button:GetAttribute('RotateEffect'),
		RotateIntensity = tonumber(Button:GetAttribute('RotateIntensity')) or 3,
		ClickSound = Button:GetAttribute('ClickSound') or 'rbxassetid://5852470908';
		HoverSound = Button:GetAttribute('HoverSound') or 'rbxassetid://6324790483';
		SFX = if Button:GetAttribute('SFX') ~= nil then Button:GetAttribute('SFX') else true;
	}
end

local function IsEmpty(Input: string)
	return Input:match('^%s*$') ~= nil
end

local function CreateSound(SoundID: number? | string?, Volume: number?)
	if IsEmpty(SoundID) then return end

	local NewSound = Instance.new('Sound')
	NewSound.Parent = workspace
	NewSound.Volume = Volume or 1
	NewSound.SoundId = if tonumber(SoundID) then `rbxassetid://{SoundID}` else SoundID
	NewSound:Play()
	NewSound.Ended:Once(function()
		task.wait(.15)
		NewSound:Destroy()
	end)
end

local function GetButtonBackgroundToAnimate(Button: GuiButton): GuiObject?
	local Result = nil

	local BackgroundValue = Button:FindFirstChild('BackgroundToAnimate')

	if BackgroundValue and BackgroundValue:IsA('ObjectValue') then
		Result = BackgroundValue.Value
	end

	return Result
end

function UIsManager.SetupUIObject(Object: GuiObject)
	if not InitialUIsValuesList.Size[Object] then
		InitialUIsValuesList.Size[Object] = Object.Size
	end

	if not InitialUIsValuesList.Position[Object] then
		InitialUIsValuesList.Position[Object] = Object.Position
	end

	if not InitialUIsValuesList.Rotation[Object] then
		InitialUIsValuesList.Rotation[Object] = Object.Rotation
	end

	if Object:IsA('Frame') and Object:GetAttribute('Openable') == true then
		local FrameInitialPosition = InitialUIsValuesList.Position[Object]

		Object.Visible = false
		Object.Position = UDim2.fromScale(FrameInitialPosition.X.Scale, FrameInitialPosition.Y.Scale + .12)

		table.insert(OpenableFramesList, Object)
	end

	if not LoadedUIsList[Object.Name] and not Object:IsA('GuiButton') then
		LoadedUIsList[Object.Name] = Object
	end
end

function UIsManager.SetupButtonAnimation(Button: GuiButton)
	local BackgroundToAnimate = GetButtonBackgroundToAnimate(Button)

	if BackgroundToAnimate then
		InitialUIsValuesList.Size[Button] = BackgroundToAnimate.Size
		InitialUIsValuesList.Rotation[Button] = BackgroundToAnimate.Rotation
	end

	if not InitialUIsValuesList.AnimateTypes[Button] then
		InitialUIsValuesList.AnimateTypes[Button] = Button:GetAttribute('AnimationType')
	end

	local AnimationsFuncList = {
		In = function(DatasToAnimate: Datas)
			local AnimateObject = DatasToAnimate.AnimateDatas.BackgroundToAnimate or DatasToAnimate.AnimateDatas.ButtonToAnimate

			local OriginalRotation = InitialUIsValuesList.Rotation[AnimateObject]
			if not OriginalRotation then return end

			local OriginalSize = InitialUIsValuesList.Size[AnimateObject]
			if not OriginalSize then warn(`Failed to find original size for {Button.Name}!!`) return end

			local HoverSize = UDim2.fromScale(math.clamp(OriginalSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.X.Scale), math.clamp(OriginalSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.Y.Scale))

			if DatasToAnimate.AnimateDatas.ButtonEventType == 'Activated' then
				Spring.target(AnimateObject, .5, 3, {
					Size = UDim2.fromScale(math.clamp(HoverSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.X.Scale), math.clamp(HoverSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.Y.Scale))
				})
				task.delay(.15, function()
					if not IsHoveringList[AnimateObject] then return end
					Spring.target(AnimateObject, .35, 3.5, {
						Size = HoverSize
					})
				end)
			elseif DatasToAnimate.AnimateDatas.ButtonEventType == 'MouseEnter' then
				IsHoveringList[AnimateObject] = true

				if not BordersList[AnimateObject] then
					BordersList[AnimateObject] = Instance.new('UIStroke')
					BordersList[AnimateObject].Parent = AnimateObject
					BordersList[AnimateObject].ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					BordersList[AnimateObject].Color = DatasToAnimate.ButtonDatas.BorderColor
					BordersList[AnimateObject].Thickness = 0
				end

				if DatasToAnimate.ButtonDatas.BorderEffect and BordersList[AnimateObject] then
					TweenService:Create(BordersList[AnimateObject], BorderInfo, {Thickness = DatasToAnimate.ButtonDatas.BorderSize}):Play()
				end

				Spring.target(AnimateObject, .5, 3, {
					Size = HoverSize
				})

				if DatasToAnimate.ButtonDatas.RotateEffect then
					TweenService:Create(AnimateObject, RotateInfo, {Rotation = DatasToAnimate.ButtonDatas.RotateIntensity}):Play()
				end
			elseif DatasToAnimate.AnimateDatas.ButtonEventType == 'MouseLeave' then
				IsHoveringList[AnimateObject] = nil

				if DatasToAnimate.ButtonDatas.BorderEffect and BordersList[AnimateObject] then
					TweenService:Create(BordersList[AnimateObject], BorderInfo, {Thickness = 0}):Play()
				end

				Spring.target(AnimateObject, .35, 3.5, {
					Size = OriginalSize
				})

				if DatasToAnimate.ButtonDatas.RotateEffect then
					TweenService:Create(AnimateObject, RotateInfo, {Rotation = OriginalRotation}):Play()
				end
			end
		end,

		Out = function(DatasToAnimate: Datas)
			local AnimateObject = DatasToAnimate.AnimateDatas.BackgroundToAnimate or DatasToAnimate.AnimateDatas.ButtonToAnimate

			local OriginalRotation = InitialUIsValuesList.Rotation[AnimateObject]
			if not OriginalRotation then return end

			local OriginalSize = InitialUIsValuesList.Size[AnimateObject]
			if not OriginalSize then warn(`Failed to find original size for {Button.Name}!!`) return end

			local HoverSize = UDim2.fromScale(OriginalSize.X.Scale + DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.Y.Scale + DatasToAnimate.ButtonDatas.AnimationIntensity)

			if DatasToAnimate.AnimateDatas.ButtonEventType == 'Activated' then
				Spring.target(AnimateObject, .5, 3, {
					Size = UDim2.fromScale(math.clamp(HoverSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.X.Scale), math.clamp(HoverSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.Y.Scale))
				})
				task.delay(.15, function()
					if not IsHoveringList[AnimateObject] then return end
					Spring.target(AnimateObject, .35, 3.5, {
						Size = HoverSize
					})
				end)
			elseif DatasToAnimate.AnimateDatas.ButtonEventType == 'MouseEnter' then
				IsHoveringList[AnimateObject] = true

				if not BordersList[AnimateObject] then
					BordersList[AnimateObject] = Instance.new('UIStroke')
					BordersList[AnimateObject].Parent = AnimateObject
					BordersList[AnimateObject].ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					BordersList[AnimateObject].Color = DatasToAnimate.ButtonDatas.BorderColor
					BordersList[AnimateObject].Thickness = 0
				end

				if DatasToAnimate.ButtonDatas.BorderEffect and BordersList[AnimateObject] then
					TweenService:Create(BordersList[AnimateObject], BorderInfo, {Thickness = DatasToAnimate.ButtonDatas.BorderSize}):Play()
				end

				Spring.target(AnimateObject, .5, 3, {
					Size = HoverSize
				})

				if DatasToAnimate.ButtonDatas.RotateEffect then
					TweenService:Create(AnimateObject, RotateInfo, {Rotation = DatasToAnimate.ButtonDatas.RotateIntensity}):Play()
				end
			elseif DatasToAnimate.AnimateDatas.ButtonEventType == 'MouseLeave' then
				IsHoveringList[AnimateObject] = nil

				if DatasToAnimate.ButtonDatas.BorderEffect and BordersList[AnimateObject] then
					TweenService:Create(BordersList[AnimateObject], BorderInfo, {Thickness = 0}):Play()
				end

				Spring.target(AnimateObject, .35, 3.5, {
					Size = OriginalSize
				})

				if DatasToAnimate.ButtonDatas.RotateEffect then
					TweenService:Create(AnimateObject, RotateInfo, {Rotation = OriginalRotation}):Play()
				end
			end
		end,
	}

	for _, EventType in Events do
		Button[EventType]:Connect(function()
			local ButtonAnimateDatas = GetButtonDatas(Button)
			if not ButtonAnimateDatas then warn(`Failed to get {Button.Name} animate datas!!`) return end

			local ButtonAnimateType = InitialUIsValuesList.AnimateTypes[Button] or 'In'
			local ButtonAnimateFunc = AnimationsFuncList[ButtonAnimateType]
			local ButtonCallbackFunc = ButtonEventsCallback[EventType][Button]

			if typeof(ButtonAnimateFunc) == 'function' then

				local ButtonBackground = GetButtonBackgroundToAnimate(Button)

				ButtonAnimateFunc({
					AnimateDatas = {
						ButtonToAnimate = Button;
						BackgroundToAnimate = ButtonBackground;
						ButtonEventType = EventType;
					};

					ButtonDatas = ButtonAnimateDatas
				})
			end

			if ButtonAnimateDatas.SFX then
				if EventType == 'Activated' then
					task.spawn(CreateSound, ButtonAnimateDatas.ClickSound, .5)
				end

				if EventType == 'MouseEnter' then
					task.spawn(CreateSound, ButtonAnimateDatas.HoverSound, .5)
				end
			end

			if typeof(ButtonCallbackFunc) == 'function' then
				ButtonCallbackFunc(Button)
			end
		end)
	end

	Button:SetAttribute('IsLoaded', true)

	if not LoadedUIsList[Button.Name] then
		LoadedUIsList[Button.Name] = Button
	end
end

function UIsManager.SetButtonEventCallback(Button: GuiButton, EventName: string, Callback: (ClickedButton: GuiButton) -> ())
	if typeof(Button) == 'Instance' and Button:IsA('GuiButton') then
		--- Yield for 3 seconds whenever button is not loaded yet to see if button load within 3 seconds then proceed...
		if not LoadedUIsList[Button.Name]then
			print(`{Button.Name} button is not loaded yet. Attempting to wait until {Button.Name} button is loaded! ⚠️`)
			local CurrentAttempts, MaxAttempts = 0, 5

			repeat task.wait(1)
				CurrentAttempts += 1
			until LoadedUIsList[Button] or CurrentAttempts >= MaxAttempts

			if LoadedUIsList[Button] then
				print(`Succesfully loaded {Button.Name} button to set event callback with {tostring(CurrentAttempts)} attempt(s)! ✅`)
			end
		end

		if not LoadedUIsList[Button.Name] then warn(`Failed to set {Button.Name} button event callback due to button is not load yet!`) return end
		if not ButtonEventsCallback[EventName] then warn(`Failed to set button callback due to event is not a valid event to set callback!`) return end

		if not ButtonEventsCallback[EventName][Button] then
			ButtonEventsCallback[EventName][Button] = Callback
		end
	else
		warn(`Failed to set button event callback due to button is not a valid button! -> Button: {Button}`)
	end
end

function UIsManager.ToggleOpenableUI(Object: GuiObject, ToggleOption: boolean)
	if typeof(Object) ~= 'Instance' or not Object:IsA('GuiObject') or not Object:GetAttribute('Openable') then warn('Object is not a valid gui object to toggle or is not openable!') return end

	local FrameInitialPosition = InitialUIsValuesList.Position[Object]
	
	Object.Visible = ToggleOption

	if ToggleOption then
		Spring.target(Object, .45, 5, {
			Position = FrameInitialPosition
		})
	else
		Object.Position = UDim2.fromScale(FrameInitialPosition.X.Scale, FrameInitialPosition.Y.Scale + .12)
	end
end

function UIsManager.RegisterNewFrameSection(ScreenGui: ScreenGui, Name: string)
	if typeof(ScreenGui) ~= 'Instance' or not ScreenGui:IsA('ScreenGui') then warn('ScreenGui expected to be a screengui but got something else!') return end
	if typeof(Name) ~= 'string' then warn(`Name expected to be a string but got {typeof(Name)}!`) return end

	if not SectionScreenGuisList[Name] then
		SectionScreenGuisList[Name] = ScreenGui
	end

	if not SectionFramesList[Name] then
		SectionFramesList[Name] = {}
	end

	for _, Obj in ScreenGui:GetDescendants() do
		if Obj:IsA('GuiObject') and Obj:GetAttribute('SectionName') == Name then
			SectionFramesList[Name][Obj] = Obj
		end
	end
end

function UIsManager.ToggleSectionFrame(SectionName: string, FrameName: string, ToggleOption: boolean, CleanLastFrame: boolean?)
	if typeof(FrameName) ~= 'string' then warn(`FrameName expected to be a string but got {typeof(FrameName)} instead!`) return end
	if typeof(SectionFramesList[SectionName]) ~= 'table' then warn('Section has not been registered yet or invalid section type. Please check again! -> ', SectionFramesList) return end

	local FramesList = SectionFramesList[SectionName]
	if not FramesList then warn(`Invalid frame list while trying to toggle section {SectionName}. Please try again!`) return end

	local SectionFrame = (function()
		local Result = nil

		local SectionScreenUI = SectionScreenGuisList[SectionName]
		if not SectionScreenUI then warn('Failed to get section screen ui to get section frame to toggle!') return Result end

		for _, Obj in SectionScreenUI:GetDescendants() do
			if Obj:IsA('GuiObject') and Obj.Name == FrameName and Obj:GetAttribute('SectionName') == SectionName then
				Result = Obj
				break
			end
		end

		return Result
	end)()

	if not SectionFrame then warn('Failed to get section frame to toggle!') return end 

	local Frame = FramesList[SectionFrame]
	if not Frame then warn(`Invalid frame to toggle section frame in {SectionName} section. Please check again!`) return end

	if CleanLastFrame then
		for _, Obj in FramesList do
			if Obj:GetAttribute('SectionName') == SectionName then
				Obj.Visible = Obj.Name == FrameName
			end
		end
	end

	Frame.Visible = ToggleOption
end

function UIsManager.GetUIElement(ElementName: string, ClassName: string?): GuiObject?
	local Result = nil

	local Element: GuiObject? = LoadedUIsList[ElementName]

	if ClassName then
		if Element and Element.ClassName == ClassName then
			Result = Element
		end
	else
		Result = Element
	end

	if not Result then
		warn(`Cannot find ui element name {ElementName} in list. Please check again! -> List:`, LoadedUIsList)
	end

	return Result
end

function UIsManager.GetLoadedUIs(ClassFilterList: {string}?)
	local List = {}

	if ClassFilterList then
		for _, Obj in LoadedUIsList do
			local FindResult = table.find(ClassFilterList, Obj.ClassName)

			if FindResult then
				table.insert(List, Obj)
			end
		end
	else
		for _, Obj in LoadedUIsList do
			table.insert(List, Obj)
		end
	end

	return List
end

function UIsManager.GetOpenableFrames(ExcludeFrame: Frame?)
	local List = {}

	for _, Frame in OpenableFramesList do
		table.insert(List, Frame)
	end

	if typeof(ExcludeFrame) == 'Instance' and ExcludeFrame:IsA('Frame') and ExcludeFrame:GetAttribute('Openable') then
		table.remove(List, table.find(List, ExcludeFrame))
	end

	return List
end

function UIsManager.GetUIElementInitialValues(Element: GuiObject?) : {[string]: any}
	local Data = {}

	for ValueName, List in InitialUIsValuesList do
		Data[ValueName] = List[Element]
	end

	return Data
end

return UIsManager
