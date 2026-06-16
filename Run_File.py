import Core_Logic_State_Cleaning
import Spatial_RD_Maker
import assign_tracts
import add_income
import add_tenure
import add_occupancy
import add_poverty
import add_average
import stata_prep
import config_Benton_Richland as config
import function_definition as func
import logging as log
import gc
import importlib
from datetime import datetime

# Configure logging
log.basicConfig(
    filename=config.loggingfile,
    level=log.INFO,
    format='%(message)s',
    filemode='a'
)

log.info(f'Beginning work at {datetime.now().strftime("%Y-%m-%d %H:%M")}')

def execute_and_clear(module, function_name):
    log.info(f'Beginning {module.__name__} Procedures at {datetime.now().strftime("%H:%M")}')
    getattr(module, function_name)(config)  # Call the .main(config) method dynamically
    log.info(f'{module.__name__} Procedures Complete.')
    gc.collect()  # Trigger garbage collection

    # Reload modules
    modules_to_reload = [
        Core_Logic_State_Cleaning,
        Spatial_RD_Maker,
        assign_tracts,
        add_income,
        add_tenure,
        add_occupancy,
        add_poverty,
        add_average,
        stata_prep,
        config,
        func,
        log]
    for module in modules_to_reload:
        importlib.reload(module)

    # Reconfigure logging after reload
    log.basicConfig(
        filename=config.loggingfile,
        level=log.INFO,
        format='%(message)s',
        filemode='a'
    )

# Execute each module function and clear memory between steps
execute_and_clear(Core_Logic_State_Cleaning, 'main')
execute_and_clear(Spatial_RD_Maker, 'main')
execute_and_clear(assign_tracts, 'main')
execute_and_clear(add_income, 'main')
execute_and_clear(add_tenure, 'main')
execute_and_clear(add_occupancy, 'main')
execute_and_clear(add_poverty, 'main')
execute_and_clear(add_average, 'main')
execute_and_clear(stata_prep, 'main')

# Clean the temporary directory
log.info(f'Beginning Cleanup Procedures at {datetime.now().strftime("%H:%M")}')
func.empty_directory(config.temp_folder)

log.info(f'Full processing complete at {datetime.now().strftime("%H:%M")}')
