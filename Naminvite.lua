local addonName = ...
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "LibWho-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, false)
-- _G[addonName] = addon -- uncomment for debugging purposes

local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

local defaults = {
	profile = {
		enabled = true,
		-- keyword = L["invite"],
		keywords = {
			L["invite"],
			L["inv"],
		},
		caseSensitive = false,
		removeKeyword = L["remove"],
		checkLevel = false,
		minLevel = 1,
		maxLevel = MAX_PLAYER_LEVEL,
		retryInterval = 10,
		guildOnly = true,
		friendsAllowed = true,
		BNetWhispers = true,
		autoConvertToRaid = true,
		autoConvertThreshold = 5,
		autoConvertOnlyOverFive = true,
		limitGroupSize = false,
		groupSize = 5,
		autoJoin = true,
		minimapIcon = {}
	}
}

local MIN_RAID_LEVEL = 10
local invitesRemaining

-- local groupMembers
-- local inviteQueue = {}
inviteQueue = {}

local function PlayerIsFriend(player)
	if not player then return false end
	local _, numFriendsOnline = GetNumFriends()

	if numFriendsOnline > 0 then
		local name
		for i = 1, numFriendsOnline do
			name = GetFriendInfo(i)
			if name == player then
				return true
			end
		end
	end
	
	return false
end

local function PlayerIsInMyGuild(player)
	if not player then return false end
	for i=1, GetNumGuildMembers() do 
		local name = GetGuildRosterInfo(i)
			if name then
			name = name:gsub("-"..GetRealmName(),"")
			if name == player then 
				return true
			end
		end
	end
	
	return false
end

function MatchKeywords(text)
	if not addon.db.profile.caseSensitive then
		text = string.lower(text)
	end
	local replace = {
		"%%",
		"%(",
		"%)",
		"%.",
		"%+",
		"%-",
		"%*",
		"%[",
		"%^",
		"%?",
		"%$",
	}
	for _,v in ipairs(addon.db.profile.keywords) do
		for _, i in ipairs(replace) do
			v=v:gsub(i,"%%"..i)
		end
		if (string.find(text, "^"..v.."$")) then
			return true
		end
	end
	return false
end

local function getQueueSize()
	return table.getn(inviteQueue)
end

local function removeFromQueue(player)
	for k,v in ipairs(inviteQueue) do
		if v[1] == player then
			table.remove(inviteQueue,k)
		end
	end
end

local function BNremoveFromQueue(presenceID)
	for k,v in ipairs(inviteQueue) do
		if v[6] == presenceID then
			table.remove(inviteQueue,k)
		end
	end
end

local function isInQueue(player)
	for k,v in ipairs(inviteQueue) do
		if v[1] == player then
			return true, v[2], k
		end
	end
	return false, false, nil
end

local function BNisInQueue(presenceID)
	for k,v in ipairs(inviteQueue) do
		if v[6] == presenceID then
			return true, v[2], k
		end
	end
	return false, false, nil
end

local function addToQueue(player,toonID,presenceID)
	if not isInQueue(player) then
		-- table.insert(inviteQueue,getQueueSize()+1,{player,false,0,0,toonID,presenceID})
		table.insert(inviteQueue,{player,false,0,0,toonID,presenceID})
	end
end

local function spotInQueue(player)
	for k,v in ipairs(inviteQueue) do
		if v[1] == player then
			return k
		end
	end
end

local function BNspotInQueue(presenceID)
	for k,v in ipairs(inviteQueue) do
		if v[6] == presenceID then
			return k
		end
	end
end

local function retryInvite(player)
	for _,v in ipairs(inviteQueue) do
		if v[1] == player then
			v[4] = math.floor(GetTime())+addon.db.profile.retryInterval
			return
		end
	end
end

local function setTimeOut(player)
	for _,v in ipairs(inviteQueue) do
		if v[1] == player then
			v[3] = GetTime()+60
			return
		end
	end
end

local function clearQueue()
	inviteQueue = {}
end

local function ForceConvertToRaid()
	for i=1,GetNumGroupMembers()-1 do
		local unit = "party"..i
		local level = UnitLevel(unit)
		if level < MIN_RAID_LEVEL then
			UninviteUnit(unit)
		end
	end
	ConvertToRaid()
end

	--[[
	foo > bar: foo greater than bar 
	foo < bar: foo less than bar
	foo >= foo: greater than or equal to bar
	foo <= bar: foo less than or equal to bar
	--]]

local function CanConvertToRaid()
	if UnitLevel("player") < MIN_RAID_LEVEL then return false end
	for i=1,GetNumGroupMembers()-1 do
		local unit = "party"..i
		local level = UnitLevel(unit)
		if level > MIN_RAID_LEVEL then
			return true
		end
	end
	return false
end

local function AttemptConvertToRaid()
	local p = {}
	for i=1,GetNumGroupMembers()-1 do
		local unit = "party"..i
		local level = UnitLevel(unit)
		if level < MIN_RAID_LEVEL then
			table.insert(p,tostring("|c"..RAID_CLASS_COLORS[select(2,UnitClass(unit))].colorStr..UnitName(unit).."|r".." ("..level..")"))
		end
	end
	
	if UnitLevel("player") < MIN_RAID_LEVEL then
		table.insert(p,tostring("|c"..RAID_CLASS_COLORS[select(2,UnitClass(unit))].colorStr..UnitName("player").."|r".." ("..UnitLevel("player")..")"))
	end
	
	if table.getn(p) > 0 then
		local message = L["Invitations paused."]
		if table.getn(p) == 1 then
			message = message.. " "..string.format(L["The following player is too low level for raid: %s"],table.concat(p,", "))
		else
			message = message.. " "..string.format(L["The following players are too low level for raid: %s"],table.concat(p,", "))
		end
		local color = ChatTypeInfo["SYSTEM"]
		for i = 1, NUM_CHAT_WINDOWS do
			local chatframe = _G["ChatFrame"..i]
			for _,v in ipairs(chatframe.messageTypeList) do
				if v == "SYSTEM" then
					chatframe:AddMessage(message,color.r,color.g,color.b)
				end
			end
		end
	else
		ConvertToRaid()
	end
end

local function invFromQueue(self, elapsed)
	if not addon.db.profile.enabled then return end
	-- if getQueueSize() == 0 then return end
	local db = addon.db.profile
	local groupSize = db.groupSize
	local autoConvertThreshold = db.autoConvertThreshold

	if not db.limitGroupSize then
		if IsInRaid() then
			groupSize = 40
		else
			groupSize = 5
		end
	end
	
	if db.autoConvertOnlyOverFive then
		autoConvertThreshold = 5
	end
	
	local invitedPlayers = 0
	for _,v in ipairs(inviteQueue) do
		if v[2] and GetTime() >= v[3] then
			removeFromQueue(v[1])
		end
		
		if v[2] then
			invitedPlayers = invitedPlayers + 1
		end
	end
	
	if GetNumGroupMembers() == 0 then
		invitesRemaining = groupSize - 1 - invitedPlayers
	elseif GetNumGroupMembers() >= 2 then
		invitesRemaining = groupSize - GetNumGroupMembers() - invitedPlayers
	end
	
	addon:UpdateDisplay()
	

	
	-- if db.autoConvertToRaid and db.limitGroupSize and UnitIsGroupLeader("player") and not IsInRaid() and not HasLFGRestrictions() and (GetNumGroupMembers() + invitedPlayers >= autoConvertThreshold and groupSize > autoConvertThreshold) then
	-- if db.autoConvertToRaid and db.limitGroupSize and UnitIsGroupLeader("player") and not IsInRaid() and not HasLFGRestrictions() and (GetNumGroupMembers() + getQueueSize() >= autoConvertThreshold and groupSize > autoConvertThreshold) then
	if db.autoConvertToRaid and db.limitGroupSize and UnitIsGroupLeader("player") and not IsInRaid() and not HasLFGRestrictions() and (GetNumGroupMembers() + getQueueSize() > autoConvertThreshold and groupSize > autoConvertThreshold) then
		-- ConvertToRaid()
		-- Stop inviting until it's a raid. Check if you can convert (check for those under level 10).
		-- Send out a whisper to the unlucky sod that doesn't get an invite until the it's a raid?
		if not self.pause then
			AttemptConvertToRaid()
			self.pause = true		
		end
		-- Let the the function for GROUP_ROSTER_UPDATE determine if we can convert to a raid.
	elseif self.pause then
		self.pause = false
	end
	
	if self.pause then
		local lastAdded = getQueueSize()
		if lastAdded > 0 and lastAdded ~= self.lastAdded then
			local user = inviteQueue[lastAdded]
			if user[6] then
				local presenceID = user[6]
				
				BNSendWhisper(presenceID,string.format(L["You are #%s in the queue."],BNspotInQueue(presenceID)).." "..string.format(L["Whisper '%s' to be removed."],db.removeKeyword))
			else
				local player = user[1]
				SendChatMessage(string.format(L["You are #%s in the queue."],spotInQueue(player)).." "..string.format(L["Whisper '%s' to be removed."],db.removeKeyword), "WHISPER", nil, player)			
			end
			
			self.lastAdded = lastAdded
		end
		 
	end
	
	if not self.pause then
		for _,v in ipairs(inviteQueue) do
			--[[
			Player: v[1]
			Invited: v[2]
			Time Out: v[3]
			Retry time: v[4]
			Toon ID: v[5]
			Presence ID: v[6]
			--]]
			-- if v[2] and GetTime() >= v[3] then
				-- removeFromQueue(v[1])
			-- end
			
			if v[2] and math.floor(GetTime()) == v[4] then
				v[4] = 1
				v[2] = false
			end
			
			if not v[2] and invitesRemaining > 0 then
				if v[5] then -- BNetWhispers
					BNInviteFriend(v[5])
				else
					C_PartyInfo.InviteUnit(v[1])
				end
				v[2] = true
				
				if v[4] == 0 then
					v[3] = GetTime()+60
				end
				break
			end
			

		end
	end
end

function addon:UpdateDisplay()

end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New(addonName.."DB", defaults)

	self.db.RegisterCallback(self, "OnProfileChanged", "UpdateConfigs")
	self.db.RegisterCallback(self, "OnProfileCopied", "UpdateConfigs")
	self.db.RegisterCallback(self, "OnProfileReset", "UpdateConfigs")
	
	self:SetupOptions()
	self.OnUpdate = CreateFrame("Frame")
	self.OnUpdate.pause = false
	self.OnUpdate:SetScript("OnUpdate",invFromQueue)
	-- groupMembers = GetNumGroupMembers()
	
	if LDB then
		self.LDBObj = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
			-- type = "launcher",
			type = "data source",
			-- label = addonName,

			text = "0",
			OnClick = function(_, msg)
				if msg == "RightButton" then
					if LibStub("AceConfigDialog-3.0").OpenFrames[addonName] then
						-- PlaySound("GAMEGENERICBUTTONPRESS")
						PlaySound(624)
						LibStub("AceConfigDialog-3.0"):Close(addonName)
					else
						-- PlaySound("GAMEDIALOGOPEN")
						PlaySound(88)
						LibStub("AceConfigDialog-3.0"):Open(addonName)
					end
				end
			end,
			icon = "Interface\\LFGFRAME\\UI-LFR-PORTRAIT",
			OnTooltipShow = function(tooltip)
				if not tooltip or not tooltip.AddLine then return end
				tooltip:AddLine(addonName)
				tooltip:AddLine(L["|cffffff00Right-click|r to open the options menu"])
			end,
		})

		if LDBIcon then
			LDBIcon:Register(addonName, self.LDBObj, self.db.profile.minimapIcon)
		end
		
		hooksecurefunc(addon,"UpdateDisplay", function()
			self.LDBObj.text = getQueueSize()
		end)
		
	end
	
	
end

local function filterIncoming(self, event, msg)
	if not addon.db.profile.enabled then return false end
	-- if addon.db.profile.guildOnly then return false end
	local db = addon.db.profile
	-- if (string.find(string.lower(msg), "^"..db.keyword.."$")) then
		-- return true
	-- end
	return MatchKeywords(msg)
end

function addon:OnEnable()
	self:RegisterEvent("CHAT_MSG_WHISPER")
	self:RegisterEvent("CHAT_MSG_BN_WHISPER")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	self:RegisterEvent("PARTY_INVITE_REQUEST")
	
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filterIncoming)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", filterIncoming)
	if LDB and LDBIcon then
		LDBIcon:Refresh(addonName, addon.db.profile.minimapIcon)
	end
end

function addon:UpdateConfigs()
	if LDB and LDBIcon then
		LDBIcon:Refresh(addonName, addon.db.profile.minimapIcon)
	end
	LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
end

function addon:SetupOptions()

	self.Options.plugins.profiles = { profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db) }
	self.Options.name = addonName
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(addonName, self.Options)
	-- LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, addonName)
end



addon.Options = {
	childGroups = "tree",
	type = "group",
	plugins = {},
	args = {
		enabled = {
			order = 1,
			type = "toggle",
			name = L["Enabled"],
			desc = L["Enable autoinvite"],
			get = function() return addon.db.profile.enabled end,
			set = function(info, value) addon.db.profile.enabled = value; end,
		},
		minimapIcon = {
			order = 2,
			type = "toggle",
			name = L["Minimap Icon"],
			desc = L["Show a Icon to open the config at the Minimap"],
			get = function() return not addon.db.profile.minimapIcon.hide end,
			set = function(info, value) addon.db.profile.minimapIcon.hide = not value; LDBIcon[value and "Show" or "Hide"](LDBIcon, addonName) end,
			-- disabled = function() return not LDBIcon end,
			disabled = function() return not LDBTitan end,
		},
		general = {
			order = 3,
			type = "group",
			name = L["General"],
			args = {
				-- intro = {
					-- order = 1,
					-- type = "description",
					-- name = L["Addon to auto invite people when they whisper a predetermined keyword."],
				-- },

				invite = {
					order = 3,
					type = "group",
					name = L["Invite Options"],
					guiInline = true,
					args = {
						-- keyword = {
							-- order = 1,
							-- type = "input",
							-- name = L["Keyword"],
							-- -- desc = L[""],
							-- get = function() return addon.db.profile.keyword end,
							-- set = function(info, value) addon.db.profile.keyword = value end,
							-- -- dialogControl = "NumberEditBox",
						-- },
						keywords = {
							order = 1,
							type = "input",
							width = "double",
							name = L["Keywords"],
							desc = L["Seperated by comma."],
							get = function()
								if table.getn(addon.db.profile.keywords) == 1 then
									return addon.db.profile.keywords[1]
								else
									return table.concat(addon.db.profile.keywords,",")
								end
							end,
							set = function(info, value)
								if value == "" then value = L["invite"]..","..L["inv"]; end
								-- Clear the keywords table.
								addon.db.profile.keywords = {}
								-- Remove any empty space.
								value = value:gsub(" ","")
								-- Replace the commas with empty space for string.gmatch.
								value = value:gsub(","," ")
								-- Insert new values into the keywords table.
								for i in string.gmatch(value,"%S+") do
									table.insert(addon.db.profile.keywords,i)
								end

							end,
						},
						spacer1 = {
							order = 2,
							width = "full",
							type = "description",
							name = "",
						},
						casesensitive = {
							order = 3,
							type = "toggle",
							width = "full",
							name = L["Case-sensitive"],
							-- desc = "",
							get = function() return addon.db.profile.caseSensitive end,
							set = function(info, value) addon.db.profile.caseSensitive = value; end,
						},
						guild = {
							order = 4,
							type = "toggle",
							width = "full",
							name = L["Guild only invites"],
							-- desc = "",
							get = function() return addon.db.profile.guildOnly end,
							set = function(info, value) addon.db.profile.guildOnly = value; end,
							disabled = function() return not IsInGuild() end
						},
						friends = {
							order = 5,
							type = "toggle",
							width = "full",
							name = L["Allow friends"],
							desc = L["Allow those on your Friends List to be invited when Guild only invites are enabled."],
							get = function() return addon.db.profile.friendsAllowed end,
							set = function(info, value) addon.db.profile.friendsAllowed = value; end,
							disabled = function() return not addon.db.profile.guildOnly end
						},
						BNetWhispers = {
							order = 6,
							type = "toggle",
							width = "full",
							name = L["Battle.net Whispers"],
							desc = L["Allow invites from Battle.net Whispers."],
							get = function() return addon.db.profile.BNetWhispers end,
							set = function(info, value) addon.db.profile.BNetWhispers = value; end,
							disabled = function() return not addon.db.profile.friendsAllowed or not addon.db.profile.guildOnly end
						},
						limitgroupsize = {
							order = 7,
							type = "toggle",
							width = "full",
							name = L["Limit group size"],
							desc = L["Set the maximum size of your group"],
							get = function() return addon.db.profile.limitGroupSize end,
							set = function(info, value) addon.db.profile.limitGroupSize = value; end,
						},
						groupsize = {
							order = 8,
							name = L["Group size"],
							desc = L["Maximum number of people in a group."],
							type = "range",
							min = 2, max = 40, step = 1,
							get = function() return addon.db.profile.groupSize end,
							set = function(info, value) addon.db.profile.groupSize = value end,
							disabled = function() return not addon.db.profile.limitGroupSize end,
						},
						spacer4 = {
							order = 9,
							type = "description",
							name = "",
							width = "full",
						},
						autoconvert = {
							order = 10,
							type = "toggle",
							width = "full",
							name = L["Auto convert to raid"],
							get = function() return addon.db.profile.autoConvertToRaid end,
							set = function(info, value) addon.db.profile.autoConvertToRaid = value; end,
							disabled = function() return not addon.db.profile.limitGroupSize end,
						},
						autoconvertonlyoverfive = {
							order = 11,
							type = "toggle",
							width = "full",
							name = L["Only if group size is over 5"],
							desc = L["Will ignore the setting for threshold."],
							get = function() return addon.db.profile.autoConvertOnlyOverFive end,
							set = function(info, value) addon.db.profile.autoConvertOnlyOverFive = value; end,
							disabled = function() return not addon.db.profile.limitGroupSize or not addon.db.profile.autoConvertToRaid end,
						},

						threshold = {
							order = 12,
							name = L["Threshold for auto convert."],
							desc = L["If group size is larger than this threshold then the party will be converted into a raid."],
							type = "range",
							min = 1, max = 5, step = 1,
							get = function() return addon.db.profile.autoConvertThreshold end,
							set = function(info, value)
								addon.db.profile.autoConvertThreshold = value
							end,
							disabled = function() return not addon.db.profile.autoConvertToRaid or not addon.db.profile.limitGroupSize end,
						},
					},
				},
				level = {
					order = 4,
					type = "group",
					name = L["Level range"],
					guiInline = true,
					args = {
						checklevel = {
							order = 1,
							type = "toggle",
							width = "full",
							name = L["Check level"],
							desc = string.format(L["Check the level of the players whispering you for an invite. Recommened when you are attempting to make a raid (or you are already in one) to avoid attempted invites of players below level %s."],MIN_RAID_LEVEL),
							get = function() return addon.db.profile.checkLevel end,
							set = function(info, value) addon.db.profile.checkLevel = value; end,
						},
						minlevel = {
							order = 2,
							name = L["Minimum level"],
							desc = string.format(L["Require a minimum level in order to get invited. In a raid group this setting will be ignored if set below %s."],MIN_RAID_LEVEL),
							type = "range",
							min = 1, max = MAX_PLAYER_LEVEL, step = 1,
							get = function() return addon.db.profile.minLevel end,
							set = function(info, value)
								-- if value <= addon.db.profile.maxLevel then
									-- addon.db.profile.minLevel = value
								-- else
									-- addon.db.profile.minLevel = addon.db.profile.maxLevel
								-- end
								if value >= addon.db.profile.maxLevel then
									addon.db.profile.maxLevel = value
								end
								addon.db.profile.minLevel = value
							end,
							disabled = function() return not addon.db.profile.checkLevel end
						},
						spacer1 = {
							order = 3,
							width = "full",
							type = "description",
							name = "",
						},
						maxlevel = {
							order = 4,
							name = L["Maximum level"],
							desc = string.format(L["The maximum level a player can be. In a raid group this setting will be ignored if set below %s."],MIN_RAID_LEVEL),
							type = "range",
							min = 1, max = MAX_PLAYER_LEVEL, step = 1,
							get = function() return addon.db.profile.maxLevel end,
							set = function(info, value)
							-- addon.Options.args.general.args.level.args.minlevel.get()
								-- if value >= addon.db.profile.minLevel then
									-- addon.db.profile.maxLevel = value
								-- else
									-- addon.db.profile.maxLevel = addon.db.profile.minLevel
								-- end
								if value <= addon.db.profile.minLevel then
									addon.db.profile.minLevel = value
								end
								addon.db.profile.maxLevel = value
							end,
							disabled = function() return not addon.db.profile.checkLevel end
						},
					}
				},
				misc = {
					order = 5,
					type = "group",
					name = L["Miscellaneous"],
					-- guiInline = true,
					cmdInline = true,
					args = {
						autojoin = {
							order = 1,
							type = "toggle",
							name = L["Auto join"],
							desc = L["Auto accept group invitations from guild members and friends."],
							get = function() return addon.db.profile.autoJoin end,
							set = function(info, value) addon.db.profile.autoJoin = value; end,
						}
					}
				}
			}
		},
	}
}

function addon:ChatMsgWhisper(player, level)
	local db = self.db.profile
	if UnitIsGroupLeader("player") or (UnitIsGroupAssistant("player") and IsInRaid()) or GetNumGroupMembers() == 0 then
		local attemptInvite = false
		
		if db.guildOnly and IsInGuild() then
			if PlayerIsInMyGuild(player) or (db.friendsAllowed and PlayerIsFriend(player)) then
				attemptInvite = true
			end
		else
			attemptInvite = true
		end
		
		if not attemptInvite then return end
		
		if db.checkLevel and level then
			
			if level < db.minLevel or level > db.maxLevel then
				if db.minLevel == db.maxLevel then
					SendChatMessage(string.format(L["Only those at level %s will be invited to this group."],db.minLevel), "WHISPER", nil, player)
				else
					SendChatMessage(string.format(L["Only those between level %s and %s will be invited to this group."],db.minLevel,db.maxLevel), "WHISPER", nil, player)
				end
				return
			end
			
			if (IsInRaid() or (db.autoConvertToRaid and db.limitGroupSize and not db.autoConvertOnlyOverFive and db.groupSize > db.autoConvertThreshold or (db.autoConvertToRaid and db.limitGroupSize and db.autoConvertOnlyOverFive and db.groupSize > 5))) and level < MIN_RAID_LEVEL then
				-- if statement of doom.
				SendChatMessage(string.format(L["You need to be at least level %s to be invited to a raid group."],MIN_RAID_LEVEL), "WHISPER", nil, player)
				return
			end
		end
					
		addToQueue(player)

		if invitesRemaining <= 0 then
			local numberInQueue = spotInQueue(player)
			if self.OnUpdate.pause then
				self.OnUpdate.lastAdded = numberInQueue
			end
			SendChatMessage(string.format(L["The group is full but you have been added to the queue as #%s."],numberInQueue).." "..string.format(L["Whisper '%s' to be removed."],db.removeKeyword), "WHISPER", nil, player)
		end
	end
end

function addon:UserDataReturned(user)
	if user then
		-- Data returned. Continue.
		if not user.Online then return end
		self:ChatMsgWhisper(user.Name, user.Level)
	end
end

function addon:CHAT_MSG_WHISPER(_, msg, player)
	if not self.db.profile.enabled then return end
	local db = self.db.profile
	player = player:gsub("-"..GetRealmName(),"")
	-- if (string.find(string.lower(msg), "^"..db.keyword.."$")) then
	if MatchKeywords(msg) then
		if UnitInParty(player) then
			SendChatMessage(L["You are already in my group!"], "WHISPER", nil, player)
			return 
		end
				
		local playerIsInQueue, invited, numberInQueue = isInQueue(player)
		
		if playerIsInQueue then
			if not invited then
				SendChatMessage(string.format(L["You are #%s in the queue."],numberInQueue).." "..string.format(L["Whisper '%s' to be removed."],db.removeKeyword), "WHISPER", nil, player)
			else
				SendChatMessage(L["Accept the group invitation, please."], "WHISPER", nil, player)
			end
			return
		end
		
		local userInfo
		local level
		if db.checkLevel then
			userInfo = self:UserInfo(player, {callback='UserDataReturned', timeout=10})
			if not userInfo then return	end -- No data returned from cache. Will return and let the callback-function call to ChatMsgWhisper.
			level = userInfo.Level
		end

		self:ChatMsgWhisper(player, level)
		
	elseif (string.find(string.lower(msg), "^"..db.removeKeyword.."$")) then
		if UnitInParty(player) then
			SendChatMessage(L["Leave the group."], "WHISPER", nil, player)
			return
		end
		local playerIsInQueue, invited = isInQueue(player)
		if playerIsInQueue then
			if not invited then
				removeFromQueue(player)
				SendChatMessage(L["You have been removed from the queue."], "WHISPER", nil, player)
			else
				SendChatMessage(L["Decline the group invitation."], "WHISPER", nil, player)
			end
		end
	end
end

function addon:CHAT_MSG_BN_WHISPER(_, msg, ...)
	if not self.db.profile.enabled then return end
	local db = self.db.profile
	
	if db.guildOnly and not db.friendsAllowed then return end
	if not db.BNetWhispers then return end
	
	-- local _, _, _, _, _, _, _, _, _, _, _, presenceID = ...
	local presenceID = select(12, ...)
	-- if (string.find(string.lower(msg), "^"..db.keyword.."$")) then
	if MatchKeywords(msg) then
	
		local playerIsInQueue, invited, numberInQueue = BNisInQueue(presenceID)
		if playerIsInQueue then
			if not invited then
				BNSendWhisper(presenceID,string.format(L["You are #%s in the queue."],numberInQueue).." "..string.format(L["Whisper '%s' to be removed."],db.removeKeyword))
			else
				BNSendWhisper(presenceID,L["Accept the group invitation, please."])
			end
			return
		end
		
		if UnitIsGroupLeader("player") or (UnitIsGroupAssistant("player") and IsInRaid()) or GetNumGroupMembers() == 0 then
			local index = BNGetFriendIndex(presenceID)
			
			if index then
				local numToons = C_BattleNet.GetFriendNumGameAccounts(index)
				
				if numToons > 0 then
				-- see if there is exactly one toon we could invite
					local numValidToons = 0
					local lastToonID
					local player
					local playerLevel
					
					for i = 1, numToons do
						-- local _, toonName, client, realm, realmID, faction, _, _, _, _, level, _, _, _, _, toonID = C_BattleNet.GetFriendGameAccountInfo(index, i);
						local info = C_BattleNet.GetFriendGameAccountInfo(index, i)
						if info.clientProgram == BNET_CLIENT_WOW and info.factionName == UnitFactionGroup("player") and info.realmID ~= 0 then
							numValidToons = numValidToons + 1
							lastToonID = info.gameAccountID
							playerLevel = tonumber(info.characterLevel)
							if info.realmName == GetRealmName() then
								player = info.characterName
							else
								player = info.characterName.."-"..info.realmName:gsub(" ","")
							end
						end
					end
					
					if numValidToons == 1 and not UnitInParty(player) then
						
						if db.checkLevel then
						
							if playerLevel < db.minLevel or playerLevel > db.maxLevel then
								if db.minLevel == db.maxLevel then
									BNSendWhisper(presenceID,string.format(L["Only those at level %s will be invited to this group."],db.minLevel))
								else
									BNSendWhisper(presenceID,string.format(L["Only those between level %s and %s will be invited to this group."],db.minLevel,db.maxLevel))
								end
								return
							end			
							
							-- if IsInRaid() and playerLevel < MIN_RAID_LEVEL then
							if (IsInRaid() or (db.autoConvertToRaid and db.limitGroupSize and not db.autoConvertOnlyOverFive and db.groupSize > db.autoConvertThreshold or (db.autoConvertToRaid and db.limitGroupSize and db.autoConvertOnlyOverFive and db.groupSize > 5))) and playerLevel < MIN_RAID_LEVEL then
								BNSendWhisper(presenceID,string.format(L["You need to be at least level %s to be invited to a raid group."],MIN_RAID_LEVEL))
								return
							end
						end
						print(player)
						addToQueue(player,lastToonID,presenceID)

						if invitesRemaining <= 0 then
							local numberInQueue = BNspotInQueue(presenceID)
							if self.OnUpdate.pause then
								self.OnUpdate.lastAdded = numberInQueue
							end
							BNSendWhisper(presenceID,string.format(L["The group is full but you have been added to the queue as #%s."],numberInQueue).." "..string.format(L["Whisper '%s' to be removed."],db.removeKeyword))
						end
					end
				end
			end
		end
	elseif (string.find(string.lower(msg), "^"..db.removeKeyword.."$")) then
		local playerIsInQueue, invited = BNisInQueue(presenceID)
		if playerIsInQueue then
			if not invited then
				BNremoveFromQueue(presenceID)
				BNSendWhisper(presenceID,L["You have been removed from the queue."])
			else
				BNSendWhisper(presenceID,L["Decline the group invitation."])
			end
		end
	end
end

function addon:GROUP_ROSTER_UPDATE()
	if not self.db.profile.enabled then return end
	local db = self.db.profile
	
	if self.OnUpdate.pause and CanConvertToRaid() then
		self.OnUpdate.pause = false
	end
	
	if not self.OnUpdate.pause and GetNumGroupMembers() == 0 then
		-- Clear the queue and send out whispers about a disband?
		-- Keep the queue and invite those in it?
		-- Add option for keeping or clearing the queue.
		clearQueue()
	end
	
end

function addon:CHAT_MSG_SYSTEM(_, msg)
	if not self.db.profile.enabled then return end
	local db = self.db.profile
	local pattern = "(.+)"
	local match, player

	match, _, player = string.find(msg,JOINED_PARTY:gsub("%%s", pattern))
	if match then
		removeFromQueue(player)
	end

	match, _, player = string.find(msg,ERR_ALREADY_IN_GROUP_S:gsub("%%s", pattern))
	if match then
		removeFromQueue(player)
	end
	
	match, _, player = string.find(msg,ERR_DECLINE_GROUP_S:gsub("%%s", pattern))
	if match then
		removeFromQueue(player)
	end
	
	match, _, player = string.find(msg,ERR_BAD_PLAYER_NAME_S:gsub("%%s", pattern))
	if match then
		retryInvite(player)
	end
	
	match, _, player = string.find(msg,ERR_INVITE_PLAYER_S:gsub("%%s", pattern))
	if match then
		setTimeOut(player)
	end
	
	-- if string.find(msg,ERR_LEFT_GROUP_YOU) or string.find(msg,ERR_GROUP_DISBANDED) then 
		-- clearQueue()
	-- end
	
	
	-- local messages ={
		-- JOINED_PARTY,
		-- ERR_ALREADY_IN_GROUP_S,
		-- -- ERR_BAD_PLAYER_NAME_S,
		-- ERR_DECLINE_GROUP_S
	-- }
	
	-- for _,v in ipairs(messages) do
		-- local match, _, player = string.find(msg,v:gsub("%%s", "(.+)"))
		-- if match then
			-- removeFromQueue(player)
			-- -- print(player)
			-- break

		-- end
	-- end
		
	-- if string.find(msg,ERR_BAD_PLAYER_NAME_S:gsub("%%s", "(.+)")) then
		-- local _,_,player = string.find(msg,ERR_BAD_PLAYER_NAME_S:gsub("%%s", "(.+)"))
		-- retryInvite(player)
	-- end
	
	-- if string.find(msg,ERR_INVITE_PLAYER_S:gsub("%%s", "(.+)")) then
		-- local _,_,player = string.find(msg,ERR_INVITE_PLAYER_S:gsub("%%s", "(.+)"))
		-- setTimeOut(player)
	-- end
	

	
	-- if string.find(msg,LEFT_PARTY:gsub("%%s", "(.+)")) then

	-- end
	-- if string.find(msg,JOINED_PARTY:gsub("%%s", "(.+)")) then
		-- -- local player = msg:gsub(JOINED_PARTY:gsub("%%s", ""),"")
		-- local _,_,player = string.find(msg,JOINED_PARTY:gsub("%%s", "(.+)"))
		-- removeFromQueue(player)
		-- -- if  UnitIsGroupLeader("player") and not IsInRaid() and db.autoConvertToRaid and (GetNumGroupMembers() >= db.autoConvertThreshold and db.groupSize > db.autoConvertThreshold) then
			-- -- ConvertToRaid()
		-- -- end
	-- end
	-- if string.find(msg,ERR_ALREADY_IN_GROUP_S:gsub("%%s", "(.+)")) then 
		-- _,_,player = string.find(msg,ERR_ALREADY_IN_GROUP_S:gsub("%%s", "(.+)"))
		-- removeFromQueue(player)
	-- end
	-- if string.find(msg,ERR_BAD_PLAYER_NAME_S:gsub("%%s", "(.+)")) then
		-- _,_,player = string.find(msg,ERR_BAD_PLAYER_NAME_S:gsub("%%s", "(.+)"))
		-- removeFromQueue(player)
	-- end
	-- if string.find(msg,ERR_DECLINE_GROUP_S:gsub("%%s", "(.+)")) then 
		-- _,_,player = string.find(msg,ERR_DECLINE_GROUP_S:gsub("%%s", "(.+)"))
		-- removeFromQueue(player)
	-- end
	

end
--[[
	local  arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16 = ...
	print(1, arg1)
	print(2, arg2)
	print(3, arg3)
	print(4, arg4) 
	print(5, arg5)
	print(6, arg6) 
	print(7, arg7)
	print(8, arg8) 
	print(9, arg9)
	print(10, arg10) 
	print(11, arg11) 
	print(12, arg12)
	print(13, arg13)
	print(14, arg14)
	print(15, arg15)
	print(16, arg16)
]]--
function addon:PARTY_INVITE_REQUEST(_, sender)
	-- if not self.db.profile.enabled then return end
	if not self.db.profile.autoJoin then return end
	if PlayerIsInMyGuild(sender) or PlayerIsFriend(sender) then
		AcceptGroup()
		for i=1, STATICPOPUP_NUMDIALOGS do
			local popup = _G["StaticPopup"..i]
			if popup.which == "PARTY_INVITE" or popup.which == "PARTY_INVITE_XREALM" then
				popup.inviteAccepted = 1
				StaticPopup_Hide("PARTY_INVITE")
				return
			end
		end
	end
end

