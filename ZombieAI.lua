--[[
	Zombie AI Script for navigating to nearest player
	Uses Roblox's PathfindingService Library (http://wiki.roblox.com/index.php?title=Pathfinding)
	
	Author: nick_hz (May 19, 2017)
--]]

hrt = script.Parent.HumanoidRootPart
values = game.ReplicatedStorage:FindFirstChild("Values") --If the zombie isn't in its original game Zombie Zone this variable will be nil/false
damage = (values and math.min(5 + values.Wave.Value/2,10) * 1.25) or 0 --values ~= nil -> Damage dependent on wave; values == nil -> Damage = 0
humanoid = script.Parent.Humanoid
FiringRange = script.Parent.FiringRange --Bool whether the zombie is in the firing range in Zombie Zone

PathService = game:GetService("PathfindingService") --Loads PathfindingService Library

function healthExp(wave) --Calculation of zombie health dependent on wave
	return math.floor(20*(1.15^(wave-1)))+32*(wave-1)
end
--[[
for i = 1,100 do
	print("Wave " .. i .. ": " .. healthExp(i))
end
]]
if values and not FiringRange.Value then
	health = healthExp(values.Wave.Value)
	humanoid.MaxHealth = health
	humanoid.Health = health
	if values.Wave.Value >= 5 then
		humanoid.WalkSpeed = 20
	elseif values.Wave.Value >= 10 then
		humanoid.WalkSpeed = 21
	elseif values.Wave.Value >= 12 then
		humanoid.WalkSpeed = 22
	end
end

humanoid.HealthChanged:connect(function()
	pcall(function() --Health bar above zombie is resized and recolored
		script.Parent.Head.Gui.TextLabel:TweenSize(UDim2.new(humanoid.Health/humanoid.MaxHealth,0,.5,0),"Out","Quad",.2)
		script.Parent.Head.Gui.TextLabel.BackgroundColor3 = Color3.fromHSV(humanoid.Health/humanoid.MaxHealth*34/100,1,1)
	end)
end)

function addV(v,x)
	v.Value = v.Value + x
end

humanoid.Died:connect(function()
	if script.Parent:FindFirstChild("HumanoidRootPart") and values then
		addV(values.SessionZombieKills,1)
	end
	if script.Parent:FindFirstChild("Head") then
		script.Parent.Head.Died:Play()
		script.Parent.Head.Gui.TextLabel.Visible = false
		script.Parent.Head.Scream:Stop()
	end
	wait(3)
	for i = 0,1,.1 do
		for j,v in pairs(script.Parent:GetChildren()) do
			pcall(function()
				if v.Name == "Head" then
					v.Decal.Transparency = i
				end
				v.Transparency = i
			end)
		end
		wait()
	end
	script.Parent:Destroy()
end)

--[[
	translate() turns given parameter into a Vector3 or nil
	translate(Vector3.new(x,y,z)) == Vector3.new(x,y,z)
	translate(Part) == Part.Position
	translate(Zombie) == Zombie.HumanoidRootPart.Position
--]]
function translate(a)
	if typeof(a) == "Vector3" then
		return a
	elseif a:IsA("Model") then
		local f = a:FindFirstChild("HumanoidRootPart")
		if not f then
			f = a:FindFirstChild("Torso")
		end
		if not f then
			f = a.PrimaryPart
		end
		if not f then
			a = nil
		else
			a = f.Position
		end
	elseif a:IsA("Part") then
		a = a.Position
	else
		a = nil
	end
	return a
end

--returns distance in 3D space from translate(a) to translate(b)
function distance(a,b)
	if a and b and translate(a) and translate(b) then
		return (translate(a) - translate(b)).magnitude
	end
end

--[[
	findNearestPlayer() returns nearest player which:
		-has its active character in Workspace
		-"Alive" value == true (If in Zombie Zone, a player can be not "Alive", but still alive, for example when waiting in the lobby)
		-Health above 0 (=alive)
	Also checks if the zombie.Parent ~= nil
--]]
function findNearestPlayer(zombie)
	if zombie == nil then
		zombie = script.Parent
	end
	local d = math.huge
	local p
	for i,v in pairs(game.Players:GetChildren()) do
		if ((values and workspace:FindFirstChild(v.Name) and v:FindFirstChild("Alive") and v.Alive.Value) or not values) and v.Character and v.Character.Humanoid.Health > 0 and script.Parent and script.Parent.Parent then
			local n = distance(v.Character,zombie)
			if n and d and n < d then
				d = n
				p = v
			end
		end
	end
	return p
end

--noY(Vector3.new(x,y,z)) == Vector3.new(x,0,z)
function noY(v)
	return Vector3.new(v.X,0,v.Y)
end

function respawn(RandPos)
	if FiringRange.Value or not values then return end
	if values.CurrentMap.Value and humanoid.Health > 0 then
		local zs = values.CurrentMap.Value.GameStuff.ZombieSpawns:GetChildren()
		if RandPos then
			script.Parent:MoveTo(zs[math.random(#zs)].Position)
		else
			local s
			local h = math.huge
			local p = findNearestPlayer()
			for j,w in pairs(zs) do
				local d = distance(p.Character,w)
				if d < h then
					h = d
					s = w
				end
			end
			if s then
				script.Parent:MoveTo(s.Position)
			end
		end
	end
end

first = true
count = 0 --Pathfinding Fail count
nmc = 1 --NotMovingCount
lasthrtpos = nil
pathvis = false --if true, it places 1x1x1 parts at each Vector3 point of the path table to show the zombie's selected path (for testing)
pathd = nil
function walkTo(a,PYS,zombieHumanoid) --PYS = Player Y Subtraction
	if zombieHumanoid == nil then
		zombieHumanoid = humanoid
	end
	nmc = nmc + 1
	if nmc == 15 then
		lasthrtpos = noY(hrt.Position)
	end
	if nmc % 50 == 0 then
		local newpos = noY(hrt.Position)
		local dis = distance(lasthrtpos,newpos)
		if dis > 3 then
			lasthrtpos = newpos
		else
			--print("nmc")
			respawn()
		end
		--[[
			Every 50th time walkTo() is called, the distance in 2D space between the current HRT Position and the last HRT Position is calculated.
			If larger than 3: lasthrtpos = newpos; else respawn zombie
		--]]
	end
	local path = PathService:ComputeRawPathAsync(hrt.Position,translate(a)+Vector3.new(0,-PYS,0),(values and values.PathfindingDistance.Value) or 300) --http://wiki.roblox.com/index.php?title=API:Class/PathfindingService/ComputeRawPathAsync
	if path.Status == Enum.PathStatus.Success then --Pathfinding Calculation succeeded
		count = 0 --Pathfinding success: Set count to 0
		local ptable = path:GetPointCoordinates()
		local dis = distance(a,script.Parent)
		if #ptable >= 3 and dis and dis > 4 then
			local ydif = ptable[2].Y - hrt.Position.Y
			if ydif then
				if ptable[3] then
					ptable[3] = ptable[3] - Vector3.new(0,ydif,0)
				end
				pcall(function() zombieHumanoid:MoveTo(ptable[3]) end)
				if math.abs(ydif) >= 3 and ptable[4] then
					zombieHumanoid.Jump = true
					pcall(function() zombieHumanoid:MoveTo(ptable[4]) end) --zombieHumanoid:MoveTo(Position) Makes the zombie walk to Position
				end
			end
			local hit = workspace:FindPartOnRayWithIgnoreList(Ray.new(hrt.CFrame.p,((hrt.CFrame * CFrame.new(0,0,-3)).p - hrt.CFrame.p).unit*3),{script.Parent,pathd}) --https://gyazo.com/5aea567040768a9bf5d82040bc7490ab
			if hit then
				zombieHumanoid.Jump = true
				wait(.2)
			end
			if pathvis.Value then --PATH VISUALIZATION
				if pathd then
					pathd:Destroy()
				end
				pathd = Instance.new("Model",workspace)
				for i,v in pairs(ptable) do
					local part = Instance.new("Part",pathd)
					part.Name = "Path"
					part.Anchored = true
					part.Size = Vector3.new(1,1,1)
					part.CFrame = CFrame.new(v)
					part.CanCollide = false
				end
			end
		else --is distance is less than 4 studs, move directly to target (no pathfinding)
			zombieHumanoid:MoveTo(translate(a))
			if translate(a).Y >= hrt.Position.Y + 1 then
				zombieHumanoid.Jump = true
				wait(.2)
			end
		end
		if dis and dis < 6 and not script.Parent.Head.Scream.Playing then --If zombie is near player, the zombie scream sound is played
			script.Parent.Head.Scream:Play()
		end
	else
		if first then
			respawn(true)
			return
		end
		--No pathfinding success, move directly towards target
		pcall(function() zombieHumanoid:MoveTo(translate(a)) end)
		count = count + 1 --pathfinding fail: count++
		if count >= 50 then
			respawn() --too many fails in a row -> respawn
			count = 0
		end
		--print("non-success")
	end
	first = false
end

--returns random child of given parameter
function getRandomChild(par)
	local ch = par:GetChildren()
	return ch[math.random(#ch)]
end

--if all (mesh)parts of zombie == nil then self destruct
function checkDes(zombie)
	if zombie == nil then
		zombie = script.Parent
	end
	local des = true
	for i,v in pairs(zombie:GetChildren()) do
		if v:IsA("MeshPart") or v:IsA("Part") then
			des = false
		end
	end
	return des
end

while true do --endless loop until zombie is destroyed
	if not FiringRange.Value then
		local p = findNearestPlayer()
		if p and p.Character and humanoid.Health > 0 then 
			walkTo(p.Character,3)
			if p.Character then
				for i,v in pairs(p.Character:GetChildren()) do
					local dis = distance(v,script.Parent)
					if script.Parent and v:IsA("Part") and dis and dis < 5 and humanoid.Health > 0 then --If any body part of the player is near enough, take damage
						p.Character.Humanoid:TakeDamage(damage)
						break
					end
				end
			end
		end
	else
		--Firing range zombie AI script (For Zombie Zone)
		wait(math.random(0,4))
		local tars = getRandomChild(workspace.ZombieSpawns)
		while distance(tars,hrt) > 6 do
			walkTo(tars,0)
			if checkDes() then script.Parent:Destroy() break end
			wait(.33)
		end
	end
	if checkDes() then pcall(function() script.Parent:Destroy() end) break end
	wait(.33)
end

--[[
	MASTER SCRIPT EXAMPLE
	Info: Roblox works with "Models", which are basically lua dictionaries with roblox objects inside
	https://gyazo.com/5f7362be9cbeecc1e66b0f8aeb53421e --Example for a model in which all zombies would be. An identical lua dictionary would look like this:
	workspace = {
		Model = {
			Zombie = {
				Head = ...,
				HumanoidRootPart = ...,
				Humanoid = ...,
			},
			Zombie = {
				Head = ...,
				HumanoidRootPart = ...,
				Humanoid = ...,
			},
			Zombie = {
				Head = ...,
				HumanoidRootPart = ...,
				Humanoid = ...,
			}
		},
		...
	}
	workspace.ZombieModel.Zombie will give you "Zombie" from "ZombieModel"

VVV   Uncomment below to view lua colors   VVV


ZombieModel = workspace.ZombieModel --Zombies Model, where all zombies are in
ZombieClone = ZombieModel.Zombie:Clone() --clones a zombie out of Zombie model, which can be used to spawn new clones once the zombie dies
while true do --endless loop
	for i,Zombie in pairs(ZombieModel:GetChildren()) do
		coroutine.wrap(function()
			local ZombieHumanoid = Zombie.Humanoid
			local ZombieHRT = Zombie.HumanoidRootPart
			local function ZombieRespawn(RandPos)
				Zombie:Destroy() --Destroy to-be-respawned zombie
				local NewZombie = ZombieClone:Clone() --re-clone ZombieClone
				NewZombie:MoveTo(Vector3.new(math.random(-50,50),50,math.random(-50,50))) --Move new zombie to random spawn point
			end
			
			if not Zombie.FiringRange.Value then
				local p = findNearestPlayer(Zombie)
				if p and p.Character and humanoid.Health > 0 then 
					walkTo(p.Character,3,ZombieHumanoid) --Now the current zombie in the for loop has been ordered to move to the nearest player to this specific zombie
					if p.Character then
						for i,v in pairs(p.Character:GetChildren()) do
							local dis = distance(v,script.Parent)
							if script.Parent and v:IsA("Part") and dis and dis < 5 and ZombieHumanoid.Health > 0 then --If any body part of the player is near enough, take damage and discontinue loop
								p.Character.Humanoid:TakeDamage(damage)
								break
							end
						end
					end
				end
			else
				--Firing range zombie AI script (For Zombie Zone)
				wait(math.random(0,4))
				local tars = getRandomChild(workspace.ZombieSpawns)
				while distance(tars,ZombieHRT) > 6 do
					walkTo(tars,0)
					if checkDes(Zombie) then break end
					wait(.33)
				end
			end
			if checkDes(Zombie) or ZombieHumanoid.Health <= 0 then ZombieRespawn(true) end
		end)()
	end
	
	wait(.33)
end
--]]
