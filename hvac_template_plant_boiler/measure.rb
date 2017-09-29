# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class HVACTemplatePlantBoiler < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "HVACTemplate:Plant:Boiler"
  end

  # human readable description
  def description
    return "Create a boiler"
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end	

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

 	# Boiler type
	boiler_type = OpenStudio::StringVector.new
    boiler_type << "DistrictHotWater"
	boiler_type << "HotWaterBoiler"
    boiler_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('boiler_type', boiler_type, true)
    boiler_type.setDisplayName("Choose boiler type.")
    boiler_type.setDefaultValue("HotWaterBoiler")
    args << boiler_type
=begin	
	# set HW design setpoint (F)
	hw_design_setpoint = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('hw_design_setpoint', false)
    hw_design_setpoint.setDisplayName("Hot water design setpoint in Fahrenheit")
    hw_design_setpoint.setDefaultValue(179.6)
    args << hw_design_setpoint
=end	
	# Fule types
	fuel_type = OpenStudio::StringVector.new
    fuel_type << "Electricity"
	fuel_type << "NaturalGas"
	fuel_type << "PropaneGas"
	fuel_type << "FuelOil#1"
	fuel_type << "FuelOil#2"
	fuel_type << "Coal"
	fuel_type << "Disel"
	fuel_type << "Gasoline"
	fuel_type << "OtherFuel1"
	fuel_type << "OtherFuel2"
	fuel_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('fuel_type', fuel_type, true)
    fuel_type.setDisplayName("Choose Fuel type.")
    fuel_type.setDefaultValue("NaturalGas")
	args << fuel_type
	
	# Boiler efficiency
	boiler_efficiency = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('boiler_efficiency', false)
    boiler_efficiency.setDisplayName("Boiler efficiency.")
    boiler_efficiency.setDefaultValue(0.8)
    args << boiler_efficiency

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
    boiler_type = runner.getStringArgumentValue("boiler_type", user_arguments)
	#hw_design_setpoint = runner.getDoubleArgumentValue("hw_design_setpoint",user_arguments)
	fuel_type = runner.getStringArgumentValue("fuel_type", user_arguments)
	boiler_efficiency = runner.getDoubleArgumentValue("boiler_efficiency",user_arguments)
    
		
	# retrieve hot water loop
	hot_water_loop = nil
    hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                        model.getPlantLoopByName('Hot Water Loop').get
                     else
					 nil
                     end
	
    
	#hw_temp_f = hw_design_setpoint
    #hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
	
	
    # DistrictHeating
    if boiler_type == 'DistrictHeating'
       dist_ht = OpenStudio::Model::DistrictHeating.new(model)
       dist_ht.setName('Purchased Heating')
       dist_ht.autosizeNominalCapacity
       hot_water_loop.addSupplyBranchForComponent(dist_ht)
    # Boiler
    else
       boiler_max_t_f = 203
       boiler_max_t_c = OpenStudio.convert(boiler_max_t_f, 'F', 'C').get
       boiler = OpenStudio::Model::BoilerHotWater.new(model)
       boiler.setName('Hot Water Loop Boiler')
       boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')
       boiler.setFuelType(fuel_type)
       #boiler.setDesignWaterOutletTemperature(hw_temp_c)
       boiler.setNominalThermalEfficiency(boiler_efficiency)
       boiler.setMaximumPartLoadRatio(1.2)
       boiler.setWaterOutletUpperTemperatureLimit(boiler_max_t_c)
       boiler.setBoilerFlowMode('LeavingSetpointModulated')
       hot_water_loop.addSupplyBranchForComponent(boiler)
    end
    return true

  end
  
end

# register the measure to be used by the application
HVACTemplatePlantBoiler.new.registerWithApplication
