local Payload = include("./Payload.lua")
local StatusPayload = table.Copy(Payload)
StatusPayload.__index = StatusPayload
StatusPayload.super = Payload
StatusPayload.name = "StatusPayload"

local function hookAndListen(name, ...)
	gameevent.Listen(name)
	hook.Add(name, ...)
end

local connecting = {}

function StatusPayload:__call(socket)
	self.super.__call(self, socket)

	local UndecorateNick = UndecorateNick or function(...) return ... end
	_G.DevsToHide = _G.DevsToHide or {}

	function self:updateStatus()
		local players = player.GetAll()
		local list = {}

		for _, ply in next, players do
			if not ply:IsBot() and not _G.DevsToHide[ply:SteamID()] then
				list[#list + 1] = {
					isAdmin = ply:IsAdmin(),
					accountId = ply:AccountID(),
					avatar = ply.SteamCache and ply:SteamCache() and ply:SteamCache().avatarfull,
					nick = UndecorateNick(ply:Nick())
				}
			end
		end

		for _, data in next, connecting do
			if not _G.DevsToHide[data.networkid] then
				list[#list + 1] = {
					isAdmin = aowl and aowl.CheckUserGroupFromSteamID(data.networkid, "developers"),
					accountId = util.AccountIDFromSteamID and util.AccountIDFromSteamID(data.networkid),
					nick = data.name .. " (joining)"
				}
			end
		end

		local wmap = cookie.GetString("wmap", "")
		local wsName, wsId = wmap:match("(.-)|(.+)")
		local map = game.GetMap()
		local workshopMap

		if wsName and #wsName > 0 then
			workshopMap = {
				name = wsName,
				id = wsId
			}
		end

		self:write({
			hostname = GetHostName(),
			players = list,
			map = map,
			workshopMap = workshopMap,
			uptime = SysTime() / 60 / 60,
			gamemode = {
				folderName = GAMEMODE.FolderName,
				name = GAMEMODE.Name,
			}
		})
	end

	self.onConnected = self.updateStatus

	local function add(self, data)
		connecting[data.userid] = data

		timer.Simple(0, function()
			self:updateStatus()
		end)
	end

	local function remove(self, data)
		if not connecting[data.userid] then return end
		connecting[data.userid] = nil

		timer.Simple(0, function()
			self:updateStatus()
		end)
	end

	hookAndListen("player_connect", self, add)
	hookAndListen("player_spawn", self, remove)
	hookAndListen("player_disconnect", self, remove)

	return self
end

function StatusPayload:__gc()
	hook.Remove("player_connect", self)
	hook.Remove("player_spawn", self)
	hook.Remove("player_disconnect", self)
end

return setmetatable({}, StatusPayload)
