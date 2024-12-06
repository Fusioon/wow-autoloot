-- Rarity comparison op
local CMP_OP = {
	EQ = 1,
	NEQ = 2,
	LT = 3,
	LTE = 4,
	GT = 5,
	GTE = 6
}

local config = {
	minRarity = 2, 	--  3 - rare 
	lootCoins = true,
	lootCurrency = true,
	lootQuestItems = true,
	lootGatheredItems = true,
	autoclose = {
		enabled = true,
		delay = 1500, -- delay in milliseconds,
		disableKeys = { IsShiftKeyDown }
	},
	forceLoot = {
		{ name = " Cloth", partial = true, rarity = 1 },
		{ name = " Potion", partial = true, active = true }
	}
};

local frame = CreateFrame("Frame", nil, UIParent);
local currentTimer = nil;
local isGatheringWindow = false;

function CheckDisableKeys() 
	for key,value in pairs(config.autoclose.disableKeys) do --actualcode
		if value() then
			return true;
		end
	end

	return false;
end

frame:RegisterEvent('LOOT_OPENED');
frame:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED');

function CompareValues(lhs, rhs, op)
	if op == nil or op == CMP_OP_EQ then
		return lhs == rhs;
	end
	if op == CMP_OP.NEQ then
		return lhs ~= rhs;
	end

	if op == CMP_OP.LT then
		return lhs < rhs;
	end
	if op == CMP_OP.LTE then
		return lhs <= rhs;
	end

	if op == CMP_OP.GT then
		return lhs > rhs;
	end
	if op == CMP_OP.GTE then
		return lhs > rhs;
	end

	error("Unknown comparison operator")
end

function CheckForceLoot(name, rarity, quantity, active)
	for i = 1, #config.forceLoot do
		local fl = config.forceLoot[i];
		if (fl.partial and string.find(name, fl.name)) or (not fl.partial and name == fl.name) then
			if (fl.active == nil or fl.active == fl.active) and
				(fl.rarity == nil or CompareValues(rarity, fl.rarity, fl.rarityCompareOP)) then
					return true;
			end
		end
	end

	return false;
end


function LOOT_OPENED(autoLoot)
	
	local count = GetNumLootItems();
	local shouldClose = not CheckDisableKeys();
	
	for i = 1, count do 
		local icon, name, quantity, currencyID, rarity, locked, isQuestItem, questId, active = GetLootSlotInfo(i);

		local lootType = GetLootSlotType(i);

		local shouldLoot = (config.lootGatheredItems and isGatheringWindow) or
						(rarity >= config.minRarity) or
						(config.lootCoins and lootType == 2) or 
						(config.lootCurrency and lootType == 3) or 
						(config.lootQuestItems and isQuestItem) or 
						CheckForceLoot(name, rarity, quantity, active);
		
		if shouldLoot and not locked then
			LootSlot(i);
		end
	end

	isGatheringWindow = false;

	if config.autoclose.enabled then
		if currentTimer ~= nil then
			currentTimer:Cancel();
		end
		currentTimer = C_Timer.NewTimer(config.autoclose.delay / 1000, function() 
			if shouldClose and not CheckDisableKeys() then
				CloseLoot();
			end
		end);
	end
end

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "LOOT_OPENED" then
		LOOT_OPENED(...);
	end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unitTarget, castGUID, spellID = ...;

		local DISENCHANT_ID = 13262;
		local SKINNING_ID = 8613;
		local HERBALISM_ID = 2366;
		local MINING_ID = 2575;

		if unitTarget == "player" and (spellID == DISENCHANT_ID or spellID == SKINNING_ID or spellID == HERBALISM_ID or spellID == MINING_ID) then
			isGatheringWindow = true;
		end
	end
end);
