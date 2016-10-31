--
-- Vehicle-groups Switcher (VeGS)
--
-- @author  Decker_MMIV - fs-uk.com, forum.farming-simulator.com, modhoster.com
-- @date    2016-11-xx
--

RegistrationHelper_VeGS = {};
RegistrationHelper_VeGS.isLoaded = false;

if SpecializationUtil.specializations['VehicleGroupsSwitcher_LoadSave'] == nil then
    SpecializationUtil.registerSpecialization('VehicleGroupsSwitcher_LoadSave', 'VehicleGroupsSwitcher_LoadSave', g_currentModDirectory .. 'VehicleGroupsSwitcher_LoadSave.lua')
    RegistrationHelper_VeGS.isLoaded = false;
end

function RegistrationHelper_VeGS:loadMap(name)
    if not g_currentMission.RegistrationHelper_VeGS_isLoaded then
        if not RegistrationHelper_VeGS.isLoaded then
            self:register();
        end
        g_currentMission.RegistrationHelper_VeGS_isLoaded = true
    else
        print("Error: VehicleGroupsSwitcher_LoadSave has been loaded already!");
    end
end

function RegistrationHelper_VeGS:deleteMap()
    g_currentMission.RegistrationHelper_VeGS_isLoaded = nil
end

function RegistrationHelper_VeGS:keyEvent(unicode, sym, modifier, isDown)
end

function RegistrationHelper_VeGS:mouseEvent(posX, posY, isDown, isUp, button)
end

function RegistrationHelper_VeGS:update(dt)
end

function RegistrationHelper_VeGS:draw()
end

function RegistrationHelper_VeGS:register()
    for _, vehicle in pairs(VehicleTypeUtil.vehicleTypes) do
        if vehicle ~= nil and SpecializationUtil.hasSpecialization(Drivable, vehicle.specializations) then
            table.insert(vehicle.specializations, SpecializationUtil.getSpecialization("VehicleGroupsSwitcher_LoadSave"))
        end
    end
    RegistrationHelper_VeGS.isLoaded = true
end

addModEventListener(RegistrationHelper_VeGS)