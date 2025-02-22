export type Events = 'Activated' | 'MouseEnter' | 'MouseLeave'
export type CallbackSetTypes = 'OpenEffectInit' | 'ButtonEvent' | 'OpenEffect' | 'UIToggleSideEffect' | 'CreateNewUIEventsEffect' | 'CreateNewSideUIEventsEffect'

export type SoundDatas = {
	SoundId: number? | string?;
	Volume: number;
	PlaybackSpeed: number;
}
export type Datas = {
	AnimateDatas: {ObjectToAnimate: GuiObject? | GuiButton?, ButtonEventType: 'Activated' | 'MouseEnter' | 'MouseLeave', AnimateObjectInitialValues: {Position: UDim2, Rotation: number, Size: UDim2}};
	ButtonDatas: {AnimationType: string, AnimationIntensity: number, BorderEffect: any, BorderColor: Color3, BorderSize: number, RotateEffect: any, RotateIntensity: number, ClickSound: string, HoverSound: string}
}

local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')

local UI_Utils = {}

if not RunService:IsClient() then
	-- // This is for autocomplete purpose. If return nil raw then no autcomplete.
	
	local Result = {
		Utils = UI_Utils;
	}
	
	Result = nil
	
	warn('UI_Utils module cannot be require on server due to performance reason. Please require on client instead!')
	
	return Result
end

local Player = Players.LocalPlayer

local Spring = require(script.Packages.Spring)

local Lists_Util = {
	_Events = {
		'Activated';
		'MouseEnter';
		'MouseLeave';
	};
	
	_AnimationInfos = {
		BorderInfo = TweenInfo.new(
			.25,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			0,
			false,
			0
		);
		
		RotateInfo = TweenInfo.new(
			.25,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			0,
			false,
			0
		);
	};

	_InitialUIsDatasList = {
		Size = {};
		Position = {};
		Rotation = {};
		AnimateTypes = {}
	};

	_ButtonsCallbacksList = {
		Activated = {};
		MouseLeave = {};
		MouseEnter = {};
	};
	
	_Callbacks = {};
	_ObjectList = {};
	_HoveringButtonsList = {};
	_LoadedUIsList = {};
	_SectionObjectsList = {
		_ScreenGuisList = {};
		_SectionObjList = {};
	};
	_OpenableObjectsList = {};
	_SideFuncs = {}
}

local SoundsFolder = workspace:FindFirstChild('Sounds') or (function()
	local Folder = Instance.new('Folder')
	Folder.Parent = workspace
	Folder.Name = 'Sounds'

	return Folder
end)()

local CurrentOpenObject = nil
local CurrentOpenSection = nil

function Lists_Util._SideFuncs.GetButtonDatas(Button: GuiButton)
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
		SFX_Volume = tonumber(Button:GetAttribute('SFX_Volume'));
		SFX_Playbackspeed = tonumber(Button:GetAttribute('SFX_Playbackspeed'));
	}
end

function Lists_Util._SideFuncs.CreateSound(Datas: SoundDatas)
	if Player:GetAttribute('MuteInterfacesSFX') then return end
	
	local NewSound = Instance.new('Sound')
	NewSound.Parent = SoundsFolder
	NewSound.SoundId = tonumber(Datas.SoundId) and `rbxassetid://{Datas.SoundId}` or Datas.SoundId
	NewSound.Volume = tonumber(Datas.Volume) or 1
	NewSound.PlaybackSpeed = tonumber(Datas.PlaybackSpeed) or 1
	NewSound:Play()
	task.delay(NewSound.TimeLength + .15, NewSound.Destroy, NewSound)
end

function Lists_Util._SideFuncs.GetButtonBackgroundToAnimate(Button: GuiButton): GuiObject?
	local Result = nil
	
	local Obj = Button:FindFirstChild('BackgroundToAnimate')
	
	if Obj and Obj:IsA('ObjectValue') then
		Result = Obj.Value
	end
	
	return Result
end

function UI_Utils.SetCallback(SetType: CallbackSetTypes, Callback: (...any) -> (), Datas: {[string]: any}? | {any}?)
	if typeof(Callback) ~= 'function' then warn(`Callback expected to be a function but got {typeof(Callback)} instead!`) return end
	
	if SetType == 'ButtonEvent' then
		if typeof(Datas.Button) == 'Instance' and Datas.Button:IsA('GuiButton') then
			
			-- Yield for 3 seconds whenever button is not loaded yet to see if button load within 3 seconds then proceed...
			
			if not Lists_Util._LoadedUIsList[Datas.Button.Name]then
				print(`{Datas.Button.Name} button is not loaded yet. Attempting to wait until {Datas.Button.Name} button is loaded! ⚠️`)
				local CurrentAttempts, MaxAttempts = 0, 5

				repeat task.wait(1)
					CurrentAttempts += 1
				until Lists_Util._LoadedUIsList[Datas.Button] or CurrentAttempts >= MaxAttempts

				if Lists_Util._LoadedUIsList[Datas.Button] then
					print(`Succesfully loaded {Datas.Button.Name} button to set event callback with {tostring(CurrentAttempts)} attempt(s)! ✅`)
				end
			end

			if not Lists_Util._LoadedUIsList[Datas.Button.Name] then warn(`Failed to set {Datas.Button.Name} button event callback due to button is not load yet!`) return end
			if not Lists_Util._ButtonsCallbacksList[Datas.EventName] then warn(`Failed to set button callback due to event is not a valid event to set callback!`) return end

			if not Lists_Util._ButtonsCallbacksList[Datas.EventName][Datas.Button] then
				Lists_Util._ButtonsCallbacksList[Datas.EventName][Datas.Button] = Callback
			end
		else
			warn(`Failed to set button event callback due to button is not a valid button! -> Button: {Datas.Button}`)
		end
	elseif SetType == 'OpenEffectInit' then
		Lists_Util._Callbacks.InitOpenEffect = Callback
	elseif SetType == 'OpenEffect' then
		Lists_Util._Callbacks.OpenEffect = Callback
	elseif SetType == 'UIToggleSideEffect' then
		Lists_Util._Callbacks.UIToggleSideEffect = Callback
	elseif SetType == 'CreateNewSideUIEventsEffect' then
		if not Lists_Util._Callbacks.UIEventsEffect then
			Lists_Util._Callbacks.SideUIEventsEffect = {}
		end

		if Lists_Util._Callbacks.UIEventsEffect and not Lists_Util._Callbacks.SideUIEventsEffect[Datas.SideEffectName] then
			Lists_Util._Callbacks.SideUIEventsEffect[Datas.SideEffectName] = Callback
		end
		
		if typeof(Datas.SideEffectInit) == 'function' then
			if not Lists_Util._Callbacks.SideEffectInits then
				Lists_Util._Callbacks.SideEffectInits = {}
			end

			if Lists_Util._Callbacks.SideEffectInits and not Lists_Util._Callbacks.SideEffectInits[Datas.SideEffectName] then
				Lists_Util._Callbacks.SideEffectInits[Datas.SideEffectName] = Datas.SideEffectInit
			end
		end
	elseif SetType == 'CreateNewUIEventsEffect' then
		if not Lists_Util._Callbacks.UIEventsEffect then
			Lists_Util._Callbacks.UIEventsEffect = {}
		end
		
		if Lists_Util._Callbacks.UIEventsEffect and not Lists_Util._Callbacks.UIEventsEffect[Datas.EffectName] then
			Lists_Util._Callbacks.UIEventsEffect[Datas.EffectName] = Callback
		end
		
		if typeof(Datas.EffectInit) == 'function' then
			if not Lists_Util._Callbacks.EffectInits then
				Lists_Util._Callbacks.EffectInits = {}
			end
			
			if Lists_Util._Callbacks.EffectInits and not Lists_Util._Callbacks.EffectInits[Datas.EffectName] then
				Lists_Util._Callbacks.EffectInits[Datas.EffectName] = Datas.EffectInit
			end
		end
	end
end

function UI_Utils.SetupUIObject(Obj: GuiObject)
	for Key: string in Lists_Util._InitialUIsDatasList do
		if Key == 'AnimateTypes' then continue end
		if typeof(Lists_Util._InitialUIsDatasList[Key]) == 'table' and not Lists_Util._InitialUIsDatasList[Key][Obj] then
			Lists_Util._InitialUIsDatasList[Key][Obj] = Obj[Key]
		end
	end
	
	if Obj:GetAttribute('Openable') == true then
		if Lists_Util._Callbacks.InitOpenEffect then
			Lists_Util._Callbacks.InitOpenEffect(Obj)
		else
			local GivenObjInitialPosition = Lists_Util._InitialUIsDatasList.Position[Obj]
			Obj.Visible = false
			Obj.Position = UDim2.fromScale(GivenObjInitialPosition.X.Scale, GivenObjInitialPosition.Y.Scale + .12)
		end
		
		if not table.find(Lists_Util._OpenableObjectsList, Obj) then
			table.insert(Lists_Util._OpenableObjectsList, Obj)
		end
	end
	
	Obj.Visible = if typeof(Obj:GetAttribute('InitVisibility')) == 'boolean' then Obj:GetAttribute('InitVisibility') else Obj.Visible
	
	if not Lists_Util._LoadedUIsList[Obj.Name] and not Obj:IsA('GuiButton') then
		Obj.Destroying:Once(function()
			if table.find(Lists_Util._OpenableObjectsList, Obj) then
				table.remove(Lists_Util._OpenableObjectsList, Obj)
			end
			Lists_Util._LoadedUIsList[Obj.Name] = Lists_Util._LoadedUIsList[Obj.Name] and nil
		end)
		
		Lists_Util._LoadedUIsList[Obj.Name] = Obj
	end
end

function UI_Utils.SetupButtonAnimation(Button: GuiButton)
	local BackgroundToAnimate = Lists_Util._SideFuncs.GetButtonBackgroundToAnimate(Button)
	
	if BackgroundToAnimate then
		for Key: string in Lists_Util._InitialUIsDatasList do
			if Key == 'AnimateTypes' then continue end
			
			if typeof(Lists_Util._InitialUIsDatasList[Key]) == 'table' and not Lists_Util._InitialUIsDatasList[Key][Button] then
				Lists_Util._InitialUIsDatasList[Key][Button] = Button[Key]
			end
		end
	end
	
	if not Lists_Util._InitialUIsDatasList.AnimateTypes[Button] then
		Lists_Util._InitialUIsDatasList.AnimateTypes[Button] = Button:GetAttribute('AnimationType')
	end
	
	if not Lists_Util._ObjectList.Borders then
		Lists_Util._ObjectList.Borders = {}
	end
	
	local AnimationsFuncList = {
		In = function(DatasToAnimate: Datas)
			local AnimateObject = DatasToAnimate.AnimateDatas.ObjectToAnimate
			
			local OriginalRotation = DatasToAnimate.AnimateDatas.AnimateObjectInitialValues.Rotation
			if not OriginalRotation then warn(`Failed to find orignal rotation for {Button.Name}!`) return end

			local OriginalSize = DatasToAnimate.AnimateDatas.AnimateObjectInitialValues.Size
			if not OriginalSize then warn(`Failed to find original size for {Button.Name}!!`) return end

			local HoverSize = UDim2.fromScale(math.clamp(OriginalSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.X.Scale), math.clamp(OriginalSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.Y.Scale))
			
			if DatasToAnimate.AnimateDatas.ButtonEventType == 'Activated' then
				Spring.target(AnimateObject, .5, 3, {
					Size = UDim2.fromScale(math.clamp(HoverSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.X.Scale), math.clamp(HoverSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.Y.Scale))
				})
				task.delay(.15, function()
					if not Lists_Util._HoveringButtonsList[AnimateObject] then return end
					Spring.target(AnimateObject, .35, 3.5, {
						Size = HoverSize
					})
				end)
			elseif DatasToAnimate.AnimateDatas.ButtonEventType == 'MouseEnter' then
				Lists_Util._HoveringButtonsList[AnimateObject] = true

				if not Lists_Util._ObjectList.Borders[AnimateObject] then
					Lists_Util._ObjectList.Borders[AnimateObject] = Instance.new('UIStroke')
					Lists_Util._ObjectList.Borders[AnimateObject].Parent = AnimateObject
					Lists_Util._ObjectList.Borders[AnimateObject].ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					Lists_Util._ObjectList.Borders[AnimateObject].Color = DatasToAnimate.ButtonDatas.BorderColor
					Lists_Util._ObjectList.Borders[AnimateObject].Thickness = 0
				end

				if DatasToAnimate.ButtonDatas.BorderEffect and Lists_Util._ObjectList.Borders[AnimateObject] then
					TweenService:Create(Lists_Util._ObjectList.Borders[AnimateObject], Lists_Util._AnimationInfos.BorderInfo, {Thickness = DatasToAnimate.ButtonDatas.BorderSize}):Play()
				end

				Spring.target(AnimateObject, .5, 3, {
					Size = HoverSize
				})

				if DatasToAnimate.ButtonDatas.RotateEffect then
					TweenService:Create(AnimateObject, Lists_Util._AnimationInfos.RotateInfo, {Rotation = DatasToAnimate.ButtonDatas.RotateIntensity}):Play()
				end
			elseif DatasToAnimate.AnimateDatas.ButtonEventType == 'MouseLeave' then
				Lists_Util._HoveringButtonsList[AnimateObject] = nil

				if DatasToAnimate.ButtonDatas.BorderEffect and Lists_Util._ObjectList.Borders[AnimateObject] then
					TweenService:Create(Lists_Util._ObjectList.Borders[AnimateObject], Lists_Util._AnimationInfos.BorderInfo, {Thickness = 0}):Play()
				end

				Spring.target(AnimateObject, .35, 3.5, {
					Size = OriginalSize
				})

				if DatasToAnimate.ButtonDatas.RotateEffect then
					TweenService:Create(AnimateObject, Lists_Util._AnimationInfos.RotateInfo, {Rotation = OriginalRotation}):Play()
				end
			end
		end,

		Out = function(DatasToAnimate: Datas)
			local AnimateObject = DatasToAnimate.AnimateDatas.ObjectToAnimate

			local OriginalRotation = DatasToAnimate.AnimateDatas.AnimateObjectInitialValues.Rotation
			if not OriginalRotation then warn(`Failed to find orignal rotation for {Button.Name}!`) return end

			local OriginalSize = DatasToAnimate.AnimateDatas.AnimateObjectInitialValues.Size
			if not OriginalSize then warn(`Failed to find original size for {Button.Name}!!`) return end

			local HoverSize = UDim2.fromScale(OriginalSize.X.Scale + DatasToAnimate.ButtonDatas.AnimationIntensity, OriginalSize.Y.Scale + DatasToAnimate.ButtonDatas.AnimationIntensity)

			if DatasToAnimate.AnimateDatas.ButtonEventType == 'Activated' then
				Spring.target(AnimateObject, .5, 3, {
					Size = UDim2.fromScale(math.clamp(HoverSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.X.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.X.Scale), math.clamp(HoverSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.Y.Scale - DatasToAnimate.ButtonDatas.AnimationIntensity, HoverSize.Y.Scale))
				})
				task.delay(.15, function()
					if not Lists_Util._HoveringButtonsList[AnimateObject] then return end
					Spring.target(AnimateObject, .35, 3.5, {
						Size = HoverSize
					})
				end)
			elseif DatasToAnimate.AnimateDatas.ButtonEventType == 'MouseEnter' then
				Lists_Util._HoveringButtonsList[AnimateObject] = true

				if not Lists_Util._ObjectList.Borders[AnimateObject] then
					Lists_Util._ObjectList.Borders[AnimateObject] = Instance.new('UIStroke')
					Lists_Util._ObjectList.Borders[AnimateObject].Parent = AnimateObject
					Lists_Util._ObjectList.Borders[AnimateObject].ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					Lists_Util._ObjectList.Borders[AnimateObject].Color = DatasToAnimate.ButtonDatas.BorderColor
					Lists_Util._ObjectList.Borders[AnimateObject].Thickness = 0
				end

				if DatasToAnimate.ButtonDatas.BorderEffect and Lists_Util._ObjectList.Borders[AnimateObject] then
					TweenService:Create(Lists_Util._ObjectList.Borders[AnimateObject], Lists_Util._AnimationInfos.BorderInfo, {Thickness = DatasToAnimate.ButtonDatas.BorderSize}):Play()
				end

				Spring.target(AnimateObject, .5, 3, {
					Size = HoverSize
				})

				if DatasToAnimate.ButtonDatas.RotateEffect then
					TweenService:Create(AnimateObject, Lists_Util._AnimationInfos.RotateInfo, {Rotation = DatasToAnimate.ButtonDatas.RotateIntensity}):Play()
				end
			elseif DatasToAnimate.AnimateDatas.ButtonEventType == 'MouseLeave' then
				Lists_Util._HoveringButtonsList[AnimateObject] = nil

				if DatasToAnimate.ButtonDatas.BorderEffect and Lists_Util._ObjectList.Borders[AnimateObject] then
					TweenService:Create(Lists_Util._ObjectList.Borders[AnimateObject], Lists_Util._AnimationInfos.BorderInfo, {Thickness = 0}):Play()
				end

				Spring.target(AnimateObject, .35, 3.5, {
					Size = OriginalSize
				})

				if DatasToAnimate.ButtonDatas.RotateEffect then
					TweenService:Create(AnimateObject, Lists_Util._AnimationInfos.RotateInfo, {Rotation = OriginalRotation}):Play()
				end
			end
		end,
	}
	
	if Lists_Util._Callbacks.UIEventsEffect then
		for Key, Callback in Lists_Util._Callbacks.UIEventsEffect do
			if not AnimationsFuncList[Key] then
				AnimationsFuncList[Key] = Callback
			end
		end
	end
	
	local ButtonBackground = Lists_Util._SideFuncs.GetButtonBackgroundToAnimate(Button)
	local ButtonAnimateType = Lists_Util._InitialUIsDatasList.AnimateTypes[Button] or 'In'
	local ButtonSideAnimateType = Button:GetAttribute('SideAnimationType')
	
	local AnimateObject = ButtonBackground or Button
	
	if Lists_Util._Callbacks.SideEffectInits and Lists_Util._Callbacks.SideEffectInits[ButtonSideAnimateType] then
		Lists_Util._Callbacks.SideEffectInits[ButtonSideAnimateType](AnimateObject)
	end
	
	if Lists_Util._Callbacks.EffectInits and Lists_Util._Callbacks.EffectInits[ButtonAnimateType] then
		Lists_Util._Callbacks.EffectInits[ButtonAnimateType](AnimateObject)
	end
	
	for _, EventType in Lists_Util._Events do
		Button[EventType]:Connect(function()
			local ButtonAnimateDatas = Lists_Util._SideFuncs.GetButtonDatas(Button)
			if not ButtonAnimateDatas then warn(`Failed to get {Button.Name} animate datas!!`) return end
			
			local ButtonCallbackFunc = Lists_Util._ButtonsCallbacksList[EventType][Button]
			local ButtonSideAnimateFunc = if Lists_Util._Callbacks.SideUIEventsEffect then Lists_Util._Callbacks.SideUIEventsEffect[ButtonSideAnimateType] else nil
			local ButtonAnimateFunc = AnimationsFuncList[ButtonAnimateType]
			
			local DatasToAnimate = {
				AnimateDatas = {
					ObjectToAnimate = AnimateObject;
					ButtonEventType = EventType;
					AnimateObjectInitialValues = UI_Utils.GetUIElementInitialValues(AnimateObject)
				};

				ButtonDatas = ButtonAnimateDatas
			}
			
			if typeof(ButtonSideAnimateFunc) == 'function' then
				task.spawn(ButtonSideAnimateFunc, DatasToAnimate)
			end
			
			if typeof(ButtonAnimateFunc) == 'function' then
				ButtonAnimateFunc(DatasToAnimate)
			end

			if ButtonAnimateDatas.SFX then
				if EventType == 'Activated' then
					task.spawn(Lists_Util._SideFuncs.CreateSound, {
						SoundId = ButtonAnimateDatas.ClickSound;
						Volume = ButtonAnimateDatas.SFX_Volume or .5;
						PlaybackSpeed = ButtonAnimateDatas.SFX_Playbackspeed or 1;
					})
				end

				if EventType == 'MouseEnter' then
					task.spawn(Lists_Util._SideFuncs.CreateSound, {
						SoundId = ButtonAnimateDatas.ClickSound;
						Volume = ButtonAnimateDatas.SFX_Volume or .5;
						PlaybackSpeed = ButtonAnimateDatas.SFX_Playbackspeed or 1;
					})
				end
			end

			if typeof(ButtonCallbackFunc) == 'function' then
				ButtonCallbackFunc(Button)
			end
		end)
	end
	
	Button.Destroying:Once(function()
		if table.find(Lists_Util._OpenableObjectsList, Button) then
			table.remove(Lists_Util._OpenableObjectsList, Button)
		end

		Lists_Util._LoadedUIsList[Button.Name] = Lists_Util._LoadedUIsList[Button.Name] and nil
		
		for _, Event in Lists_Util._Events do
			Lists_Util._ButtonsCallbacksList[Event][Button] = Lists_Util._ButtonsCallbacksList[Event][Button] and nil
		end
	end)
	
	Button:SetAttribute('IsLoaded', true)

	if not Lists_Util._LoadedUIsList[Button.Name] then
		Lists_Util._LoadedUIsList[Button.Name] = Button
	end
end

function UI_Utils.ToggleOpenableUI(Object: GuiObject, ToggleOption: boolean)
	if typeof(Object) ~= 'Instance' or not Object:IsA('GuiObject') or not Object:GetAttribute('Openable') then warn('Object is not a valid gui object to toggle or is not openable!') return end
	
	if Lists_Util._Callbacks.UIToggleSideEffect then
		Lists_Util._Callbacks.UIToggleSideEffect(ToggleOption)
	end
	
	if Lists_Util._Callbacks.OpenEffect then
		Lists_Util._Callbacks.OpenEffect(Object, ToggleOption)
	else
		local FrameInitialPosition = Lists_Util._InitialUIsDatasList.Position[Object]

		Object.Visible = ToggleOption

		if ToggleOption then
			Spring.target(Object, .45, 5, {
				Position = FrameInitialPosition
			})
		else
			Object.Position = UDim2.fromScale(FrameInitialPosition.X.Scale, FrameInitialPosition.Y.Scale + .12)
		end
	end
end

function UI_Utils.GetLoadedUIs(ClassFilterList: {string}?) : {GuiObject}
	local List = {}

	if ClassFilterList then
		for _, Obj in Lists_Util._LoadedUIsList do
			local FindResult = table.find(ClassFilterList, Obj.ClassName)

			if FindResult then
				table.insert(List, Obj)
			end
		end
	else
		for _, Obj in Lists_Util._LoadedUIsList do
			table.insert(List, Obj)
		end
	end

	return List
end

function UI_Utils.GetOpenableObject(ExcludeObj: GuiObject?) : {GuiObject}
	local List = {}

	for _, Obj in Lists_Util._OpenableObjectsList do
		table.insert(List, Obj)
	end

	if typeof(ExcludeObj) == 'Instance' and ExcludeObj:IsA('Frame') and ExcludeObj:GetAttribute('Openable') then
		table.remove(List, table.find(List, ExcludeObj))
	end

	return List
end

function UI_Utils.RegisterNewFrameSection(ScreenGui: ScreenGui, Name: string)
	if typeof(ScreenGui) ~= 'Instance' or not ScreenGui:IsA('ScreenGui') then warn('ScreenGui expected to be a screengui but got something else!') return end
	if typeof(Name) ~= 'string' then warn(`Name expected to be a string but got {typeof(Name)}!`) return end

	if not Lists_Util._SectionObjectsList._ScreenGuisList[Name] then
		Lists_Util._SectionObjectsList._ScreenGuisList[Name] = ScreenGui
	end

	if not Lists_Util._SectionObjectsList._SectionObjList[Name] then
		Lists_Util._SectionObjectsList._SectionObjList[Name] = {}
	end

	for _, Obj in ScreenGui:GetDescendants() do
		if Obj:IsA('GuiObject') and Obj:GetAttribute('SectionName') == Name then
			Lists_Util._SectionObjectsList._SectionObjList[Name][Obj] = Obj
		end
	end
end

function UI_Utils.ToggleSectionFrame(SectionName: string, FrameName: string, ToggleOption: boolean, CleanLastFrame: boolean?)
	if typeof(FrameName) ~= 'string' then warn(`FrameName expected to be a string but got {typeof(FrameName)} instead!`) return end
	if typeof(Lists_Util._SectionObjectsList._SectionObjList[SectionName]) ~= 'table' then warn('Section has not been registered yet or invalid section type. Please check again! -> ', Lists_Util._SectionObjectsList._SectionObjList) return end

	local FramesList = Lists_Util._SectionObjectsList._SectionObjList[SectionName]
	if not FramesList then warn(`Invalid frame list while trying to toggle section {SectionName}. Please try again!`) return end

	local SectionFrame = (function()
		local Result = nil

		local SectionScreenUI = Lists_Util._SectionObjectsList._ScreenGuisList[SectionName]
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
			if Obj:IsA('GuiObject') and Obj:GetAttribute('SectionName') == SectionName then
				Obj.Visible = Obj.Name == FrameName
			end
		end
	end

	Frame.Visible = ToggleOption
end

function UI_Utils.GetUIElement(ElementName: string, ClassName: string?): GuiObject?
	local Result = nil

	local Element: GuiObject? = Lists_Util._LoadedUIsList[ElementName]

	if ClassName then
		if Element and Element.ClassName == ClassName then
			Result = Element
		end
	else
		Result = Element
	end

	if not Result then
		warn(`Cannot find ui element name {ElementName} in list. Please check again! -> List:`, Lists_Util._LoadedUIsList)
	end

	return Result
end

function UI_Utils.GetUIElementInitialValues(Element: GuiObject?): {Position: UDim2, Rotation: number, Size: UDim2}
	local Data = {}

	for ValueName, List in Lists_Util._InitialUIsDatasList do
		Data[ValueName] = List[Element]
	end

	return Data
end

function UI_Utils.GetCurrentOpenObjects()
	return CurrentOpenObject, CurrentOpenSection
end

return {
	Utils = UI_Utils;
	SideFuncs = Lists_Util._SideFuncs;
	Packages = (function()
		local List = {}
		
		for _, Package in script.Packages:GetChildren() do
			if not Package:IsA('ModuleScript') then continue end
			
			if not List[Package.Name] then
				List[Package.Name] = require(Package)
			end
		end
		
		return List
	end)()
}
