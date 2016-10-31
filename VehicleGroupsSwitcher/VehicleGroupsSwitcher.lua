--
-- VehicleGroupsSwitcher (VeGS)
--
-- @author  Decker_MMIV (DCK)
-- @contact fs-uk.com, modcentral.co.uk, forum.farming-simulator.com
-- @date    2016-11-xx
--


VehicleGroupsSwitcher = {};
--
local modItem = ModsUtil.findModItemByModName(g_currentModName);
VehicleGroupsSwitcher.version = (modItem and modItem.version) and modItem.version or "?.?.?";
--
VehicleGroupsSwitcher.showingVeGS = false;
--
VehicleGroupsSwitcher.bigFontSize   = 0.020;
VehicleGroupsSwitcher.smallFontSize = 0.017;
VehicleGroupsSwitcher.hudOverlayPosSize = {0.2,0.1, 0.6,0.8}; -- X,Y,Width,Height
VehicleGroupsSwitcher.hudTitlePos       = {0.5,0.86} -- X(center),Y
VehicleGroupsSwitcher.hudColumnsPos     = {
   { 0.30, VehicleGroupsSwitcher.hudTitlePos[2] - VehicleGroupsSwitcher.bigFontSize }  -- Col1(x,y)
  ,{ 0.60, VehicleGroupsSwitcher.hudTitlePos[2] - VehicleGroupsSwitcher.bigFontSize }  -- Col2(x,y)
}

VehicleGroupsSwitcher.fontColor         = {1.0, 1.0, 1.0, 1.0}; -- white
VehicleGroupsSwitcher.fontSelectedColor = {1.0, 1.0, 0.3, 1.0}; -- yellowish
VehicleGroupsSwitcher.fontShadeColor    = {0.0, 0.0, 0.0, 1.0}; -- black
VehicleGroupsSwitcher.fontDisabledColor = {0.5, 0.5, 0.5, 1.0}; -- gray
--
VehicleGroupsSwitcher.groupNames = {}
VehicleGroupsSwitcher.groupsDisabled = {};
VehicleGroupsSwitcher.initialized = -1;
VehicleGroupsSwitcher.showError = false;
VehicleGroupsSwitcher.hasRefreshedOnJoin = nil;

-- Register as event listener
addModEventListener(VehicleGroupsSwitcher);

--
--
--

function VehicleGroupsSwitcher_Steerable_PostLoad(self, savegame)
  --if self.name == nil or self.realVehicleName == nil then
  --  self.name = Utils.getXMLI18N(self.xmlFile, "vehicle.name", "", "(unidentified vehicle)", self.customEnvironment);
  --end

    local storeItem = StoreItemsUtil.storeItemsByXMLFilename[self.configFileName:lower()];
    if storeItem ~= nil and storeItem.name ~= nil then
        local brand = ""
        if storeItem.brand ~= nil and storeItem.brand ~= "" then
            brand = tostring(storeItem.brand) .. " " 
        end
        self.modVeGS = self.modVeGS or {group=0,pos=0}
        self.modVeGS.vehicleName = brand .. tostring(storeItem.name);
    end
end
Steerable.postLoad = Utils.appendedFunction(Steerable.postLoad, VehicleGroupsSwitcher_Steerable_PostLoad);

-- Add extra function to Vehicle.LUA
if Vehicle.getVehicleName == nil then
    Vehicle.getVehicleName = function(self)
        if self.modVeGS and self.modVeGS.vehicleName then return self.modVeGS.vehicleName end;
        if self.realVehicleName then return self.realVehicleName; end;
        if self.name            then return self.name;            end;
        return "(vehicle with no name)";
    end
end

--
--
--

-- Support-function, that I would like to see be added to InputBinding class.
-- Maybe it is, I just do not know what its called.
local function getKeyIdOfModifier(binding)
    if InputBinding.actions[binding] == nil then
        return nil;  -- Unknown input-binding.
    end;
    if table.getn(InputBinding.actions[binding].keys1) <= 1 then
        return nil; -- Input-binding has only one or zero keys. (Well, in the keys1 - I'm not checking keys2)
    end;
    -- Check if first key in key-sequence is a modifier key (LSHIFT/RSHIFT/LCTRL/RCTRL/LALT/RALT)
    if Input.keyIdIsModifier[ InputBinding.actions[binding].keys1[1] ] then
        return InputBinding.actions[binding].keys1[1]; -- Return the keyId of the modifier key
    end;
    return nil;
end

--

local function FS13renderTextWithShade(x,y, textSize, forecolor, text)
    setTextColor(unpack(VehicleGroupsSwitcher.fontShadeColor));
    renderText(x + (textSize/20), y - (textSize/10), textSize, text);
    setTextColor(unpack(forecolor));
    renderText(x, y, textSize, text);
end;

local function FS15renderText(x,y, textSize, forecolor, text)
    setTextColor(unpack(forecolor));
    renderText(x, y, textSize, text);
end;

--

VehicleGroupsSwitcher.getGroupName = function(grpNum)
  if grpNum ~= nil and grpNum >= 1 and grpNum <= 10 then
    return VehicleGroupsSwitcher.groupNames[grpNum]
  end
  return ""
end

VehicleGroupsSwitcher.setGroupName = function(grpNum, grpName, force)
  if grpNum ~= nil and grpNum >= 1 and grpNum <= 10 then
    VehicleGroupsSwitcher.groupNames[grpNum] = tostring(grpName)
  end
end

VehicleGroupsSwitcher.onGroupNameRename = function(self, superFunc)
  if not VehicleGroupsSwitcher.groupIdxToRename then
    superFunc(self)
  else
    if self.textElement.text ~= "" then
      --VehicleGroupsSwitcher.groupNames[VehicleGroupsSwitcher.groupIdxToRename] = filterText(self.textElement.text)
      VehicleGroupsSwitcher.setGroupName(VehicleGroupsSwitcher.groupIdxToRename, self.textElement.text)
      VehicleGroupsSwitcher.dirtyTimeout = g_currentMission.time + 2000; -- broadcast update, after 2 seconds have passed from now
      VehicleGroupsSwitcher.needToSaveGroupNames = true
    end
    VehicleGroupsSwitcher.groupIdxToRename = nil
    self.textElement:setText("")
    g_gui:showGui("")
  end
end

--[[
function VehicleGroupsSwitcher.loadGroupNames()
  if g_server ~= nil or g_dedicatedServerInfo ~= nil then
    local tag="VehicleGroupsSwitcher"
    local fileName = g_currentMission.missionInfo:getSavegameDirectory(g_currentMission.missionInfo.savegameIndex) .. "/VehicleGroupsSwitcher_Config.XML"
    if fileExists(fileName) then
      local xmlFile = loadXMLFile(tag, fileName)
      if xmlFile ~= nil and xmlFile ~= 0 then
        local i=0
        while true do
          local groupTag = (tag..".group(%d)"):format(i);
          i=i+1
          local idx = getXMLInt(   xmlFile, groupTag.."#id")
          if idx == nil or idx < 1 or idx > 10 then
            break
          end
          VehicleGroupsSwitcher.setGroupName(idx, getXMLString(xmlFile, groupTag.."#name"), true)
          --VehicleGroupsSwitcher.groupsDisabled[idx] = getXMLBool(  xmlFile, groupTag.."#disabled")
        end
        xmlFile = nil;
      end
    end
  end
end

function VehicleGroupsSwitcher.saveGroupNames(self)
  if g_server ~= nil or g_dedicatedServerInfo ~= nil then
    local tag="VehicleGroupsSwitcher"
    local fileName = g_currentMission.missionInfo:getSavegameDirectory(g_currentMission.missionInfo.savegameIndex) .. "/VehicleGroupsSwitcher_Config.XML"
    local xmlFile = createXMLFile(tag, fileName, tag)
    for i=1,10 do
      local groupTag = (tag..".group(%d)"):format(i-1);
      setXMLInt(   xmlFile, groupTag.."#id", i)
      setXMLString(xmlFile, groupTag.."#name", VehicleGroupsSwitcher.getGroupName(i))
      --setXMLBool(  xmlFile, groupTag.."#disabled", VehicleGroupsSwitcher.groupsDisabled[i])
    end
    saveXMLFile(xmlFile)
  end
end
--]]

--

function VehicleGroupsSwitcher:loadMap(name)
    if VehicleGroupsSwitcher.initialized > 0 then
        return;
    end;
    if VehicleGroupsSwitcher.initialized < 0 then
        --g_careerScreen.saveSavegame = Utils.appendedFunction(g_careerScreen.saveSavegame, VehicleGroupsSwitcher.saveGroupNames)
        g_chatDialog.onSendClick = Utils.overwrittenFunction(g_chatDialog.onSendClick, VehicleGroupsSwitcher.onGroupNameRename)
    end
    VehicleGroupsSwitcher.initialized = 1; -- Step-1

    self.hudBackground = createImageOverlay("dataS2/menu/blank.png");
    setOverlayColor(self.hudBackground, 0,0,0, 0.7)
    VehicleGroupsSwitcher.bigFontSize   = 0.020;
    VehicleGroupsSwitcher.smallFontSize = 0.017;
    VehicleGroupsSwitcher.renderTextWithShade = FS15renderText;

    -- Screen resolution aspect ratio fixes
    local w1 = getTextWidth(VehicleGroupsSwitcher.bigFontSize, string.rep("M",20))
    local w2 = getTextWidth(VehicleGroupsSwitcher.bigFontSize, "   ")
    VehicleGroupsSwitcher.hudOverlayPosSize = {0.5-(w1+w2),0.1, (w1+w2)*2,0.8}; -- X,Y,Width,Height
    VehicleGroupsSwitcher.hudColumnsPos     = {
       { 0.5-(w2/2+w1), VehicleGroupsSwitcher.hudTitlePos[2] - VehicleGroupsSwitcher.bigFontSize }  -- Col1(x,y)
      ,{ 0.5+(w2/2),    VehicleGroupsSwitcher.hudTitlePos[2] - VehicleGroupsSwitcher.bigFontSize }  -- Col2(x,y)
    }
    
    --
    for idx=1,10 do
      VehicleGroupsSwitcher.setGroupName(idx, g_i18n:getText("group"):format(idx), true)
    end
    --VehicleGroupsSwitcher.loadGroupNames()
    --
    self.keyModifier = getKeyIdOfModifier(InputBinding.VEGS_TOGGLE_EDIT);
    
    if not (    self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_01)
            and self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_02)
            and self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_03)
            and self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_04)
            and self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_05)
            and self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_06)
            and self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_07)
            and self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_08)
            and self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_09)
            and self.keyModifier == getKeyIdOfModifier(InputBinding.VEGS_GRP_10))
    then
        VehicleGroupsSwitcher.showError = true;
        print("ERROR: One-or-more inputbindings for VehicleGroupsSwitcher do not use the same modifier-key (SHIFT/CTRL/ALT)!");
        return;
    end;
--
    VehicleGroupsSwitcher.hideKeysInHelpbox = false
--[[    
    local modName = "VehicleGroupsSwitcher"
    if  ModsSettings ~= nil 
    and ModsSettings.isVersion ~= nil
    and ModsSettings.isVersion("0.2.0", modName)
    then
        VehicleGroupsSwitcher.hideKeysInHelpbox = ModsSettings.getBoolLocal(modName, "settings", "hideKeysInHelpBox", VehicleGroupsSwitcher.hideKeysInHelpbox)
    end
--]]    
--
    g_currentMission:addOnUserEventCallback(VehicleGroupsSwitcher.callbackUserEvent, self);
    VehicleGroupsSwitcher.showError = false;
end;

function VehicleGroupsSwitcher:deleteMap()
    VehicleGroupsSwitcher.initialized = 0;
    VehicleGroupsSwitcher.hasRefreshedOnJoin = nil;
    --
    VehicleGroupsSwitcher.refInspector = nil;
    VehicleGroupsSwitcher.refLoadStatus = nil;
    --
    g_currentMission:removeOnUserEventCallback(VehicleGroupsSwitcher.callbackUserEvent);
    delete(self.hudBackground);
    self.hudBackground = nil;
end;

--[[
function VehicleGroupsSwitcher:applyHooks()    
    -- Special cases... This might probably cause me problems in future mods.
    local env = getfenv(0);
    for modName,enabled in pairs(g_modIsLoaded) do
        if env[modName] ~= nil then
            if VehicleGroupsSwitcher.refInspector == nil then
                if env[modName].Inspector ~= nil then
                    -- Inspector mod found. Overwrite its draw() function, to hide it when VeG-S is shown.
                    VehicleGroupsSwitcher.refInspector = env[modName].Inspector;
                    env[modName].Inspector.draw = Utils.overwrittenFunction(env[modName].Inspector.draw, VehicleGroupsSwitcher.inspectorDraw);
                end;
            end
            if VehicleGroupsSwitcher.refLoadStatus == nil then
                if env[modName].Loadstatus ~= nil and LoadStatus ~= nil and LoadStatus.draw ~= nil then
                    -- LoadStatus mod found. Overwrite its draw() function, to hide it when VeG-S is shown.
                    VehicleGroupsSwitcher.refLoadStatus = env[modName].Loadstatus;
                    env[modName].Loadstatus.draw = Utils.overwrittenFunction(env[modName].Loadstatus.draw, VehicleGroupsSwitcher.loadStatusDraw);
                end;
            end;
        end;
    end;
end;

-- Function to hide Inspector, when VeG-S wants to show its display.
function VehicleGroupsSwitcher.inspectorDraw(self, superFunc)
    if VehicleGroupsSwitcher.showingVeGS then
        return;
    end;
    superFunc(self);
end

-- Function to hide LoadStatus, when VeG-S wants to show its display.
function VehicleGroupsSwitcher.loadStatusDraw(self, superFunc)
    if VehicleGroupsSwitcher.showingVeGS then
        return;
    end;
    superFunc(self);
end
--]]

function VehicleGroupsSwitcher:mouseEvent(posX, posY, isDown, isUp, button)
end;

function VehicleGroupsSwitcher:keyEvent(unicode, sym, modifier, isDown)
end

function VehicleGroupsSwitcher:update(dt)
--[[
    if VehicleGroupsSwitcher.initialized < 2 then
        VehicleGroupsSwitcher.initialized = 2; -- Step-2
        -- Can not apply hooks in loadMap(), due to some random order when mods are loaded in multiplayer.
        -- So it is done once in this update() function.
        VehicleGroupsSwitcher.applyHooks(self);
        return;
    end;
--]]    
    --
    -- Only "master users" has the ability to move vehicles to different groups.
    local isEditingAllowed = (g_server ~= nil);
    if g_server == nil then
        if self.isModifying or ((self.keyModifier == nil) or (Input.isKeyPressed(self.keyModifier))) or InputBinding.hasEvent(InputBinding.VEGS_TOGGLE_EDIT) then 
            -- Find if this client-user is a "master user"
            for _,v in pairs(g_currentMission.users) do
                if v.userId == g_currentMission.playerUserId then
                    isEditingAllowed = v.isMasterUser;
                    break
                end
            end
            -- v0.97
            -- When using a Listen-server (i.e. player hosted), if "Reset Vehicles" are allowed, then allow clients to modify VeG-S too.
            -- TODO: Figure out if there is some kind of "user administration system" to use instead.
            isEditingAllowed = isEditingAllowed or g_currentMission.clientPermissionSettings.resetVehicle;
        end
    end
    --
    if isEditingAllowed then
        if not VehicleGroupsSwitcher.hideKeysInHelpbox and g_currentMission.missionInfo.showHelpMenu then
            if self.isModifying or ((self.keyModifier == nil) or (Input.isKeyPressed(self.keyModifier))) then
                -- Show keys in helpbox
                g_currentMission:addHelpButtonText(g_i18n:getText("VEGS_TOGGLE_EDIT"), InputBinding.VEGS_TOGGLE_EDIT, nil, GS_PRIO_HIGH);
                if self.isModifying and not g_currentMission.player.isEntered then
                    g_currentMission:addHelpButtonText(g_i18n:getText("editGroupUp"),   InputBinding.MENU_UP    ,nil ,GS_PRIO_NORMAL);
                    g_currentMission:addHelpButtonText(g_i18n:getText("editGroupDown"), InputBinding.MENU_DOWN  ,nil ,GS_PRIO_NORMAL);
                    g_currentMission:addHelpButtonText(g_i18n:getText("editPosUp"),     InputBinding.MENU_LEFT  ,nil ,GS_PRIO_NORMAL);
                    g_currentMission:addHelpButtonText(g_i18n:getText("editPosDown"),   InputBinding.MENU_RIGHT ,nil ,GS_PRIO_NORMAL);
                end;
            end;
        end;
        --
        if InputBinding.hasEvent(InputBinding.VEGS_TOGGLE_EDIT) or self.isModifying then 
            if self.isModifying then
                local vehGroupOffset = nil;
                local vehPosOffset = nil;
--[[Development
                if Input.isKeyPressed(Input.KEY_lalt) then
                  local x=0
                  if     InputBinding.hasEvent(InputBinding.MENU_LEFT)  then x=-1
                  elseif InputBinding.hasEvent(InputBinding.MENU_RIGHT) then x=1
                  end
                  if g_currentMission.controlledVehicle then
                    local col = ((g_currentMission.controlledVehicle.modVeGS.group-1) % 5) + 1
                    local xx = VehicleGroupsSwitcher.hudColumnsPos[col][1]
                    xx = xx + x/100
                    VehicleGroupsSwitcher.hudColumnsPos[col][1] = xx
                  end
                  renderText(0.5, 0.002, 0.02, tostring(xx))
                else
--Development]]
                  if     InputBinding.hasEvent(InputBinding.MENU_UP)    then vehGroupOffset = -1;
                  elseif InputBinding.hasEvent(InputBinding.MENU_DOWN)  then vehGroupOffset =  1;
                  elseif InputBinding.hasEvent(InputBinding.MENU_LEFT)  then vehPosOffset = -1;
                  elseif InputBinding.hasEvent(InputBinding.MENU_RIGHT) then vehPosOffset =  1;
                  end
--                end
                --
                if vehGroupOffset ~= nil then
                    local vehObj = g_currentMission.controlledVehicle;
                    if vehObj ~= nil and vehObj.isEntered then
                        vehObj.modVeGS = vehObj.modVeGS or {group=0,pos=0}
                        vehObj.modVeGS.group = (vehObj.modVeGS.group + vehGroupOffset) % 11;
                        if vehObj.modVeGS.group ~= 0 then
                            vehObj.modVeGS.pos = 99;
                            vehPosOffset = 0; --  Force reposition within group
                        end;
                        self.dirtyTimeout = g_currentMission.time + 2000; -- broadcast update, after 2 seconds have passed from now
                    end;
                end;
                --
                if vehPosOffset ~= nil then
                    local vehObj = g_currentMission.controlledVehicle;
                    if vehObj ~= nil and vehObj.isEntered then
                        vehObj.modVeGS = vehObj.modVeGS or {group=0,pos=0}
                        if vehObj.modVeGS.group >= 1 and vehObj.modVeGS.group <= 10 then
                            local grpOrder = {}
                            for _,grpVehObj in pairs(g_currentMission.steerables) do
                                if (grpVehObj.modVeGS ~= nil) and grpVehObj.modVeGS.group == vehObj.modVeGS.group then
                                    table.insert(grpOrder, grpVehObj);
                                end;
                            end;
                            table.sort(grpOrder, function(l,r) return l.modVeGS.pos < r.modVeGS.pos end);
                            local idx = 1;
                            local curVehPos = nil;
                            for _,grpVehObj in ipairs(grpOrder) do
                                grpVehObj.modVeGS.pos = idx;
                                if grpVehObj.isEntered then
                                    curVehPos = idx;
                                end;
                                idx = idx + 1;
                            end;
                            if curVehPos ~= nil then
                                if vehPosOffset < 0 and curVehPos > 1 then
                                    grpOrder[curVehPos-1].modVeGS.pos = grpOrder[curVehPos-1].modVeGS.pos + 1;
                                    grpOrder[curVehPos].modVeGS.pos = grpOrder[curVehPos].modVeGS.pos - 1;
                                    self.dirtyTimeout = g_currentMission.time + 2000; -- broadcast update, after 2 seconds have passed from now
                                elseif vehPosOffset > 0 and curVehPos < table.getn(grpOrder) then
                                    grpOrder[curVehPos].modVeGS.pos = grpOrder[curVehPos].modVeGS.pos + 1;
                                    grpOrder[curVehPos+1].modVeGS.pos = grpOrder[curVehPos+1].modVeGS.pos - 1;
                                    self.dirtyTimeout = g_currentMission.time + 2000; -- broadcast update, after 2 seconds have passed from now
                                end;
                            end;
                        end;
                    end;
                end;
                --
                if VehicleGroupsSwitcher.groupIdxToRename == nil and (g_gui.currentGuiName ~= "" and g_gui.currentGuiName ~= nil) then
                    -- If player activates some GUI screen, stop VEGS from rendering
                    self.isModifying = false;
                else
                    self.isModifying = not InputBinding.hasEvent(InputBinding.VEGS_TOGGLE_EDIT);
                end;
            else
                self.isModifying = true;
            end;
        end;
    else
        -- Editing not allowed
        self.isModifying = false;
    end;

    if self.dirtyTimeout ~= nil and self.dirtyTimeout < g_currentMission.time then
        self.dirtyTimeout = nil;
        VehicleGroupsSwitcherEvent.sendEvent();
        --
--[[        
        if VehicleGroupsSwitcher.needToSaveGroupNames then
          VehicleGroupsSwitcher.needToSaveGroupNames = nil
          VehicleGroupsSwitcher.saveGroupNames()
        end
--]]        
    end;
    
    -- This construct is used, so we do not activate other actions that might have been assigned the normal-keys (i.e. 1,2,3...9,0)
    local vegsSwitchTo = nil;
    local multiAction = nil;
    if InputBinding.hasEvent(InputBinding.VEGS_GRP_TAB) then
        -- Switch within the same group (if possible)
        for _,vehObj in pairs(g_currentMission.steerables) do
            if vehObj.isEntered then
                if vehObj.modVeGS ~= nil then
                    vegsSwitchTo = vehObj.modVeGS.group;
                end;
                break;
            end;
        end;
    elseif InputBinding.hasEvent(InputBinding.VEGS_GRP_NXT) then vegsSwitchTo = 99; -- Switch to next enabled group
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_01) then multiAction = 1;
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_02) then multiAction = 2;
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_03) then multiAction = 3;
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_04) then multiAction = 4;
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_05) then multiAction = 5;
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_06) then multiAction = 6;
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_07) then multiAction = 7;
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_08) then multiAction = 8;
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_09) then multiAction = 9;
    elseif InputBinding.isPressed(InputBinding.VEGS_GRP_10) then multiAction = 10;
    elseif not VehicleGroupsSwitcher.hideKeysInHelpbox 
      and g_currentMission.missionInfo.showHelpMenu
      and ((self.keyModifier == nil) or (Input.isKeyPressed(self.keyModifier))) then
        -- Show keys in helpbox, only when modifier-key is pressed (if it has been assigned)
        g_currentMission:addHelpButtonText(g_i18n:getText("VEGS_GRP_TAB"),     InputBinding.VEGS_GRP_TAB ,nil ,GS_PRIO_LOW);
        g_currentMission:addHelpButtonText(g_i18n:getText("VEGS_GRP_NXT"),     InputBinding.VEGS_GRP_NXT ,nil ,GS_PRIO_LOW);
    end;

    if self.prevAction == nil and multiAction ~= nil then
        self.prevAction = {multiAction, g_currentMission.time};
    elseif self.prevAction ~= nil then
        local delay = g_currentMission.time - self.prevAction[2];
        if delay > 800 and delay < 2000 then 
            -- Keypress was more than 800ms, 
            if self.isModifying then
                -- and in editing-mode, so rename group-name
                VehicleGroupsSwitcher.groupIdxToRename = self.prevAction[1]
                g_gui:showGui("ChatDialog")
                g_chatDialog.textElement:setText(VehicleGroupsSwitcher.getGroupName(VehicleGroupsSwitcher.groupIdxToRename))
            else
                -- else it is a group enable/disable
                local b = VehicleGroupsSwitcher.groupsDisabled[self.prevAction[1]] or false;
                VehicleGroupsSwitcher.groupsDisabled[self.prevAction[1]] = not b;
                -- Do not let it change again
                self.prevAction[2] = self.prevAction[2] - 5000;
            end
        end;
        -- Has key been released?
        if multiAction == nil then
            if delay < 800 then
                -- Keypress was less than 800ms, so it is a vehicle switch
                vegsSwitchTo = self.prevAction[1];
            end;
            self.prevAction = nil;
        end;
    end;
    --
--
    local foundVehObj = nil;
    if vegsSwitchTo ~= nil then
        --
        local slots = {}
        for idx=1,10 do
            slots[idx] = {}
        end;
        local curGroup = 0;
        for idx,vehObj in pairs(g_currentMission.steerables) do
            if (vehObj.modVeGS ~= nil) and vehObj.modVeGS.group >= 1 and vehObj.modVeGS.group <= 10 then
                table.insert(slots[vehObj.modVeGS.group], vehObj);
                if vehObj.isEntered then
                    curGroup = vehObj.modVeGS.group;
                end;
            end;
        end;
        for idx=1,10 do
            table.sort(slots[idx], function(l,r) return l.modVeGS.pos < r.modVeGS.pos; end);
        end;
        --
        if vegsSwitchTo >= 1 and vegsSwitchTo <= 10 then
            local startIdx = 0;
            -- Switching within same group?
            if curGroup == vegsSwitchTo then
                -- Find vehicle in current group, that player is in
                for idx,vehObj in ipairs(slots[vegsSwitchTo]) do
                    if vehObj.isEntered then
                        startIdx = idx;
                        break;
                    end;
                end;
            end;
            -- Switch to next available vehicle in group.
            local numVeh = table.getn(slots[vegsSwitchTo]);
            for idx=startIdx, numVeh+startIdx do
                local vehObj = slots[vegsSwitchTo][(idx % numVeh)+1]
                if vehObj ~= nil and (not vehObj.isEntered and not vehObj.isControlled) then
                    foundVehObj = vehObj;
                    break;
                end;
            end;
        elseif vegsSwitchTo == 99 then
            -- Switch to next enabled group
            for grp=curGroup, curGroup+10 do
                vegsSwitchTo = (grp % 10)+1;
                if VehicleGroupsSwitcher.groupsDisabled[vegsSwitchTo] ~= true then
                    for idx=1, table.getn(slots[vegsSwitchTo]) do
                        local vehObj = slots[vegsSwitchTo][idx]
                        if not vehObj.isEntered and not vehObj.isControlled then
                            foundVehObj = vehObj;
                            break;
                        end;
                    end;
                    if foundVehObj ~= nil then
                        break;
                    end;
                end;
            end;
        end;
    end;

    if foundVehObj then
        g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent:new(
            foundVehObj, 
            g_currentMission.missionInfo.playerName,
            g_currentMission.missionInfo.playerIndex,
            g_currentMission.missionInfo.playerColorIndex
        ));
    end;
    
    -- FS15, 'crouch' work-around.
    if g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.isEntered then
        -- In vehicle
        VehicleGroupsSwitcher.showingVeGS = self.isModifying or ((self.keyModifier ~= nil) and (Input.isKeyPressed(self.keyModifier)));    
    else
        -- When on-foot, require double-tab on CTRL  .. I.e. <CTRL>, release within 500ms, <CTRL>-and-hold
        if (self.keyModifier ~= nil) then
          if self.crouchDelay == nil then 
            if Input.isKeyPressed(self.keyModifier) then
              self.crouchDelay = -500
            end
          elseif self.crouchDelay <= 0 then
            self.crouchDelay = math.min(0, self.crouchDelay + dt)
            if not Input.isKeyPressed(self.keyModifier) then
              if self.crouchDelay == 0 then
                self.crouchDelay = nil
              else
                self.crouchDelay = 1
              end
            end
          elseif self.crouchDelay > 0 then
            self.crouchDelay = self.crouchDelay + dt
            if Input.isKeyPressed(self.keyModifier) then
              VehicleGroupsSwitcher.showingVeGS = true
            else
              VehicleGroupsSwitcher.showingVeGS = false
              if self.crouchDelay > 500 then
                self.crouchDelay = nil
              end
            end
          end
        end
    end
end;

function VehicleGroupsSwitcher:getTipText()
    if self.tipTime == nil or self.tipTime < g_currentMission.time then
      self.tipTime = g_currentMission.time + 7000
      self.currentTipIdx = Utils.getNoNil(self.currentTipIdx,0) + Utils.getNoNil(self.currentTipDirection,1)
      local i18nText = ("tip%d"):format(self.currentTipIdx)
      if not g_i18n:hasText(i18nText) then
        if Utils.getNoNil(self.currentTipDirection,1) > 0 and self.isModifying then
          self.currentTipIdx = -1
          self.currentTipDirection = -1
        else
          self.currentTipIdx = 1
          self.currentTipDirection = 1
        end
      end
    else
      local i18nText = ("tip%d"):format(self.currentTipIdx)
      return g_i18n:getText(i18nText)
    end
    return nil
end

function VehicleGroupsSwitcher:draw()
    if VehicleGroupsSwitcher.showError then
        --if InputBinding.isPressed(InputBinding.VEGS_TOGGLE_EDIT) then
        --    setTextAlignment(RenderText.ALIGN_CENTER);
        --    VehicleGroupsSwitcher.renderTextWithShade(0.5, 0.7, VehicleGroupsSwitcher.bigFontSize, VehicleGroupsSwitcher.fontColor, g_i18n:getText("ControlsError"));
        --end;
        if InputBinding.hasEvent(InputBinding.VEGS_TOGGLE_EDIT) then
            g_currentMission.inGameMessage:showMessage(g_i18n:getText("ControlsErrorTitle"), g_i18n:getText("ControlsError"), 10000);
        end
        return;
    end;
    --
    if VehicleGroupsSwitcher.showingVeGS then
        local slots = { {},{},{},{},{},{},{},{},{},{} }
        local unassigned = {}
        for idx,vehObj in pairs(g_currentMission.steerables) do
            if vehObj.modVeGS ~= nil and vehObj.modVeGS.group ~= nil and vehObj.modVeGS.group >= 1 and vehObj.modVeGS.group <= 10 then
                if vehObj.modVeGS.pos == nil then
                    vehObj.modVeGS.pos = 99;
                end;
                table.insert(slots[vehObj.modVeGS.group], vehObj);
            else
                table.insert(unassigned, vehObj);
            end;
        end;
        local slotsHeight = {}
        for idx=1,10 do
            table.sort(slots[idx], function(l,r) return l.modVeGS.pos < r.modVeGS.pos; end);
            slotsHeight[idx] = VehicleGroupsSwitcher.bigFontSize + (table.getn(slots[idx]) * VehicleGroupsSwitcher.smallFontSize)
        end;
        --
        local col1Height,col2Height = 0,0
        if self.isModifying then
            col2Height = VehicleGroupsSwitcher.bigFontSize + (table.getn(unassigned) * VehicleGroupsSwitcher.smallFontSize)
        end
        for idx=1,5 do
          col1Height = col1Height + slotsHeight[idx]
          col2Height = col2Height + slotsHeight[11 - idx]
        end

        local slotColumnSplitIdx = 6
        local maxCalculations = 5
        while (maxCalculations > 0 and slotColumnSplitIdx > 2 and slotColumnSplitIdx < 10) do
            maxCalculations = maxCalculations - 1
            local diffHeight = math.abs(col1Height - col2Height)
            if (diffHeight <= 0.01) then
                maxCalculations=0
            elseif (col1Height < col2Height) then
                local tmp1 = col1Height + slotsHeight[slotColumnSplitIdx]
                local tmp2 = col2Height - slotsHeight[slotColumnSplitIdx]
                if (math.abs(tmp1 - tmp2) < diffHeight) then
                    col1Height = tmp1
                    col2Height = tmp2
                    slotColumnSplitIdx=slotColumnSplitIdx+1
                else
                    maxCalculations=0
                end
            elseif (col1Height > col2Height) then
                local tmp1 = col1Height - slotsHeight[slotColumnSplitIdx-1]
                local tmp2 = col2Height + slotsHeight[slotColumnSplitIdx-1]
                if (math.abs(tmp1 - tmp2) < diffHeight) then
                    col1Height = tmp1
                    col2Height = tmp2
                    slotColumnSplitIdx=slotColumnSplitIdx-1
                else
                    maxCalculations=0
                end
            end
        end
        --
        local xPos,yPos = unpack(VehicleGroupsSwitcher.hudTitlePos)
        --
        if self.hudBackground ~= nil then
            renderOverlay(self.hudBackground, unpack(VehicleGroupsSwitcher.hudOverlayPosSize));
        end;
        --
        setTextBold(true);
        setTextAlignment(RenderText.ALIGN_CENTER);
        VehicleGroupsSwitcher.renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.bigFontSize, VehicleGroupsSwitcher.fontColor, g_i18n:getText("VEGS"));

        local tipTxt = self:getTipText()
        if tipTxt ~= nil then
          setTextBold(false);
          yPos = yPos - VehicleGroupsSwitcher.smallFontSize * 0.8
          VehicleGroupsSwitcher.renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.smallFontSize * 0.7, VehicleGroupsSwitcher.fontDisabledColor, tipTxt);
        end
        setTextAlignment(RenderText.ALIGN_LEFT);
        --
        xPos,yPos = unpack(VehicleGroupsSwitcher.hudColumnsPos[1])
        for idx=1,10 do
            if idx == slotColumnSplitIdx then
                xPos,yPos = unpack(VehicleGroupsSwitcher.hudColumnsPos[2])
            end;
            --
            setTextBold(true);
            yPos = yPos - VehicleGroupsSwitcher.bigFontSize;
            local grpColor = VehicleGroupsSwitcher.groupsDisabled[idx]==true and VehicleGroupsSwitcher.fontDisabledColor or VehicleGroupsSwitcher.fontColor;
            VehicleGroupsSwitcher.renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.bigFontSize, grpColor, g_i18n:getText("groupLabel"):format(idx%10, VehicleGroupsSwitcher.groupNames[idx]));
            --
            setTextBold(false);
            for _,vehObj in pairs(slots[idx]) do
                local color = (vehObj.isEntered and VehicleGroupsSwitcher.fontSelectedColor or grpColor);
                yPos = yPos - VehicleGroupsSwitcher.smallFontSize;
                VehicleGroupsSwitcher.renderTextWithShade(xPos + VehicleGroupsSwitcher.smallFontSize, yPos, VehicleGroupsSwitcher.smallFontSize, color, tostring(vehObj:getVehicleName()));
                --
                if vehObj.isControlled
                or vehObj.isHired  -- Hired helper
                or (vehObj.drive ~= nil and vehObj.drive == true)  -- CoursePlay (old)
                or (vehObj.getIsCourseplayDriving ~= nil and vehObj:getIsCourseplayDriving())  -- CoursePlay (v4.00.0056)
                or (vehObj.modFM ~= nil and vehObj.modFM.FollowVehicleObj ~= nil) -- FollowMe
                then
                    local txt;
                    if vehObj.isControlled then
                        txt = vehObj.controllerName;
                        if txt == nil then
                            txt = g_i18n:getText("player");
                        end;
                    elseif vehObj.isHired then
                        txt = g_i18n:getText("hired");
                    elseif (vehObj.drive ~= nil and vehObj.drive == true)  -- CoursePlay (old)
                        or (vehObj.getIsCourseplayDriving ~= nil and vehObj:getIsCourseplayDriving()) then -- CoursePlay (v4.00.0056)
                        txt = g_i18n:getText("courseplay");
                    elseif (vehObj.modFM ~= nil and vehObj.modFM.FollowVehicleObj ~= nil) then
                        txt = g_i18n:getText("followme");
                    else
                        txt = g_i18n:getText("unknown");
                    end;
                    --[[
                    setTextAlignment(RenderText.ALIGN_RIGHT);
                    VehicleGroupsSwitcher.renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.smallFontSize, color, txt);
                    setTextAlignment(RenderText.ALIGN_LEFT);
                    --]]
                    yPos = yPos - VehicleGroupsSwitcher.smallFontSize/1.5;
                    VehicleGroupsSwitcher.renderTextWithShade(xPos+VehicleGroupsSwitcher.smallFontSize*1.25, yPos, VehicleGroupsSwitcher.smallFontSize/1.5, color, txt);
                end;
            end;
        end;
        --
        if self.isModifying then
            setTextBold(true);
            yPos = yPos - VehicleGroupsSwitcher.bigFontSize;
            VehicleGroupsSwitcher.renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.bigFontSize, VehicleGroupsSwitcher.fontColor, g_i18n:getText("unassigned"));
            --
            setTextBold(false);
            for _,vehObj in pairs(unassigned) do
                local color = (vehObj.isEntered and VehicleGroupsSwitcher.fontSelectedColor or VehicleGroupsSwitcher.fontColor);
                yPos = yPos - VehicleGroupsSwitcher.smallFontSize;
                VehicleGroupsSwitcher.renderTextWithShade(xPos + VehicleGroupsSwitcher.smallFontSize, yPos, VehicleGroupsSwitcher.smallFontSize, color, tostring(vehObj:getVehicleName()));
                --
                if vehObj.isControlled
                or vehObj.isHired  -- Hired helper
                or (vehObj.drive ~= nil and vehObj.drive == true)  -- CoursePlay
                or (vehObj.getIsCourseplayDriving ~= nil and vehObj:getIsCourseplayDriving())  -- CoursePlay (v4.00.0056)
                or (vehObj.modFM ~= nil and vehObj.modFM.FollowVehicleObj ~= nil) -- FollowMe
                then
                    local txt;
                    if vehObj.isControlled then
                        txt = vehObj.controllerName;
                        if txt == nil then
                            txt = g_i18n:getText("player");
                        end;
                    elseif vehObj.isHired then
                        txt = g_i18n:getText("hired");
                    elseif (vehObj.drive ~= nil and vehObj.drive == true)  -- CoursePlay (old)
                        or (vehObj.getIsCourseplayDriving ~= nil and vehObj:getIsCourseplayDriving()) then -- CoursePlay (v4.00.0056)
                        txt = g_i18n:getText("courseplay");
                    elseif (vehObj.modFM ~= nil and vehObj.modFM.FollowVehicleObj ~= nil) then
                        txt = g_i18n:getText("followme");
                    else
                        txt = g_i18n:getText("unknown");
                    end;
                    --[[
                    setTextAlignment(RenderText.ALIGN_RIGHT);
                    VehicleGroupsSwitcher.renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.smallFontSize, color, txt);
                    setTextAlignment(RenderText.ALIGN_LEFT);
                    --]]
                    yPos = yPos - VehicleGroupsSwitcher.smallFontSize/1.5;
                    VehicleGroupsSwitcher.renderTextWithShade(xPos+VehicleGroupsSwitcher.smallFontSize*1.25, yPos, VehicleGroupsSwitcher.smallFontSize/1.5, color, txt);
                end;
            end;
        end;
    end;
end;

---
---
---

VehicleGroupsSwitcherEvent = {};
VehicleGroupsSwitcherEvent_mt = Class(VehicleGroupsSwitcherEvent, Event);

InitEventClass(VehicleGroupsSwitcherEvent, "VehicleGroupsSwitcherEvent");

function VehicleGroupsSwitcherEvent:emptyNew()
    local self = Event:new(VehicleGroupsSwitcherEvent_mt);
    self.className="VehicleGroupsSwitcherEvent";
    return self;
end;

function VehicleGroupsSwitcherEvent:new(isRefreshRequest)
    local self = VehicleGroupsSwitcherEvent:emptyNew()
    self.isRefreshRequest = isRefreshRequest;
    return self;
end;

function VehicleGroupsSwitcherEvent:writeStream(streamId, connection)
--print(tostring(g_currentMission.time).. "ms - VehicleGroupsSwitcherEvent:writeStream(streamId, connection)");
    local cnt = Utils.clamp(table.getn(g_currentMission.steerables), 0, 127);
    if self.isRefreshRequest then
        -- Magic number zero means "request a refresh"
        cnt = 0;
    end;
    -- Do not rely on that the peers may have the same number of steerables in their array! So tell how many we are going to send now.
    streamWriteInt8(streamId, cnt); -- If more than 127 steerables, then this will be a problem!
    if cnt > 0 then
      for i=1,10 do
        streamWriteString(streamId, VehicleGroupsSwitcher.getSroupName(i))
      end
      for i=1,cnt do
          local vegsGroup = 0;
          local vegsPos = 0;
          if g_currentMission.steerables[i].modVeGS ~= nil then
              vegsGroup = Utils.clamp(g_currentMission.steerables[i].modVeGS.group, 0, 15);
              vegsPos   = Utils.clamp(g_currentMission.steerables[i].modVeGS.pos, 0, 15);
          end;
          local id = networkGetObjectId(g_currentMission.steerables[i]);
          streamWriteInt32(streamId, id);
          streamWriteUIntN(streamId, vegsGroup, 4);
          streamWriteUIntN(streamId, vegsPos,   4); -- 0-15, if more than 15 in a group, this will be a problem.
  --print(tostring(id).." / "..tostring(vegsGroup) .." / ".. tostring(vegsPos));
      end
    end
end;

function VehicleGroupsSwitcherEvent:readStream(streamId, connection)
--print(tostring(g_currentMission.time).. "ms - VehicleGroupsSwitcherEvent:readStream(streamId, connection)");
    local wasDirty = false
    local cnt = streamReadInt8(streamId);
    if cnt > 0 then
      for i=1,10 do
        local newName = streamReadString(streamId)
        wasDirty = wasDirty or (VehicleGroupsSwitcher.getGroupName(i) ~= newName)
        VehicleGroupsSwitcher.setGroupName(i, newName, true)
      end
      for i=1,cnt do
          local id = streamReadInt32(streamId);
          local vegsGroup = streamReadUIntN(streamId, 4);
          local vegsPos   = streamReadUIntN(streamId, 4);
          local vehObj = networkGetObject(id);
          if vehObj ~= nil then
              if vehObj.modVeGS == nil then
                  vehObj.modVeGS = {}
                  wasDirty = true
              end;
              wasDirty = wasDirty or (vehObj.modVeGS.group ~= vegsGroup) or (vehObj.modVeGS.pos ~= vegsPos);
              vehObj.modVeGS.group = vegsGroup;
              vehObj.modVeGS.pos   = vegsPos;
              -- Will cause a race-condition, when another player also is in VeGS' edit-mode.
          end;
      end;
    end
    -- Was it a refresh-request, and we are the server?
    if g_server ~= nil and (wasDirty or cnt == 0)  then
--print(tostring(g_currentMission.time).."ms VehicleGroupsSwitcherEvent:readStream(streamId, connection) refresh request");
        -- Just broadcast to all players...
        VehicleGroupsSwitcher.dirtyTimeout = g_currentMission.time + 2000
    end
end;

function VehicleGroupsSwitcherEvent.sendEvent(isRefreshRequest, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(VehicleGroupsSwitcherEvent:new(nil), nil, nil, nil);
        else
            g_client:getServerConnection():sendEvent(VehicleGroupsSwitcherEvent:new(isRefreshRequest));
        end;
    end;
end;

function VehicleGroupsSwitcher:callbackUserEvent()
--print(tostring(g_currentMission.time).."ms VehicleGroupsSwitcher:callbackUserEvent() g_server==nil:"..tostring(g_server == nil));
    if g_server == nil and not VehicleGroupsSwitcher.hasRefreshedOnJoin then
        -- We're a Client and looks like having just joined...
        -- Send a "request refresh" event.
        VehicleGroupsSwitcherEvent.sendEvent(true);
        VehicleGroupsSwitcher.hasRefreshedOnJoin = true;
    end;
end

--
print(string.format("Script loaded: VehicleGroupsSwitcher.lua (v%s)", VehicleGroupsSwitcher.version));
