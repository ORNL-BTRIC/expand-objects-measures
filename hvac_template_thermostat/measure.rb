# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class HVACTemplateThermostat < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "HVACTemplate:Thermostat"
  end

  # human readable description
  def description
    return "Assign cooling and heating setpoint temperature schedule to thermal zones."
  end 	

  # human readable description of modeling approach
  def modeler_description
    return "Assign cooling and heating setpoint temperature schedule to thermal zones. Use existing cooling and heating schedule, or generate ones from constant heating and cooling setpoint temperature." 
  end 
  
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #populate choice argument for thermal zones in the model
    zone_handles = OpenStudio::StringVector.new
    zone_display_names = OpenStudio::StringVector.new

    #putting zone names into hash
    zone_hash = {}
    model.getThermalZones.each do |zone|
      zone_hash[zone.name.to_s] = zone
    end

    #looping through sorted hash of zones
    zone_hash.sort.map do |zone_name, zone|
      #if zone.thermostatSetpointDualSetpoint.is_initialized
        zone_handles << zone.handle.to_s
        zone_display_names << zone_name
    end
    

    #add building to string vector with zones
    building = model.getBuilding
    zone_handles << building.handle.to_s
    zone_display_names << "*All Thermal Zones*"
    
    #make an argument for zones
    zones = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("zones", zone_handles, zone_display_names, true)
    zones.setDisplayName("Choose Thermal Zones to add/change thermostat schedules on.")
    zones.setDefaultValue("*All Thermal Zones*") 
    args << zones

    #populate choice argument for schedules in the model
    sch_handles = OpenStudio::StringVector.new
    sch_display_names = OpenStudio::StringVector.new

    #putting schedule names into hash
    sch_hash = {}
    model.getSchedules.each do |sch|
      sch_hash[sch.name.to_s] = sch
    end

    #looping through sorted hash of schedules
    sch_hash.sort.map do |sch_name, sch|
      if not sch.scheduleTypeLimits.empty?
        unitType = sch.scheduleTypeLimits.get.unitType
        if unitType == "Temperature"
          sch_handles << sch.handle.to_s
          sch_display_names << sch_name
        end
      end
    end
	
    #add empty handle to string vector with schedules
    sch_handles << OpenStudio::toUUID("").to_s
    sch_display_names << "Not Used"

    #make an argument for cooling schedule
	#either using existing cooling schedule or use a constant temperature for cooling setpoint temperature
    cooling_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("cooling_sch", sch_handles, sch_display_names, false)
    cooling_sch.setDisplayName("Choose Cooling Schedule.")
    cooling_sch.setDefaultValue("Not Used") 
    args << cooling_sch   

    #make an argument for cooling schedule from a constant temp
    cooling_temp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('cooling_temp', false)
    cooling_temp.setDisplayName("Or define constant cooling setpoint temperature (F).")
    cooling_temp.setDescription("This value will only be used when cooling schedule was not selected (Not Used)")
	cooling_temp.setDefaultValue("75") 
    args << cooling_temp   	

    #make an argument for heating schedule
    heating_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("heating_sch", sch_handles, sch_display_names, false)
    heating_sch.setDisplayName("Choose Heating Schedule.")
    heating_sch.setDefaultValue("Not Used")
    args << heating_sch
	
	#make an argument for heating schedule from a constant temp
    heating_temp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('heating_temp', false)
    heating_temp.setDisplayName("Or define constant heating setpoint temperature (F).")
    heating_temp.setDescription("This value will only be used when heating schedule was not selected (Not Used)")
	heating_temp.setDefaultValue("70")
    args << heating_temp   
    
    return args
  end #end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

   #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    zones = runner.getOptionalWorkspaceObjectChoiceValue("zones",user_arguments,model) #model is passed in because of argument type
    cooling_sch = runner.getOptionalWorkspaceObjectChoiceValue("cooling_sch",user_arguments,model) #model is passed in because of argument type
    heating_sch = runner.getOptionalWorkspaceObjectChoiceValue("heating_sch",user_arguments,model) #model is passed in because of argument type
    cooling_temp = runner.getDoubleArgumentValue("cooling_temp",user_arguments) #model is passed in because of argument type
    heating_temp = runner.getDoubleArgumentValue("heating_temp",user_arguments) #model is passed in because of argument type

    #check the zone selection for reasonableness
    apply_to_all_zones = false
    selected_zone = nil
    if zones.empty?
      handle = runner.getStringArgumentValue("zones",user_arguments)
      if handle.empty?
        runner.registerError("No thermal zone was chosen.")
        return false
      else
        runner.registerError("The selected thermal zone with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if not zones.get.to_ThermalZone.empty?
        selected_zone = zones.get.to_ThermalZone.get
      elsif not zones.get.to_Building.empty?
        apply_to_all_zones = true
      else
        runner.registerError("Script Error - argument not showing up as thermal zone.")
        return false
      end
    end  #end of if zones.empty?
    
    #depending on user input, add selected zones to an array
    selected_zones = [] 
    if apply_to_all_zones == true
      selected_zones = model.getThermalZones
    else
      selected_zones << selected_zone
    end

	if cooling_sch.empty?
      handle = runner.getStringArgumentValue("cooling_sch",user_arguments)
      if handle == OpenStudio::toUUID("").to_s
        # generate cooling schedule from a constant temperature
        #define starting units
        cooling_temp_ip = OpenStudio::convert(cooling_temp,"F","C").get 
        cooling_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        cooling_sch.setName("cooling_sch")
        cooling_sch.defaultDaySchedule().setName("Cooling Temp Default")
        cooling_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),cooling_temp_ip)
      else
        runner.registerError("The selected schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if not cooling_sch.get.to_Schedule.empty?
        cooling_sch = cooling_sch.get.to_Schedule.get
      else
        runner.registerError("Script Error - argument not showing up as schedule.")
        return false
      end
    end  #end of if cooling_sch.empty?

	#check the heating_sch for reasonableness
    if heating_sch.empty?
      handle = runner.getStringArgumentValue("heating_sch",user_arguments)
      if handle == OpenStudio::toUUID("").to_s
        # generate heating schedule from a constant temperature
	
        #define starting units
        heating_temp_ip = OpenStudio::convert(heating_temp,"F","C").get 
        heating_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        heating_sch.setName("heating_sch")
        heating_sch.defaultDaySchedule().setName("Heating Temp Default")
        heating_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),heating_temp_ip)
      else
        runner.registerError("The selected schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if not heating_sch.get.to_Schedule.empty?
        heating_sch = heating_sch.get.to_Schedule.get
      else
        runner.registerError("Script Error - argument not showing up as schedule.")
        return false
      end
    end  #end of if heating_sch.empty?
	
    if heating_sch or cooling_sch
    
      selected_zones.each do |zone|
        
        thermostatSetpointDualSetpoint = zone.thermostatSetpointDualSetpoint
        if thermostatSetpointDualSetpoint.empty?
          thermostatSetpointDualSetpoint = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
		  thermostatSetpointDualSetpoint.setHeatingSetpointTemperatureSchedule(heating_sch)
		  thermostatSetpointDualSetpoint.setCoolingSetpointTemperatureSchedule(cooling_sch)
		  zone.setThermostatSetpointDualSetpoint(thermostatSetpointDualSetpoint)
		next
        end
		
        thermostatSetpointDualSetpoint = thermostatSetpointDualSetpoint.get
        # make sure this thermostat is unique to this zone
        if thermostatSetpointDualSetpoint.getSources("OS_ThermalZone".to_IddObjectType).size > 1
          # if not create a new copy
          runner.registerInfo("Copying thermostat for thermal zone '#{zone.name}'.")
          
          oldThermostat = thermostatSetpointDualSetpoint
          thermostatSetpointDualSetpoint = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
          if not oldThermostat.heatingSetpointTemperatureSchedule.empty?
            thermostatSetpointDualSetpoint.setHeatingSetpointTemperatureSchedule(oldThermostat.heatingSetpointTemperatureSchedule.get)
          end
          if not oldThermostat.coolingSetpointTemperatureSchedule.empty?
            thermostatSetpointDualSetpoint.setCoolingSetpointTemperatureSchedule(oldThermostat.coolingSetpointTemperatureSchedule.get)
          end
          zone.setThermostatSetpointDualSetpoint(thermostatSetpointDualSetpoint)
        end
          
        if heating_sch
          if not thermostatSetpointDualSetpoint.setHeatingSetpointTemperatureSchedule(heating_sch)
            runner.registerError("Script Error - cannot set heating schedule for thermal zone '#{zone.name}'.")
            return false
          end
        end
        
        if cooling_sch
          if not thermostatSetpointDualSetpoint.setCoolingSetpointTemperatureSchedule(cooling_sch)
            runner.registerError("Script Error - cannot set cooling schedule for thermal zone '#{zone.name}'.")
            return false
          end
        end
                     
     end
    end
                
   
    return true
 
  end #end the run method
end
# register the measure to be used by the application
HVACTemplateThermostat.new.registerWithApplication
