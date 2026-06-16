# heat_pump_subsidy_case_study
Income Qualified Heat Pump Study Code

This repository includes the code files necessary to pull and assess the findings and figures used in the article "Evaluating the Efficacy of Low-Icnome Heat Pump Incentives." 

Initial data collection, cleaning and management is conducted through Python. Users will need to get a Census API key in order to download the appropriate data. Additionally, the CoreLogic household files used as the basis for this analysis are available upon reasonable request. 

Functions used in the python files are found in the function_definition.py file
Configurations and specifications for the case study are found in the config_Benton_Richland.py file. 
Initial work was conducted via a SLURM cluster and similar architecture may be required due to processing space requirements. 

Final analysis and figures were developed via STATA. 
