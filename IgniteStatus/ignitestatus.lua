--[[

    IGNITESTATUS v1.0

]]--

------------------------------------------------------------------

-- Local Variables for UI data
local TotalDmg = 0;
local IgniteCharge = 0;
local ScorchCharge = 0;
local IgniteOwner = "";
local TotalTicks = 0;
local CurTickDmg = 0;
local IgniteTime = 0;
local TrustedSenders = {};
local TickTable = {};
local CurrentTarget = "";

local DefaultISOptions = {
	["ISVersion"] = IGNITESTATUS_VERSION;
	["ISScale"] = 1;
	["ISPrint"] = 1;
	["ISOn"]    = 1;
	["Debug"]   = 0;
	["ISLocked"]= 0;
};

-- Option Variables


----------------------------------
-- Loading Function
----------------------------------
function IGNITESTATUS_OnLoad()

    -- Register events
    this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE");
    this:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER"); 
    this:RegisterEvent("VARIABLES_LOADED");
    this:RegisterEvent("ADDON_LOADED");
    this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH");
    this:RegisterEvent("CHAT_MSG_ADDON");
    this:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE");
    this:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE");
    this:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE");
    this:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE");
    this:RegisterEvent("CHAT_MSG_IGNITESTATUS");

    -- Slash Commands
    SLASH_IGNITE1 = "/ignite";
    SLASH_IGNITE2 = "/is";

    SlashCmdList["IGNITE"] = IGNITESTATUS_SlashHandler;
    
    -- Set the random seed
    randomseed(random(0,2147483647)+(GetTime()*1000));
    
	
	-- Displays Welcome Msg
	DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_WELCOME);
	
	-- Can't be moved off the screen
	IGNITESTATUSFrame:SetClampedToScreen(true);

end

----------------------------------
-- Clone Options
----------------------------------
function IS_FreshOptions()
	ISOptions = {
	["ISVersion"] = DefaultISOptions.ISVersion;
	["ISScale"] = DefaultISOptions.ISScale;
	["ISPrint"] = DefaultISOptions.ISPrint;
	["ISOn"]    = DefaultISOptions.ISOn;
	["Debug"]   = 0;
	["ISLocked"]= 0;
	};
end

----------------------------------
-- Slash command function
----------------------------------
function IGNITESTATUS_SlashHandler(msg)

	local _, _, command, args = string.find(msg, "(%w+)%s?(.*)");
	if(command) then
		command = strlower(command);
	else
		command = "";
	end

	if(command == "summary") then
		if(ISOptions.ISPrint == 0 ) then
			ISOptions.ISPrint = 1;
			DEFAULT_CHAT_FRAME:AddMessage("Enabled summary", 1, 1, 0);
		elseif(ISOptions.ISPrint == 1 ) then
			ISOptions.ISPrint = 0;
			DEFAULT_CHAT_FRAME:AddMessage("Disabled summary", 1, 1, 0);
		end
	elseif(command == "help") then
	    DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_SLASHHELP1);
	    DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_SLASHHELP2);
	    DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_SLASHHELP3);
	    DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_SLASHHELP4);
	    DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_SLASHHELP5);
	elseif(command == "scale") then
		if(tonumber(args)) then
			local newscale = tonumber(args);
			IGNITESTATUSFrame:SetScale(newscale);
			ISOptions.ISScale  = newscale;
			IGNITESTATUSFrame:Show();
			DEFAULT_CHAT_FRAME:AddMessage("Scale is now "..newscale, 1, 1, 0);
		end
	elseif(command == "reset") then
		IGNITESTATUS_ClearData();
		IGNITESTATUS_UpdateDisplay();
		DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_RESET);
	elseif(command == "lock") then
		if(ISOptions.ISLocked == 1) then
			DEFAULT_CHAT_FRAME:AddMessage("Disabled lock", 1, 1, 0);
			ISOptions.ISLocked = 0;
		else
			DEFAULT_CHAT_FRAME:AddMessage("Enabled lock", 1, 1, 0);
			ISOptions.ISLocked = 1;
		end
	elseif(command == "debug") then
		if( IGNITESTATUSFrame:IsVisible() and ISOptions.Debug == 0 ) then
			ISOptions.Debug = 1;
			DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_DEBUGON);
		else
			ISOptions.Debug = 0;
			DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_DEBUGOFF);
		end
	elseif(command == "color") then
		if( ColorPickerFrame:IsVisible()) then
			ColorPickerFrame:Hide();
		else
			ColorPickerFrame:Show();
		end
	elseif(command == "") then
		if( ISOptions.ISOn == 1 ) then
            IGNITESTATUS_ToggleHidden();
		else
			ISOptions.ISOn = 1;
            DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_ON);
            IGNITESTATUSFrame:Show();
		end
	end
end

----------------------------------
-- Event Handler
----------------------------------
function IGNITESTATUS_OnEvent()
    if ( ISOptions ~= nil ) then
    	if ( not ISOptions.ISOn ) then
        	return; 
    	end
    end 

    -- Parse the Event
    IGNITESTATUS_Parse(event, arg1);   

end


----------------------------------
-- Event Parse Function
----------------------------------
function IGNITESTATUS_Parse(event, arg1)

    -- If no argument, return
    if (not arg1) then
        return;
    end
    
    -- DEBUG
    if(ISOptions ~= nil) then
    	if( ISOptions.Debug == 1 and arg1 ~= "CTRA" and arg1 ~= "AddonReq" ) then
			ChatFrame3:AddMessage( "Event " .. event .. " : " .. arg1 );
		end
	end

    if (UnitName("target") ~= nil) then
        CurrentTarget = UnitName("target");
    end
    
    local searchStr, dmg, resist;
    
    -- if we have a target
    if (CurrentTarget ~= nil) then

	local SearchTarget = string.gsub(CurrentTarget, '%-', '%%-');

        -- sync update
        if ( event == "CHAT_MSG_ADDON" and arg1 == CHAT_MSG_IGNITESTATUS and (arg3 == "RAID" or arg3 == "PARTY")) then
            IGNITESTATUS_GetUpdate(arg2);
            return;
        
        -- test for crit timer
        elseif (event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_SPELL_PARTY_DAMAGE" or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE" or event == "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE") then
            -- My Damage Resist
            searchStr = "crits " .. SearchTarget .. IGNITESTATUS_EVENT_FIRECRITR_SEARCH;
            
            -- Look for Ignite Damage Resist
            for dmg, resist in string.gfind(arg1, searchStr ) do
                myMsg = "FC " ..  UnitName("player") .. "," .. CurrentTarget;
                IGNITESTATUS_SendUpdate(myMsg);
                return;
            end
            
            -- My Damage
            searchStr = "crits " .. SearchTarget .. IGNITESTATUS_EVENT_FIRECRIT_SEARCH;
            
            -- Look for Ignite Damage
            for dmg in string.gfind(arg1, searchStr ) do
                myMsg = "FC " ..  UnitName("player") .. "," .. CurrentTarget;
                IGNITESTATUS_SendUpdate(myMsg);
                return;
            end        
        
        -- Monster Died
        elseif (event == "CHAT_MSG_COMBAT_HOSTILE_DEATH") then
            
            -- Get Mob Name
            local _, _, mobName = string.find(arg1, IGNITESTATUS_DEATH_REGEXP);
            if (not mobName) then 
                return; 
            end

            -- Make sure its our target
            if (mobName == CurrentTarget) then    
                myMsg = "SC " ..  UnitName("player") .. "," .. mobName .. ",0";
                IGNITESTATUS_SendUpdate(myMsg);
                myMsg = "DE " ..  UnitName("player") .. "," .. mobName;
                IGNITESTATUS_SendUpdate(myMsg);
            end
            return;
        
        --Addon Loaded
        elseif (event == "ADDON_LOADED") then
			if (strlower(arg1) == "ignitestatus") then
				IS_Vars_Loaded = 1;
				if ( ISOptions == nil ) then
					IS_FreshOptions();
				elseif (  ISOptions["ISVersion"] ~= IGNITESTATUS_VERSION ) then
					IS_FreshOptions();
				end
			end
			-- Display the main screen
    		if ( ISOptions ~= nil ) then
    			if ( ISOptions.ISOn == 1) then
    				IGNITESTATUSFrame:Show();
    			end
    		end
		elseif (event == "VARIABLES_LOADED") then
			if (not IS_Vars_Loaded) then
				IS_Vars_Loaded = 1;
				if ( ISOptions == nil or ISOptions["ISVersion"] ~= IGNITESTATUS_VERSION) then
					DEFAULT_CHAT_FRAME:AddMessage("Fresh Options2");
					IS_FreshOptions();
				end
			end
			
			-- Display the main screen
    		if ( ISOptions ~= nil ) then
    			if ( ISOptions.ISOn == 1) then
    				IGNITESTATUSFrame:Show();
    			end
    		end

        -- Ignite/Scorch Charge or Dmg tick
        elseif (event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE") then

            -- setup the search string
            searchStr = SearchTarget .. IGNITESTATUS_EVENT_SEARCH;

            -- Look for an Ignite or Scorch
            local eventName;
            for eventName in string.gfind(arg1, searchStr ) do

                -- Scorches
                if (eventName == IGNITESTATUS_EVENT_SCORCH1) then
                    myMsg = "SC " ..  UnitName("player") .. "," .. CurrentTarget .. ",1";
                    IGNITESTATUS_SendUpdate(myMsg);
                elseif (eventName == IGNITESTATUS_EVENT_SCORCH2) then
                    myMsg = "SC " ..  UnitName("player") .. "," .. CurrentTarget .. ",2";
                    IGNITESTATUS_SendUpdate(myMsg);
                elseif (eventName == IGNITESTATUS_EVENT_SCORCH3) then
                    myMsg = "SC " ..  UnitName("player") .. "," .. CurrentTarget .. ",3";
                    IGNITESTATUS_SendUpdate(myMsg);
                elseif (eventName == IGNITESTATUS_EVENT_SCORCH4) then
                    myMsg = "SC " ..  UnitName("player") .. "," .. CurrentTarget .. ",4";
                    IGNITESTATUS_SendUpdate(myMsg);
                elseif (eventName == IGNITESTATUS_EVENT_SCORCH5) then
                    myMsg = "SC " ..  UnitName("player") .. "," .. CurrentTarget .. ",5";
                    IGNITESTATUS_SendUpdate(myMsg);

                -- Ignites
                elseif (eventName == IGNITESTATUS_EVENT_IGNITE1) then
                    myMsg = "IG " ..  UnitName("player") .. "," .. CurrentTarget .. ",1";
                    IGNITESTATUS_SendUpdate(myMsg);
                elseif (eventName == IGNITESTATUS_EVENT_IGNITE2) then
                    myMsg = "IG " ..  UnitName("player") .. "," .. CurrentTarget .. ",2";
                    IGNITESTATUS_SendUpdate(myMsg);
                elseif (eventName == IGNITESTATUS_EVENT_IGNITE3) then
                    myMsg = "IG " ..  UnitName("player") .. "," .. CurrentTarget .. ",3";
                    IGNITESTATUS_SendUpdate(myMsg);
                elseif (eventName == IGNITESTATUS_EVENT_IGNITE4) then
                    myMsg = "IG " ..  UnitName("player") .. "," .. CurrentTarget .. ",4";
                    IGNITESTATUS_SendUpdate(myMsg);
                elseif (eventName == IGNITESTATUS_EVENT_IGNITE5) then
                    myMsg = "IG " ..  UnitName("player") .. "," .. CurrentTarget .. ",5";
                    IGNITESTATUS_SendUpdate(myMsg);
                end                    
                return;
            end    

            -- My Damage Resist
            searchStr = SearchTarget .. IGNITESTATUS_EVENT_IGNITEDMGR_SEARCH;
            
            -- Look for Ignite Damage Resist
            for dmg, resist in string.gfind(arg1, searchStr ) do
                myMsg = "TK " ..  UnitName("player") .. "," .. CurrentTarget .. "," .. UnitName("player") .. "," .. (TotalTicks + 1) .. "," .. dmg;
                IGNITESTATUS_SendUpdate(myMsg);
                return;
            end
            
            -- My Damage
            searchStr = SearchTarget .. IGNITESTATUS_EVENT_IGNITEDMG_SEARCH;
            
            -- Look for Ignite Damage
            for dmg in string.gfind(arg1, searchStr ) do
                myMsg = "TK " ..  UnitName("player") .. "," .. CurrentTarget .. "," .. UnitName("player") .. "," .. (TotalTicks + 1) .. "," .. dmg;
                IGNITESTATUS_SendUpdate(myMsg);
                return;
            end

            -- Someone Else Damage Resist
            searchStr = SearchTarget .. IGNITESTATUS_EVENT_IGNITEDMGR_OTHER_SEARCH;
            
            -- Look for Ignite Damage Resist
            for dmg, who, resist in string.gfind(arg1, searchStr ) do
                if (who) then
                    myMsg = "TK " ..  UnitName("player") .. "," .. CurrentTarget .. "," .. who .. "," .. (TotalTicks + 1) .. "," .. dmg;
                    IGNITESTATUS_SendUpdate(myMsg);
                end                    
                return;
            end
            
            -- Someone Else Damage
            searchStr = SearchTarget .. IGNITESTATUS_EVENT_IGNITEDMG_OTHER_SEARCH;
            
            -- Look for Ignite Damage
            for dmg, who in string.gfind(arg1, searchStr ) do
                if (who) then
                    myMsg = "TK " ..  UnitName("player") .. "," .. CurrentTarget .. "," .. who .. "," .. (TotalTicks + 1) .. "," .. dmg;
                    IGNITESTATUS_SendUpdate(myMsg);
                end                    
                return;
            end

        -- Ignite or Scorch Fade
        elseif (event == "CHAT_MSG_SPELL_AURA_GONE_OTHER") then

            -- setup the search string
            searchStr = IGNITESTATUS_EVENT_FADE_SEARCH .. SearchTarget .. ".";
            if( ISOptions.Debug == 1) then
				ChatFrame3:AddMessage( "Ignite call target " .. CurrentTarget,1,1,0);
			end
            
            -- Look for an Ignite or Scorch
            for eventName in string.gfind(arg1, searchStr ) do

                -- Scorch Fade
                if (eventName == IGNITESTATUS_EVENT_SCORCH_FADE) then
                    myMsg = "SC " ..  UnitName("player") .. "," .. CurrentTarget .. ",0";
                    IGNITESTATUS_SendUpdate(myMsg);

                -- Ignite Fade
                elseif (eventName == IGNITESTATUS_EVENT_IGNITE_FADE) then
                    myMsg = "IF " ..  UnitName("player") .. "," .. CurrentTarget;
                    IGNITESTATUS_SendUpdate(myMsg);
                end                    
                return;
            end
        end
    end
end
    
----------------------------------
-- Update UI With Values
----------------------------------
function IGNITESTATUS_UpdateDisplay()
    -- Set Text on UI    
    igniteFrame_IGNITESTATUS_vOwner:SetText("Ignite Owner: |cff20ff20" .. IgniteOwner);
    igniteFrame_IGNITESTATUS_vTick:SetText("# of Ticks: |cffff2020" .. TotalTicks);
    igniteFrame_IGNITESTATUS_vTotDmg:SetText("Total Damage: |cffff2020" .. TotalDmg);
    igniteFrame_IGNITESTATUS_vDmg:SetText("Current Damage: |cffff2020" .. CurTickDmg);
    igniteFrame_IGNITESTATUS_vScorch:SetText("Fire Vul: |cffff2020" .. ScorchCharge);
    igniteFrame_IGNITESTATUS_vTarget:SetText("Target: |cffff2020" .. CurrentTarget);

end

----------------------------------
-- Send Sync Msg Updates
----------------------------------
function IGNITESTATUS_SendUpdate(msg)
	-- DEBUG
    if( ISOptions.Debug == 1) then
		ChatFrame3:AddMessage( "Message: " .. msg );
	end
	if( GetNumPartyMembers()>0 or GetNumRaidMembers()>0 ) then
		SendAddonMessage(CHAT_MSG_IGNITESTATUS, msg, "RAID");
	else
		IGNITESTATUS_GetUpdate(msg);
	end
end
----------------------------------
-- Get Sync Msg Updates
----------------------------------
function IGNITESTATUS_GetUpdate(arg1)
	local _, _, command, args = string.find(arg1, "(%w+)%s?(.*)");
    
    -- Scorch Update
    if (command == "SC") then
        local _, _, sender, tgtname, value = string.find(arg1, IGNITESTATUS_SYNC_SC);
        if (CurrentTarget == tgtname) then
            ScorchCharge = tonumber(value);
            IGNITESTATUS_UpdateDisplay();
        end
        
    -- Ignite Update
    elseif (command == "IG") then
        local _, _, sender, tgtname, value = string.find(arg1, IGNITESTATUS_SYNC_IG);
        if (CurrentTarget == tgtname) then
            -- is this the first ignite for us?
            if (IgniteCharge == 0) then
            	-- DEBUG
    			if( ISOptions.Debug == 1) then
					ChatFrame3:AddMessage( "First Ignite.",1,1,0);
				end
                IGNITESTATUS_NewIgnite();
            end
            -- Set Data if different
            if (tonumber(value) ~= IgniteCharge) then
                tinsert(TrustedSenders,sender);
                IgniteCharge = tonumber(value);
                IGNITESTATUS_StartIgniteTimer();
                IGNITESTATUS_UpdateDisplay();
            end
        end

    -- Fire Crit
    elseif (command == "FC") then
        local _, _, sender, tgtname = string.find(arg1, IGNITESTATUS_SYNC_FC);
        if (CurrentTarget == tgtname) then
            IGNITESTATUS_StartIgniteTimer();
        end
        
    -- Ignite Fade
    elseif (command == "IF") then
        local _, _, sender, tgtname = string.find(arg1, IGNITESTATUS_SYNC_IF);
        if( ISOptions.Debug == 1) then
				ChatFrame3:AddMessage( "Sending Ignite Fade for " .. tgtname,1,1,0);
			end
        if (CurrentTarget == tgtname) then
        	-- DEBUG
    		if( ISOptions.Debug == 1) then
				ChatFrame3:AddMessage( "Ignite fades.",1,1,0);
			end
            IGNITESTATUS_DisplayIgniteSummary();
            IGNITESTATUS_NewIgnite();
            IGNITESTATUS_UpdateDisplay();
        end    

    -- Mob Dead
    elseif (command == "DE") then
        local _, _, sender, tgtname = string.find(arg1, IGNITESTATUS_SYNC_DE);
        if (CurrentTarget == tgtname) then
       		-- DEBUG
    		if( ISOptions.Debug == 1) then
				ChatFrame3:AddMessage( "Mob Dies.",1,1,0);
			end
            IGNITESTATUS_DisplayIgniteSummary();
            IGNITESTATUS_ClearData();
            IGNITESTATUS_UpdateDisplay();
        end
                    
    -- Ignite Tick Damage
    elseif (command == "TK") then
        local _, _, sender, tgtname, owner, ticknum, value = string.find(arg1, IGNITESTATUS_SYNC_TK);
        if (CurrentTarget == tgtname) then
        
            -- Check to see if this is a trusted sender
            for k,v in TrustedSenders do
                if (v == sender) then
                
                    -- Search Flag
                    found = false;

                    -- Update Old Data
                    for x,y in TickTable do
                        if (x == tonumber(ticknum)) then
                            found = true;
                            if (tonumber(value) < TickTable[x]) then
                                TickTable[x] = tonumber(value);
                            end
                            break;
                        end
                    end
                    
                    -- Add New Data
                    if (found == false) then
                        tinsert(TickTable,tonumber(value));      
                    end
                    
                    IgniteOwner = owner;
                    TotalTicks = getn(TickTable);
                    CurTickDmg = tonumber(value);
                    IGNITESTATUS_CalculateTotalDamage();
                    IGNITESTATUS_UpdateDisplay();
                    return;             
                end
            end
        end
    end
end

----------------------------------
-- Calculates the total damage
----------------------------------
function IGNITESTATUS_CalculateTotalDamage()
    TotalDmg = 0;
    for k,v in TickTable do
        TotalDmg = TotalDmg + v;
    end
end

----------------------------------
-- Display Ignite Summary Function
----------------------------------
function IGNITESTATUS_DisplayIgniteSummary()
    IGNITESTATUS_CalculateTotalDamage();
    if (TotalTicks > 0) then
        myStr = "-- Last: |cffff0000" .. IgniteOwner .. "|cffffffff (" .. TotalTicks .. " / " .. CurTickDmg .. ") - |cffff0000" .. TotalDmg .. " |cffffffffTotal";
        igniteFrame_IGNITESTATUS_Last:SetText(myStr);
        if ( ISOptions.ISPrint == 1) then
            DEFAULT_CHAT_FRAME:AddMessage(myStr);
        end
    end
end

----------------------------------
-- Clear Target Name
----------------------------------
function IGNITESTATUS_ClearTarget()
	CurrentTarget = "";
end

----------------------------------
-- Clear Data Function
----------------------------------
function IGNITESTATUS_ClearData()
    IgniteOwner = "";
    TotalTicks = 0;
    TotalDmg = 0;
    CurTickDmg = 0;
    IgniteTime = 0;
    IGNITESTATUS_SetIgniteTimer(0);
    TrustedSenders = {};
    TickTable = {};
    IgniteCharge = 0;
    ScorchCharge = 0;
	CurrentTarget = "";
end

----------------------------------
-- Clear Data for new ignite
----------------------------------
function IGNITESTATUS_NewIgnite()
	IgniteOwner = "";
    TotalTicks = 0;
    TotalDmg = 0;
    CurTickDmg = 0;
    IgniteTime = 0;
    IGNITESTATUS_SetIgniteTimer(0);
    TrustedSenders = {};
    TickTable = {};
    IgniteCharge = 0;
end

----------------------------------
-- Ignite Timer Start Function
----------------------------------
function IGNITESTATUS_StartIgniteTimer()
    IgniteTime = GetTime();
    IGNITESTATUS_SetIgniteTimer(4);
end

----------------------------------
-- Update Function for the Timer
----------------------------------
function IGNITESTATUS_TimerOnUpdate()
    if (IgniteTime > 0) then
        elapsed = GetTime() - IgniteTime;
        if (elapsed >= 0 and elapsed < 1) then
            IGNITESTATUS_SetIgniteTimer(4);
        elseif (elapsed >= 1 and elapsed < 2) then
            IGNITESTATUS_SetIgniteTimer(3);
        elseif (elapsed >= 2 and elapsed < 3) then
            IGNITESTATUS_SetIgniteTimer(2);
        elseif (elapsed >= 3 and elapsed < 4) then
            IGNITESTATUS_SetIgniteTimer(1);
        else
            IGNITESTATUS_SetIgniteTimer(0);
            IgniteTime = 0;
        end
    end
end

----------------------------------
-- Ignite Timer Set Function
----------------------------------
function IGNITESTATUS_SetIgniteTimer(theTime)
	if (theTime ~= 0) then
    	igniteFrame_IGNITESTATUS_vTimeLeft:SetText(theTime);
    else
    	igniteFrame_IGNITESTATUS_vTimeLeft:SetText("");
    end
end

----------------------------------
-- Frame moving
----------------------------------
function IGNITESTATUS_StartMoving()
	if(ISOptions.ISLocked == 0) then
		IGNITESTATUSFrame:StartMoving();
	end
end

----------------------------------
-- Frame sizing
----------------------------------
function IGNITESTATUS_StartSizing(pt)
	if(ISOptions.ISLocked == 0) then
		IGNITESTATUSFrame:StartSizing(pt);
	end
end


function IGNITESTATUS_ToggleHidden(sync)
    DEFAULT_CHAT_FRAME:AddMessage(IGNITESTATUS_TEXT_OFF);
    IGNITESTATUSFrame:Hide();
    ISOptions.ISOn = 0;
end

function IGNITESTATUS_ShowTooltip(msg)
    -- put the tool tip in the default position
    GameTooltip:SetOwner(this, "ANCHOR_TOPRIGHT");
    GameTooltip:SetText(msg, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
        NORMAL_FONT_COLOR.b, 1);
end
