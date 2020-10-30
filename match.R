require(data.table)
require(distances)
require(magrittr)
require(ggplot2)

# TODO: pass argument that supplies treatment colum name
treat_col = 'low_income'

import_paths = list(
  input_data = 'demo_data.csv',
  pscores = 'demo_pscores.csv')

export_paths = list(
  matches = 'output/matches.csv',
  plot_data = 'output/plot_data.csv',
  pp_unmatched = 'output/pp_unmatched.png',
  pp_matched = 'output/pp_matched.png',
  sample_averages = 'output/sample_averages.png')

# Import & Format
#===============================================
input_dat = fread(import_paths$input_data, key = 'id') %>%
  merge(fread(import_paths$pscores, key = 'id')) %>%
  .[order(-pscore)]
setnames(input_dat, treat_col, 'treated')

compare_cols = names(input_dat) %>% setdiff(c('treated', 'id', 'pscore'))

treated_rows = input_dat[treated == 'Yes', which = TRUE]
target_dat = input_dat[-treated_rows, .SD, .SDcols = 'id']

# Functions
#===============================================
find_match_gen = function(dist_obj, match_pool) {
  function(rnum){
    match_dat = as.data.table(distance_columns(dist_obj, rnum), keep.rownames = TRUE)
    id_selected = setdiff(names(match_dat), 'rn')
    setnames(match_dat, 'rn', 'id')
    match_dat = merge(match_dat, match_pool, by = 'id')
    match_dat = match_dat[which.min(get(id_selected))]
    setnames(match_dat, 'id', 'match')
    melt(match_dat, id.vars = 'match', variable.name = 'id', value.name = 'distance')
  }
}
make_counter = function(fun_name, n) {
  x = 0
  step_size = n %/% 20
  function() {
    if(x == 0) cat(fun_name, '\n', 'Progress:')
    x <<- x + 1
    if(x %% step_size == 0) cat('X')
    if(x == n) cat('100% \n')
  }
}
calc_ks = function(d, n = n_treated) 2 * exp(-n * d^2)
transform_cdf = function(dat) {
  cdfs = split(dat, by = 'status') %>%
    lapply(function(dat) ecdf(dat$value))
  new_cols = names(cdfs)
  dat[, (new_cols):= lapply(cdfs, function(f) f(value))]
  dat
}
calc_tstat = function(u1, u2, v1, v2, n1, n2) (u1 - u2) / sqrt(v1 / n1 + v2 / n2)
calc_p_value = function(t) round(2 * pnorm(-abs(t)), 2)

## Sequential Inexact Matching
#===============================================
dist_lookup = distances(
  input_dat[, .SD, .SDcols = c('id', compare_cols)], 
  id_variable = 'id', 
  normalize = 'mahalanobize')

matchDT = as.data.table(list(match = NULL, id = NULL, distance = NULL))
counter = make_counter('Matching', n = length(treated_rows))
startTime = Sys.time()

for(treated_row in treated_rows) {
  find_match = find_match_gen(dist_lookup, match_pool = target_dat)
  matchDT = rbind(matchDT, find_match(rnum = treated_row))
  target_dat = target_dat[!(id %in% matchDT$match)]
  counter()
}

t_elapsed = Sys.time() - startTime
cat('Matching Complete! Time Elapsed:', t_elapsed, '\n')

fwrite(matchDT, export_paths$matches)

## Configure Data for Plots
#===============================================
cat('Generating summary plots \n')

input_dat[, (compare_cols):= lapply(.SD, as.numeric), .SDcols = compare_cols]
n_treated = uniqueN(input_dat[treated == 'Yes'])
input_dat[id %in% matchDT$match, status:= 'matched']
input_dat[is.na(status) & treated == 'No', status:= 'unmatched']
input_dat[treated == 'Yes', status:= treat_col]
setnames(input_dat, 'treated', treat_col)
input_dat[, status:= factor(status, levels = c(treat_col, 'matched', 'unmatched'))]

fwrite(input_dat, export_paths$plot_data)

## Plot Comparision
#===============================================
pp_dat = input_dat[, .SD, .SDcols = c('status', 'id', compare_cols)] %>%
  melt(id.vars = c('status', 'id')) %>%
  split(by = 'variable') %>%
  lapply(transform_cdf) %>%
  rbindlist %>%
  melt(id.vars = setdiff(names(.), c('unmatched', 'matched')), variable.name = 'group', value.name = 'comparison')
pp_dat[, deviation:= abs(get(treat_col) - comparison)]
pp_dat[, D:= max(deviation), by = c('group', 'variable')]
pp_dat[, ks:= pmin(calc_ks(D), 1)]
pp_dat[, variable_ks:= sprintf('%s (D=%s,ks=%s)', variable, round(D, 2), round(ks, 2))]

# TODO: later add autoscaling of plot export sizes based on # of covariates
groups = c('matched', 'unmatched')
names(groups) = groups

pp_plot = lapply(groups, function(g) {
  ggplot(pp_dat[group == g], aes(x = get(treat_col), y = comparison, color = deviation)) +
    geom_point() +
    scale_color_gradient2(low = 'darkgreen', mid = 'yellow',  high = 'red', midpoint = .2) +
    scale_x_continuous(name = treat_col) +
    facet_wrap(~variable_ks) +
    guides(color = FALSE) +
    ggtitle('PP-Plots', sprintf('%s comparison', g)) +
    geom_abline(slope = 1, linetype = 2)
})
ggsave(pp_plot$unmatched, file = export_paths$pp_unmatched, width = 8, height = 5)
ggsave(pp_plot$matched, file = export_paths$pp_matched, width = 8, height = 5)

# Averages Plot
avg_dat = input_dat[, .SD, .SDcols = c('id', 'status', compare_cols)] %>%
  melt(id.vars = c('id', 'status'))
treated_stats = avg_dat[status == treat_col, .(tmean = mean(value), tvar = var(value)), by = 'variable']
avg_dat = merge(avg_dat, treated_stats)

avg_dat = avg_dat[, .(
  value = mean(value), 
  se = sd(value) /  sqrt(.N),
  tstat = calc_tstat(mean(value), tmean, var(value), tvar, .N, n_treated)), 
  by = .(status, variable)] %>%
  unique

avg_dat[status != treat_col, p:= calc_p_value(tstat), by = 'status']

avg_dat = avg_dat %>%
  merge(avg_dat[status == 'unmatched', .(p_u = calc_p_value(tstat), variable)]) %>%
  merge(avg_dat[status == 'matched', .(p_m = calc_p_value(tstat), variable)])
avg_dat[, variable_p:= sprintf('%s (pu<%s, pm<%s)', variable, pmax(p_u, .01), pmax(p_m, .01))]

avg_plot = ggplot(
  data = avg_dat, 
  aes(x = status, y = value, ymin = value - 1.96 * se, ymax = value + 1.96 * se, color = abs(p))) +
  geom_point() +
  geom_errorbar() +
  coord_flip() +
  facet_wrap(~variable_p, scales = 'free_x') +
  scale_color_gradient2(low = 'red', mid = 'green',  high = 'darkgreen', midpoint = .5, na.value = 'black') +
  ggtitle('Comparing Sample Averages') +
  guides(color = FALSE)
ggsave(avg_plot, file = export_paths$sample_averages, width = 8, height = 5)

cat('Plots Exported \n')

