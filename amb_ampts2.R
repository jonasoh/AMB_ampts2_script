# amb_ampts2.R -
#   calculate BMP values from AMPTS II output

# clean slate
rm(list=ls())

# use pacman for handling library loading and installation
if (!require('pacman')) {
  install.packages('pacman')
  library(pacman)
}
p_load(data.table, dplyr, tidyr, biogas, lubridate, stringr, zoo, ggplot2, readxl)

# ask the user for location of log file
# there is no support for directory picker under non-windows platforms
msg <- 'This script processes a directory containing the AMPTS log file converted to XLSX format, and the corresponding experiment setup file (setup.xlsx).'
if (.Platform$OS.type == 'unix') {
  cat(paste0(msg, '\n\n'))
  dir <- readline(prompt = "Enter directory: ")
} else {
  utils::winDialog(type='ok', msg)
  dir <- choose.dir(getwd(), "Choose folder to process")
}
outdir <- paste0(dir, '/Output')
if (!dir.exists(outdir)) dir.create(outdir)

l = list.files(path=dir, pattern='^(report_[^~].*|setup)\\.xlsx$', ignore.case=T, full.names=T)
if(length(l) < 2) {
  stop("Specified directory contains less than two .xlsx files.")
} else if (length(grep('/setup\\.xlsx$', l, ignore.case=T)) != 1) {
  stop("Specified directory doesn't contain the setup.xlsx file.")
}

log_data <- NULL
for(file in l) {
  f <- tolower(basename(file))
  if(f == 'setup.xlsx')
    setup <- as.data.frame(read_xlsx(file))
  else {
    # read the ampts log file, skipping the metadata header
    log <- read_xlsx(file, skip=15)
    #log <- log[,c(1,17:ncol(log))]
    log <- log[,c(1:16)]
    
    # frequency of data collection
    freq <- names(log)[1]
    
    # convert to long format
    log |> pivot_longer(cols=last_col(offset=14):last_col(), names_pattern='^([A-Z][0-9]*)+ .*$', 
                        names_to='Reactor', values_to='vol') -> log

    log_data <- rbind(log_data, log)
  }
}

setDT(log_data)

# measured volumes are 100% CH4
log_data$xCH4 <- 1

# remove NA's in volume data using last observation carried forward
log_data[, vol := na.locf(vol), by=Reactor]
log_data$vol <- as.numeric(log_data$vol)

# XXX: assume three replicates for VS measurements for now
# XXX: check whether this is the correct calculation for stderr
setup$vs.stderr <- setup$`VS STDEV` * setup$`Substrate mass` / sqrt(3)
setup$subst.vs.mass <- setup$`Substrate mass` * setup$`Substrate VS`

# find inoculum name
inoc.desc <- unique(setup$Description[setup$`Substrate mass` == 0 | is.na(setup$`Substrate mass`)])
if(length(inoc.desc) > 1) {
  stop('More than one inoculum control detected.')
} else if (is.na(inoc.desc)) {
  stop('Inoculum control not detected in data.')
}

# the biogas package only uses data frames
log_data <- as.data.frame(log_data)

# summary statistics
bg_means <- summBg(log_data, setup=setup, id.name='Reactor', time.name=freq, vol.name='vol', when='1p3d', 
                   inoc.name=inoc.desc, inoc.m.name='Inoculum mass', norm.name='subst.vs.mass', #norm.se.name='vs.stderr',
                   descrip.name='Description')
bg_means_end <- summBg(log_data, setup=setup, id.name='Reactor', time.name=freq, vol.name='vol', when='end', 
                       inoc.name=inoc.desc, inoc.m.name='Inoculum mass', norm.name='subst.vs.mass', #norm.se.name='vs.stderr',
                       descrip.name='Description')

# rates for plotting
bg_rates <- summBg(log_data, setup=setup, id.name='Reactor', time.name=freq, vol.name='vol', when='1p3d', 
                   inoc.name=inoc.desc, inoc.m.name='Inoculum mass', norm.name='subst.vs.mass', #norm.se.name='vs.stderr',
                   descrip.name='Description', show.obs=T, show.rates=T)

# for plotting raw data
raw_data <- merge(log_data, setup |> select(c(Reactor, Description)), by="Reactor")

# generate plots
daily_prod_plot <- ggplot(bg_rates, aes_string(x=freq, y='rrvCH4', group='Reactor', color='Description')) +
  geom_line(size=1) +
  theme_bw() +
  ylab("Daily methane production compared to cumulative methane production (%)") +
  scale_x_continuous(name = "Time (days)", breaks = seq(0, max(bg_rates[1]), by=2)) +
  scale_y_sqrt(breaks = c(0, 1, 10, 25, 50, 75, 100, 125)) +
  geom_hline(yintercept=1, size=1) +
  theme(legend.position="bottom")

cum_prod_plot <- ggplot(bg_rates, aes_string(x=freq, y='vol', group='Reactor', color='Description')) + 
  geom_line(size=1) +
  theme_bw() +
  ylab(expression(Cumulative~methane~production~(Nml~CH[4]~(g~VS)^-1))) +
  theme(legend.position="bottom")

mean_cum_prod_plot <- ggplot(bg_rates, aes_string(x=freq, y='vol', group='Description', color='Description')) + 
  geom_smooth() +
  theme_bw() +
  ylab(expression(Cumulative~methane~production~(Nml~CH[4]~(g~VS)^-1))) +
  theme(legend.position="bottom")

raw_plot <- ggplot(raw_data, aes_string(x=freq, y='vol', group='Reactor', color='Description')) + 
  geom_line(size=1) +
  ylab('Unadjusted methane production (Nml CH4)') +
  theme_bw() +
  theme(legend.position='bottom')

ggsave(paste0(outdir, '/Daily rates.pdf'), daily_prod_plot, width=20, height=16, units='cm')
ggsave(paste0(outdir, '/Cumulative production.pdf'), cum_prod_plot, width=20, height=16, units='cm')
ggsave(paste0(outdir, '/Cumulative production (means).pdf'), mean_cum_prod_plot, width=20, height=16, units='cm')
ggsave(paste0(outdir, '/Unadjusted production.pdf'), raw_plot, width=20, height=16, units='cm')

# generate tables
write.table(bg_means, paste0(outdir, '/BMP means (1% 3d).tsv'), sep='\t', row.names=F, quote=F)
write.table(bg_means_end, paste0(outdir, '/BMP means (until end).tsv'), sep='\t', row.names=F, quote=F)
write.table(bg_rates, paste0(outdir, '/Per-sample results.tsv'), sep='\t', row.names=F, quote=F)
