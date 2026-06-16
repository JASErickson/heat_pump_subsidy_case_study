def main(config):

    import os
    import requests
    import re
    from bs4 import BeautifulSoup
    from requests.adapters import HTTPAdapter
    from requests.packages.urllib3.util.retry import Retry # type: ignore
    from urllib.parse import urljoin
    import zipfile
    import pandas as pd
    import numpy as np
    import geopandas as gpd
    import requests
    from shapely.geometry import Point
    from pyproj import Transformer
    from shapely import wkt
    import logging as log
    import function_definition as func

    state_name = config.state
    base_url = config.base_url
    downfolder = config.downloaded_folder
    boundary_file = config.boundary_file
    output_crs = config.output_crs
    loggingfile = config.loggingfile

    #Set up logging
    log.basicConfig(filename=loggingfile,
                        level=log.INFO,
                        format='%(message)s',
                        filemode='a')

    hh = pd.read_csv(config.file_2, low_memory=False)
    hh[['Parcel_Lat_clean', 'Parcel_Long_clean']] = hh[['Parcel_Lat_clean', 'Parcel_Long_clean']].astype(float)
    h = gpd.GeoDataFrame(hh, geometry=gpd.points_from_xy(hh['Parcel_Long_clean'], hh['Parcel_Lat_clean']), crs=output_crs)
    del hh
    hh = h
    hh['Year']=hh['Year'].astype(int)
    log.info("loading complete")
    log.info(len(hh))

    # Initialize the final GeoDataFrame
    gdf_t = gpd.GeoDataFrame()

    # Loop through each year and process the data
    for year in np.unique(hh['Year']):

        # Get the list of ZIP file URLs
        zip_files = func.download_tract_files(base_url, year, downfolder, config.key, state=state_name)
        log.info(zip_files)

        # List to keep track of all shapefiles
        all_shapefiles = []

        # Download and unzip each file
        for file in zip_files:
            shapefiles = func.id_shapefiles(file, config.temp_folder)
            all_shapefiles.extend(shapefiles)
            log.info(f"{file} identified")

        # Process each extracted shapefile
        for shp_path in all_shapefiles:
            gdf = gpd.read_file(shp_path)
            log.info(f"Loaded shapefile {shp_path}")

            # Remove numbers from column names
            gdf.columns = [re.sub(r'\d+$', '', col) for col in gdf.columns]

            # Add a 'year' column based on the year variable
            gdf['year'] = str(year)

            # Append to the master GeoDataFrame
            gdf_t = pd.concat([gdf_t, gdf], ignore_index=True)
            log.info(f"{year} added to dataframe")

    # Save the combined GeoDataFrame to a file
    gdf_t.rename(columns={'TRACTCE':'TRACT_FIPS','year':'Year'},inplace=True)
    gdf_t.to_file(boundary_file, driver="GeoJSON")
    log.info(f"All data has been combined and saved to {boundary_file}")

    # Get tract boundaries
    gdf_t['Year']=gdf_t['Year'].astype(int)
    gdf_t = gdf_t.to_crs(config.output_crs)

    log.info(gdf_t.columns)

    #Merge
    left_df, right_df = func.drop_index_columns(hh, gdf_t)
    left_df = left_df.to_crs(config.output_crs)
    right_df = right_df.to_crs(config.output_crs)
    left_df['Year'] = left_df['Year'].astype(int)
    right_df['Year'] = right_df['Year'].astype(int)

    joined = gpd.GeoDataFrame()
    for y in np.unique(left_df['Year']):
        join_temp = gpd.sjoin(left_df[left_df['Year']==y],right_df[right_df['Year']==y],how='left',predicate='intersects')
        joined = pd.concat([joined,join_temp],ignore_index=True)
        log.info(f"{y} added to dataframe")
    joined = joined.drop('Year_right',axis=1)
    joined.rename(columns={'Year_left':'Year'},inplace=True)

    log.info("begin backdating")
    joint = func.backdate_tract(joined)
    log.info("backdating complete")
    log.info(np.unique(joint['TRACT_FIPS']))
    joint.to_csv(config.file_3,compression='gzip')

import config_Benton_Richland as config
if __name__ == "__main__":
    main(config)