# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class HVACTemplatePlantChiller < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "HVACTemplate:Plant:Chiller"
  end

  # human readable description
  def description
    return "Creat chiller"
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

	# Chiller type
	chiller_type = OpenStudio::StringVector.new
    chiller_type << "DistrictChilledWater"
	chiller_type << "ElectricCentrifugalChiller"
    chiller_type << "ElectricScrewChiller"
	chiller_type << "ElectricReciprocatingChiller"
    chiller_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('chiller_type', chiller_type, true)
    chiller_type.setDisplayName("Choose chiller type.")
    chiller_type.setDefaultValue("ElectricReciprocatingChiller")
    args << chiller_type
	
    # chiller COP
    chiller_cop = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('chiller_cop', false)
    chiller_cop.setDisplayName("Chiller Nominal COP.")
    chiller_cop.setDefaultValue(3.2)
    args << chiller_cop
	
	#Condenser type
	
	condenser_type = OpenStudio::StringVector.new
    condenser_type << "WaterCooled"
	condenser_type << "AirCooled"
    condenser_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('condenser_type', condenser_type, true)
    condenser_type.setDisplayName("Choose condenser type.")
    condenser_type.setDefaultValue("WaterCooled")
    args << condenser_type
		
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
    chiller_type = runner.getStringArgumentValue("chiller_type", user_arguments)
	chiller_cop = runner.getDoubleArgumentValue("chiller_cop",user_arguments)
	condenser_type = runner.getStringArgumentValue("condenser_type", user_arguments)
	
	# retrieve chilled water loop
	chilled_water_loop = nil
    chilled_water_loop = if model.getPlantLoopByName('Chilled Water Loop').is_initialized
                        model.getPlantLoopByName('Chilled Water Loop').get
                     else
					    runner.registerError ("No chilled water loop. Need to create chilled water loop")
                     end
	
    #add CW loop
	
	unless chiller_type == "DistrictChilledWater"
	 if condenser_type == 'WaterCooled'
        condenser_water_loop = OpenStudio::Model::PlantLoop.new(model)
        condenser_water_loop.setName('Condenser Water Loop')
        condenser_water_loop.setMaximumLoopTemperature(80)
        condenser_water_loop.setMinimumLoopTemperature(5)
	    # Condenser water loop controls
        cw_temp_f = 70 # CW setpoint 70F
        cw_temp_sizing_f = 85 # CW sized to deliver 85F
        cw_delta_t_r = 10 # 10F delta-T
        cw_approach_delta_t_r = 7 # 7F approach
        cw_temp_c = OpenStudio.convert(cw_temp_f, 'F', 'C').get
        cw_temp_sizing_c = OpenStudio.convert(cw_temp_sizing_f, 'F', 'C').get
        cw_delta_t_k = OpenStudio.convert(cw_delta_t_r, 'R', 'K').get
        cw_approach_delta_t_k = OpenStudio.convert(cw_approach_delta_t_r, 'R', 'K').get
        cw_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        cw_temp_sch.setName("Condenser Water Loop Temp - #{cw_temp_f}F")
        cw_temp_sch.defaultDaySchedule.setName("Condenser Water Loop Temp - #{cw_temp_f}F Default")
        cw_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), cw_temp_c)
        cw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, cw_temp_sch)
        cw_stpt_manager.addToNode(condenser_water_loop.supplyOutletNode)
        sizing_plant = condenser_water_loop.sizingPlant
        sizing_plant.setLoopType('Condenser')
        sizing_plant.setDesignLoopExitTemperature(cw_temp_sizing_c)
        sizing_plant.setLoopDesignTemperatureDifference(cw_delta_t_k)
  
    # Condenser water pump
       cw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
       cw_pump.setName('Condenser Water Loop Pump')
       cw_pump_head_ft_h2o = 60.0
       cw_pump_head_press_pa = OpenStudio.convert(cw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
       cw_pump.setRatedPumpHead(cw_pump_head_press_pa)
	   cw_pump.setPumpControlType('Intermittent')
       cw_pump.addToNode(condenser_water_loop.supplyInletNode)
    
	   cooling_tower_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
       condenser_water_loop.addSupplyBranchForComponent(cooling_tower_bypass_pipe)
       chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
       condenser_water_loop.addDemandBranchForComponent(chiller_bypass_pipe)
       supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
       supply_outlet_pipe.addToNode(condenser_water_loop.supplyOutletNode)
       demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
       demand_inlet_pipe.addToNode(condenser_water_loop.demandInletNode)
       demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
       demand_outlet_pipe.addToNode(condenser_water_loop.demandOutletNode)
	 end
	end
	
    # DistrictCooling
    if chiller_type == 'DistrictChilledWater'
      dist_clg = OpenStudio::Model::DistrictCooling.new(model)
      dist_clg.setName('Purchased Cooling')
      dist_clg.autosizeNominalCapacity
      chilled_water_loop.addSupplyBranchForComponent(dist_clg)
    else

      # Make the correct type of chiller based these properties
    
      chiller = OpenStudio::Model::ChillerElectricEIR.new(model)
      chiller.setName("#{condenser_type} #{chiller_type} Chiller")
      chilled_water_loop.addSupplyBranchForComponent(chiller)
	  chiller.setReferenceCOP(chiller_cop)
      ref_cond_wtr_temp_f = 95
      ref_cond_wtr_temp_c = OpenStudio.convert(ref_cond_wtr_temp_f, 'F', 'C').get
      chiller.setReferenceEnteringCondenserFluidTemperature(ref_cond_wtr_temp_c)
      chiller.setMinimumPartLoadRatio(0.15)
      chiller.setMaximumPartLoadRatio(1.0)
      chiller.setOptimumPartLoadRatio(1.0)
      chiller.setMinimumUnloadingRatio(0.25)
      chiller.setCondenserType(condenser_type)
      chiller.setLeavingChilledWaterLowerTemperatureLimit(OpenStudio.convert(36, 'F', 'C').get)

    end
	
    return true

  end
  
end

# register the measure to be used by the application
HVACTemplatePlantChiller.new.registerWithApplication
