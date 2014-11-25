--@Name ArenaScript
--@Type ModuleScript
--@Parent game.ServerScriptService
--@END
--^ Going to be used for a plugin later. Most likely.

local players = {}
local kfactor = 30
local teleportService = game:GetService("TeleportService")
local ratingData = game:GetService("DataStoreService"):GetDataStore("RatingData")
local lobbyId = 181194460
local playerHasDied = false

-- Handle the PlayerAdded event to setup the players table
game.Players.PlayerAdded:connect(function(player)
	
	-- When a character has died we want to update the players table. We also want to
	-- set our global playerHasDied variable to true so we know the game has ended
	player.CharacterAdded:connect(function(character)
		character.Humanoid.Died:connect(function()
			print(player.Name .. " has died")
			players[tostring(player.userId)].Died = true
			playerHasDied = true
		end)
	end)
	
	-- Get player's rank from the datastore and set the died status in players table to false
	print("Getting player data for " .. player.Name)
	local playerData = {}
	playerData.Rating = ratingData:GetAsync(tostring(player.userId)).Rating
	playerData.Died = false
	players[tostring(player.userId)] = playerData
end)

-- Use Elo rating system to cacluate how much each player's rating should change
local calculateRatingChange = function(playerA, playerB)
	-- Get each player's rating from the players table
	local playerARating = players[tostring(playerA.userId)].Rating
	local playerBRating = players[tostring(playerB.userId)].Rating

	-- Get whether each player has died from the players table
	local playerADied = players[tostring(playerA.userId)].Died
	local playerBDied = players[tostring(playerB.userId)].Died	
	
	-- Calculate how likely each player was to win the match. Note that expectedA + expectedB = 1
	local expectedA = 1 / (1 + math.pow(10,(playerBRating - playerARating)/400))
	local expectedB = 1 - expectedA
	
	-- Calculate a score based on how well a player has performed. Note the following values:
	-- Win = 1
	-- Tie = .5
	-- Loss = 0
	-- We start at .5 (assuming a tie). Then, if a player dies that player looses .5 score and the other
	-- player gains .5 to their score.
	local scoreA = .5
	local scoreB = .5
	if playerADied then
		scoreA = scoreA - .5
		scoreB = scoreB + .5
	end	
	if playerBDied then
		scoreA = scoreA + .5
		scoreB = scoreB - .5
	end
	
	-- Calculate how much each player's rating should change based on their score, their expected chance
	-- of winning, and finally limiting by the kfactor
	local playerAChange = kfactor * (scoreA - expectedA)
	local playerBChange = kfactor * (scoreB - expectedB)
	
	return playerAChange, playerBChange
end

-- Update DataStore with player's new rating value
local adjustPlayerRating = function(player, rankingChange)
	ratingData:UpdateAsync(tostring(player.userId), function(oldValue)
		local newValue = oldValue
		newValue.Rating = newValue.Rating + rankingChange
		return newValue
	end)
end

-- Wait for two players before lowering barrier
print("Waiting for players")
while game.Players.NumPlayers < 2 do
	wait()
end
print("Done waiting for players")

-- Now players are in game remove barriers
for _, barrier in pairs(game.Workspace.Barriers:GetChildren()) do
	barrier.CanCollide = false
	barrier.Transparency = 1
end

print("Waiting for a player to die")
while not playerHasDied do
	wait()
end
print("Player has died! Time to adjust scores")

-- wait a moment before checking if both players have died to account for a tie
wait(1)

local playerA = nil
local playerB = nil
for _, player in pairs(game.Players:GetPlayers()) do
	if playerA == nil then
		playerA = player
	else
		playerB = player
	end
end

-- calculate how much each player's rating will change
local playerAchange, playerBchange = calculateRatingChange(playerA, playerB)
print("PlayerA points should change by " .. playerAchange)
print("PlayerB points should change by " .. playerBchange)

-- change each player's points and rating
adjustPlayerRating(playerA, playerAchange)
adjustPlayerRating(playerB, playerBchange)

print("Sending players back to lobby")
wait(5)

-- teleport players back to lobby
for _, player in pairs(game.Players:GetPlayers()) do
	teleportService:Teleport(lobbyId, player)
end
