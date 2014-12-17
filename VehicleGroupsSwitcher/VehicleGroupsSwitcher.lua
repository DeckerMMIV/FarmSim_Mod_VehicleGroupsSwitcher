--
-- VeG-S - VehicleGroups Switcher - (previously known as "FastSwitcher")
--
-- @author  Decker_MMIV - fs-uk.com, forum.farming-simulator.com, modhoster.com
-- @date    2012-11-17
--
-- @history
--  2012-November
--      v0.9        - Took FastSwitcher v1.3 from FS2011, and changed alot.
--      v0.91       - Added "switch within group", suggested by Knut & KaosKnite.
--      v0.92       - Minor tweaks. Could also be used in FS2011, if modified slightly.
--  2013-February   
--      v0.93       - Added "switch to next group"
--                  - Added "disable/enable group", used for "switch to next group"
--      v0.94       - Added "position within a group"
--                  - Added save/load of the above
--                  - Added hiding of Inspector while VeG-S is showing its display.
--                  - Multiplayer, synchronizing to clients when they join the game.
--  2013-July
--      v0.95       - Added hiding of LoadStatus while VeG-S is showing its display.
--      v0.96       - Patch 2.0.0.4 beta 2
--  2013-September
--      v0.97       - Multiplayer, when a player joins, automatically refresh VeG-S list.
--                  - Patch 2.0.0.7 beta 4 required, due to "Reset Vehicles"
--                  - Allow client player(s) to modify the VeG-S list, if/when either;
--                      - "Reset Vehicles" are allowed (listen server / player hosted)
--                      - or player is a "master user" (dedicated server)
--                  - Changed default key for 'Toggle edit-mode' to LEFT CTRL E.
--  2014-February
--      v0.98       - Changed method of getting vehicle name, to be the same as Glance.
--                  - getVehicleName() function added to 'Vehicle' table.
--

--[[

Bugs/Suggestions

buciffal
  How doable is changing the names of the groups? Say like from "Group 1" to "Cowzone" and so on... depending of each one's needs  
  http://fs-uk.com/forum/index.php?topic=124904.msg862509#msg862509

--]]


VehicleGroupsSwitcher = {};
--
local modItem = ModsUtil.findModItemByModName(g_currentModName);
VehicleGroupsSwitcher.version = (modItem and modItem.version) and modItem.version or "?.?.?";
--
VehicleGroupsSwitcher.showingVeGS = false;
--
VehicleGroupsSwitcher.hudPosSize = {x1=0.15, x2=0.55, x=0.37, y=0.8, w=1, h=0.8}; -- X,Y,Width,Height        -- TODO: Make position customizable from within the game.
VehicleGroupsSwitcher.bigFontSize   = 0.023;
VehicleGroupsSwitcher.smallFontSize = 0.020;
VehicleGroupsSwitcher.fontColor         = {1.0, 1.0, 1.0, 1.0}; -- white
VehicleGroupsSwitcher.fontSelectedColor = {1.0, 1.0, 0.3, 1.0}; -- yellowish
VehicleGroupsSwitcher.fontShadeColor    = {0.0, 0.0, 0.0, 1.0}; -- black
VehicleGroupsSwitcher.fontDisabledColor = {0.5, 0.5, 0.5, 1.0}; -- gray
--
VehicleGroupsSwitcher.groupsDisabled = {};
VehicleGroupsSwitcher.initialized = 0;
VehicleGroupsSwitcher.hasRefreshedOnJoin = nil;

-- Register as event listener
addModEventListener(VehicleGroupsSwitcher);

--
--
--

function VehicleGroupsSwitcher_Steerable_PostLoad(self, xmlFile)
  if self.name == nil or self.realVehicleName == nil then
    self.name = Utils.getXMLI18N(xmlFile, "vehicle.name", "", "(unidentified vehicle)", self.customEnvironment);
  end
end
Steerable.postLoad = Utils.appendedFunction(Steerable.postLoad, VehicleGroupsSwitcher_Steerable_PostLoad);

-- Add extra function to Vehicle.LUA
if Vehicle.getVehicleName == nil then
    Vehicle.getVehicleName = function(self)
        if self.realVehicleName then return self.realVehicleName; end;
        if self.name            then return self.name;            end;
        return "(vehicle with no name)";
    end
end

--
--
--

-- FS2013
-- Support-function, that I would like to see be added to InputBinding class.
-- Maybe it is, I just do not know what its called.
function getKeyIdOfModifier(binding)
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
--]]

--[[ FS2011
--http://stackoverflow.com/questions/656199/search-for-an-item-in-a-lua-list
function Set(list)
    local set = {};
    for _,l in ipairs(list) do
        set[l]=true;
    end;
    return set;
end;

function getKeyIdOfModifier(binding)
    local allowedModifiers = Set({
        Input.KEY_lshift,
        Input.KEY_rshift,
        Input.KEY_shift,
        Input.KEY_lctrl, 
        Input.KEY_rctrl, 
        Input.KEY_lalt,  
        Input.KEY_ralt  
    });
    for _,k in pairs(InputBinding.digitalActions[binding].key1Modifiers) do
        if allowedModifiers[k] then
            return k;
        end;
    end;
    return nil;
end;
--]]

--
--
--

function VehicleGroupsSwitcher:loadMap(name)
    if VehicleGroupsSwitcher.initialized > 0 then
        return;
    end;
    VehicleGroupsSwitcher.initialized = 1; -- Step-1
--print(tostring(g_currentMission.time).."ms VehicleGroupsSwitcher:loadMap(name)");
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
        print("ERROR: One-or-more inputbindings for VehicleGroupsSwitcher do not use the same modifier-key (SHIFT/CTRL/ALT)!");
        return;
    end;

-- FS2013    
    self.hudBackground = createImageOverlay("dataS2/menu/black.png");
    g_currentMission:addOnUserEventCallback(VehicleGroupsSwitcher.callbackUserEvent, self); -- Patch 2.0.0.4
--]]    
end;

function VehicleGroupsSwitcher:deleteMap()
    VehicleGroupsSwitcher.initialized = 0;
    VehicleGroupsSwitcher.hasRefreshedOnJoin = nil;
    --
    VehicleGroupsSwitcher.refInspector = nil;
    VehicleGroupsSwitcher.refLoadStatus = nil;
    --
    g_currentMission:removeOnUserEventCallback(VehicleGroupsSwitcher.callbackUserEvent); -- Patch 2.0.0.4
    delete(self.hudBackground);
    self.hudBackground = nil;
end;

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

function VehicleGroupsSwitcher:mouseEvent(posX, posY, isDown, isUp, button)
end;

function VehicleGroupsSwitcher:keyEvent(unicode, sym, modifier, isDown)
end

function VehicleGroupsSwitcher:update(dt)
    if VehicleGroupsSwitcher.initialized < 2 then
        VehicleGroupsSwitcher.initialized = 2; -- Step-2
        -- Can not apply hooks in loadMap(), due to some random order when mods are loaded in multiplayer.
        -- So it is done once in this update() function.
        VehicleGroupsSwitcher.applyHooks(self);
        return;
    end;
    --
    -- Patch 2.0.0.4 - Only "master users" has the ability to move vehicles to different groups.
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
        if g_currentMission.showHelpText then
            if self.isModifying or ((self.keyModifier == nil) or (Input.isKeyPressed(self.keyModifier))) then
                -- Show keys in helpbox
                g_currentMission:addHelpButtonText(g_i18n:getText("VEGS_TOGGLE_EDIT"), InputBinding.VEGS_TOGGLE_EDIT);
                if self.isModifying and not g_currentMission.player.isEntered then
                    g_currentMission:addHelpButtonText(g_i18n:getText("editGroupUp"),   InputBinding.MENU_UP);
                    g_currentMission:addHelpButtonText(g_i18n:getText("editGroupDown"), InputBinding.MENU_DOWN);
                    g_currentMission:addHelpButtonText(g_i18n:getText("editPosUp"),     InputBinding.MENU_LEFT);
                    g_currentMission:addHelpButtonText(g_i18n:getText("editPosDown"),   InputBinding.MENU_RIGHT);
                end;
            end;
        end;
        --
        if InputBinding.hasEvent(InputBinding.VEGS_TOGGLE_EDIT) or self.isModifying then 
            if self.isModifying then
                local vehGroupOffset = nil;
                local vehPosOffset = nil;
                if     InputBinding.hasEvent(InputBinding.MENU_UP)    then vehGroupOffset = -1;
                elseif InputBinding.hasEvent(InputBinding.MENU_DOWN)  then vehGroupOffset =  1;
                elseif InputBinding.hasEvent(InputBinding.MENU_LEFT)  then vehPosOffset = -1;
                elseif InputBinding.hasEvent(InputBinding.MENU_RIGHT) then vehPosOffset =  1;
                end
                --
                if vehGroupOffset ~= nil then
                    local vehObj = g_currentMission.controlledVehicle;
                    if vehObj ~= nil and vehObj.isEntered then
                        if vehObj.modVeGS == nil then
                            vehObj.modVeGS = {group=0, pos=0};
                        end;
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
                        if vehObj.modVeGS == nil then
                            vehObj.modVeGS = {group=0, pos=0};
                        end;
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
                if (g_gui.currentGuiName ~= "" and g_gui.currentGuiName ~= nil) then
                    -- If player activates some GUI screen, stop VEGS from rendering
                    self.isModifying = false;
                else
                    self.isModifying = not InputBinding.hasEvent(InputBinding.VEGS_TOGGLE_EDIT);
                end;
            else
                self.isModifying = true;
            end;
        end;
        --
        if self.dirtyTimeout ~= nil and self.dirtyTimeout < g_currentMission.time then
            self.dirtyTimeout = nil;
            VehicleGroupsSwitcherEvent.sendEvent();
        end;
    else
        -- Editing not allowed
        self.isModifying = false;
    end;
    --
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
    elseif g_currentMission.showHelpText and ((self.keyModifier == nil) or (Input.isKeyPressed(self.keyModifier))) then
        -- Show keys in helpbox, only when modifier-key is pressed (if it has been assigned)
        g_currentMission:addHelpButtonText(g_i18n:getText("VEGS_GRP_TAB"),     InputBinding.VEGS_GRP_TAB);
        g_currentMission:addHelpButtonText(g_i18n:getText("VEGS_GRP_NXT"),     InputBinding.VEGS_GRP_NXT);
    end;

    if self.prevAction == nil and multiAction ~= nil then
        self.prevAction = {multiAction, g_currentMission.time};
    elseif self.prevAction ~= nil then
        local delay = g_currentMission.time - self.prevAction[2];
        if delay > 800 and delay < 2000 then 
            -- Keypress was more than 800ms, so it is a group enable/disable
            local b = VehicleGroupsSwitcher.groupsDisabled[self.prevAction[1]] or false;
            VehicleGroupsSwitcher.groupsDisabled[self.prevAction[1]] = not b;
            -- Do not let it change again
            self.prevAction[2] = self.prevAction[2] - 5000;
        end;
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
        g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent:new(foundVehObj, g_settingsNickname));
    end;
end;

function renderTextWithShade(x,y, textSize, forecolor, text)
    setTextColor(unpack(VehicleGroupsSwitcher.fontShadeColor));
    renderText(x + (textSize/20), y - (textSize/10), textSize, text);
    setTextColor(unpack(forecolor));
    renderText(x, y, textSize, text);
end;

function VehicleGroupsSwitcher:draw()
    if self.initialized < 1 then
        if InputBinding.isPressed(InputBinding.VEGS_TOGGLE_EDIT) then
            setTextAlignment(RenderText.ALIGN_CENTER);
            renderTextWithShade(0.5, 0.7, VehicleGroupsSwitcher.bigFontSize, VehicleGroupsSwitcher.fontColor, g_i18n:getText("ControlsError"));
        end;
        return;
    end;
    --
    VehicleGroupsSwitcher.showingVeGS = self.isModifying or ((self.keyModifier ~= nil) and (Input.isKeyPressed(self.keyModifier)));
    if VehicleGroupsSwitcher.showingVeGS then
        local slots = {}
        local unassigned = {}
        for idx=1,10 do
            slots[idx] = {}
        end;
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
        for idx=1,10 do
            table.sort(slots[idx], function(l,r) return l.modVeGS.pos < r.modVeGS.pos; end);
        end;
        --
        local xPos = 0.5;
        local yPos = VehicleGroupsSwitcher.hudPosSize.y;
        local yPosLowest = 0.5;
        --
-- FS2013        
        if self.hudBackground ~= nil then
            setOverlayColor(self.hudBackground, 1,1,1, 0.5);
            renderOverlay(self.hudBackground, 0.0,0.33, 1.0,0.50);
        end;
--]]
        --
        setTextBold(true);
        setTextAlignment(RenderText.ALIGN_CENTER);
        renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.bigFontSize, VehicleGroupsSwitcher.fontColor, g_i18n:getText("VEGS"));
        setTextAlignment(RenderText.ALIGN_LEFT);
        --
        for idx=1,10 do
            if idx == 1 then
                xPos = VehicleGroupsSwitcher.hudPosSize.x1;
                yPos = VehicleGroupsSwitcher.hudPosSize.y - VehicleGroupsSwitcher.smallFontSize;
            elseif idx == 6 then
                yPosLowest = math.min(yPos, yPosLowest);
                xPos = VehicleGroupsSwitcher.hudPosSize.x2;
                yPos = VehicleGroupsSwitcher.hudPosSize.y - VehicleGroupsSwitcher.smallFontSize;
            end;
            --
            setTextBold(true);
            yPos = yPos - VehicleGroupsSwitcher.bigFontSize;
            local grpColor = VehicleGroupsSwitcher.groupsDisabled[idx]==true and VehicleGroupsSwitcher.fontDisabledColor or VehicleGroupsSwitcher.fontColor;
            renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.bigFontSize, grpColor, string.format(g_i18n:getText("group"), idx));
            --
            setTextBold(false);
            for _,vehObj in pairs(slots[idx]) do
                local color = (vehObj.isEntered and VehicleGroupsSwitcher.fontSelectedColor or grpColor); --VehicleGroupsSwitcher.fontColor);
                yPos = yPos - VehicleGroupsSwitcher.smallFontSize;
                --local vehName = string.format("%d) ", vehObj.modVeGS.pos)..tostring(vehObj.name);
                renderTextWithShade(xPos + VehicleGroupsSwitcher.smallFontSize, yPos, VehicleGroupsSwitcher.smallFontSize, color, tostring(vehObj:getVehicleName()));
                --
                if vehObj.isControlled
                or vehObj.isHired  -- Hired helper
                or (vehObj.drive ~= nil and vehObj.drive == true)  -- CoursePlay
                then
                    local txt;
                    if vehObj.isControlled then
                        txt = vehObj.controllerName;
                        if txt == nil then
                            txt = g_i18n:getText("player");
                        end;
                    elseif vehObj.isHired then
                        txt = g_i18n:getText("hired");
                    elseif (vehObj.drive ~= nil and vehObj.drive == true) then
                        txt = g_i18n:getText("courseplay");
                    else
                        txt = g_i18n:getText("unknown");
                    end;
                    setTextAlignment(RenderText.ALIGN_RIGHT);
                    renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.smallFontSize, color, txt);
                    setTextAlignment(RenderText.ALIGN_LEFT);
                end;
            end;
        end;
        --
        if self.isModifying then
            xPos = VehicleGroupsSwitcher.hudPosSize.x;
            yPos = math.min(yPos, yPosLowest);
            --
            setTextBold(true);
            yPos = yPos - VehicleGroupsSwitcher.bigFontSize;
            renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.bigFontSize, VehicleGroupsSwitcher.fontColor, g_i18n:getText("unassigned"));
            --
            setTextBold(false);
            for _,vehObj in pairs(unassigned) do
                local color = (vehObj.isEntered and VehicleGroupsSwitcher.fontSelectedColor or VehicleGroupsSwitcher.fontColor);
                yPos = yPos - VehicleGroupsSwitcher.smallFontSize;
                renderTextWithShade(xPos + VehicleGroupsSwitcher.smallFontSize, yPos, VehicleGroupsSwitcher.smallFontSize, color, tostring(vehObj:getVehicleName()));
                --
                if vehObj.isControlled
                or vehObj.isHired  -- Hired helper
                or (vehObj.drive ~= nil and vehObj.drive == true)  -- CoursePlay
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
                    elseif (vehObj.drive ~= nil and vehObj.drive == true) then
                        txt = g_i18n:getText("courseplay");
                    elseif (vehObj.modFM ~= nil and vehObj.modFM.FollowVehicleObj ~= nil) then
                        txt = g_i18n:getText("followme");
                    else
                        txt = g_i18n:getText("unknown");
                    end;
                    setTextAlignment(RenderText.ALIGN_RIGHT);
                    renderTextWithShade(xPos, yPos, VehicleGroupsSwitcher.smallFontSize, color, txt);
                    setTextAlignment(RenderText.ALIGN_LEFT);
                end;
            end;
        end;
    end;
end;

--
function VehicleGroupsSwitcher.loadFromAttributesAndNodes(self, superFunc, xmlFile, key, resetVehicles)
    self.modVeGS = {group=0, pos=0};
    --
    if not resetVehicles and g_server ~= nil then
        local vegsGrpPos = getXMLString(xmlFile, key .. string.format("#vegsGrpPos"));
        if vegsGrpPos ~= nil then
            local parts = Utils.splitString(";", vegsGrpPos);
            if #parts > 0 then
                local grpPos = Utils.splitString(".", parts[1]);
                if #grpPos > 0 then
                    self.modVeGS.group = tonumber(grpPos[1]);
                end;
                if #grpPos > 1 then
                    self.modVeGS.pos = tonumber(grpPos[2]);
                end;
            end;
            if #parts > 1 then
                if parts[2] == "grpDis" and self.modVeGS.group >= 1 and self.modVeGS.group <= 10 then
                    VehicleGroupsSwitcher.groupsDisabled[self.modVeGS.group] = true;
                end;
            end;
            -- TODO: group-names
        else
            -- Attempt to read 'VeGS v0.92' setting.
            self.modVeGS.group = Utils.getNoNil(getXMLInt(xmlFile, key .. string.format("#vegs_group")), 0);
        end;
    end;
    --
    return superFunc(self, xmlFile, key, resetVehicles);
end;

function VehicleGroupsSwitcher.getSaveAttributesAndNodes(self, superFunc, nodeIdent)
    local attributes;
    local nodes;
    attributes, nodes = superFunc(self, nodeIdent);
    --
    if self.modVeGS ~= nil and self.modVeGS.group > 0 then
        local grpState = VehicleGroupsSwitcher.groupsDisabled[self.modVeGS.group]==true and "grpDis" or "grpEna";
        local grpName = "reserved"; -- TODO, make sure to HTML-entity convert this!
        attributes = attributes .. ' vegsGrpPos="'..string.format("%d.%d;%s;%s", self.modVeGS.group, self.modVeGS.pos, grpState, grpName)..'"';
    end;
    --
    return attributes, nodes;
end;

Vehicle.loadFromAttributesAndNodes = Utils.overwrittenFunction(Vehicle.loadFromAttributesAndNodes, VehicleGroupsSwitcher.loadFromAttributesAndNodes);
Vehicle.getSaveAttributesAndNodes  = Utils.overwrittenFunction(Vehicle.getSaveAttributesAndNodes,  VehicleGroupsSwitcher.getSaveAttributesAndNodes);

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
    -- v0.97
    if self.isRefreshRequest then
        -- Magic number zero means "request a refresh"
        cnt = 0;
    end;
    -- Do not rely on that the peers may have the same number of steerables in their array! So tell how many we are going to send now.
    streamWriteInt8(streamId, cnt); -- If more than 127 steerables, then this will be a problem!
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
end;

function VehicleGroupsSwitcherEvent:readStream(streamId, connection)
--print(tostring(g_currentMission.time).. "ms - VehicleGroupsSwitcherEvent:readStream(streamId, connection)");
    local cnt = streamReadInt8(streamId);
    for i=1,cnt do
        local id = streamReadInt32(streamId);
        local vegsGroup = streamReadUIntN(streamId, 4);
        local vegsPos   = streamReadUIntN(streamId, 4);
        local vehObj = networkGetObject(id);
        if vehObj ~= nil then
            if vehObj.modVeGS == nil then
                vehObj.modVeGS = {}
            end;
            vehObj.modVeGS.group = vegsGroup;
            vehObj.modVeGS.pos   = vegsPos;
            -- Will cause a race-condition, when another player also is in VeGS' edit-mode.
        end;
    end;
    -- Was it a refresh-request, and we are the server?
    if cnt == 0 and g_server ~= nil then
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

-- Patch 2.0.0.4
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
