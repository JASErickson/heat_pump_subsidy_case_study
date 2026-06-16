def main(config):

    import pandas as pd
    import glob
    import numpy as np
    import os
    import time
    import logging as log
    from datetime import datetime
    import shutil
    import function_definition as func

    #Define Folder Location
    temp_folder = config.temp_folder
    file_pattern = config.sourcefiles
    outfile = config.file_1
    loggingfile = config.loggingfile

    #Set up logging
    log.basicConfig(filename=loggingfile,
                        level=log.INFO,
                        format='%(message)s',
                        filemode='a')
    pd.option_context('display.max_columns', None)

    #Validate
    file_list = glob.glob(file_pattern)
    
    CL_usecols=["SITUS STATE", "SITUS COUNTY", "FIPS CODE", "CENSUS ID", "MARKET TOTAL VALUE", "YEAR BUILT", 
                    "EFFECTIVE YEAR BUILT", "STORIES NUMBER", "NUMBER OF UNITS", "TOTAL ROOMS - ALL BUILDINGS","LAND USE CODE", "FUEL CODE", 
                    "HEATING TYPE CODE", "AIR CONDITIONING CODE", "COMPOSITE PROPERTY LINKAGE KEY", "TAXROLL CERTIFICATION DATE", 
                    "UNIVERSAL BUILDING SQUARE FEET", "LIVING SQUARE FEET - ALL BUILDINGS", 
                    "PARCEL LEVEL LATITUDE", "PARCEL LEVEL LONGITUDE"]
    CL_dtypes={"SITUS STATE": str, "SITUS COUNTY": str, "FIPS CODE": str, "CENSUS ID": str, 
                "MARKET TOTAL VALUE": float, "YEAR BUILT": float, "EFFECTIVE YEAR BUILT": float, 
                "STORIES NUMBER": float, "NUMBER OF UNITS": float, "TOTAL ROOMS - ALL BUILDINGS": float, "LAND USE CODE": str, "FUEL CODE": str,
                "AIR CONDITIONING CODE": str, "HEATING TYPE CODE": str, "COMPOSITE PROPERTY LINKAGE KEY": str, 
                "TAXROLL CERTIFICATION DATE": str, "UNIVERSAL BUILDING SQUARE FEET": float, 
                "LIVING SQUARE FEET - ALL BUILDINGS": float, "PARCEL LEVEL LATITUDE": float, 
                "PARCEL LEVEL LONGITUDE": float}

    llt_usecols=['FIPS CODE', 'Property_ID', 'CENSUS ID', 'Parcel_Lat', 'Parcel_Long',
            'SITUS STATE', 'SITUS COUNTY', 'Home_Price', 'Home_Value', 'Year_Built',
            'Eff_Yr_Built', 'HEATING TYPE CODE', 'Stories','Rooms','Unit_Count', 'LUse', 'ac_code', 'fuel_type',
            'Square_Feet', 'Live_Square_Feet', 'TAXROLL CERTIFICATION DATE', 'indexa', 'HEAT INDC',
            'Month', 'Year', 'Year_Revised']
    llt_dtypes={'FIPS CODE':str, 'Property_ID':str, 'CENSUS ID':str, 'Parcel_Lat':float, 'Parcel_Long':float,
            'SITUS STATE':str, 'SITUS COUNTY':str, 'Home_Price':float, 'Home_Value':float, 'Year_Built':float,
            'Eff_Yr_Built':float, 'HEATING TYPE CODE':str, 'Stories':float,'Rooms':float,'Unit_Count':float, 'LUse':str, 'ac_code':str, 'fuel_type':str,
            'Square_Feet':float, 'Live_Square_Feet':float, 'TAXROLL CERTIFICATION DATE':str, 'indexa':str, 'HEAT INDC':float,
            'Month':float, 'Year':float, 'Year_Revised':float}

    #Index the time
    t4=time.time()

    #Loop over CoreLogic Files of the relevant type to deduplicate
    for file in file_list:
        func.deduplicate_file(file,CL_usecols,CL_dtypes,temp_folder)

    # If CL_Clean exists, use it directly to fill missing lat long
    df=pd.DataFrame()
    for i in os.listdir(temp_folder):
        if i.startswith('temp_CL_hh_deduplicated'):
            data = func.fill_missing_lat_long_type(os.path.join(temp_folder, i),llt_usecols,llt_dtypes,'Parcel_Lat','Parcel_Long','LUse','Property_ID')
            df = pd.concat([df, data], ignore_index=True)
        else: 
            continue
    ta = time.time()
    log.info(f"Final, full dataframe length: {len(df)}")

    #Record processing times
    log.info(f"file processing complete. Time elapsed: {str(ta - t4)}")
    log.info(f"beginning file writing to CSV")
    tb=time.time()

    #log.info final file
    df.to_csv(outfile,compression='gzip')
    log.info(f"file written. Time elapsed: {func.ftime(time.time()-tb)}")
    log.info(f"total processing time: {func.ftime(time.time()-t4)}")
    log.info(f"finished: {datetime.now().strftime('%d, %b, %y %H:%M:%S')}")
    log.info(f"Dataframe length: {len(df)}")

import config_Benton_Richland as config
if __name__ == "__main__":
    main(config)