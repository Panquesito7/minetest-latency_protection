local players_position = {}

local timer = tonumber(minetest.settings:get("latency_protection.timer")) or 20
local jitter_max = tonumber(minetest.settings:get("latency_protection.jitter_max")) or 1.5
local time_max = tonumber(minetest.settings:get("latency_protection.time_max")) or 2000

local function step()
	for name, data in pairs(players_position) do
		local info = minetest.get_player_information(name)
		if not data.protection_violation and info.avg_jitter <= jitter_max then
			data.pos = minetest.get_player_by_name(name):get_pos()
		else
			data.protection_violation = false
		end
		players_position[name] = data
	end
	minetest.after(timer, step)
end

minetest.register_on_joinplayer(function(player)
	players_position[player:get_player_name()] = {pos = player:get_pos(), protection_violation = false, last_time = 0}
end)

minetest.register_on_leaveplayer(function(player)
	players_position[player:get_player_name()] = nil
end)

minetest.after(timer, step)

-- It has to be registered later for it to work.
minetest.register_on_mods_loaded(function()
	local old_is_protected = minetest.is_protected

	function minetest.is_protected(pos, name)
		local results = old_is_protected(pos, name)
		local player = minetest.get_player_by_name(name)
		if results and player then
			local data = players_position[name]
			local now = minetest.get_us_time()
			-- If is_protected is called too quickly from the previous call, the player will be teleported.
			if now - data.last_time <= time_max then
				player:set_pos(data.pos)
				data.protection_violation = true
			end
			data.last_time = now
			players_position[name] = data
		end
		return results
	end

	minetest.register_on_respawnplayer(function(player)
		players_position[player:get_player_name()].pos = player:get_pos()
		return false
	end)
end)
