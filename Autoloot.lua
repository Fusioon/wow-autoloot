local config = {
	minRarity = 3, 	--  3 - rare 
	lootCoins = true,
	lootCurrency = true,
	lootQuestItems = true,
	autoclose = {
		enabled = true,
		delay = 1500, -- delay in milliseconds,
		disableKeys = { IsShiftKeyDown }
	}
};

local frame = CreateFrame("Frame", nil, UIParent);

function CheckDisableKeys() 
	for key,value in pairs(config.autoclose.disableKeys) do --actualcode
		if value() then
			return true;
		end
	end

	return false;
end

frame:RegisterEvent('LOOT_OPENED');

function LOOT_OPENED(autoloot)
	
	local count = GetNumLootItems();
	local shouldClose = not CheckDisableKeys();

	for i = 1, count do 
		local icon, name, quantity, unknown, rarity, locked, isQuestItem, questId, active = GetLootSlotInfo(i);

		local lootType = GetLootSlotType(i);

		local shouldLoot = (rarity >= config.minRarity) or
						(config.lootCoins and lootType == 2) or 
						(config.lootCurrency and lootType == 3) or 
						(config.lootQuestItems and isQuestItem);
		
		if shouldLoot and not locked then
			LootSlot(i);
		end
	end

	if config.autoclose.enabled then
		C_Timer.After(config.autoclose.delay / 1000, function() 
			if shouldClose and not CheckDisableKeys() then
				CloseLoot();
			end
		end);
	end
end

frame:SetScript("OnEvent", function(self, event, ...)
	LOOT_OPENED(...);
end);
