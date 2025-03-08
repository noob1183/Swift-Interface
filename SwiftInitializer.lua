repeat task.wait() until game:IsLoaded()

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Lighting = game:GetService('Lighting')
local TweenService = game:GetService('TweenService')

local Modules = ReplicatedStorage.Modules

local Player = Players.LocalPlayer
local PlayerGui = Player:FindFirstChild('PlayerGui') or Player:WaitForChild('PlayerGui')

-- local BlackFrame = GameUI:FindFirstChild('BlackFrame') or GameUI:WaitForChild('BlackFrame') 

local Camera = workspace.CurrentCamera

local Interface_Loader = require(path.to.loader)

-- local SideEffectInfo = TweenInfo.new(.25)

local CameraLastFOV = Camera.FieldOfView

local LoadedComponents = {}

local LastFailedComponent = nil

-- GameUI.Enabled = false

-- Interface_Loader.AddInterface(GameUI)
Interface_Loader.Load()

-- local UI_Blur = Instance.new('BlurEffect')
-- UI_Blur.Parent = Lighting
-- UI_Blur.Name = 'UI_Blur'
-- UI_Blur.Enabled = true
-- UI_Blur.Size = 0

-- Interface_Loader.Shared.SwiftUI.Utils.SetCallback('UIToggleSideEffect', function(Option: boolean)
-- 	if Option then
-- 		Interface_Loader.Shared.SwiftUI.SideFuncs.CreateSound({
-- 			SoundId = 9119736978;
-- 			PlaybackSpeed = .7;
-- 		})
-- 	end

-- 	TweenService:Create(UI_Blur, SideEffectInfo, {Size = Option and 24 or 0}):Play()
-- 	TweenService:Create(Camera, SideEffectInfo, {FieldOfView = Option and CameraLastFOV / 1.2 or CameraLastFOV}):Play()
-- 	TweenService:Create(BlackFrame, SideEffectInfo, {BackgroundTransparency = Option and .5 or 1}):Play()
-- end)

for _, Component in script.Components:GetChildren() do
	if Component:IsA('ModuleScript') and not Component:GetAttribute('IsLoaded') then
		Component:GetAttributeChangedSignal('IsLoaded'):Once(function()
			if not Component:GetAttribute('IsLoaded') then return end

			if not table.find(LoadedComponents, Component) then
				table.insert(LoadedComponents, Component)
			end
		end)

		task.delay(15, function()
			if Component:GetAttribute('IsLoaded') then return end
			warn(`Component {Component.Name} taking too long too load. Exceed over 15s to load.`)
			Component:SetAttribute('Failed', true)
		end)

		task.spawn(function()
			local function LoadComponent(ComponentToLoad: ModuleScript)
				local ComponentValue = require(ComponentToLoad)
				if typeof(ComponentValue) == 'function' then
					ComponentValue()
				end
				ComponentToLoad:SetAttribute('IsLoaded', true)
			end

			local function RunLoad(GivenComponent: ModuleScript)
				local ComponentToLoad = GivenComponent or Component

				if ComponentToLoad:GetAttribute('Failed') and ComponentToLoad:GetAttribute('ErrorLevel') == 'Critical' then 
					Player:Kick(`\n\nThe game has failed to load a component. Please report this to us IMMEDIATELY because this is a critical error!\n\n \n Critical Error: {ComponentToLoad:GetAttribute('Error')} \n`)
					return
				end

				local function ProtectedLoadCall()
					local Succ, Err = pcall(LoadComponent, ComponentToLoad)
					return Succ, tostring(Err), if not Succ then ComponentToLoad else nil
				end

				local IsSucc, ErrorMsg, FailedComponent = ProtectedLoadCall()

				if not IsSucc then
					LastFailedComponent = FailedComponent
					FailedComponent:SetAttribute('Error', ErrorMsg)
					warn(`Failed to load component {Component.Name}. Retrying to load again! Error: {ErrorMsg}`)
					task.wait(3)
					warn(`Attempting to reload component {Component.Name} due to component failed to load!`)
					RunLoad(FailedComponent)
				else
					if LastFailedComponent then
						local AttributesRemoveListIfExist = {
							'Error';
							'Failed';
						}

						for _, AttributeName in AttributesRemoveListIfExist do
							if LastFailedComponent:GetAttribute(AttributeName) then
								LastFailedComponent:SetAttribute(AttributeName)
							end
						end
					end
					
					LastFailedComponent = nil
				end
			end

			RunLoad()
		end)
	end
end

  -- GameUI.Enabled = true
