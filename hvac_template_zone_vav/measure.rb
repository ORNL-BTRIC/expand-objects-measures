# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class HVACTemplateZoneVAV < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "HVACTemplate:Zone:VAV"
  end

  # human readable description
  def description
    return "OS Version of HVACTemplate:Zone:VAV"
  end

  # human readable description of modeling approach
  def modeler_description
    return "OS Version of HVACTemplate:Zone:VAV"
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
      if zone.thermostatSetpointDualSetpoint.is_initialized
        zone_handles << zone.handle.to_s
        zone_display_names << zone_name
      end
    end

    #add building to string vector with zones
    building = model.getBuilding
    zone_handles << building.handle.to_s
    zone_display_names << "*All Thermal Zones*"
    
    #make an argument for zones
    zones = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("zones", zone_handles, zone_display_names, true)
    zones.setDisplayName("Choose Thermal Zones to have VAV boxes.")
    zones.setDefaultValue("*All Thermal Zones*") #if no zone is chosen this will run on all zones
    args << zones
	
	#Need to select air loop (i.e., system for the VAV zones)
	#populate choice argument for air loops in the model
    air_loop_handles = OpenStudio::StringVector.new
    air_loop_display_names = OpenStudio::StringVector.new

    #putting air loop names into hash
    air_loop_args = model.getAirLoopHVACs
    air_loop_args_hash = {}
    air_loop_args.each do |air_loop_arg|
      air_loop_args_hash[air_loop_arg.name.to_s] = air_loop_arg
    end

    #looping through sorted hash of air loops
    air_loop_args_hash.sort.map do |air_loop_name,air_loop|
      air_loop_handles << air_loop.handle.to_s
      air_loop_display_names << air_loop_name
    end
    

    #make an argument for air loops
    system = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("system", air_loop_handles, air_loop_display_names,true)
    system.setDisplayName("Choose an Air Loop for zone VAV systems.")
    system.setDefaultValue("") #if no air loop is chosen this will run on all air loops
    args << system
	
	#choose reheating availability schedule name
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
	
	#Reheating coil
	
	reheat_type = OpenStudio::StringVector.new
    reheat_type << "None"
	reheat_type << "HotWater"
	reheat_type << "Electric"
    reheat_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('reheat_type', reheat_type, true)
    reheat_type.setDisplayName("Choose reheat type.")
    reheat_type.setDefaultValue("None")
    args << reheat_type
	
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
    zones = runner.getOptionalWorkspaceObjectChoiceValue("zones",user_arguments,model) #model is passed in because of argument type
    system = runner.getOptionalWorkspaceObjectChoiceValue("system",user_arguments,model)
	system_sch  = runner.getOptionalWorkspaceObjectChoiceValue("system_sch",user_arguments,model) #model is passed in because of argument type
	reheat_type = runner.getStringArgumentValue("reheat_type",user_arguments)
	
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
	
	# retrieve hot water loop
	hot_water_loop = nil
    hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                        model.getPlantLoopByName('Hot Water Loop').get
                        else
                        if reheat_type == "HotWater"
					      runner.registerError ("No hot water loop. Need to create a hot water loop to add hot water heating coil")
					    end
					 end
	
    # Control temps for HW loop
    # will only be used when hot_water_loop is provided.
    hw_temp_f = 180 # HW setpoint 180F
    hw_delta_t_r = 20 # 20F delta-T

    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get
	
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
	
	if system.empty?
      handle = runner.getStringArgumentValue("system",user_arguments)
      if handle.empty?
        runner.registerError("No system was chosen.")
        return false
      else
        runner.registerError("The selected system with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if not system.get.to_AirLoopHVAC.empty?
        selected_airloop = system.get.to_AirLoopHVAC.get
      else
        runner.registerError("Script Error - argument not showing up as system.")
        return false
      end
    end  #end of if system.empty?
    

	sys_dsn_prhtg_temp_f = 44.6 # Design central deck to preheat to 44.6F
    sys_dsn_clg_sa_temp_f = 57.2 # Design central deck to cool to 57.2F
    sys_dsn_htg_sa_temp_f = 62 # Central heat to 62F
    zn_dsn_clg_sa_temp_f = 55 # Design VAV box for 55F from central deck
    zn_dsn_htg_sa_temp_f = 122 # Design VAV box to reheat to 122F
    rht_rated_air_in_temp_f = 62 # Reheat coils designed to receive 62F
    rht_rated_air_out_temp_f = 90 # Reheat coils designed to supply 90F...but zone expects 122F...?
    clg_sa_temp_f = 55 # Central deck clg temp operates at 55F

    sys_dsn_prhtg_temp_c = OpenStudio.convert(sys_dsn_prhtg_temp_f, 'F', 'C').get
    sys_dsn_clg_sa_temp_c = OpenStudio.convert(sys_dsn_clg_sa_temp_f, 'F', 'C').get
    sys_dsn_htg_sa_temp_c = OpenStudio.convert(sys_dsn_htg_sa_temp_f, 'F', 'C').get
    zn_dsn_clg_sa_temp_c = OpenStudio.convert(zn_dsn_clg_sa_temp_f, 'F', 'C').get
    zn_dsn_htg_sa_temp_c = OpenStudio.convert(zn_dsn_htg_sa_temp_f, 'F', 'C').get
    rht_rated_air_in_temp_c = OpenStudio.convert(rht_rated_air_in_temp_f, 'F', 'C').get
    rht_rated_air_out_temp_c = OpenStudio.convert(rht_rated_air_out_temp_f, 'F', 'C').get
    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get

    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)
	
   # Hook the VAV system to each zone
    selected_zones.each do |zone|
    # Reheat coil
       rht_coil = nil
       if reheat_type == "Electric" 
        rht_coil = OpenStudio::Model::CoilHeatingElectric.new(model, system_sch)
        rht_coil.setName("#{zone.name} Rht Coil")
       elsif  reheat_type == "HotWater"
        rht_coil = OpenStudio::Model::CoilHeatingWater.new(model, system_sch)        #rht_coil.setName("#{zone.name} Rht Coil")
        rht_coil.setRatedInletWaterTemperature(hw_temp_c)
        rht_coil.setRatedInletAirTemperature(rht_rated_air_in_temp_c)
        rht_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        rht_coil.setRatedOutletAirTemperature(rht_rated_air_out_temp_c)
        hot_water_loop.addDemandBranchForComponent(rht_coil)
       else
	    rht_coil = nil
	  end

      # VAV terminal
	  if reheat_type == "None"
         terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, system_sch)
         terminal.setName("#{zone.name} VAV Term")
         selected_airloop.addBranchForZone(zone, terminal.to_StraightComponent)
	  else
         terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, system_sch, rht_coil)
         terminal.setName("#{zone.name} VAV Term")
         terminal.setZoneMinimumAirFlowMethod('Constant')
         selected_airloop.addBranchForZone(zone, terminal.to_StraightComponent)
      end
	  

      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(zn_dsn_clg_sa_temp_c)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(zn_dsn_htg_sa_temp_c)
    end

    return true
  end	
	
 end
 

# register the measure to be used by the application
HVACTemplateZoneVAV.new.registerWithApplication
