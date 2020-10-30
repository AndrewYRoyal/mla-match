import pandas as pd
import subprocess
import json

paths = {
    'input_data': 'demo_data.csv',
    'pscores': 'demo_pscores.csv',
    'features': 'demo_features.json'
}

with open(paths['features']) as f:
    features = json.load(f)

features['model']

# Retrieve Propensity Scores
#=================================
# If pscores = NULL, this section will
    # 1)Read input data. 2) format and export data and model parameters to LGBM. 3) Call LGBM 4) import predictions 5) export pscores for R to use
# If pscores != Null

# Call Matching Script
#=================================

#subprocess.call ("/usr/bin/Rscript --vanilla /pathto/MyrScript.r", shell=True)
subprocess.call ("Rscript match.R", shell=True)
