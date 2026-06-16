# Function Definition File
# This file is intended to contain all defined functions used elsewhere in the analysis procedure
# Note that inputs may be configured in the respective config files

#Imports
import numpy as np
from scipy.interpolate import UnivariateSpline, interp1d
from scipy.integrate import quad
import requests
import pandas as pd
from bs4 import BeautifulSoup
import re
import os
import re
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry # type: ignore
from urllib.parse import urljoin
import zipfile
import geopandas as gpd
from shapely.geometry import Point
from pyproj import Transformer
from shapely import wkt
import logging as log
from datetime import datetime
import time
from sklearn.neighbors import BallTree

# Define the Deduplication procedure
def deduplicate_file(file, usecols, dtypes, temp_folder):
    # Identify the file and delimit rule
    file_name = os.path.basename(file)
    file_name = os.path.splitext(file_name)[0]
    file_name = file_name.split("_")[-1]
    log.info(f"beginning deduplication work on {file}")

    # Load only select parts
    data = pd.read_csv(file, usecols=usecols, dtype=dtypes, low_memory=False)

    # Create Indexa (time-location index) and HEAT INDC
    data['indexa'] = data['COMPOSITE PROPERTY LINKAGE KEY'].astype(str) + data['TAXROLL CERTIFICATION DATE'].astype(str)
    data['HEAT INDC'] = np.where(data['HEATING TYPE CODE'].notnull() & (data['HEATING TYPE CODE'] != ''), 1, 0)
    log.info(f"{file_name} initial length: {len(data)}, deduplicating file now.")

    # Deduplication
    # Identify duplicate rows, keep rows with non-null values in 'HEATING TYPE CODE' if any rows have them
    data['has_duplicate'] = data['indexa'].duplicated(keep=False)  # Include all duplicates
    data = data.sort_values(by='indexa')

    # Separate duplicate and non-duplicate rows
    dup = data[data['has_duplicate'] == True]
    dedup = data[data['has_duplicate'] == False]

    log.info(f"duplicate data length: {len(dup)}")
    log.info(f"non-duplicate data length: {len(dedup)}")

    # Proceed only if there are duplicates
    if len(dup) > 0:
        # Step 1: Define valid columns
        valid_columns = ["HEATING TYPE CODE", "MARKET TOTAL VALUE", "STORIES NUMBER", "LAND USE CODE",
                        "LIVING SQUARE FEET - ALL BUILDINGS", "NUMBER OF UNITS", "PARCEL LEVEL LONGITUDE",
                        "PARCEL LEVEL LATITUDE"]

        # Step 2: Group by 'indexa' and process each group
        dup_groups = dup.groupby('indexa')
        processed_rows = []

        # Step 3: Process each group
        for indexa, group in dup_groups:
            # Calculate non-null/non-empty values count in valid_columns for each row
            group = group.copy()  # Avoid setting with copy warning
            group['non_null_count'] = group[valid_columns].apply(lambda row: sum(row.notnull() & (row != '')), axis=1)
            # Select the row with the highest non-null count
            best_row = group.loc[group['non_null_count'].idxmax()].copy()
            # Fill missing values in the selected best_row
            best_row = fill_missing_with_common(best_row, group,valid_columns)
            # Append processed best_row to list
            processed_rows.append(best_row)

        # Step 4: Convert list of processed rows to DataFrame and drop the non-null count column
        deduplicated_df = pd.DataFrame(processed_rows).drop(columns='non_null_count')
        # Step 5: Combine deduplicated rows with non-duplicated rows
        dedup = pd.concat([dedup, deduplicated_df], axis=0).reset_index(drop=True)
        # Final clean DataFrame
        CL_Clean = dedup

        # Clean up temporary variables
        del deduplicated_df, processed_rows, dup, valid_columns
    else:
        # If no duplicates, use non-duplicated data as the final cleaned DataFrame
        CL_Clean = dedup
        del dedup, dup

    t4 = time.time()
    log.info(f"de-duplicated file {file_name} length: {len(CL_Clean)}")

    # Create Unit Price
    CL_Clean['Home_Value'] = CL_Clean['MARKET TOTAL VALUE'].copy()
    CL_Clean.loc[CL_Clean['NUMBER OF UNITS'] > 1, 'Home_Value'] = CL_Clean['Home_Value'] / CL_Clean['NUMBER OF UNITS']

    # Rename Columns
    log.info("renaming columns")
    CL_Clean = CL_Clean.rename(columns={
        'COMPOSITE PROPERTY LINKAGE KEY': 'Property_ID',
        'MARKET TOTAL VALUE': 'Home_Price',
        'YEAR BUILT': 'Year_Built',
        'EFFECTIVE YEAR BUILT': 'Eff_Yr_Built',
        'STORIES NUMBER': 'Stories',
        'TOTAL ROOMS - ALL BUILDINGS': 'Rooms',
        'UNIVERSAL BUILDING SQUARE FEET': 'Square_Feet',
        'LIVING SQUARE FEET - ALL BUILDINGS': 'Live_Square_Feet',
        'NUMBER OF UNITS': 'Unit_Count',
        'LAND USE CODE': 'LUse',
        'FUEL CODE': 'fuel_type',
        'AIR CONDITIONING CODE': 'ac_code',
        'PARCEL LEVEL LATITUDE': 'Parcel_Lat',
        'PARCEL LEVEL LONGITUDE': 'Parcel_Long'
    })

    CL_Clean['TAXROLL CERTIFICATION DATE'] = pd.to_datetime(CL_Clean['TAXROLL CERTIFICATION DATE'])
    CL_Clean['Month'] = CL_Clean['TAXROLL CERTIFICATION DATE'].dt.month
    CL_Clean['Year'] = CL_Clean['TAXROLL CERTIFICATION DATE'].dt.year
    CL_Clean['Year_Revised'] = CL_Clean['Year'] + np.where(CL_Clean['Month'] < 6, 0, 1)

    # Save temp dataframe to temp_file
    temp_csv_file = os.path.join(temp_folder, f"temp_CL_hh_deduplicated_{file_name}.csv.gz")
    CL_Clean.to_csv(temp_csv_file, index=False, compression="gzip")
    log.info(f"Data shape after deduplication: {CL_Clean.shape}")

    return None

#Define procedure for reattribution of lat/long
def fill_missing_lat_long_type(dat,usecols,dtype,lat,long,type,id):
    t1 = time.time()
    log.info(f"beginning lat-long work on {dat}")

    #Read the data from CSV
    df = pd.read_csv(dat,usecols=usecols,dtype=dtype,low_memory=False)
    log.info("Read CSV file and created dataframe.")

    # Step 1: Collect info
    log.info(f"data length: {len(df)}")
    log.info(df.dtypes)

    # Step 2: Create fully clean DataFrame
    clean_rows = df[
        (df[lat].notna() & df[lat] != 0) &
        (df[long].notna() & df[long] != 0) &
        (df[id].notna() & df[id] != '')][[id,lat,long]]
    clean_rows = clean_rows.drop_duplicates()
    clean_rows = clean_rows.groupby(id).apply(lambda x: x.mode().iloc[0]).reset_index(drop=True)
    log.info(f"clean DF created. length: {len(clean_rows)}")

    # Step 3: Create dataframe with rows without missing or invalid data
    data = df[(df[id].notna()) & (df[id]!= '')]
    log.info(f"functional dataframe length: {len(data)}")

    # Step 4: merge
    cd = pd.merge(data, clean_rows, on=id, how='left', suffixes=('', '_clean'))

    #Repeat for LUse
    clean_rows = cd[(cd[type].notna()) & (cd[type] !=0) & (cd[type] != "")][[id,type]]
    clean_rows = clean_rows.drop_duplicates()
    clean_rows = clean_rows.groupby(id).apply(lambda x: x.mode().iloc[0]).reset_index(drop=True)
    log.info(f"clean DF created. length: {len(clean_rows)}")
    data = cd[(cd[id].notna()) & (cd[id]!= '')]
    clean_data = pd.merge(data, clean_rows, on=id, how='left', suffixes=('', '_clean'))

    log.info(f"valid rows remaining: {len(clean_data)}")
    log.info(clean_data.columns)

    return clean_data

# Function to get formatted time.
def ftime(seconds):
    seconds = int(seconds)
    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours:02}:{minutes:02}:{seconds:02}"

#Function to get state abbreviation

def get_state_abbr(state=None):
    state_abbreviations = {
        "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
        "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
        "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
        "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
        "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
        "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
        "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
        "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
        "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
        "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC",
        "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX", "Utah": "UT",
        "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
        "Wisconsin": "WI", "Wyoming": "WY"
    }
    return state_abbreviations if state is None else state_abbreviations.get(state, None)

#Function to get state ID given state name

def get_state_id(state,key):
    if state:
        surl = f'https://api.census.gov/data/{datetime.now().year-2}/acs/acs5'
        params = {
            "get": "NAME",
            "for": "state:*",
            "key": key
        }
        for attempt in range(5):  # Retry up to 3 times
            try:
                response = requests.get(surl, params=params, timeout=30)
                response.raise_for_status()
                data = response.json()
                df = pd.DataFrame(data[1:], columns=data[0])
                sID = df[df['NAME'] == state]['state'].values[0]
                return sID
            except (requests.exceptions.ConnectTimeout, requests.exceptions.HTTPError) as e:
                log.info(f"Attempt {attempt + 1} failed: {e}")
                time.sleep(5)  # Wait 5 seconds before retrying
        raise Exception("Failed to connect to the Census API after 3 attempts")

# function to get county IDs given state ID

def get_county_id(county,key,state,sID):
    if county:
        curl = f'https://api.census.gov/data/{datetime.now().year-2}/acs/acs5'
        params = {
            "get": "NAME",
            "for": "county:*",
            "in": f"state:{sID}",
            "key": key
        }
        for attempt in range(3):  # Retry up to 3 times
            try:
                response = requests.get(curl, params=params, timeout=10)
                response.raise_for_status()
                data = response.json()
                df = pd.DataFrame(data[1:], columns=data[0])
                cID = df[df['NAME'] == f'{county} County, {state}']['county'].values[0]
                return cID
            except (requests.exceptions.ConnectTimeout, requests.exceptions.HTTPError) as e:
                log.info(f"Attempt {attempt + 1} failed: {e}")
                time.sleep(5)  # Wait 5 seconds before retrying
        raise Exception("Failed to connect to the Census API after 3 attempts")

# Function to fill with the most common in the group
def fill_missing_with_common(row, group, valid_columns):
    for col in valid_columns:
        if pd.isnull(row[col]) or row[col] == '':
            most_common_value = group[col].dropna().loc[group[col] != ''].mode()
            if not most_common_value.empty:
                row[col] = most_common_value.iloc[0]
    return row

# Function to get data from unindexed websites

def get_soup(url):
    session = requests.Session()
    retries = Retry(total=5, backoff_factor=1, status_forcelist=[502, 503, 504])
    session.mount('https://', HTTPAdapter(max_retries=retries))

    try:
        response = session.get(url, timeout=30)
        response.raise_for_status()
        return BeautifulSoup(response.text, 'html.parser')
    except requests.exceptions.Timeout:
        log.info(f"Timeout occurred while trying to connect to {url}")
    except requests.exceptions.RequestException as e:
        log.info(f"An error occurred: {e}")
        return None

#Function to download a file from a webpage

def download_file(url, save_path):
    session = requests.Session()
    retries = Retry(total=5, backoff_factor=1, status_forcelist=[502, 503, 504])
    session.mount('https://', HTTPAdapter(max_retries=retries))

    try:
        with session.get(url, stream=True, timeout=30) as r:
            if r.status_code == 404:
                log.info(f"File not found: {url}")
                return  # Skip 404 errors silently
            r.raise_for_status()
            os.makedirs(os.path.dirname(save_path), exist_ok=True)
            with open(save_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        log.info(f"Downloaded {save_path}")
    except requests.exceptions.Timeout:
        log.info(f"Timeout occurred while trying to download {url}")
    except requests.exceptions.RequestException as e:
        log.info(f"An error occurred while downloading {url}: {e}")

# Function to extract all shapefiles from a zip archive

def id_shapefiles(zip_path, extract_to_dir):
    shapefile_paths = []
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_to_dir)
        for file in zip_ref.namelist():
            if file.endswith('.shp'):
                shapefile_paths.append(os.path.join(extract_to_dir, file))
    return shapefile_paths

# Function to clean the directory

def empty_directory(directory):
    for file in os.listdir(directory):
        file_path = os.path.join(directory, file)
        try:
            if os.path.isfile(file_path):
                os.remove(file_path)
            elif os.path.isdir(file_path):
                os.rmdir(file_path)
        except Exception as e:
            log.info(f"Error deleting {file_path}: {e}")

#Function to drop an index column

def drop_index_columns(left_df, right_df):
    left_has_index_l = 'index_left' in left_df.columns
    left_has_index_r = 'index_right' in left_df.columns
    right_has_index_l = 'index_right' in right_df.columns
    right_has_index_r = 'index_right' in right_df.columns
    if left_has_index_l:
        left_df = left_df.drop(columns=['index_left'])
    if left_has_index_r:
        left_df = left_df.drop(columns=['index_right'])
    if right_has_index_l:
        right_df = right_df.drop(columns=['index_left'])
    if right_has_index_r:
        right_df = right_df.drop(columns=['index_right'])
    return left_df, right_df

#Zone Definition given two spatial areas
def in_zone(territory1,territory2,points):
    points['in_ter1']=points.geometry.within(territory1['geometry'].iloc[0]).astype(int)
    points['in_ter2']=points.geometry.within(territory2['geometry'].iloc[0]).astype(int)
    points['in_zone']=points['in_ter1']+points['in_ter2']
    output = gpd.GeoDataFrame(points[points['in_zone']==1])
    return output

# distance from a boundary spatially defined
def distance(points,boundary):
    points['distance']=points.geometry.distance(boundary)
    points['distance']=points['distance']*np.where(points['in_ter1']==1,-1,1)
    output = gpd.GeoDataFrame(points)
    return output

# FUnction to download tract files for shapefiles

def download_tract_files(base_url, year, downfolder, key, state=None):
    file_list = []

    all_states = [
        "Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado", "Connecticut", "Delaware",
        "Florida", "Georgia", "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas",
        "Kentucky", "Louisiana", "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota", "Mississippi",
        "Missouri", "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York",
        "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
        "South Dakota", "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington", "West Virginia",
        "Wisconsin", "Wyoming"
    ]

    states_to_process = [state] if state else all_states

    for st in states_to_process:
        state_num = get_state_id(st,key)
        state_abb = get_state_abbr(st)

        if not state_num or not state_abb:
            log.info(f"State information not found for {st}")
            continue

        links = []
        file = None

        if year == 1992:
            url = f"{base_url}{year}/{state_num}/"
            soup = get_soup(url)
            if soup:
                links1 = soup.find_all('a', href=re.compile(r'\d{5}\.zip'))
                links = [urljoin(url, link['href']) for link in links1]
            if links is None:
                log.info(f"No file for {links}")
                continue
        elif year == 1999:
            url = f"{base_url}{year}/{state_abb}/"
            soup = get_soup(url)
            if soup:
                links1 = soup.find_all('a', href=re.compile(r'tgr\d{5}\.zip'))
                links = [urljoin(url, link['href']) for link in links1]
            if links is None:
                log.info(f"No file for {links}")
                continue
        elif year == 2000:
            file = f"{base_url}TRACT/{year}/tl_{year}_{state_num}_tract00.zip"
        elif year in {2002, 2003}:
            url = f"{base_url}{year}/{state_num}_{state_abb}/"
            soup = get_soup(url)
            if soup:
                links1 = soup.find_all('a', href=re.compile(r'tgr\d{5}\.zip'))
                links = [urljoin(url, link['href']) for link in links1]
            if links is None:
                log.info(f"No file for {links}")
                continue
        elif year == 2007:
            url = f"{base_url}{year}FE/{state_num}_{st.upper()}/"
            soup = get_soup(url)
            if soup:
                links1 = soup.find_all('a', href=re.compile(r'\d{5}_[a-zA-Z]+/$'))
                for lin in links1:
                    href = lin['href']
                    code = href.split('_')[0]
                    lin_url = urljoin(url, href)
                    link = f"{lin_url}fe_{year}_{code}_tract00.zip"
                    links.append(link)
            if links is None:
                log.info(f"No file for {links}")
                continue
        elif year in {2008, 2009}:
            file = f"{base_url}{year}/{state_num}_{st.upper()}/tl_{year}_{state_num}_tract00.zip"
        elif year == 2010:
            file = f"{base_url}{year}/TRACT/{year}/tl_{year}_{state_num}_tract10.zip"
        elif year in range(2011, 2025):
            file = f"{base_url}{year}/TRACT/tl_{year}_{state_num}_tract.zip"

        if file:
            save_path = os.path.join(downfolder, f"{state_abb.lower()}_{os.path.basename(file)}")
            download_file(file, save_path)
            file_list.append(save_path)
        else:
            for link in links:
                if link:
                    save_path = os.path.join(downfolder, f"{state_abb.lower()}_{os.path.basename(link)}")
                    download_file(link, save_path)
                    file_list.append(save_path)
    return file_list

# extract a census dataset based on year, granularity, type, location and census key

def census_extract(level, year, dataset, table, key, state, tablesetting=None, county=None):
    year = str(year)
    dataset = str(dataset)
    part = str(tablesetting)
    if county:
        co = f" county:{county}"
        if part:
            curl = f"https://api.census.gov/data/{str(year)}/acs/{dataset}/{part}"
                # Parameters for the request, including your API key
            params = {
                "get": f"group({table})",
                "for": f"{level}:*",
                "in": f"state:{state}{co}",
                "key": key
            }
        else:
            curl = f"https://api.census.gov/data/{str(year)}/acs/{dataset}"
                # Parameters for the request, including your API key
            params = {
                "get": f"group({table})",
                "for": f"{level}:*",
                "in": f"state:{state}{co}",
                "key": key
            }
    else:
        curl = f"https://api.census.gov/data/{str(year)}/acs/{dataset}"
            # Parameters for the request, including your API key
        params = {
            "get": f"group({table})",
            "for": f"{level}:*",
            "in": f"state:{state}",
            "key": key
        }
    # Make GET request
    response = requests.get(curl, params=params)
    log.info(response.url)
    # Check if request was successful
    if response.status_code == 200:
        # Convert response to JSON format
        data = response.json()
        df = pd.DataFrame(data[1:], columns=data[0])
        log.info(f"{year} data loaded")

    else:
        log.info(f"Error: {response.status_code} for {year}. Note that if acs5 data is before 2010, no data will load.")
        return None
    #Get the labels for each column
    # Send a GET request to the webpage
    if part:
        lurl = f"https://api.census.gov/data/{str(year)}/acs/{dataset}/{part}/groups/{table}.html"
    else:
        lurl = f"https://api.census.gov/data/{str(year)}/acs/{dataset}/groups/{table}.html"

    response = requests.get(lurl)

    # Check if request was successful
    if response.status_code == 200:
        # Parse the HTML content
        soup = BeautifulSoup(response.content, "html.parser")

        # Find the table containing the data
        table_html = soup.find("table")

        if table_html:
            # Extract column headers from the <thead>
            headers = [th.text.strip() for th in table_html.find_all("th")]

            # Extract rows of data from the <tbody>
            data_rows = []
            for tr in table_html.find("tbody").find_all("tr"):  # Iterate over rows in <tbody>
                row = [td.text.strip() for td in tr.find_all("td")]
                if row:  # Avoid appending empty rows
                    data_rows.append(row)

            # Create the DataFrame
            dfl = pd.DataFrame(data_rows, columns=headers)
            dfl = dfl.iloc[1:].reset_index(drop=True)

            # Function to find rightmost index
            def find_rightmost_index(s):
                index = s[::-1].find("!!")
                if index != -1:
                    return len(s) - index - 2  # Subtract 2 to exclude "!!"
                return -1

            # Extract and clean the labels
            dfl["Label"] = dfl["Label"].apply(lambda x: x[find_rightmost_index(x)+2:] if find_rightmost_index(x) != -1 else x)
            dfl["Label"] = dfl["Label"].str.replace(" ", "_").str.replace(",", "").str.replace(":","")

            # Filter based on part and name criteria
            if part == 'subject':
                dfl = dfl[dfl["Name"].str.contains('C01')]
            dfl = dfl[dfl["Name"].str.endswith("E")]
            dfl = dfl[['Name', 'Label']]
            row = pd.DataFrame([['GEO_ID', 'Geography']], columns=['Name', 'Label'])
            dfl = pd.concat([dfl, row], ignore_index=True)

            filtered_df = df.copy()

            # Assign labels
            code_label_map = dict(zip(dfl["Name"], dfl["Label"]))
            filtered_df.rename(columns=code_label_map, inplace=True)

            renamed_columns = dfl['Label'].tolist()
            filtered_df = filtered_df[[col for col in filtered_df.columns if col in renamed_columns]]
            filtered_df.replace("-999999999", 0, inplace=True)

            return filtered_df

        else:
            log.info("No table found in HTML response.")
    else:
        log.info("Error:", response.status_code)
        return None

# Function to find the maximum bound of a 'X or greater' bracket given an average across all brackets

def find_max(counts, buckets, mean_total):
    # Step 0: Ensure counts and mean_total are numeric
    counts = pd.to_numeric(counts, errors='coerce')  # Convert counts to numeric, set invalid to NaN
    mean_total = pd.to_numeric(mean_total, errors='coerce')  # Ensure mean_total is numeric

    # Step 1: Total count and sum
    total_count = counts.sum()
    total_sum = mean_total * total_count

    # Step 2: Calculate lower bucket subtotal
    midpoints = [(buckets[i] + buckets[i+1]) / 2 for i in range(len(buckets) - 2)]
    minpoints = [buckets[i] for i in range(len(buckets) - 1)]

    subtotal_lower = sum(count * midpoint for count, midpoint in zip(counts[:-1], midpoints))
    min_subtotal_lower = sum(count * minpoint for count, minpoint in zip(counts[:-1], minpoints))

    # Step 3: Calculate the sum and count of the highest bucket
    sum_high = total_sum - subtotal_lower
    count_high = counts.iloc[-1]
    x_min = buckets[-2]  # Lower bound of the highest bucket
    if count_high == 0:  # Prevent division by zero
        max = x_min + 2
    else:
        mu_high = sum_high / count_high  # Mean for the highest bucket

    # Step 4: Estimate the upper bound of the highest bucket (uniform distribution assumption)
        x_max = 2 * (mu_high - x_min) + x_min  # Using midpoint formula for uniform distribution

    # Step 5: Validate and check
        if x_max > x_min:
            max = x_max
        else:
            max = x_min + 2

    return max

# Function to assign a house the same tract as it's given another year if it exists

def backdate_tract(df):
    short = df[df['TRACT_FIPS'].isna()]
    long = df.dropna(subset=['TRACT_FIPS'])
    for hh in np.unique(short['Property_ID']):
        relevant_rows = long[long['Property_ID'] == hh]
        if not relevant_rows.empty:
            latest_year = relevant_rows['Year'].max()
            geo_id = relevant_rows[relevant_rows['Year'] == latest_year]['TRACT_FIPS'].values[0]
            short.loc[short['Property_ID'] == hh, 'TRACT_FIPS'] = geo_id
    combined = pd.concat([long, short], axis=0)
    return combined

# get min_max: extract the bottom and top of a bracket based on the column header

def get_brackets(column_names):
    brackets = []
    for col in column_names:
        if 'Less_than' in col:
            brackets.append(0)
        elif 'or_more' in col:
            brackets.append(int(re.search(r'\$(\d+)', col).group(1)))
            brackets.append(None)
        else:
            parts = re.findall(r'\$(\d+)', col)
            brackets.append(int(parts[0]))
    return brackets

def gen_dist(len, lower, upper, percent, type=None):
    # Step 2: Compute midpoints and densities
    midpoints = (lower + upper) / 2
    densities = percent / (upper - lower)

    # Step 3: Interpolate PDF
    pdf_spline = UnivariateSpline(midpoints, densities, s=0, k=3)

    # Step 4: Normalize the PDF
    pdf_integral, _ = quad(pdf_spline, midpoints[0], midpoints[-1])
    normalized_pdf = lambda x: pdf_spline(x) / pdf_integral

    # Step 5: Create CDF
    cdf_x = np.linspace(midpoints[0], midpoints[-1], 10000)
    cdf_y = np.cumsum(normalized_pdf(cdf_x)) * (cdf_x[1] - cdf_x[0])
    cdf_interp = interp1d(cdf_y, cdf_x, bounds_error=False, fill_value=(cdf_x[0], cdf_x[-1]))

    # Step 6: Sample random values based on population
    num_samples = int(len)
    random_samples = [cdf_interp(np.random.uniform()) for _ in range(num_samples)]

    # Create labeled data
    df = {'Type': type, 'Value': random_samples}

    # Sort by Type and Value in descending order
    df_sorted = df.sort_values(by=['Type', 'Value'], ascending=[True, False]).reset_index(drop=True)

    return df_sorted

# Generate N random samples based on brackets and percentages assuming uniform distribution within brackets

def generate_random_samples(brackets, percentages, N, Na):
    # Normalize percentages to sum to 1
    probabilities = np.array(percentages) / sum(percentages)

    # Step 1: Randomly choose a bracket based on probabilities
    bucket_indices = np.random.choice(len(probabilities), size=N, p=probabilities)

    # Step 2: Generate all samples within the chosen brackets
    brackets = np.array(brackets)

    # Ensure we don't exceed array bounds
    upper_bounds = np.where(bucket_indices + 1 < len(brackets), brackets[bucket_indices + 1], brackets[-1])
    lower_bounds = brackets[bucket_indices]

    # Uniformly sample from each bracket
    random_samples = np.random.uniform(lower_bounds, upper_bounds)

    # Step 3: Create the first DataFrame (N x 1)
    df_samples = pd.DataFrame({'income': random_samples})

    # Step 4: Add NaN rows to the bottom of df_samples
    none_count = max(0, Na - N)  # Ensure it's not negative
    nan_rows = pd.DataFrame({'income': [np.nan] * none_count})

    # Append the NaN rows at the bottom of df_samples
    df_samples = pd.concat([df_samples, nan_rows], ignore_index=True)

    return df_samples

# Function to compute neighborhood counts
def compute_neighbor_counts(df, radius, lat_col, long_col, year_col, treat_col, condition_col):
    earth_radius = 6371000  # meters
    radius_radians = radius / earth_radius  # Convert meters to radians

    # Convert lat/lon to radians
    df['lat_rad'] = np.radians(df[lat_col])
    df['lon_rad'] = np.radians(df[long_col])

    for x in [0,1]:
        for y in [0,1]:
            df[f'{treat_col}_{x}{condition_col}_{y}']=0
    df[f'avg_{treat_col}'] = 0.0
    df[f'avg_{condition_col}'] = 0.0

    out=pd.DataFrame(columns=df.columns)
    df.sort_values(by=year_col,inplace=True)

    # Process each year separately
    for year in df[year_col].unique():
        df_year = df[df[year_col] == year].reset_index(drop=True)
        log.info(f"working on year {year}. Number of rows: {len(df_year)}")

        # Build BallTree for efficient spatial lookup
        tree = BallTree(df_year[['lat_rad', 'lon_rad']], metric='haversine')

        neighbors_indices = tree.query_radius(df_year[['lat_rad','lon_rad']].values,r=radius_radians)

        # Process neighbors in batch
        for i, idx_within_radius in enumerate(neighbors_indices):
            # Exclude self from the count
            idx_within_radius = idx_within_radius[idx_within_radius != i]

            # Subset the neighbors
            neighbors = df_year.iloc[idx_within_radius]

            # Count conditions
            for x in [0, 1]:
                for y in [0, 1]:
                    df_year.at[i, f'{treat_col}_{x}{condition_col}_{y}'] = ((neighbors[condition_col] == y) & (neighbors[treat_col] == x)).sum()

            # Compute averages safely
            treat_denom = max(len(neighbors[neighbors[treat_col].notna()]), 1)
            cond_denom = max(len(neighbors[neighbors[condition_col].notna()]), 1)

            df_year.at[i, f'avg_{treat_col}'] = len(neighbors[neighbors[treat_col] == 1]) / treat_denom
            df_year.at[i, f'avg_{condition_col}'] = len(neighbors[neighbors[condition_col] == 1]) / cond_denom

            log.info(f"{round(i/len(df_year)*100,3)}% complete with {year}.")
        # Append processed data to output
        out = pd.concat([out, df_year], axis=0, ignore_index=True)

    return out
