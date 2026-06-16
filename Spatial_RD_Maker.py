def main(config):    

    import pandas as pd
    import os
    import logging as log
    from datetime import datetime
    import requests
    from io import BytesIO
    from zipfile import ZipFile
    import numpy as np
    import random
    import shapely
    from shapely.geometry import Polygon, MultiPolygon
    import geopandas as gpd
    import matplotlib.pyplot as plt
    from matplotlib.patches import Patch
    from shapely import wkt
    import tempfile
    import scipy.stats as scipy
    from datetime import date
    from shapely.wkt import loads
    import function_definition as func
    import tracemalloc

    #Case Study Parameters
    State = config.state
    State_ID = config.sID
    case_name = config.casename
    CRS = config.CRS
    Territory_1_Name = config.Territory_1_Name
    Territory_2_Name = config.Territory_2_Name

    loggingfile = config.loggingfile
    url_electric = config.url_electric
    url_gas = config.url_gas
    url_states = config.url_states
    url_counties = config.url_counties

    read_file = config.file_1
    LUse_codes = config.LUse_codes
    heating_codes = config.heating_codes
    temp_folder = config.temp_folder

    out_file = config.file_2
    out_file_fig = config.fig_file

    #Set up logging
    log.basicConfig(filename=loggingfile,
                        level=log.INFO,
                        format='%(message)s',
                        filemode='a')
    pd.option_context('display.max_rows', None, 'display.max_columns', None)

    tracemalloc.start()

    # Record memory usage at the start
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage at start: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    ##########
    #ELECTRIC
    #define parameters (note HIFLD data uses EPSG 4326)
    params_electric = {
        'where': '1=1',
        'outFields': ['OBJECTID', 'ID', 'NAME', 'STATE','TYPE', 'REGULATED', 'CNTRL_AREA', 'PLAN_AREA', 'RETAIL_MWH','CUSTOMERS','YEAR','Shape__Area'],
        'outSR': '4326',
        'f': 'geojson'
    }

    #Work with Electric Territory Data
    response_e = requests.get(url_electric,params=params_electric)
    data = response_e.json()
    gdf_e = gpd.GeoDataFrame.from_features(data['features'],crs='EPSG:4326')
    gdf_e = gdf_e.to_crs(epsg=CRS)
    e = gdf_e[['ID','NAME','STATE','YEAR','geometry']]
    del gdf_e
    gdf_e = e
    gdf_e['ID'] = gdf_e['ID'].astype('str')

    log.info('electricity geo dataframe imported')
    log.info(gdf_e.columns)

    # Download the state shapefile for the specified state
    state = gpd.read_file(url_states)
    s = state[state['NAME'] == State]
    del state
    state = s
    log.info(state.head(1).to_string())

    # Download the county shapefile for the specified state
    counties = gpd.read_file(url_counties)
    c = counties[counties['STATE_NAME'] == State]
    del counties
    counties = c
    log.info(counties.head(2).to_string())

    # Reproject one of the shapefiles to match
    counties = counties.to_crs(epsg=CRS)
    state = state.to_crs(epsg=CRS)
    log.info("file CRS types: {}, {}, {}".format(gdf_e.crs, counties.crs, state.crs))

    # Rename NAME columns
    gdf_e.rename(columns={'NAME':'Elec_Name'},inplace=True)
    state.rename(columns={'NAME':'State'},inplace=True)
    counties.rename(columns={'NAME':'County'},inplace=True)

    # Filter state territories that intersect with the state
    state_territories = gpd.overlay(gdf_e, state, how='intersection')
    log.info(np.unique(state_territories['Elec_Name']))
    if Territory_1_Name in np.unique(state_territories['Elec_Name']):
        log.info('Territory 1 confirmed')
    else:
        log.info('Territory 1 mismatch')
    if Territory_2_Name in np.unique(state_territories['Elec_Name']):
        log.info('Territory 2 confirmed')
    else:
        log.info('Territory 2 mismatch')

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after electric import: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    ########
    #FIGURE
    
    # Create a figure and axis using pyplot.subplots
    fig, ax = plt.subplots(figsize=(10, 10))

    # Plot county boundaries with a light grey border
    counties.plot(ax=ax, color='none', edgecolor='lightgrey')

    # Plot state boundary with a thick blue border
    state.plot(ax=ax, color='none', edgecolor='blue', linewidth=3)

    # Sort the GeoDataFrame by 'Elec_Name' in alphabetical order
    state_territories = state_territories.sort_values(by='Elec_Name')

    # Generate a list of random distinct colors for each territory
    colors = ['#{:02x}{:02x}{:02x}'.format(random.randint(0, 255), random.randint(0, 255), random.randint(0, 255)) for _ in range(len(state_territories))]

    # Assign unique colors to each territory
    labels = range(1, len(state_territories) + 1)
    state_territories['Label'] = labels

    for i, geom in enumerate(state_territories['geometry']):
        gpd.GeoSeries(geom).plot(ax=ax, color=colors[i], label=labels[i])

    # Add labels with numbers within each territory
    for index, row in state_territories.iterrows():
        centroid = row['geometry'].centroid
        ax.annotate(f'{row["Label"]}', xy=(centroid.x, centroid.y), xytext=(5, 5), textcoords='offset points', fontsize=8)

    # Title and labels
    ax.set_title(f"Territories in the state of {State}")
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")

    # Save the plot to a file
    fig.savefig(os.path.expanduser(f'{out_file_fig}/{State}_elec_ter.png'))
    log.info(f"{State} territories map created")

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after territories map: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    #########
    #Boundaries

    # Filter territories based on their names
    territory1 = gpd.GeoDataFrame(state_territories[state_territories['Elec_Name'] == Territory_1_Name])
    territory2 = gpd.GeoDataFrame(state_territories[state_territories['Elec_Name'] == Territory_2_Name])

    # Check if the GeoDataFrames are empty
    if territory1.empty:
        log.info("territory 1 empty")
        return
    if territory2.empty: 
        log.info("territory 2 empty")
        return
    if territory1.geometry.isnull().all():
        log.info("territory 1 null")
        return
    if territory2.geometry.isnull().all():
        log.info("territory 2 null")
        return

    # Calculate the boundary between the two territories
    boundary = territory1.geometry.unary_union.boundary.intersection(territory2.geometry.unary_union.boundary)

    # PLOT
    # Define temporary gdf for the geometry of the boundary
    boundary_gdf = gpd.GeoDataFrame(geometry=gpd.GeoSeries(boundary))

    # Create a new figure and axis
    fig, ax = plt.subplots(figsize=(10, 10))

    # Plot territory1 with blue color and add label
    territory1.plot(ax=ax, color='blue', alpha=0.5, edgecolor='black')

    # Plot territory2 with green color and add label
    territory2.plot(ax=ax, color='green', alpha=0.5, edgecolor='black')

    # Plot the boundary with red color and add label
    boundary_gdf.plot(ax=ax, color='red', linewidth=2, linestyle='-')

    # Manually create legend handles
    legend_elements = [
        Patch(facecolor='blue', edgecolor='black', alpha=0.5, label=Territory_1_Name),
        Patch(facecolor='green', edgecolor='black', alpha=0.5, label=Territory_2_Name),
        plt.Line2D([0], [0], color='red', linewidth=2, linestyle='-', label='Boundary')
    ]

    # Add legend
    ax.legend(handles=legend_elements, loc='upper right')

    # Set the title of the plot
    plt.title('Territories and Boundary')

    # Save to file
    plt.savefig(os.path.expanduser(f'{out_file_fig}/{case_name}_boundary_map.png'))

    # Log the creation of the map
    log.info("Case study map created")

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after case study map: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    ###########
    #CoreLogic Load
    households_df = pd.read_csv(read_file)
    log.info(f"upload completed")
    log.info(f"intial dataframe length (full state): {len(households_df)}")

    # Convert household locations to GeoDataFrame
    gdf_households = gpd.GeoDataFrame(
        households_df,
        geometry=gpd.points_from_xy(households_df['Parcel_Long_clean'], households_df['Parcel_Lat_clean']),
        crs='EPSG:4326'
    )
    gdf_households=gdf_households.to_crs(epsg=CRS)

    hhdf = func.in_zone(territory1,territory2,gdf_households)
    log.info(f"lenght of dataframe including just relevant territories: {len(hhdf)}")
    hhdf = func.distance(hhdf,boundary)
    log.info(f"verfied length: {len(hhdf)}")

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after CL Data loaded: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    ############
    #Electric Price Data
    #Create an empty DataFrame to store the data
    e_sales = pd.DataFrame()

    # Iterate over the years from 2001 to 2021
    for year in range(2001, 2022):
        if year in range(2001, 2012):
            folder_url = f"https://www.eia.gov/electricity/data/eia861/archive/zip/861_{year}.zip"
        elif year in range(2012, 2022):
            folder_url = f"https://www.eia.gov/electricity/data/eia861/archive/zip/f861{year}.zip"
        else:
            folder_url = f"https://www.eia.gov/electricity/data/eia861/zip/f861{year}.zip"

        # Define possible filename variations

        rate_files = [
            f"{year}/Sales_Ult_Cust_{year}.xlsx",
            f"Sales_Ult_Cust_{year}.xlsx",
            f"Sales_Ult_Cust_{year}.xls"
        ]

        rate_CS_files = [
            f"{year}/Sales_Ult_Cust_CS_{year}.xlsx",
            f"{year}/Sales_Ult_Cust_CS_{year}.xls",
            f"Sales_Ult_Cust_CS_{year}.xlsx",
            f"Sales_Ult_Cust_CS_{year}.xls",
        ]

        rate_file = None
        rate_CS_file = None
        response = requests.get(folder_url)
        zip_content = ZipFile(BytesIO(response.content),'r')

        #Process loop by file
        with tempfile.TemporaryDirectory(prefix="Electricity", dir=os.path.expanduser(temp_folder)) as tempfolder:
            for filename in rate_files:
                selection = ['Data Year','Utility Number','Utility Name','State','Thousand Dollars','Megawatthours']
                if filename in zip_content.namelist():
                    rate_file = zip_content.extract(filename, path=tempfolder)
                    rdf = pd.read_excel(rate_file,header=2)
                    if 'Thousands Dollars' in rdf.columns:
                        rdf = rdf.rename(columns={'Thousands Dollars': 'Thousand Dollars'})
                    rdf=rdf[selection]
                    e_sales = pd.concat([e_sales, rdf], ignore_index=True)
            for filename in rate_CS_files:
                selection = ['Data Year','Utility Number','Utility Name','State','Thousand Dollars','Megawatthours']
                if filename in zip_content.namelist():
                    rate_CS_file = zip_content.extract(filename, path=tempfolder)
                    rdf = pd.read_excel(rate_CS_file,header=2)
                    if 'STATE' in rdf.columns:
                        rdf = rdf.rename(columns={'STATE':'State'})
                    if 'Thousands Dollars' in rdf.columns:
                        rdf = rdf.rename(columns={'Thousands Dollars':'Thousand Dollars'})
                    rdf=rdf[selection]
                    e_sales = pd.concat([e_sales, rdf], ignore_index=True)

    #Post-processing
    log.info('rate files imported')
    e_sales = e_sales.rename_axis('Index')
    e_sales = e_sales[e_sales['Data Year'].isin(range(2001,2022))]
    e_sales['Utility Number'] = e_sales['Utility Number'].astype('str').str.split('.').str[0]
    e_sales['Thousand Dollars'] = pd.to_numeric(e_sales['Thousand Dollars'], errors='coerce')
    e_sales['Megawatthours'] = pd.to_numeric(e_sales['Megawatthours'], errors='coerce')
    e_sales['e_Rate'] = np.nan
    mask = e_sales['Megawatthours'] != 0
    e_sales.loc[mask, 'e_Rate'] = e_sales.loc[mask, 'Thousand Dollars'] / e_sales.loc[mask, 'Megawatthours']

    #Add the necessary identifiers and merge the data into household dataframe so each house in each year should have an electric price.
    #Note the merge on Year not Year_Revised, as the actual year of the record is more relevant for the application of true energy prices.
    hhdf['Utility_ID'] = np.where(hhdf['in_ter1'] == 1, territory1['ID'], territory2['ID'])
    hhdf['Utility_Name'] = np.where(hhdf['in_ter1'] == 1, territory1['Elec_Name'], territory2['Elec_Name'])
    hhdf=hhdf.merge(e_sales,how='left',left_on=['Utility_ID','Year'],right_on=['Utility Number','Data Year'])
    log.info(f"length after adding electric data: {len(hhdf)}")

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after electric rate data loaded: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    ###########
    #Gas
    #define parameters
    params_gas = {
        'where': '1=1',
        'outFields': ['OBJECTID', 'SVCTERID', 'VAL_DATE', 'NAME', 'STATE', 'TYPE', 'COUNTY', 'COUNTYFIPS', 'COMPID','Shape__Area'],
        'outSR': '4326',
        'f': 'geojson'
    }

    #Work with Gas Territory Data
    response_g = requests.get(url_gas, params=params_gas)
    data = response_g.json()
    gdf_g = gpd.GeoDataFrame.from_features(data['features'])
    g= gdf_g[['COMPID','NAME','STATE','geometry']]
    del gdf_g
    gdf_g = g
    gdf_g = gdf_g.rename(columns={'COMPID':'ID'}).astype('str')

    # Get Gas price data for each utility from https://www.eia.gov/naturalgas/ngqs/#?report=RPC&year1=2001&year2=2021&company=Name&items=1010CS,1010VL
    g_price = pd.read_csv(config.gas_prices)

    g_price_melt = pd.melt(g_price, id_vars=['Area', 'Company', 'Item'], var_name='Year', value_name='Value')
    g_sales = pd.pivot_table(g_price_melt, values='Value', index=['Area', 'Company', 'Year'], columns='Item', aggfunc='sum').reset_index()
    sales = g_sales.rename(columns={'Residential Sales Revenue': 'Revenue', 'Residential Sales Volume': 'Volume'})
    del g_sales
    g_sales = sales
    g_sales['g_Rate']=g_sales['Revenue']/g_sales['Volume']

    # Split the 'Field' column into two new columns
    g_sales[['Utility ID', 'State', 'Utility Name']] = g_sales['Company'].str.extract(r'^(.*?)\s*([A-Z]{2})\s*\((.*)\)$')

    # Remove leading/trailing whitespaces from the new columns
    g_sales['Utility ID'] = g_sales['Utility ID'].str.strip()
    g_sales['Utility Name'] = g_sales['Utility Name'].str.strip()
    g_sales['State'] = g_sales['State'].str.strip()
    g_sales = g_sales.loc[~g_sales['Company'].str.contains('All Companies')]

    #merge area and utility sales
    g_rate_area = g_sales.merge(gdf_g[['geometry','ID','STATE','NAME']],left_on=['Utility ID','State'],right_on=['ID','STATE'],how='left').reset_index()
    g_price_area = g_rate_area[['Utility ID','Utility Name','State','Year','g_Rate','geometry']]

    # Align spatial elements
    g_price_area = g_price_area.rename(columns={'Utility ID':'Gas Utility Number','Utility Name':'Gas Utility Name'}).astype('str')
    g_price_area = g_price_area.rename(columns={'Year':'Gas Year'}).astype('str')
    g_price_area['Gas Year']=g_price_area['Gas Year'].astype('int')
    g_price_area = g_price_area.loc[g_price_area['geometry']!='nan']
    g_price_area['geometry'] = g_price_area['geometry'].apply(lambda geom: wkt.loads(geom) if isinstance(geom, str) else geom)
    g_price_area = gpd.GeoDataFrame(g_price_area, geometry='geometry', crs='EPSG:4326')
    g_price_area = g_price_area.to_crs(epsg=CRS)
    log.info("g_rate_area complete")

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after g_rate_area developed {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    #Make Household Data Spatial
    hhdf = hhdf.rename(columns={'Utility_ID':'Electric Utility ID','Utility_Name':'Electric Utility Name','Data Year':'Electric Year'}).astype('str')
    hhdf['geometry'] = hhdf['geometry'].apply(loads)
    hhdf = gpd.GeoDataFrame(hhdf, geometry='geometry',crs=f'EPSG:{CRS}')

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after hhdf geodataframe loaded {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    #Merge Gas
    hhdf2 = gpd.sjoin(hhdf,g_price_area, how='left', predicate='within')
    hhdf2[['Year','Gas Year']]=hhdf2[['Year','Gas Year']].astype('str')
    hhdf2_filtered = hhdf2[hhdf2['Gas Utility Name'].notnull() & (hhdf2['Year'] == hhdf2['Gas Year'])]
    log.info(f"length of df with valid gas utility and matching year {len(hhdf2_filtered)}")
    hhdf2_filtered = pd.concat([hhdf2_filtered, hhdf2[hhdf2['Gas Utility Name'].isnull()]])
    hhdf2=hhdf2_filtered
    log.info(f"length of df after combining with households outside gas area: {len(hhdf2_filtered)}")
    del hhdf2_filtered

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after merging of gas data: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    #Plot
   # Create a figure and axis using pyplot.subplots
    fig, ax = plt.subplots(figsize=(10, 10))

    # Plot territories and boundary
    territory1.plot(ax=ax, color='blue', alpha=0.5, edgecolor='black')
    territory2.plot(ax=ax, color='green', alpha=0.5, edgecolor='black')
    boundary_gdf.plot(ax=ax, color='red', linewidth=2, linestyle='-')
    hhdf2.plot(ax=ax, color='black', markersize=0.5, label='Households')

    # Manually specify the legend handles
    legend_elements = [
        Patch(facecolor='blue', alpha=0.5, edgecolor='black', label=Territory_1_Name),
        Patch(facecolor='green', alpha=0.5, edgecolor='black', label=Territory_2_Name),
        plt.Line2D([0], [0], color='red', linewidth=2, linestyle='-', label='Shared Boundary'),
        Patch(facecolor='black', label='Households')
    ]

    # Add a legend with the specified handles and labels
    ax.legend(handles=legend_elements, loc='upper right')

    # Save the plot to a file
    plt.savefig(os.path.expanduser(f'{out_file_fig}/{case_name}_households.png'))

    # Log the creation of the map
    log.info("Case study map created")

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after plotting with gas: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    ############
    #Check before assigning
    hhdf2['LUse2'] = hhdf2['LUse_clean'].astype(str).apply(lambda x: x[:3].zfill(3))
    hhdf2['LUse3'] = hhdf2['LUse'].astype(str).apply(lambda x: x[:3].zfill(3))
    log.info(pd.unique(hhdf2['LUse2']))
    log.info(hhdf2.dtypes)

    codes = pd.read_csv(LUse_codes, dtype={'LUse2': str})
    codes['LUse2'] = codes['LUse2'].astype(str).apply(lambda x: x[:3].zfill(3))
    hhdf2 = pd.merge(hhdf2, codes, on='LUse2', how='left')
    hhdf2.rename(columns={'LUse_Type': 'LUse_Type_clean'}, inplace=True)
    hhdf2 = pd.merge(hhdf2, codes, left_on='LUse3',right_on='LUse2',how='left')
    dummies = pd.get_dummies(hhdf2['LUse_Type_clean'], prefix='LUse')
    dummies = dummies.astype(int)
    for col in dummies.columns:
        log.info(f"{col}: {dummies[col].dtype}")

    # Generate residential indicators
    res_all = ['LUse_residential_nec','LUse_townhouse_rowhouse','LUse_apartment_hotel','LUse_apartment','LUse_cabin','LUse_cooperative','LUse_condominium','LUse_condominiumproject','LUse_duplex','LUse_midrisecondo','LUse_highrisecondo','LUse_frat_sororityhouse','LUse_residencehall_dormitories','LUse_multifamily10unitsplus','LUse_multifamily10unitsless','LUse_multifamilydwelling','LUse_mixedcomplex','LUse_mobilehomepark','LUse_mobilehome','LUse_manufacturedhome','LUse_pud','LUse_quadruplex','LUse_groupquarters','LUse_ruralhomesite','LUse_single_family_residence','LUse_transientlodging','LUse_triplex','LUse_timeshare','LUse_timesharecondo']
    sing_fam = ['LUse_residential_nec','LUse_townhouse_rowhouse','LUse_cabin','LUse_duplex','LUse_mobilehomepark','LUse_mobilehome','LUse_manufacturedhome','LUse_pud','LUse_quadruplex','LUse_ruralhomesite','LUse_single_family_residence','LUse_triplex']
    trailer_home = ['LUse_mobilehomepark','LUse_mobilehome','LUse_manufacturedhome']
    mult_fam = ['LUse_apartment_hotel','LUse_apartment','LUse_cooperative','LUse_condominium','LUse_condominiumproject','LUse_midrisecondo','LUse_highrisecondo','LUse_frat_sororityhouse','LUse_residencehall_dormitories','LUse_multifamily10unitsplus','LUse_multifamily10unitsless','LUse_multifamilydwelling','LUse_mixedcomplex','LUse_groupquarters','LUse_timeshare','LUse_timesharecondo']

    # Filter columns to only include those that exist in the DataFrame
    res_all_existing = [col for col in res_all if col in dummies.columns]
    sing_fam_existing = [col for col in sing_fam if col in dummies.columns]
    trailer_home_existing = [col for col in trailer_home if col in dummies.columns]
    mult_fam_existing = [col for col in mult_fam if col in dummies.columns]

    # Sum across existing columns
    dummies['LUse_res_all'] = dummies[res_all_existing].sum(axis=1, min_count=1)
    dummies['LUse_res_sing_fam'] = dummies[sing_fam_existing].sum(axis=1, min_count=1)
    dummies['LUse_trailer_home'] = dummies[trailer_home_existing].sum(axis=1, min_count=1)
    dummies['LUse_mult_fam'] = dummies[mult_fam_existing].sum(axis=1, min_count=1)

    for col in dummies.columns:
        log.info(f"{col}: {dummies[col].dtype}")

    # Concatenate the dummy variables with the original DataFrame
    hhdf2 = pd.concat([hhdf2, dummies[['LUse_res_all','LUse_res_sing_fam','LUse_trailer_home','LUse_mult_fam']]], axis=1)
    for col in hhdf2.columns:
        log.info(f"{col}: {hhdf2[col].dtype}")
    log.info(f"length after adding landuse types: {len(hhdf2)}")

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after LUse assignment: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    #heating type
    #Check before assigning
    hhdf2['htc2'] = hhdf2['HEATING TYPE CODE'].astype(str).apply(lambda x: x[:3].zfill(3))

    codes = pd.read_csv(heating_codes)
    codes['htc2'] = codes['htc2'].astype(str).apply(lambda x: x[:3].zfill(3))
    hhdf2 = pd.merge(hhdf2, codes, on='htc2', how='left')
    dummies = pd.get_dummies(hhdf2['heating_type'], prefix='htc')
    dummies = dummies.astype(int)
    for col in dummies.columns:
        log.info(f"{col}: {dummies[col].dtype}")

    # Generate the heat pump indicator
    HP_cols = ['htc_heat_pump','htc_heat_pump_electric','htc_heat_pump_gas','htc_heat_pump_hotwater','htc_heat_pump_coal_wood','htc_heat_pump_oil','htc_heatpump_solar','htc_wall_heat_pump']
    HP_cols_existing = [col for col in HP_cols if col in dummies.columns]
    dummies['HP'] = dummies[HP_cols_existing].sum(axis=1,min_count=1)

    for col in dummies.columns:
        log.info(f"{col}: {dummies[col].dtype}")

    # Concatenate the dummy variables with the original DataFrame
    hhdf2 = pd.concat([hhdf2, dummies['HP']], axis=1)
    log.info(f"length after adding heating types: {len(hhdf2)}")

    for col in hhdf2.columns:
        log.info(f"{col}: {hhdf2[col].dtype}")

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after Heating type assignment: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    #heating fuel type
    #Check before assigning
    hhdf2['ftc2'] = hhdf2['fuel_type'].astype(str).apply(lambda x: x[:3].zfill(3))

    codes = pd.read_csv(config.fuel_codes)
    codes['ftc2'] = codes['ftc2'].astype(str).apply(lambda x: x[:3].zfill(3))
    hhdf2 = pd.merge(hhdf2, codes, on='ftc2', how='left')
    log.info(f"length after adding fuel names: {len(hhdf2)}")
    log.info(hhdf2.dtypes)

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after fuel assignment: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    #AC type
    hhdf2['ac'] = hhdf2['ac_code'].astype(str).apply(lambda x: x[:3].zfill(3))
    
    codes = pd.read_csv(config.ac_codes)
    codes['ac'] = codes['ac'].astype(str).astype(str).apply(lambda x: x[:3].zfill(3))
    hhdf2 = pd.merge(hhdf2, codes, on='ac',how='left')
    log.info(f"length after adding ac types: {len(hhdf2)}")
    log.info(hhdf2.dtypes)

    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage after AC assignment: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")

    #Save the final file
    hhdf2.to_csv(out_file,compression='gzip')
    log.info(f"final length: {len(hhdf2)}")
    current, peak = tracemalloc.get_traced_memory()
    log.info(f"Memory usage at end of Spatial_RD_Maker: {current / 10**6:.2f} MB; Peak: {peak / 10**6:.2f} MB")
    log.info(f"Data saved to {out_file} at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

import config_Benton_Richland as config
if __name__ == "__main__":
    main(config)