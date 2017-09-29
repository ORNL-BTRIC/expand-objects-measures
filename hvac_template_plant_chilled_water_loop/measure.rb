# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class HVACTemplatePlantChilledWaterLoop < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "HVACTemplate:Plant:ChilledWaterLoop"
  end

  # human readable description
  def description
    return "Creat chilled water loop"
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # define CHW pump control
	
	chw_pump_control = OpenStudio::StringVector.new
    chw_pump_control << "intermittent"
	chw_pump_control << "continuous"
    chw_pump_control = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('chw_pump_control',chw_pump_control, true)
    chw_pump_control.setDisplayName("Choose CHW pump control type.")
    chw_pump_control.setDefaultValue("intermittent")
    args << chw_pump_control
	
	# set CHW design setpoint (F)
	chw_design_setpoint = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('chw_design_setpoint', false)
    chw_design_setpoint.setDisplayName("Chilled water design setpoint in Fahrenheit")
    chw_design_setpoint.setDefaultValue(44.996)
    args << chw_design_setpoint
	
	# CHW pump type/configuration
	
	chw_pump_type = OpenStudio::StringVector.new
    chw_pump_type << "ConstantPrimaryNoSecondary"
	chw_pump_type << "ConstantPrimaryVariableSecondary"
    chw_pump_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('chw_pump_type', chw_pump_type, true)
    chw_pump_type.setDisplayName("Choose CHW pump type and configuration.")
    chw_pump_type.setDefaultValue("ConstantPrimaryNoSecondary")
    args << chw_pump_type
		
	# Loop design delta T (F)
	chw_design_deltaT = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('chw_design_deltaT', false)
    chw_design_deltaT.setDisplayName("Chilled water design deltaT in Fahrenheit")
    chw_design_deltaT.setDefaultValue(12)
    args << chw_design_deltaT
	
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
    chw_pump_control = runner.getStringArgumentValue("chw_pump_control", user_arguments)
	chw_design_setpoint = runner.getDoubleArgumentValue("chw_design_setpoint",user_arguments)
	chw_pump_type = runner.getStringArgumentValue("chw_pump_type", user_arguments)
	chw_design_deltaT = runner.getDoubleArgumentValue("chw_design_deltaT",user_arguments)
  
    # add Chilled Water Loop

    chilled_water_loop = OpenStudio::Model::PlantLoop.new(model)
    chilled_water_loop.setName('Chilled Water Loop')
    chilled_water_loop.setMaximumLoopTemperature(98)
    chilled_water_loop.setMinimumLoopTemperature(1)

    # Chilled Water Loop controls
    chw_temp_f = chw_design_setpoint
    chw_delta_t_r = chw_design_deltaT
    chw_temp_c = OpenStudio.convert(chw_temp_f, 'F', 'C').get
    chw_delta_t_k = OpenStudio.convert(chw_delta_t_r, 'R', 'K').get
    chw_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    chw_temp_sch.setName("Chilled Water Loop Temp - #{chw_temp_f}F")
    chw_temp_sch.defaultDaySchedule.setName("Chilled Water Loop Temp - #{chw_temp_f}F Default")
    chw_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), chw_temp_c)
    chw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, chw_temp_sch)
    chw_stpt_manager.setName('Chilled Water Loop setpoint manager')
    chw_stpt_manager.addToNode(chilled_water_loop.supplyOutletNode)
    sizing_plant = chilled_water_loop.sizingPlant
    sizing_plant.setLoopType('Cooling')
    sizing_plant.setDesignLoopExitTemperature(chw_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(chw_delta_t_k)

	# Chilled water pumps
    if chw_pump_type == 'ConstantPrimaryNoSecondary'
      # Primary chilled water pump
      pri_chw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
      pri_chw_pump.setName('Chilled Water Loop Pump')
      pri_chw_pump_head_ft_h2o = 60.0
      pri_chw_pump_head_press_pa = OpenStudio.convert(pri_chw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      pri_chw_pump.setRatedPumpHead(pri_chw_pump_head_press_pa)
      pri_chw_pump.setMotorEfficiency(0.9)
      pri_chw_pump.setPumpControlType('Intermittent')
      pri_chw_pump.addToNode(chilled_water_loop.supplyInletNode)
    elsif chw_pump_type == 'ConstantPrimaryVariableSecondary'
      # Primary chilled water pump
      pri_chw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
      pri_chw_pump.setName('Chilled Water Loop Primary Pump')
      pri_chw_pump_head_ft_h2o = 60
      pri_chw_pump_head_press_pa = OpenStudio.convert(pri_chw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      pri_chw_pump.setRatedPumpHead(pri_chw_pump_head_press_pa)
      pri_chw_pump.setMotorEfficiency(0.9)
      pri_chw_pump.setPumpControlType('Intermittent')
      pri_chw_pump.addToNode(chilled_water_loop.supplyInletNode)
      # Secondary chilled water pump
      sec_chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      sec_chw_pump.setName('Chilled Water Loop Secondary Pump')
      sec_chw_pump_head_ft_h2o = 60
      sec_chw_pump_head_press_pa = OpenStudio.convert(sec_chw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      sec_chw_pump.setRatedPumpHead(sec_chw_pump_head_press_pa)
      sec_chw_pump.setMotorEfficiency(0.9)
      # Curve makes it perform like variable speed pump
      sec_chw_pump.setFractionofMotorInefficienciestoFluidStream(0)
      sec_chw_pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
      sec_chw_pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0205)
      sec_chw_pump.setCoefficient3ofthePartLoadPerformanceCurve(0.4101)
      sec_chw_pump.setCoefficient4ofthePartLoadPerformanceCurve(0.5753)
      sec_chw_pump.setPumpControlType('Intermittent')
      sec_chw_pump.addToNode(chilled_water_loop.demandInletNode)
      # Change the chilled water loop to have a two-way common pipes
      chilled_water_loop.setCommonPipeSimulation('CommonPipe')
    end
	
	 # chilled water loop pipes
    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    chilled_water_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    chilled_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.addToNode(chilled_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.addToNode(chilled_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.addToNode(chilled_water_loop.demandOutletNode)
	
	return true

  end
  
end

# register the measure to be used by the application
HVACTemplatePlantChilledWaterLoop.new.registerWithApplication
