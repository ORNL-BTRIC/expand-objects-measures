# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class HVACTemplatePlantTower < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "HVACTemplate:Plant:Tower"
  end

  # human readable description
  def description
    return "Creat cooling tower"
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    cooling_tower_type = OpenStudio::StringVector.new
    cooling_tower_type << "SingleSpeed"
	cooling_tower_type << "TwoSpeed"
    cooling_tower_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('cooling_tower_type', cooling_tower_type, true)
    cooling_tower_type.setDisplayName("Choose cooling tower type.")
    cooling_tower_type.setDefaultValue("SingleSpeed")
    args << cooling_tower_type
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    	
	# retrieve condenser water loop
	condenser_water_loop = nil
    condenser_water_loop = if model.getPlantLoopByName('Condenser Water Loop').is_initialized
                        model.getPlantLoopByName('Condenser Water Loop').get
                     else
					    runner.registerError ("No chiller. Need to create a chiller which is not a districed chilled water")
                     end
					 
    # assign the user inputs to variables
    cooling_tower_type = runner.getStringArgumentValue("cooling_tower_type", user_arguments)

    # add cooling tower
      twr_name = "#{cooling_tower_type}"
      # Tower object depends on the control type
      cooling_tower = nil
      if cooling_tower_type == 'SingleSpeed'
        cooling_tower = OpenStudio::Model::CoolingTowerSingleSpeed.new(model)
      else
        cooling_tower = OpenStudio::Model::CoolingTowerTwoSpeed.new(model)
      end

      # Set the properties that apply to all tower types
      # and attach to the condenser loop.
      unless cooling_tower.nil?
        cooling_tower.setName(twr_name)
        condenser_water_loop.addSupplyBranchForComponent(cooling_tower)
      end
    
	return true
	end
    
end
  
  
# register the measure to be used by the application
HVACTemplatePlantTower.new.registerWithApplication
