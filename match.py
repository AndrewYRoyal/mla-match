import pandas as pd
import subprocess

paths = {
    'input_data': 'input.csv',
    'pscores': 'pscores.csv'
}

# Retrieve Propensity Scores
#=================================
# If pscores = NULL, this section will
    # 1)Read input data. 2) format and export data and model parameters to LGBM. 3) Call LGBM 4) import predictions 5) export pscores for R to use
# If pscores != Null

# Call Matching Script
#=================================

#subprocess.call ("/usr/bin/Rscript --vanilla /pathto/MyrScript.r", shell=True)
subprocess.call ("Rscript match.R", shell=True)
