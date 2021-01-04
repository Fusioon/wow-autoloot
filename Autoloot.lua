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

local frame = UIParent;

function CheckDisableKeys() 
	for key,value in pairs(config.autoclose.disableKeys) do --actualcode
		if value() then
			return true;
		end
	end

	return false;
end

frame:RegisterEvent('LOOT_OPENED', function(autoloot) 
	local count = GetNumLootItems();
	local shouldClose = not CheckDisableKeys();

	for i = 1, count, 1 do 
		local icon, name, quantity, rarity, locked, isQuestItem, questId, active = GetLootSlotInfo();
		
		local shouldLoot = (rarity >= config.minRarity) or
						(config.lootCoins and LootSlotIsCoin(i)) or 
						(config.lootCurrency and LootSlotIsCurrency(i)) or 
						(config.lootQuestItems and isQuestItem);
		
		if shouldLoot and not locked then
			LootSlot(i);
		end
	end

	if config.autoclose.enabled then
		C_Timer.After(config.autoclose.delay / 1000, function() 
			if shouldClose or not CheckDisableKeys() then
				CloseLoot();
			end
		end);
	end
end);