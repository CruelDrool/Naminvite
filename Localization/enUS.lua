local addonName = ...
-- English localization file for enUS and enGB.
local AceLocale = LibStub:GetLibrary("AceLocale-3.0")
local L = AceLocale:NewLocale(addonName, "enUS", true)
if not L then return end

-- MINIMAP ICON --
L["Minimap Icon"] = true
L["Show a Icon to open the config at the Minimap"] = true
L["|cffffff00Right-click|r to open the options menu"] = true

-- CONFIGURATION --
L["Addon to auto invite people when they whisper a predetermined keyword."] = true
L["Enabled"] = true
L["General"] = true
-- CONFIGURATION: Invite options
L["Enable autoinvite"] = true
L["Invite Options"] = true
L["Keywords"] = true
L["Case-sensitive"] = true
L["Seperated by comma."] = true
L["invite"] = true
L["inv"] = true
L["remove"] = true
L["Guild only invites"] = true
L["Allow friends"] = true
L["Allow those on your Friends List to be invited when Guild only invites are enabled."] = true
L["Battle.net Whispers"] = true
L["Allow invites from Battle.net Whispers."] = true
L["Limit group size"] = true
L["Set the maximum size of your group"] = true
L["Group size"] = true
L["Auto convert to raid"] = true
L["Only if group size is over 5"] = true
L["Will ignore the setting for threshold."] = true
L["Threshold for auto convert."] = true
L["If group size is larger than this threshold then the party will be converted into a raid."] = true
-- CONFIGURATION: Level range
L["Level range"] = true
L["Check level"] = true
L["Check the level of the players whispering you for an invite. Recommened when you are attempting to make a raid (or you are already in one) to avoid attempted invites of players below level %s."] = true
L["Maximum number of people in a group."] = true
L["Minimum level"] = true
L["Require a minimum level in order to get invited. In a raid group this setting will be ignored if set below %s."] = true
L["Maximum level"] = true
L["The maximum level a player can be. In a raid group this setting will be ignored if set below %s."] = true
-- CONFIGURATION: Miscellaneous
L["Miscellaneous"] = true
L["Auto join"] = true
L["Auto accept group invitations from guild members and friends."] = true

-- ChatFrame Messages --
L["Invitations paused."] = true
L["The following player is too low level for raid: %s"]  = true
L["The following players are too low level for raid: %s"]  = true

-- Whispers --
L["You are already in my group!"] = true
L["Leave the group."]= true
L["The group is full but you have been added to the queue as #%s."] = true
L["You are #%s in the queue."] = true
L["Whisper '%s' to be removed."] = true
L["You have been removed from the queue."] = true
L["You need to be at least level %s to be invited to a raid group."] = true
L["Accept the group invitation, please."] = true
L["Decline the group invitation."] = true
L["Only those at level %s will be invited to this group."] = true
L["Only those between level %s and %s will be invited to this group."] = true

