import pandas as pd
import subprocess
import json

paths = {
    'input_data': 'data/demo/data.csv',
    'pscores': 'data/demo/pscores.csv',
    'features': 'cfg/demo/features.json',
    'model_cfg': 'cfg/model_config.json'
}

with open(paths['features']) as f:
    features = json.load(f)
with open(paths['model_cfg']) as f:
    model_cfg = json.load(f)


dep_var = 'low_income'

# Retrieve Propensity Scores
#=================================
# If pscores = NULL, this section will
    # 1)Read input data. 2) format and export data and model parameters to LGBM. 3) Call LGBM 4) import predictions 5) export pscores for R to use
# If pscores != Null

model_cfg.


# add these to the dict
#"dep_var": ["low_income"],
#"ivars": ["area", "rent_sqft", "units", "yr_built", "lat", "lon", "low_income", "value_imprv_sqft"],
# name the dict   "low_income"

# "n_estimators":[25,50,75,100,200,300,400,500,600,700,800,900,1000],
# "num_leaves":[4,8,16,32,64,128]
model_params = {
    dep_var:
        {
            "dep_var":[dep_var],
            "ivars":features['model'],
            "log_dep":[False],
            "meta":{
                "project":["project"],
                "alias":["alias"]
            },
            "params":
                {
                    "param_grid":
                        {
                            "n_estimators":[25]
                        },
                    "cv":[10],
                    "n_jobs":[-1],
                    "verbose":[1],
                    "estimator":
                        ["LGBMClassifier"],
                    "scoring":["accuracy"]
                }
        }
}

with open('params.json', 'w') as outfile:
    json.dump(model_params, outfile)

# Call Matching Script
#=================================
subprocess.call ("Rscript match.R", shell=True)
