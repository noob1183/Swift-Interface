local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local GuiService = game:GetService('GuiService')

local Player = Players.LocalPlayer

local ConfigurationsReplicatorSignal = ReplicatedStorage:FindFirstChild('ConfigurationsReplicatorSignal') or ReplicatedStorage:WaitForChild('ConfigurationsReplicatorSignal')

local Modules = ReplicatedStorage.Modules

local SwiftUI = require(path.to.swiftinterface)

local InitialVisibleSectionsList = {}
local InterfacesToLoad = {}

local LastOpenUI = nil

local Loader = {}

repeat task.wait() until GuiService:GetGuiInset() ~= Vector2.new()

local GuiInset = GuiService:GetGuiInset()

local function IsTableEmpty(GivenTable: {any})
	local Counter = 0

	for _ in GivenTable do
		Counter += 1
	end

	return Counter <= 0
end

local function ToggleOpenableUI(Object: GuiObject, ToggleOption: boolean?, ToggleSideEffect: boolean?)
	ToggleSideEffect = ToggleSideEffect or true

	if LastOpenUI and Object ~= LastOpenUI then
		if not ToggleOption then
			LastOpenUI = nil
		end
		ToggleSideEffect = false
	end

	if ToggleOption then
		LastOpenUI = Object
	elseif Object == LastOpenUI then
		LastOpenUI = nil
	end

	SwiftUI.Utils.ToggleOpenableUI(Object, ToggleOption, ToggleSideEffect)
end

local function SetupObject(Interface: ScreenGui, Obj: Instance)
	local LoadedList = SwiftUI.Utils.GetLoadedUIs()
	
	if Obj:GetAttribute('IsLoaded') or table.find(LoadedList, Obj) then return end
	
	if Obj:IsA('GuiObject') and not Obj:HasTag('Ignored') then
		SwiftUI.Utils.SetupUIObject(Obj)

		if Obj:GetAttribute('IgnoreUIInset') == true then
			Obj.AnchorPoint = Vector2.new(.5, 1)
			Obj.Position = UDim2.new(.5, 0, 1, 0)
			Obj.Size = UDim2.new(Obj.Size.X.Scale + (Obj.Size.X.Offset + GuiInset.X) / Interface.AbsoluteSize.X, 0, Obj.Size.Y.Scale + (Obj.Size.Y.Offset + GuiInset.Y) / Interface.AbsoluteSize.Y, 0)
		end

		if Obj:GetAttribute('SectionName') then
			local FrameSectionName = Obj:GetAttribute('SectionName')
			SwiftUI.Utils.ToggleSectionFrame(FrameSectionName, Obj.Name, table.find(InitialVisibleSectionsList, Obj.Name) ~= nil)
		end
	end
	
	if Obj:IsA('TextLabel') or Obj:IsA('TextButton') or Obj:IsA('TextBox') then
		local function GetProps(Input: string)
			local Result = {}
			
			if typeof(Input) ~= 'string' then
				warn(`Input expected to be string but got {typeof(Input)} instead when getting props from string!`)
				Result = nil
				return Result
			end

			for Value in Input:gmatch('[^,]+') do
				table.insert(Result, Value:match('^%s*(.-)%s*$'))
			end

			return Result
		end
		
		if typeof(Obj:GetAttribute('Uppercase')) == 'string' then
			local Props = GetProps(Obj:GetAttribute('Uppercase'))
			
			if Props then
				for _, Prop in Props do
					Obj[Prop] = string.upper(Obj[Prop])
					
					Obj:GetPropertyChangedSignal(Prop):Connect(function()
						Obj[Prop] = string.upper(Obj[Prop])
					end)
				end
			end
		elseif typeof(Obj:GetAttribute('Lowercase')) == 'string' then
			local Props = GetProps(Obj:GetAttribute('Uppercase'))

			if Props then
				for _, Prop in Props do
					Obj[Prop] = string.lower(Obj[Prop])

					Obj:GetPropertyChangedSignal(Prop):Connect(function()
						Obj[Prop] = string.lower(Obj[Prop])
					end)
				end
			end
		end
	end

	if Obj:IsA('GuiButton') then
		if not Obj.Active then
			Obj.Active = true
		end

		SwiftUI.Utils.SetupButtonAnimation(Obj)
	end
end

ConfigurationsReplicatorSignal.OnClientEvent:Connect(function(ReplicatedInterface: ScreenGui, ReplicateDatas: {{Object: Instance, ObjectAnimateBackground: Instance, ObjectAttributes: {[string]: any}}})
	if not ReplicateDatas or IsTableEmpty(ReplicateDatas) then
		warn(`Cannot find data(s) or data(s) is empty to replicate for {ReplicatedInterface.Name}!`)
		ReplicatedInterface:SetAttribute('ReplicatedConfigurations', true)
		return
	end

	for _, Data in ReplicateDatas do
		if typeof(Data) == 'table' and not IsTableEmpty(Data) then
			local Object = Data.Object
			local ObjectAnimateBackground = Data.ObjectAnimateBackground
			local ObjectAttributes = Data.ObjectAttributes

			if ObjectAnimateBackground then
				local NewBackgroundAnimateValue = Instance.new('ObjectValue')
				NewBackgroundAnimateValue.Parent = Object
				NewBackgroundAnimateValue.Value = ObjectAnimateBackground
				NewBackgroundAnimateValue.Name = 'BackgroundToAnimate'
			end

			for AttributeName, AttributeValue in ObjectAttributes do
				Object:SetAttribute(AttributeName, AttributeValue)
			end
		end
	end

	ReplicatedInterface:SetAttribute('ReplicatedConfigurations', true)
end)

function Loader.AddInterface(Input: ScreenGui? | {ScreenGui}?)
	if typeof(Input) == 'table' then
		for _, Obj in Input do
			if typeof(Obj) == 'Instance' and Obj:IsA('ScreenGui') then
				if not InterfacesToLoad[Obj] then
					InterfacesToLoad[Obj] = Obj
				end
			end
		end
	else
		if not InterfacesToLoad[Input] then
			InterfacesToLoad[Input] = Input
		end
	end
end

function Loader.Load()
	local Load_Start_Time = os.clock()

	print('💻 Initializing interface(s)... ⚙️')

	if IsTableEmpty(InterfacesToLoad) then
		warn(`There are no interface(s) to load. Please add an interface using AddInterface function!`)
		print(`Interfaces loaded in {os.clock() - Load_Start_Time}s! ✅`)
		return
	end

	local KickThread = task.delay(120, function()
		if IsTableEmpty(InterfacesToLoad) then return end
		Player:Kick('⚠️ The game having some issue with initializing user interface. Please try to check your internet and try again later! ⚠️')
	end)

	for _, Interface in InterfacesToLoad do
		task.spawn(function()
			if typeof(Interface) == 'Instance' and Interface:IsA('ScreenGui') then
				for _, Obj in Interface:GetDescendants() do
					SetupObject(Interface, Obj)
					
					if InterfacesToLoad[Interface] then
						InterfacesToLoad[Interface] = nil
						
						Interface.DescendantAdded:Connect(function(NewObject: GuiObject)
							SetupObject(Interface, NewObject)
							ConfigurationsReplicatorSignal:FireServer(Interface)
						end)
					end
				end
				ConfigurationsReplicatorSignal:FireServer(Interface)
			end
		end)
	end

	repeat task.wait() until IsTableEmpty(InterfacesToLoad)

	task.cancel(KickThread)

	print(`Interfaces loaded in {os.clock() - Load_Start_Time}s! ✅`)
	
	Player:SetAttribute('Interfaces_Loaded', true)
end

Loader.Shared = {
	TogglesList = {};
	ToggleOpenableUI = ToggleOpenableUI;
	SwiftUI = SwiftUI;
}

return Loader
