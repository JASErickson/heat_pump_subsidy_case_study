#Configuration File
    #Use this file to configure the details of the analysis: set variables, states, outfiles etc.

#Initial setup and function definitions
import pandas as pd
import requests
from datetime import datetime
import numpy as np
import os
import time
import function_definition as func

#Here is where direct inputs for the scneario are input
casename = 'Benton vs Richland' #Change by case
state = 'Washington' #Change by case
county = 'Benton' #Change by case
discontinuity = 'spatial' #Change by case
analysis_area = 'utility' #Coptions are 'utility', 'state', 'county'
CRS = 32611 #Change to fit region closely
Territory_1_Name = 'PUD NO 1 OF BENTON COUNTY' #Utility name per HFLID
Territory_2_Name = 'CITY OF RICHLAND - (WA)' #Utility name per HFLID
key = "{YOUR KEY HERE}"
bandwidth = 3.5

# Incentive Details
standard_elec_central = 1000
standard_elec_variable = 1200
standard_hp_variable = 200
standard_elec_ductless = 800
benton_lmi = 3800
richland_lmi_central = 6200
richland_lmi_ductless = 4400
benton_start = 2015
richland_start = 1981

#Here is where folders are assigned - revise as needed to your structure
top_folder = f'{YOUR FILE HERE}' #Must already exist
working_folder = f'{top_folder}/cases/{casename}' #Change as needed
logging_folder = f"{working_folder}/logs"#Change as needed
data_folder = f"{working_folder}/data"#Change as needed
temp_folder = f"{data_folder}/temp_files" #Change as needed
downloaded_folder = f"{top_folder}/Downloaded Datafiles"#Change as needed
out_folder = f"{working_folder}/outfiles"#Change as needed

#Here is where files are assigned for logging
loggingfile =  f"{logging_folder}/Spatial_RD_{state}_{datetime.date(datetime.now())}.log" #Change as needed

#Here is where files are saved before and after each step:
file_1 = f"{temp_folder}/{casename}_State_Cleaning_output.csv.gz"
file_2 = f'{temp_folder}/{casename}_Spatial_output.csv.gz'
file_3 = f"{temp_folder}/{casename}_Add_income_output.csv.gz"
file_4 = f"{temp_folder}/{casename}_Add_tenure_output.csv.gz"
file_5 = f"{temp_folder}/{casename}_Add_occupancy_output.csv.gz"
file_6 = f"{temp_folder}/{casename}_Add_poverty_output.csv.gz"
file_7 = f"{temp_folder}/{casename}_Add_average_output.csv.gz"
final_file = f"{out_folder}/{casename}_Final_RDD_Dataset.csv.gz"
fig_file = f'{out_folder}/figures' #Change as needed

#Calculated Elements
sID = str(func.get_state_id(state,key))
cID = str(func.get_county_id(county,key,state,sID))
FIPS = sID+cID
state_abb = func.get_state_abbr(state)

####
#Specific to CoreLogic Cleaning
sourcefiles = f"~/HistProperty_State{sID}*.csv" #File available upon reasonable request

####
#Specific to Spatial RD Maker
LUse_codes = f"{downloaded_folder}/CL_LUse_codes.csv" #Change as needed
htc_elec = f"{downloaded_folder}/HTC_elec_type.csv" #Change as needed
ftc_elec = f"{downloaded_folder}/FTC_elec_type.csv" #Change as needed
heating_codes = f"{downloaded_folder}/CL_htc_codes.csv" #Change as needed
fuel_codes = f"{downloaded_folder}/CL_ftc_codes.csv" #Change as needed
ac_codes = f"{downloaded_folder}/CL_ac_codes.csv" #Change as needed
gas_prices = f"{downloaded_folder}/Gas sales by Year & company.csv" #Change as needed

url_electric = 'https://services1.arcgis.com/Hp6G80Pky0om7QvQ/arcgis/rest/services/Retail_Service_Territories/FeatureServer/0/query' #electric service territories shapefiles
url_gas = 'https://services1.arcgis.com/Hp6G80Pky0om7QvQ/arcgis/rest/services/Natural_Gas_Service_Territories/FeatureServer/0/query' #Natural Gas territory shapefiles
url_states = "https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_state_20m.zip" #state shapefiles
url_counties = "https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_county_20m.zip" #county shapefiles

####
#Specific to ecocological regression
    #_1 indicates the first datatype to be assinged (must be numerical like income) and _2 indicates second type (like renter/owner)
level = 'tract'
dataset = 'acs5'
base_url = "https://www2.census.gov/geo/tiger/TIGER"
output_crs = 'EPSG:4326'

datatype_1 = "income"
table_1 = 'S1901'
part_1 = 'subject'

datatype_2 = "renter_owner"
table_2 = 'B25003'
part_2 = ''

datatype_3 = "poverty"
table_3 = 'S1702'
part_3 = ''

datatype_4 = "occupants"
table_4 = 'B11016'
part_4 = ''


boundary_file = f"{downloaded_folder}/combined_tract_shapes.geojson"

#Create folders
os.makedirs(logging_folder, exist_ok=True)
os.makedirs(data_folder, exist_ok=True)
os.makedirs(temp_folder, exist_ok=True)
os.makedirs(downloaded_folder, exist_ok=True)
os.makedirs(out_folder, exist_ok=True)
os.makedirs(fig_file, exist_ok=True)