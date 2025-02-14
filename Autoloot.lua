local config = {
	enabled = true,
	dynamicLootWindow = true,
	minRarity = 2,
	maxRarity = 4,
	lootCoins = true,
	lootCurrency = true,
	lootQuestItems = true,
	lootMiningItems = true,
	lootSkinningItems = true,
	lootHerbGatheringItems = true,
	lootDisenchantingItems = true,
	lootFishing = true,
	autoclose = {
		enabled = true,
		delay = 1500, -- delay in milliseconds,
		disableKeys = { "shift" },
		disableOnMaxRarity = true, -- Do not autoclose when there is item with item rarity higher than max
	},
	forceLoot = {
		{ name = " Cloth", partial = true, minRarity = 1, maxRarity = 1 },
		{ name = " Potion", partial = true, active = true }
	}
};

local KEY_MAP = {
	mod = IsModifierKeyDown,
	shift = IsShiftKeyDown,
	control = IsControlKeyDown,
	alt = IsAltKeyDown
};

local frame = CreateFrame("Frame", nil, UIParent);
local currentTimer = nil;
local isGatheringWindow = false;
local lootedItems = {};
local lootedItemsCount = 0;

frame:RegisterEvent('LOOT_READY');
frame:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED');
frame:RegisterEvent('ADDON_LOADED');
frame:RegisterEvent('PLAYER_LOGOUT');

function CheckDisableKeys() 
	for i = 1, #config.autoclose.disableKeys do
		local fn = KEY_MAP[string.lower(config.autoclose.disableKeys[i])];
		if fn ~= nil and fn() then
			return true;
		end
	end

	return false;
end

function CheckForceLoot(name, rarity, quantity, active)
	for i = 1, #config.forceLoot do
		local fl = config.forceLoot[i];
		if (fl.partial and string.find(name, fl.name)) or (not fl.partial and name == fl.name) then
			if (fl.active == nil or fl.active == fl.active) and
				(fl.minRarity == nil or rarity >= fl.minRarity) and
				(fl.maxRarity == nil or rarity <= fl.maxRarity) then
					return true;
			end
		end
	end

	return false;
end

function LOOT_READY(autoLoot)
	
	local count = GetNumLootItems();
	local shouldClose = not CheckDisableKeys();
	
	wipe(lootedItems);
	lootedItemsCount = 0;

	local lootMethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod();
	local lootThreshold = GetLootThreshold();
	local needsRoll = ((UnitInAnyGroup("player")) and (lootMethod ~= "freeforall"));

	if (config.lootFishing and IsFishingLoot()) then
		isGatheringWindow = true;
	end

	for i = 1, count do 
		local icon, name, quantity, currencyID, rarity, locked, isQuestItem, questId, active = GetLootSlotInfo(i);

		local lootType = GetLootSlotType(i);

		local shouldLoot = (isGatheringWindow) or
						(rarity >= config.minRarity and rarity <= config.maxRarity) or
						(config.lootCoins and lootType == 2) or 
						(config.lootCurrency and lootType == 3) or 
						(config.lootQuestItems and isQuestItem) or 
						CheckForceLoot(name, rarity, quantity, active);

		if config.autoclose.disableOnMaxRarity and rarity > config.maxRarity then
			shouldClose = false;
		end

		if shouldLoot and not locked then
			LootSlot(i);
			lootedItems[i] = true;
			if (not needsRoll or rarity < lootThreshold) then
				lootedItemsCount = lootedItemsCount + 1;
			end
		else
			lootedItems[i] = false;
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
	if not config.enabled then
		return;
	end

	if event == "LOOT_READY" then
		LOOT_READY(...);
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unitTarget, castGUID, spellID = ...;

		local DISENCHANT_ID = 13262;
		local SKINNING_ID = 8613;
		local HERBALISM_ID = 2366;
		local MINING_ID = 2575;

		local isGathering = (config.lootDisenchantingItems and spellID == DISENCHANT_ID) or 
							(config.lootSkinningItems and spellID == SKINNING_ID) or 
							(config.lootHerbGatheringItems and spellID == HERBALISM_ID) or 
							(config.lootMiningItems and spellID == MINING_ID);

		if unitTarget == "player" and isGathering then
				isGatheringWindow = true;
		end
	elseif event == "ADDON_LOADED" then
		local name = ...
		if name == "Autoloot" then
			if AutolootConfig ~= nil then
				config = AutolootConfig;
			else
				AutolootConfig = config;
			end
			CreateSettingsUI();
			if (config.dynamicLootWindow) then
				HookDynamicLootWindowSize();
			end
		end
	end
	if event == "PLAYER_LOGOUT" then
		AutolootConfig = config;
	end
end);

function HookDynamicLootWindowSize()
	local regions = { LootFrame:GetRegions() };
	for i = 1, #regions do
		local r = regions[i];
		if (r.GetText and r:GetText() == ITEMS) then
			r:ClearAllPoints();
			r:SetPoint("TOP", 12, -5);
		end
	end

	local x, y = 0, -4;
	local buttonHeight = LootButton1:GetHeight() + abs(y);
	local baseHeight = LootFrame:GetHeight() - (buttonHeight * LOOTFRAME_NUMBUTTONS);

	hooksecurefunc("LootFrame_Show", function(self, ...)
		local maxButtons = floor(UIParent:GetHeight()/LootButton1:GetHeight() * 0.7)
		local num = GetNumLootItems();

		num = min(num, maxButtons);
		
		LootFrame:SetHeight(baseHeight + ((num - lootedItemsCount) * buttonHeight));

		local positionIndex = 0;

		for i = 1, num do
			if (not lootedItems[i]) then
				if (positionIndex == 0) then
					local button = _G["LootButton"..i];
					button:ClearAllPoints();
					button:SetPoint("TOPLEFT", LootFrame, "TOPLEFT", 9, -64 + y);
					positionIndex = i;
				end

				if (i > LOOTFRAME_NUMBUTTONS) then
					local button = _G["LootButton"..i];
					if (not button) then
						button = CreateFrame(ItemButtonMixin and "ItemButton" or "Button", "LootButton"..i, LootFrame, "LootButtonTemplate", i);
					end
					LOOTFRAME_NUMBUTTONS = i;
				end
				if (positionIndex ~= i) then
					local button = _G["LootButton"..i];
					button:ClearAllPoints();
					button:SetPoint("TOP", "LootButton"..positionIndex, "BOTTOM", x, y);
				end
				positionIndex = i;
			end
		end
		
		LootFrame_Update();
	end);
end

-- Addon Settings UI 

function CreateSettingsUI()

	local category = Settings.RegisterVerticalLayoutCategory("Autoloot");

	do
		local name = "Enable Autoloot";
		local variable = "Autoloot_Toggle";
		local variableKey = "enabled";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "";
		Settings.CreateCheckbox(category, setting, tooltip);
	end
	
	do
		local name = "Dynamic loot window";
		local variable = "Autoloot_DynamicLootWindowSize";
		local variableKey = "dynamicLootWindow";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);
		setting:SetValueChangedCallback(function (...)
			
		end);

		local tooltip = "Dynamically change loot window size to show as much items as possible\n(Requires UI reload)";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Coins";
		local variable = "Autoloot_coins";
		local variableKey = "lootCoins";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Enable autolooting of coins";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Currency";
		local variable = "Autoloot_currency";
		local variableKey = "lootCurrency";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Enable autolooting of currency items:\nBadges, Emblems, Marks...";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Quest items";
		local variable = "Autoloot_qitems";
		local variableKey = "lootQuestItems";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Enable autolooting of quest items"
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Mining items";
		local variable = "Autoloot_miningItems";
		local variableKey = "lootMiningItems";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Enable autolooting of items from mining";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Disenchanting items";
		local variable = "Autoloot_disenchItems";
		local variableKey = "lootDisenchantingItems";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Enable autolooting of items from disenchanting";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Herb gathering items";
		local variable = "Autoloot_herbgathItem";
		local variableKey = "lootHerbGatheringItems";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Enable autolooting of items from herb gathering";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Skinning items";
		local variable = "Autoloot_skinningItems";
		local variableKey = "lootSkinningItems";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Enable autolooting of items from skinning";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Fishing items";
		local variable = "Autoloot_fishingItems";
		local variableKey = "lootFishing";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Enable autolooting of items from fishing";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Autoclose";
		local variable = "Autoloot_autoclose";
		local variableKey = "enabled";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config.autoclose, type(defaultValue), name, defaultValue);

		local tooltip = "Enable to automatically close loot window after specified delay";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Autoclose max rarity";
		local variable = "Autoloot_autocloseDisableOnMaxRarity";
		local variableKey = "disableOnMaxRarity";
		local defaultValue = true;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config.autoclose, type(defaultValue), name, defaultValue);

		local tooltip = "Disable automatic loot window closing when there is an item which excedes Max Rarity";
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	do
		local name = "Autoclose delay";
		local variable = "Autoloot_AutocloseDelay";
		local variableKey = "delay";
		local defaultValue = 1500;
		local minValue = 100;
		local maxValue = 5000;
		local step = 100;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config.autoclose, type(defaultValue), name, defaultValue);

		local tooltip = "Delay for loot window auto close (ms)";
		local options = Settings.CreateSliderOptions(minValue, maxValue, step);
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right);
		Settings.CreateSlider(category, setting, options, tooltip);
	end

	do
		local name = "Autoclose disable modifier";
		local variable = "Autoloot_AutocloseMod";
		local variableKey = "value";
		local defaultValue = "shift";
		local tooltip = "Modifier key to disable automatic window closing";

		local function GetOptions()
			local container = Settings.CreateControlTextContainer();
			container:Add("shift", "Shift");
			container:Add("control", "Control");
			container:Add("alt", "Alt");
			container:Add("mod", "Any Modifier");
			container:Add("", "None");
			return container:GetData();
		end
		local tmp = {}

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, tmp, type(defaultValue), name, defaultValue);
		Settings.CreateDropdown(category, setting, GetOptions, tooltip);
		Settings.SetOnValueChangedCallback(variable, function(_, setting, value) 
			config.autoclose.disableKeys[1] = value;
		end);
	end

	local itemRarityTooltip = "";
	for i = 0, 8 do
		local desc = _G["ITEM_QUALITY" .. i .. "_DESC"];
		if desc ~= nil then
			local color = ITEM_QUALITY_COLORS[i];
			if color ~= nil then
				itemRarityTooltip = itemRarityTooltip .. color.hex .. i .. " - " .. desc  .. "\n";
			end
		end
	end

	do
		local name = "Min item rarity";
		local variable = "Autoloot_MinItemRarity";
		local variableKey = "minRarity";
		local defaultValue = 2;
		local minValue = 0;
		local maxValue = 8;
		local step = 1;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Minimal item rarity to be autolooted\n" .. itemRarityTooltip;

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right);
		Settings.CreateSlider(category, setting, options, tooltip);
	end

	do
		local name = "Max item rarity";
		local variable = "Autoloot_MaxItemRarity";
		local variableKey = "maxRarity";
		local defaultValue = 4;
		local minValue = 0;
		local maxValue = 8;
		local step = 1;

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, config, type(defaultValue), name, defaultValue);

		local tooltip = "Maximal item rarity to be autolooted\n" .. itemRarityTooltip;

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right);
		Settings.CreateSlider(category, setting, options, tooltip);
	end


	function dump(o)
		if type(o) == 'table' then
		   local s = '{ '
		   for k,v in pairs(o) do
			  if type(k) ~= 'number' then k = '"'..k..'"' end
			  s = s .. '['..k..'] = ' .. dump(v) .. ','
		   end
		   return s .. '} '
		else
		   return tostring(o)
		end
	 end
	 

	-- @TODO
	-- Custom "force loot" filter settings
	local filtersFrame = CreateFrame("Frame");
	local filterSubcategory, filtersSubcategoryLayout = Settings.RegisterCanvasLayoutSubcategory(category, filtersFrame, "Custom filter");
	do
		local name = "Force loot";
		local variable = "Autoloot_FilterSelection";
		local variableKey = "selection";
		local defaultValue = 1;
		local tooltip = "Custom filter for autoloot.";

		local function GetOptions()
			local container = Settings.CreateControlTextContainer();
			for i = 1, #config.forceLoot do
				container:Add(i, config.forceLoot[i].name);
			end
			return container:GetData();
		end
		local tmp = {}

		local index = -1;
		local function setSelected(i, force)
			if (i == index and not force) then
				return;
			end
			index = i;
		end

		-- local setting = Settings.RegisterAddOnSetting(filterSubcategory, variable, variableKey, tmp, type(defaultValue), name, defaultValue);
		-- Settings.CreateDropdown(filterSubcategory, setting, GetOptions, tooltip);
		-- Settings.SetOnValueChangedCallback(variable, function(_, setting, value) 
		-- 	-- print(value);
		-- 	setSelected(value, false);
		-- end);

		local newFilter = CreateFrame("Button", nil, filtersFrame, "UIPanelButtonTemplate");
		newFilter:SetSize(130, 24);
		newFilter:SetPoint("TOPLEFT", filtersFrame, "TOPLEFT", 0, 0);
		newFilter:SetText("New");
		newFilter:SetScript("OnClick", function(self, arg1)

		end);

		local removeFilter = CreateFrame("Button", nil, filtersFrame, "UIPanelButtonTemplate");
		removeFilter:SetSize(130, 24);
		removeFilter:SetPoint("TOPRIGHT", filtersFrame, "TOPRIGHT", 0, 0);
		removeFilter:SetText("Remove");
		removeFilter:SetScript("OnClick", function(self, arg1)
			
		end);

		local selector = CreateFrame("Frame", nil, filtersFrame, "SettingsDropdownControlTemplate");
		selector:SetSize(130, 24);
		selector:SetPoint("CENTER", filtersFrame, "TOP", -65, -12);
		
		-- local nameInput = CreateFrame("EditBox", nil, filtersFrame, "InputBoxTemplate");
		-- nameInput:SetSize(200, 20);
		-- nameInput:SetPoint("LEFT", filtersFrame, "TOPLEFT", 0, -60);

		local enabledCheckbox = CreateFrame("CheckButton", nil, filtersFrame, "UICheckButtonTemplate");
		enabledCheckbox:SetSize(20, 20);
		enabledCheckbox:SetPoint("LEFT", filtersFrame, "TOPLEFT", 0, -80);
		local fuzzyCheckbox = CreateFrame("CheckButton", nil, filtersFrame, "UICheckButtonTemplate");
		fuzzyCheckbox:SetSize(20, 20);
		fuzzyCheckbox:SetPoint("LEFT", filtersFrame, "TOPLEFT", 0, -100);

		local minRaritySlider = CreateFrame("Slider", nil, filtersFrame, "SettingsListElementTemplate");
		local maxnRaritySlider = CreateFrame("Slider", nil, filtersFrame, "SettingsListElementTemplate");
		

	end

	Settings.RegisterAddOnCategory(category);
end