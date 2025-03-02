local ReplicatedStorage = game:GetService('ReplicatedStorage')

local BlacklistedSerializeAttributes = {}

local ConfigurationsReplicatorSignal = Instance.new('RemoteEvent')
ConfigurationsReplicatorSignal.Name = 'ConfigurationsReplicatorSignal'
ConfigurationsReplicatorSignal.Parent = ReplicatedStorage

local function GetButtonBackgroundToAnimate(Button: GuiButton): GuiObject?
	local Result = nil

	local Obj = Button:FindFirstChild('BackgroundToAnimate')

	if Obj and Obj:IsA('ObjectValue') then
		Result = Obj.Value
	end

	return Result
end

local function IsDictEmpty(GivenDict: {[string]: any})
	local Counter = 0

	for _ in GivenDict do
		Counter += 1
	end

	return Counter <= 0
end

local function SerializeConfigurations(ScreenGui: ScreenGui)
	local SerializedData = {}

	for Index, Obj in ScreenGui:GetDescendants() do
		if not IsDictEmpty(Obj:GetAttributes()) then
			if not SerializedData[Index] then
				SerializedData[Index] = {}
			end
			
			SerializedData[Index].Object = Obj
			SerializedData[Index].ObjectAttributes = Obj:GetAttributes()

			if Obj:IsA('GuiButton') then
				local BackgroundToAnimate = GetButtonBackgroundToAnimate(Obj)

				if BackgroundToAnimate then
					SerializedData[Index].ObjectAnimateBackground = BackgroundToAnimate

					local BackgroundToAnimateValue = Obj:FindFirstChild('BackgroundToAnimate')

					if BackgroundToAnimateValue and BackgroundToAnimateValue:IsA('ObjectValue') then
						BackgroundToAnimateValue:Destroy()
					end
				end
			end
			
			for AttributeName in SerializedData[Index].ObjectAttributes do
				if Obj:GetAttribute(AttributeName) then
					Obj:SetAttribute(AttributeName)
				end
			end
		end
	end

	return SerializedData
end

ConfigurationsReplicatorSignal.OnServerEvent:Connect(function(Player: Player, Value: ScreenGui? | {ScreenGui}?)
	local ReplicateDatas = {}

	if typeof(Value) == 'table' then
		for _, ScreenGui in Value do
			if ScreenGui:IsA('ScreenGui') then
				for _, Data in SerializeConfigurations(Value) do
					table.insert(ReplicateDatas, Data)
				end
			end
		end
	elseif typeof(Value) == 'Instance' and Value:IsA('ScreenGui') then
		for _, Data in SerializeConfigurations(Value) do
			table.insert(ReplicateDatas, Data)
		end
	else
		warn(`Value input is not valid to replicate configurations!`)
		return
	end

	ConfigurationsReplicatorSignal:FireClient(Player, Value, ReplicateDatas)
end)
