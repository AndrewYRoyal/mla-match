import pandas as pd
import os
import subprocess
import json
import argparse

parser = argparse.ArgumentParser('Machine Learning Assisted Sample Matching')
parser.add_argument('--data', dest='data', default='', action='store', required=True)
parser.add_argument('--dep', dest='dep_var', default='', action='store', required=True)
parser.add_argument('--features', dest='features', default='', action='store')
parser.add_argument('--pscores', dest='pscores', default='', action='store')
args = parser.parse_args()

dep_var = args.dep_var
import_paths = {
    'data': f'data/{args.data}',
    'pscores': f'data/{args.pscores}',
    'features': f'cfg/{args.features}',
    'model_cfg': 'cfg/model_config.json',
    'predictions': f'output/predictions/{dep_var}.csv'
}
export_paths = {
    'model_input': 'Site-LGBM/input/input.csv',
    'model_params': 'Site-LGBM/input/model_params.json',
    'pscores': 'data/pscores.csv'
}

# Retrieve Propensity Scores
#=================================
if args.pscores == '':
    print('No propensity scores supplied. Calculating scores with LightGBM.')
    model_dat = pd.read_csv(import_paths['data'])
    if args.features != '':
        with open(import_paths['features']) as f:
            features = json.load(f)
    else:
        features = set(model_dat.columns).difference(['id', dep_var])
    model_dat = model_dat[['id', dep_var] + features['model']]
    with open(import_paths['model_cfg']) as f:
        model_cfg = json.load(f)
    model_cfg.update({'dep_var': [dep_var]})
    model_cfg.update({'ivars': features['model']})
    model_cfg = {dep_var: model_cfg}

    if (not os.path.exists(export_paths['model_input'])):
        os.mkdir(export_paths['model_input'])

    model_dat.to_csv(export_paths['model_input'], index=False)
    with open(export_paths['model_params'], 'w') as outfile:
        json.dump(model_cfg, outfile)

    gbm_call = 'python Site-LGBM/predict.py --data {} --params {}'.format(
        export_paths['model_input'],
        export_paths['model_params']
    )
    subprocess.call(gbm_call, shell=True)

    pscores = pd.read_csv(import_paths['predictions'])
    pscores.rename(columns={'Yes': 'pscore'}, inplace=True)
    pscores[['id', 'pscore']].to_csv(export_paths['pscores'], index=False)
else:
    pscores = pd.read_csv(import_paths['pscores'])
    pscores.to_csv(export_paths['pscores'], index=False)

# Call Matching Script
#=================================
# TODO: supply Rscript with: 1) path to cfg file for match features, 2) dep_var, 3) path to data file
r_call = 'Rscript match.R --dep {} --data {} --pscores {} --features {}'.format(
    dep_var,
    import_paths['data'],
    export_paths['pscores'],
    import_paths['model_cfg']
)
r_call = 'Rscript match.R'

subprocess.call ("Rscript match.R", shell=True)

# "n_estimators":[25,50,75,100,200,300,400,500,600,700,800,900,1000],
# "num_leaves":[4,8,16,32,64,128]
