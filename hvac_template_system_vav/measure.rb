# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class HVACTemplateSystemVAV < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "HVACTemplate:System:VAV"
  end

  # human readable description
  def description
    return "Create VAV System"
  end

  # human readable description of modeling approach
  def modeler_description
    return "OS Version of HVACTemplate:System:PackagedVAV. Input values in this measure will generate Packaged VAV system. Another template measure HVACTemplate:Zone:VAV, or HVACTemplate:Zone:VAV:FanPowered, or HVACTemplate:Zone:VAV:HeatAndCool should be applied after applying this measure."
  end

  # define the arguments that the user will input
   def arguments(model)
   args = OpenStudio::Ruleset::OSArgumentVector.new

    # the name of the space to add to the model
    system_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("system_name", true) #Do we need to call this air loop name instead of system name?
    system_name.setDisplayName("New system name")
    system_name.setDescription("This name will be used as the name of the new system.")
    args << system_name
	
	# choose system availability schedule name
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
        #puts "#{sch.name}, #{unitType}"
        if unitType == "Availability"
          sch_handles << sch.handle.to_s
          sch_display_names << sch_name
        end
      end
    end

    #add empty handle to string vector with schedules
    sch_handles << OpenStudio::toUUID("").to_s
    sch_display_names << "*Always On*"
    
    #make an argument for system availability schedule
    system_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("system_sch", sch_handles, sch_display_names, true)
    system_sch.setDisplayName("Choose System Availability Schedule.")
    system_sch.setDefaultValue("*Always On*") 
    args << system_sch

 # Define heating coil
 # Choose heating coil type

    heating_coil_options = OpenStudio::StringVector.new
    heating_coil_options << "None"
	heating_coil_options << "Gas"
	heating_coil_options << "Electric"
	heating_coil_options << "HotWater"
    heating_coil_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('heating_coil_type', heating_coil_options, true)
    heating_coil_type.setDisplayName("Choose the type of heating coil.")
    heating_coil_type.setDefaultValue("None")
    args << heating_coil_type

# Define gas heating coil efficiency
    rated_hc_gas_efficiency = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('rated_hc_gas_efficiency', false)
    rated_hc_gas_efficiency.setDisplayName("Rated Gas Heating Coil Efficiency (0-1.00)")
    rated_hc_gas_efficiency.setDefaultValue(0.8)
    args << rated_hc_gas_efficiency	
    



	#make choice argument economizer control type
    economizer_type = OpenStudio::StringVector.new
    economizer_type << "FixedDryBulb"
    economizer_type << "FixedEnthalpy"
    economizer_type << "DifferentialDryBulb"
    economizer_type << "DifferentialEnthalpy"
    economizer_type << "FixedDewPointAndDryBulb"
    economizer_type << "NoEconomizer"
    economizer_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("economizer_type", economizer_type,true)
    economizer_type.setDisplayName("Economizer Control Type.")
    economizer_type.setDefaultValue("NoEconomizer")
	args << economizer_type	
	
    ##make an argument for econoMaxDryBulbTemp
    econoMaxDryBulbTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("econoMaxDryBulbTemp",true)
    econoMaxDryBulbTemp.setDisplayName("Economizer Maximum Limit Dry-Bulb Temperature (F).")
    econoMaxDryBulbTemp.setDefaultValue(69.0)
    args << econoMaxDryBulbTemp

    #make an argument for econoMaxEnthalpy
    econoMaxEnthalpy = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("econoMaxEnthalpy",true)
    econoMaxEnthalpy.setDisplayName("Economizer Maximum Enthalpy (Btu/lb).")
    econoMaxEnthalpy.setDefaultValue(28.0)
    args << econoMaxEnthalpy

    #make an argument for econoMaxDewpointTemp
    econoMaxDewpointTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("econoMaxDewpointTemp",true)
    econoMaxDewpointTemp.setDisplayName("Economizer Maximum Limit Dewpoint Temperature (F).")
    econoMaxDewpointTemp.setDefaultValue(55.0)
    args << econoMaxDewpointTemp

    #make an argument for econoMinDryBulbTemp
    econoMinDryBulbTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("econoMinDryBulbTemp",true)
    econoMinDryBulbTemp.setDisplayName("Economizer Minimum Limit Dry-Bulb Temperature (F).")
    econoMinDryBulbTemp.setDefaultValue(-100.0)
    args << econoMinDryBulbTemp
	
	#make choice argument for heat recovery type
    heat_recovery_type = OpenStudio::StringVector.new
    heat_recovery_type << "None"
    heat_recovery_type << "Sensible"
    heat_recovery_type << "Enthalpy"
    heat_recovery_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("heat_recovery_type", heat_recovery_type,true)
    heat_recovery_type.setDisplayName("Heat Recovery Type.")
    heat_recovery_type.setDefaultValue("None")
	args << heat_recovery_type	
	
	#make an argument for sensible heat recovery effectiveness
    sens_recovery = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sens_recovery",true)
    sens_recovery.setDisplayName("Sensible Heat Recoevery Effectiveness (0-1.0).")
    sens_recovery.setDefaultValue(0.7)
    args << sens_recovery
	
	#make an argument for latent heat recovery effectiveness
    lat_recovery = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("lat_recovery",true)
    lat_recovery.setDisplayName("Latent Heat Recoevery Effectiveness (0-1.0).")
    lat_recovery.setDefaultValue(0.65)
    args << lat_recovery
	
	#make choice argument dehumidification
    dehumidification_control_type = OpenStudio::StringVector.new
    dehumidification_control_type << "None"
	dehumidification_control_type << "CoolReheat"
    dehumidification_control_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("dehumidification_control_type", dehumidification_control_type,true)
    dehumidification_control_type.setDisplayName("Dehumidification control Type.")
	dehumidification_control_type.setDefaultValue("None")
    args << dehumidification_control_type	
    
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
        zone_handles << zone.handle.to_s
        zone_display_names << zone_name
    end
	
	#add empty handle to string vector with schedules
    zone_handles << OpenStudio::toUUID("").to_s
    zone_display_names << "Not Used"
	
	
	#make an argument for dehumidification control zones
    dehumidification_control_zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("dehumidification_control_zone", zone_handles, zone_display_names, false)
    dehumidification_control_zone.setDisplayName("Choose control Zone for dehumidification.")
    dehumidification_control_zone.setDefaultValue("")
    args << dehumidification_control_zone
		
	#make an argument for dehumidification setpoint
    dehumidification_setpoint = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("dehumidification_setpoint",true)
    dehumidification_setpoint.setDisplayName("Dehumidification setpoint (percent).")
    dehumidification_setpoint.setDefaultValue(60)
    args << dehumidification_setpoint
	
	#make choice argument humidifier
    humidifier_type = OpenStudio::StringVector.new
    humidifier_type << "None"
	humidifier_type << "ElectricSteam"
    humidifier_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("humidifier_type", humidifier_type,true)
    humidifier_type.setDisplayName("Humidifier Type.")
	humidifier_type.setDefaultValue("None")
    args << humidifier_type	
	
	#make an argument for humidifier control zones
    humidifier_control_zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("humidifier_control_zone", zone_handles, zone_display_names, false)
    humidifier_control_zone.setDisplayName("Choose control Zone for humidifier.")
    humidifier_control_zone.setDefaultValue("")
    args << humidifier_control_zone
		
	#make an argument for humidifier setpoint
    humidifier_setpoint = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("humidifier_setpoint",true)
    humidifier_setpoint.setDisplayName("humidifier setpoint (percent).")
    humidifier_setpoint.setDefaultValue(30)
    args << humidifier_setpoint
	
return args
 
 end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    system_name = runner.getStringArgumentValue("system_name", user_arguments)
    system_sch  = runner.getOptionalWorkspaceObjectChoiceValue("system_sch",user_arguments,model) #model is passed in because of argument type
    heating_coil_type = runner.getStringArgumentValue("heating_coil_type",user_arguments)
    rated_hc_gas_efficiency = runner.getDoubleArgumentValue("rated_hc_gas_efficiency",user_arguments) 
	economizer_type = runner.getStringArgumentValue("economizer_type",user_arguments)
    econoMaxDryBulbTemp = runner.getDoubleArgumentValue("econoMaxDryBulbTemp",user_arguments)
    econoMaxEnthalpy = runner.getDoubleArgumentValue("econoMaxEnthalpy",user_arguments)
    econoMaxDewpointTemp = runner.getDoubleArgumentValue("econoMaxDewpointTemp",user_arguments)
    econoMinDryBulbTemp = runner.getDoubleArgumentValue("econoMinDryBulbTemp",user_arguments)
    heat_recovery_type = runner.getStringArgumentValue("heat_recovery_type", user_arguments)
	sens_recovery = runner.getDoubleArgumentValue("sens_recovery",user_arguments)
	lat_recovery = runner.getDoubleArgumentValue("lat_recovery",user_arguments)
	dehumidification_control_type = runner.getStringArgumentValue("dehumidification_control_type",user_arguments)
	dehumidification_control_zone = runner.getOptionalWorkspaceObjectChoiceValue("dehumidification_control_zone", user_arguments,model)
	dehumidification_setpoint = runner.getDoubleArgumentValue("dehumidification_setpoint",user_arguments)
	humidifier_type = runner.getStringArgumentValue("humidifier_type",user_arguments)
	humidifier_control_zone = runner.getOptionalWorkspaceObjectChoiceValue("humidifier_control_zone",user_arguments,model)
	humidifier_setpoint = runner.getDoubleArgumentValue("humidifier_setpoint",user_arguments)
  
	#retrieve selected thermal control zones for humidifier and dehumidification
   	if dehumidification_control_type == "CoolReheat"
	   selected_dehumidification_control_zone =  dehumidification_control_zone.get.to_ThermalZone.get
	end
	if humidifier_type == "ElectricSteam"
       selected_humidifier_control_zone =  humidifier_control_zone.get.to_ThermalZone.get
    end
	
    # check the system_name for reasonableness   --> Need to update per added input parameters.
    if system_name.empty?
      runner.registerError("Empty system name was entered.")
      return false
    end
	
		#check the system_sch for reasonableness
    if system_sch.empty?
      handle = runner.getStringArgumentValue("system_sch",user_arguments)
      if handle == OpenStudio::toUUID("").to_s
        system_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        system_sch.setName("system_sch")
        system_sch.defaultDaySchedule().setName("system schedule Default")
        system_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),1.0)
      else
        runner.registerError("The selected schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if not system_sch.get.to_Schedule.empty?
        system_sch = system_sch.get.to_Schedule.get
      else
        runner.registerError("Script Error - argument not showing up as schedule.")
        return false
      end
    end  

	#check economizer values for reasonableness
    default = 69 #same value as default argument
    if econoMaxDryBulbTemp > default * 1.2
      runner.registerWarning("Economizer Maximum Limit Dry-Bulb Temperature of #{econoMaxDryBulbTemp}(F) seems high.")
    elsif econoMaxDryBulbTemp < default * 0.8
      runner.registerWarning("Economizer Maximum Limit Dry-Bulb Temperature of #{econoMaxDryBulbTemp}(F) seems low.")
    end
    #this argument has an error check in addition to the warning check.
    if econoMaxDryBulbTemp > 150
      runner.registerWarning("Economizer Maximum Limit Dry-Bulb Temperature of #{econoMaxDryBulbTemp}(F) is too high. Measure will not run.")
    elsif econoMaxDryBulbTemp < 20
      runner.registerWarning("Economizer Maximum Limit Dry-Bulb Temperature of #{econoMaxDryBulbTemp}(F) is too high. Measure will not run.")
    end

    default = 28 #same value as default argument
    if econoMaxEnthalpy > default * 1.1
      runner.registerWarning("Economizer Maximum Enthalpy of #{econoMaxEnthalpy}(Btu/lb) seems high.")
    elsif econoMaxEnthalpy < default * 0.9
      runner.registerWarning("Economizer Maximum Enthalpy of #{econoMaxEnthalpy}(Btu/lb) seems low.")
    end

    default = 55 #same value as default argument
    if econoMaxDewpointTemp > default * 1.2
      runner.registerWarning("Economizer Maximum Limit Dewpoint Temperature of #{econoMaxDewpointTemp}(F) seems high.")
    elsif econoMaxDewpointTemp < default * 0.8
      runner.registerWarning("Economizer Maximum Limit Dewpoint Temperature of #{econoMaxDewpointTemp}(F) seems low.")
    end

	# retrieve hot water loop
	hot_water_loop = nil
	hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                        model.getPlantLoopByName('Hot Water Loop').get
					 else
					   if heating_coil_type == "HotWater"
					      runner.registerError ("No hot water loop. Need to create a hot water loop to add hot water heating coil")
					   end
					 end
	
	# retrieve chilled water loop
	chilled_water_loop = nil
    chilled_water_loop = if model.getPlantLoopByName('Chilled Water Loop').is_initialized
                            model.getPlantLoopByName('Chilled Water Loop').get
                 		 else
						    runner.registerError ("No chilled water loop. VAV system needs chilled water loop")
					   	 end

    # Default control temps for HW loop

    hw_temp_f = 180 # HW setpoint 180F
    hw_delta_t_r = 20 # 20F delta-T

    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get
	
    # Control temps used across all air handlers
    clg_sa_temp_f = 55.04 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    preclg_sa_temp_f = 55.04 # Precool to 55F
    htg_sa_temp_f = 55.04 # Central deck htg temp 55F
    rht_sa_temp_f = 104 # VAV box reheat to 104F
    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f, 'F', 'C').get
    preclg_sa_temp_c = OpenStudio.convert(preclg_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
	
    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

	# Air handler (Air loop)
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    air_loop.setName(system_name)
    air_loop.setAvailabilitySchedule(system_sch)
	
	# Air handler controls
    stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    stpt_manager.addToNode(air_loop.supplyOutletNode)
        
	# sizing_system.setPreheatDesignTemperature(sys_dsn_prhtg_temp_c)
    sizing_system = air_loop.sizingSystem
    sizing_system.setPreheatDesignTemperature(prehtg_sa_temp_c)
    sizing_system.setPrecoolDesignTemperature(preclg_sa_temp_c)
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_sa_temp_c)
    sizing_system.setSizingOption('NonCoincident')
    sizing_system.setAllOutdoorAirinCooling(false)
    sizing_system.setAllOutdoorAirinHeating(false)
    air_loop.setNightCycleControlType('CycleOnAny')
	
    # Fan
    fan = OpenStudio::Model::FanVariableVolume.new(model, system_sch)
    fan.setName("#{air_loop.name} Fan")
    fan.setFanPowerMinimumFlowRateInputMethod('fraction')
    fan.setFanPowerMinimumFlowFraction(0.25)
    fan.addToNode(air_loop.supplyInletNode)

	# Select heating coil type - if users want to use hotwater heating coil, hot water loop and boilers should be created first. 
	case heating_coil_type
	when "Electric"
	  htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, system_sch)
      htg_coil.setName("#{air_loop.name} Main Htg Coil")
      htg_coil.addToNode(air_loop.supplyInletNode)
	when "Gas" 
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, system_sch)
	  htg_coil.setGasBurnerEfficiency(rated_hc_gas_efficiency)
      htg_coil.setName("#{air_loop.name} Main Htg Coil")
      htg_coil.addToNode(air_loop.supplyInletNode)
	when "HotWater"
	     htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, system_sch)
         htg_coil.setName("#{air_loop.name} Main Htg Coil")
         htg_coil.setRatedInletWaterTemperature(hw_temp_c)
         htg_coil.setRatedInletAirTemperature(prehtg_sa_temp_c)
         htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
         htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)
         htg_coil.addToNode(air_loop.supplyInletNode)
         hot_water_loop.addDemandBranchForComponent(htg_coil)
	when "None"
      runner.registerInfo("No heating coil was selected.")
    end
     	
    # Cooling coil
    clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, system_sch)
    clg_coil.setName("#{air_loop.name} Clg Coil")
    clg_coil.addToNode(air_loop.supplyInletNode)
    clg_coil.setHeatExchangerConfiguration('CrossFlow')
    chilled_water_loop.addDemandBranchForComponent(clg_coil)
    clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")
	

	# Outdoor air intake system & economizer controller
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.setMinimumOutdoorAirSchedule(system_sch)
    oa_intake_controller.setEconomizerControlType(economizer_type)
	oa_intake_controller.setEconomizerMaximumLimitDryBulbTemperature(econoMaxDryBulbTemp)
	oa_intake_controller.setEconomizerMaximumLimitEnthalpy(econoMaxEnthalpy)
	oa_intake_controller.setEconomizerMaximumLimitDewpointTemperature(econoMaxDewpointTemp)
	oa_intake_controller.setEconomizerMinimumLimitDryBulbTemperature(econoMinDryBulbTemp)
	
	oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)
    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Ventilation Controller")
    controller_mv.setAvailabilitySchedule(system_sch)
    
	# Add ERV
    if heat_recovery_type == "Sensible"
       erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
	   erv.setSensibleEffectivenessat100HeatingAirFlow(sens_recovery)
       erv.setLatentEffectivenessat100HeatingAirFlow(0.0)
       erv.setSensibleEffectivenessat75HeatingAirFlow(sens_recovery+0.05)
       erv.setLatentEffectivenessat75HeatingAirFlow(0.0)
       erv.setSensibleEffectivenessat100CoolingAirFlow(sens_recovery)
       erv.setLatentEffectivenessat100CoolingAirFlow(0.0)
       erv.setSensibleEffectivenessat75CoolingAirFlow(sens_recovery+0.05)
       erv.setLatentEffectivenessat75CoolingAirFlow(0.0)
	   erv.setSupplyAirOutletTemperatureControl(true)
	   erv.setHeatExchangerType('Rotary')
       erv.setFrostControlType('MinimumExhaustTemperature')
       erv.setThresholdTemperature(1.7) # EPlus default
       erv.addToNode(oa_intake.outboardOANode.get)
	elsif heat_recovery_type == "Enthalpy"
	   erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
       erv.setSensibleEffectivenessat100HeatingAirFlow(sens_recovery)
       erv.setLatentEffectivenessat100HeatingAirFlow(lat_recovery)
       erv.setSensibleEffectivenessat75HeatingAirFlow(sens_recovery+0.05)
       erv.setLatentEffectivenessat75HeatingAirFlow(lat_recovery+0.05)
       erv.setSensibleEffectivenessat100CoolingAirFlow(sens_recovery)
       erv.setLatentEffectivenessat100CoolingAirFlow(lat_recovery)
       erv.setSensibleEffectivenessat75CoolingAirFlow(sens_recovery+0.05)
       erv.setLatentEffectivenessat75CoolingAirFlow(lat_recovery+0.05)
	   erv.setSupplyAirOutletTemperatureControl(true)
       erv.setHeatExchangerType('Rotary')
       erv.setFrostControlType('MinimumExhaustTemperature')
       erv.setThresholdTemperature(1.7) # EPlus default
       erv.addToNode(oa_intake.outboardOANode.get)
	end	

		# Humidistat schedule
	if dehumidification_control_type == "CoolReheat"
	   dehumidification_sch = OpenStudio::Model::ScheduleRuleset.new(model)
	   dehumidification_sch.setName("dehumidification_sch")
	   dehumidification_sch.defaultDaySchedule().setName("dehumidification schedule Default")
	   dehumidification_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),dehumidification_setpoint)
	end
	if humidifier_type == "ElectricSteam"
       humidifier_sch = OpenStudio::Model::ScheduleRuleset.new(model)
	   humidifier_sch.setName("humidifier_sch")
	   humidifier_sch.defaultDaySchedule().setName("humidifier schedule Default")
	   humidifier_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),humidifier_setpoint)	
	end
	
	# Humidistat schedule without humidifier
       no_humidifier_sch = OpenStudio::Model::ScheduleRuleset.new(model)
	   no_humidifier_sch.setName("no_humidifier_sch")
	   no_humidifier_sch.defaultDaySchedule().setName("no humidifier schedule Default")
	   no_humidifier_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),0.0)	
	
	# Humidistat schedule without dehumidification control
       no_dehumidification_sch = OpenStudio::Model::ScheduleRuleset.new(model)
	   no_dehumidification_sch.setName("no_dehumidification_sch")
	   no_dehumidification_sch.defaultDaySchedule().setName("no dehumidification schedule Default")
	   no_dehumidification_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),100.0)
	
    # Add humidistat
    case humidifier_type 
	when "None"
		if dehumidification_control_type == "None"
			runner.registerInfo("No humidity controls.")
		elsif dehumidification_control_type == "CoolReheat"
			humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
			humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(dehumidification_sch)
			humidistat.setHumidifyingRelativeHumiditySetpointSchedule(no_humidifier_sch)
			selected_dehumidification_control_zone.setZoneControlHumidistat(humidistat)
		end
	when "ElectricSteam"
		if dehumidification_control_type == "None"
			humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
			humidistat.setHumidifyingRelativeHumiditySetpointSchedule(humidifier_sch)
		    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(no_dehumidification_sch)
			selected_humidifier_control_zone.setZoneControlHumidistat(humidistat)
	    elsif dehumidification_control_type == "CoolReheat"
		    if selected_humidifier_control_zone == selected_dehumidification_control_zone
				  humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
			      humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(dehumidification_sch)
				  humidistat.setHumidifyingRelativeHumiditySetpointSchedule(humidifier_sch)
				  selected_humidifier_control_zone.setZoneControlHumidistat(humidistat)
	        else
			      humidistat_1 = OpenStudio::Model::ZoneControlHumidistat.new(model)
			      humidistat_1.setHumidifyingRelativeHumiditySetpointSchedule(humidifier_sch)
				  humidistat_1.setDehumidifyingRelativeHumiditySetpointSchedule(no_dehumidification_sch)
				  selected_humidifier_control_zone.setZoneControlHumidistat(humidistat_1) 
			      humidistat_2 = OpenStudio::Model::ZoneControlHumidistat.new(model)
				  humidistat_2.setDehumidifyingRelativeHumiditySetpointSchedule(dehumidification_sch)
				  humidistat_2.setHumidifyingRelativeHumiditySetpointSchedule(no_humidifier_sch)
				  selected_dehumidification_control_zone.setZoneControlHumidistat(humidistat_2)
			end
		end
	end
    
  return true
end

  
end
# register the measure to be used by the application
HVACTemplateSystemVAV.new.registerWithApplication
