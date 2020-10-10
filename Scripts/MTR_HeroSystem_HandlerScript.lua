-- MTR_HeroSystem_HandlerScript
-- Author: Angelo
-- DateCreated: 2020-08-15 11:05:23
--------------------------------------------------------------

--At Game Initializing: (doesn't need event, put in main body)
	--if a Leader with a trait associated with a unit that has a tag "CLASS_HERO" then add that Leader to a table "tValidPlayers"
	--GONNA BE A LOT OF QUERIES FOR THIS, BUT RUNS ON INIT, DOES NOT RUN ON ANY EVENT, SHOULDN'T BE AN ISSUE
	
--At Unit Death of Valid Player:
	--if unit is on ValidUnitList (All units on this list were checked for tag "CLASS_HERO")
	--then refer to table "Unit_BuildingPrereqs" and CONSTRUCT the building for that unit in the civilization's capital (intentionalally specific to this)

--At Unit Trained of Valid Player:
	--if said unit has tag "CLASS_HERO"
	--then refer to table "Unit_BuildingPrereqs" and DECONSTRUCT the building for that unit in the civilization's capital (intentionalally specific to this)
	
	
	
--EXCESSIVE, SHOULD ONLY BE MADE IF FAILSAFE NEEDED INCASE BUILDING SOMEHOW DELETES ITSELF(Building stays in that city even if conquered, need to retake to get Lyn back)
--NOTE: Doing this as I couldn't figure out how to make Player start with Lyn and it's safer to do this anyway
--At turn end
	--for each valid player:
		--if Hero is dead AND Hero's Building does not exist in the ORIGINAL capital 
			--construct building in the capital for that player
		
--====================================================================
--UTILITIES
--====================================================================
function MTR_getValidUnits(sTag)
	--print("MTR_getValidUnits");
	--print(sTag);
	tTableOutput = {};
		local tQueryUnits = DB.Query("SELECT * FROM TypeTags WHERE Type IN (SELECT UnitType FROM Units) AND (Tag = '" .. sTag .. "')");
		for k, v in ipairs(tQueryUnits) do
			--print(v.Type);
			--tTableOutput to be filled out as so tTableOutput["UNIT_MTR_LYNDIS_UH"] = "BUILDING_MTR_LYNDIS_UH";
			local tQueryBuildings = DB.Query("SELECT Unit, PrereqBuilding FROM Unit_BuildingPrereqs WHERE (Unit = '".. v.Type .."')"); --Puts UnitType (i.e. UNIT_MTR_LYNDIS_UH) and grabs building (i.e. BUILDING_MTE_LYNDIS_UH)
			
			for a, b in ipairs(tQueryBuildings) do
				local sBuilding = b.PrereqBuilding;
				--print(sBuilding);
				tTableOutput[v.Type] = sBuilding;
				--print(v.Type);
				--print(tTableOutput[v.Type]);
			end
		end
	--print("returning");
	return tTableOutput;
end

function MTR_getValidPlayers(tInput)
	--print("MTR_getValidPlayers");
	local tValidPlayerTypes = {}; --key is LeaderType, value is UnitType
	local tValidPlayerIds = {}; --key is playerId, value is LeaderType
	
	--print(tInput);
	for k, v in pairs(tInput) do --ipairs didnt work this time? switched to pairs as ipairs just got skipped over
		--print("tInput Loop");
		--print(k); --unit (key)
		--print(v); --building (value)
		local tQueryTrait = DB.Query("SELECT UnitType, TraitType FROM Units WHERE (UnitType = '".. k .."')");
		for a, b in ipairs(tQueryTrait) do
			--print(b.TraitType);
			local tQueryLeader = DB.Query("SELECT LeaderType, TraitType FROM LeaderTraits WHERE (TraitType = '".. b.TraitType .."')");
			for c, d in ipairs(tQueryLeader) do
				tValidPlayerTypes[d.LeaderType] = k;
				--print(tValidPlayerTypes[d.LeaderType]);
			end;
		end
	end

	for k, v in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		--print("PlayerManager ID Loop");
		--print(v);
		local leaderType = PlayerConfigurations[v]:GetLeaderTypeName();
		--print(leaderType);
		if tValidPlayerTypes[leaderType] ~= nil then
			--print("exists in tValidPlayerTypes, assigning it's value  to tValidPlayerIds[v]");
			--print("v: " .. v)
			--print("tValidPlayerTypes[leaderType]: " .. tValidPlayerTypes[leaderType]);
			tValidPlayerIds[v] = tValidPlayerTypes[leaderType];
		end
	end
	--print("returning...");
    return tValidPlayerIds;
end

function MTR_ConvertNumToBinary(iNumber)
	--print("Convert Number to Binary" .. iNumber);
    -- returns a table of bits
	local iBits = 8;
	
    local tTable={} -- will contain the bits
    for b=iBits,1,-1 do
        rest=math.fmod(iNumber,2)
        tTable[b]=rest
        iNumber=(iNumber-rest)/2
    end
	
	--print(table.concat(tTable));
	
    if iNumber==0 then 
		--print(tTable);
		return tTable;	
	else 
		--print("Not enough bits to represent this number");
	end
end

--====================================================================
--Constants
--====================================================================

	local sClass = "CLASS_HERO";
	local tValidUnitList = MTR_getValidUnits(sClass); --Table containing all UnitTypes that are a class list in tValidUnitClassList. 					Returns BuildingType when given UnitType
	local tValidPlayerList = MTR_getValidPlayers(tValidUnitList); --Key is PlayerID, returns UnitType based on what MTR_getValidPlayers returns. 		Returns UnitType when given playerId (NOT LeaderType)

	local tAbilityListMelee = --this is for use with the binary result of MTR_ConvertNumToBinary in order to adjust the abilities of the Unit accordingly 
	{
	"ABILITY_MTR_HEROSCALING_128",
	"ABILITY_MTR_HEROSCALING_64",
	"ABILITY_MTR_HEROSCALING_32",
	"ABILITY_MTR_HEROSCALING_16",
	"ABILITY_MTR_HEROSCALING_8",
	"ABILITY_MTR_HEROSCALING_4",
	"ABILITY_MTR_HEROSCALING_2",
	"ABILITY_MTR_HEROSCALING_1"
	}
	local tAbilityListRanged = 
	{
	"ABILITY_MTR_HEROSCALING_RANGED_128",
	"ABILITY_MTR_HEROSCALING_RANGED_64",
	"ABILITY_MTR_HEROSCALING_RANGED_32",
	"ABILITY_MTR_HEROSCALING_RANGED_16",
	"ABILITY_MTR_HEROSCALING_RANGED_8",
	"ABILITY_MTR_HEROSCALING_RANGED_4",
	"ABILITY_MTR_HEROSCALING_RANGED_2",
	"ABILITY_MTR_HEROSCALING_RANGED_1"
	}

	local iEraScaling = 1.35; --This is how much "Combat" and "RangedCombat" Values get multiplied by per era
	
	
--====================================================================
--Custom Functions (Utilities the depend on the constants above)
--====================================================================
function MTR_HeroSystem_BuildBuildingInCapital(pPlayer, sType)
	--print("MTR_HeroSystem_BuildBuildingInCapital()");
	
	local pCapital = pPlayer:GetCities():GetCapitalCity();
	local pCapitalBuildings = pCapital:GetBuildings();
	
	local sBuilding = tValidUnitList[sType];
	--print("sBuilding: " .. sBuilding);
	local iBuildingIndex = GameInfo.Buildings[sBuilding].Index; --THIS IS FOR THE INDEX IN THE DATABASE (VERY IMPORTANT DISTINCTION)
	--print(sBuilding .. " has index of: " .. iBuildingIndex);
	--needed to create the dummy buildings for some reason
	local pPlot = Map.GetPlot(pCapital:GetX(), pCapital:GetY());
	local iPlot = pPlot:GetIndex();
	
	if (pCapitalBuildings:HasBuilding(iBuildingIndex) == false) then --Makes sure building doesnt exist
		--print("Adding Building to Capital: " .. sBuilding);
		pCapital:GetBuildQueue():CreateIncompleteBuilding(iBuildingIndex, iPlot, 100);
	end
	
end

function MTR_HeroSystem_DestroyBuildingInCapital(pPlayer, sType)
	--print("MTR_HeroSystem_DestroyBuildingInCapital()");
	
	local pCapital = pPlayer:GetCities():GetCapitalCity();
	local pCapitalBuildings = pCapital:GetBuildings();
	
	local sBuilding = tValidUnitList[sType];
	--print("sBuilding: " .. sBuilding);
	local iBuildingIndex = GameInfo.Buildings[sBuilding].Index; --THIS IS FOR THE INDEX IN THE DATABASE (VERY IMPORTANT DISTINCTION)
	--print(sBuilding .. " has index of: " .. iBuildingIndex);
	
	if (pCapitalBuildings:HasBuilding(iBuildingIndex) == true) then --Makes sure building exists
		--print("Removing Building from Capital: " .. sBuilding);
		pCapitalBuildings:RemoveBuilding(iBuildingIndex);
	end
	
end

--=====================================================================================
--Adjusts a given unit so it gains a bonus of "iBonus" through the abilities listed in tAbilityListMelee
function MTR_UHSystem_GrantUnitMeleeBonus(pUnit, iBonus)
	--print("MTR_UHSystem_GrantUnitMeleeBonus()");
	
	local iUnitType = pUnit:GetType();
	--local sUnitType = GameInfo.Units[iUnitType].UnitType; --This is the String for the UnitType

	local tBinaryMelee = MTR_ConvertNumToBinary(iBonus);
	
	local pUnitAbility = pUnit:GetAbility(); --Assuming this returns all abilities similar to the :members() function
	
	for key, value in ipairs(tBinaryMelee) do --loops through each value of the binary number and uses "1" to turn it on and "0" to turn it off for each ability so it totals the actual number
	
		--print("Key: " .. key);
		local sAbility = tAbilityListMelee[key];
		--print(sAbility);
		local iCurrentCount = pUnitAbility:GetAbilityCount(sAbility);
		--print("iCurrentCount: " .. iCurrentCount);
		
		if (iCurrentCount<=0 and value==1) then --if ability is needed and it isn't on
			--print("Adding Stack")
			pUnitAbility:ChangeAbilityCount(sAbility,1);
		end
		if (iCurrentCount>0 and value==0) then --if ability is unneeded and it is on
			--print("Removing Stack")
			pUnitAbility:ChangeAbilityCount(sAbility,-1);
		end
	
		--print("Done altering ability")
		local iCurrentCount = pUnitAbility:GetAbilityCount(sAbility);
		--print("iCurrentCount: " .. iCurrentCount);
	end
end

--=====================================================================================
--Adjusts a given unit so it gains a ranged-initiation bonus of "iBonus" through the abilities listed in tAbilityListRanged
function MTR_UHSystem_GrantUnitRangedBonus(pUnit, iBonus)
	--print("MTR_UHSystem_GrantUnitRangedBonus()");
	
	local iUnitType = pUnit:GetType();
	--local sUnitType = GameInfo.Units[iUnitType].UnitType; --This is the String for the UnitType

	local tBinaryRanged = MTR_ConvertNumToBinary(iBonus);
	
	local pUnitAbility = pUnit:GetAbility(); --Assuming this returns all abilities similar to the :members() function
	
	for key, value in ipairs(tBinaryRanged) do --loops through each value of the binary number and uses "1" to turn it on and "0" to turn it off for each ability so it totals the actual number
	
		--print("Key: " .. key);
		local sAbility = tAbilityListRanged[key];
		--print(sAbility);
		local iCurrentCount = pUnitAbility:GetAbilityCount(sAbility);
		--print("iCurrentCount: " .. iCurrentCount);
		
		if (iCurrentCount<=0 and value==1) then --if ability is needed and it isn't on
			--print("Adding Stack")
			pUnitAbility:ChangeAbilityCount(sAbility,1);
		end
		if (iCurrentCount>0 and value==0) then --if ability is unneeded and it is on
			--print("Removing Stack")
			pUnitAbility:ChangeAbilityCount(sAbility,-1);
		end
	
		--print("Done altering ability")
		local iCurrentCount = pUnitAbility:GetAbilityCount(sAbility);
		--print("iCurrentCount: " .. iCurrentCount);
	end
end

function MTR_UHSystem_ProcessAbilities(pUnit)
	--print("MTR_UHSystem_ProcessAbilities()");
	
	local iEra = Game.GetEras():GetCurrentEra(); --Returns the era the game currently is in (i.e. 0 for ancient) THIS STARTS AT '0' UNLIKE IPAIRS WHICH AS FAR AS I CAN SEE STARTS AT '1'
	--print("Era " ..iEra);
	
	local iUnitType = pUnit:GetType(); --Index for the unit
	--local sUnitType = GameInfo.Units[iUnitType].UnitType; --This is the String for the UnitType
	local iUnitBaseMeleeStrength = GameInfo.Units[iUnitType].Combat; --Melee Combat Value
	local iUnitBaseRangedStrength = GameInfo.Units[iUnitType].RangedCombat; --Ranged Combat Value
	
	local iMeleeTarget = math.floor(iUnitBaseMeleeStrength*(iEraScaling^iEra));
	--print("iMeleeTarget" .. iMeleeTarget);
	local iRangedTarget = math.floor(iUnitBaseRangedStrength*(iEraScaling^iEra));
	--print("iRangedTarget" .. iRangedTarget);
	
	local iMeleeBonus = iMeleeTarget-iUnitBaseMeleeStrength; --This accounts for what the unit has as its base strength
	local iRangedBonus = iRangedTarget-iUnitBaseRangedStrength; --This accounts for what the unit has as its base rangedstrength
	
	MTR_UHSystem_GrantUnitMeleeBonus(pUnit, iMeleeBonus);
	MTR_UHSystem_GrantUnitRangedBonus(pUnit, iRangedBonus);
end


	
--====================================================================
--Runs at UnitRemovedFromMap
--====================================================================
function MTR_HeroSystem_UnitRemovedFromMap(iPlayerID, iUnitID)
	if (tValidPlayerList[iPlayerID] == nil) then return end --abort if not ValidPlayer
	
	local pPlayer = Players[iPlayerID];
	local pUnit = pPlayer:GetUnits():FindID(iUnitID);

	local iUnitType = pUnit:GetType();
	local sUnitType = GameInfo.Units[iUnitType].UnitType;

    if (tValidUnitList[sUnitType] == nil) then return end --abort if not valid UnitType
	--print("HERO DIED: " .. sUnitType);
	
	MTR_HeroSystem_BuildBuildingInCapital(pPlayer, sUnitType)
end


--====================================================================
--Runs at UnitAddedToMap
--====================================================================
function MTR_HeroSystem_UnitAddedToMap(iPlayerID, iUnitID)
	if (tValidPlayerList[iPlayerID] == nil) then return end --abort if not ValidPlayer
	
	local pPlayer = Players[iPlayerID];
	local pUnit = pPlayer:GetUnits():FindID(iUnitID);

	local iUnitType = pUnit:GetType();
	local sUnitType = GameInfo.Units[iUnitType].UnitType;

    if (tValidUnitList[sUnitType] == nil) then return end --abort if not valid UnitType
	--print("HERO TRAINED: " .. sUnitType);
	
	MTR_HeroSystem_DestroyBuildingInCapital(pPlayer, sUnitType);
	MTR_UHSystem_ProcessAbilities(pUnit); --The Unit spawns with all abilities enabled so it has +255 strength the moment it spawns, this runs the process to properly scale it the second its created.
end	

--====================================================================
--Runs at TurnDeactivated
--====================================================================
function MTR_HeroSystem_PlayerTurnDeactivated(iPlayerID)
	if (tValidPlayerList[iPlayerID]==nil) then return end --abort if not ValidPlayer
	
	local pPlayer = Players[iPlayerID];
	
	local sUnit = tValidPlayerList[iPlayerID];
	local sBuilding = tValidUnitList[sUnit];
	local iBuildingIndex = GameInfo.Buildings[sBuilding].Index; --THIS IS FOR THE INDEX IN THE DATABASE (VERY IMPORTANT DISTINCTION)
	
	for i, pUnit in pPlayer:GetUnits():Members() do
		local iUnitType = pUnit:GetType();
		local sUnitType = GameInfo.Units[iUnitType].UnitType;
		if (sUnitType == sUnit) then
			return
		end
	end
	
	for i, pCity in pPlayer:GetCities():Members() do
		if pCity:GetBuildings():HasBuilding(iBuildingIndex) == true then 
			return 
		end --abort if city found with building
	end
	
	MTR_HeroSystem_BuildBuildingInCapital(pPlayer, sUnit);
end

--====================================================================
--Runs at UnitMoved (FOR TESTING PURPOSES)
--====================================================================
function MTR_HeroSystem_UnitMoved(iPlayerID, iUnitID, iX, iY, locallyVisible, stateChange)
	--print("MTR_HeroSystem_UnitMoved")
	
	if (tValidPlayerList[iPlayerID] == nil) then return end --abort if not ValidPlayer
	--print("Valid Player!")
	
	local pPlayer = Players[iPlayerID];
	local pUnit = pPlayer:GetUnits():FindID(iUnitID);
	local sType = GameInfo.Units[pUnit:GetType()].UnitType;
	--print("sType: " .. sType);
	
	if (tValidUnitList[sType] == nil) then return end --abort if not valid UnitType
	--print("Valid unit!");
	
	MTR_UHSystem_ProcessAbilities(pUnit);
end
	
	
	
	
--====================================================================
--Inputting Functions into the Game Events 
--====================================================================
--Events.UnitRemovedFromMap.Add(MTR_HeroSystem_UnitRemovedFromMap) --Removed due to errors clogging lua log, also unneeded as currently the script checks at the beginning of a turn anyway for if a Hero is dead
Events.UnitAddedToMap.Add(MTR_HeroSystem_UnitAddedToMap)

Events.UnitMoved.Add(MTR_HeroSystem_UnitMoved);

Events.PlayerTurnDeactivated.Add(MTR_HeroSystem_PlayerTurnDeactivated);