# Please set working directory to the location of this source file
# using the setwd() command or using Session > Set working directory in RStudio

# Loads required packages
library(tidyverse)

# Reading in and summarizing the results from table 1
# First we can read the results from the output file
tableS1data = read_csv("pnas-tableS1.csv")
tableS1 = tableS1data %>%
  mutate(max_riding_time=max_riding_time,
         benchmark=benchmark) %>%
  group_by(max_riding_time, benchmark) %>%
  select(-c(exp_id, iter)) %>%
  spread(key=exp_name, value=buses) %>%
  mutate(Z_LBH=LBH,
         Z_inf=one,
         Z_Chen=Chen,
         Z_BiRD=many,
         Z_hyb=combined,
         improvement = (min(LBH, Chen)-many)/min(LBH, Chen),
         improvement2 = (min(LBH, Chen)-combined)/min(LBH, Chen),
         LBH=NULL, many=NULL, one=NULL, combined=NULL, Chen=NULL) %>%
  arrange(max_riding_time, benchmark)

# If we want to look at the table
tableS1 %>% View()

# This long table gives a mapping between the experiment_id and the
# experiment parameters. For example, row one tells us that experiment
# 1 corresponds to benchmark RSRB01 with a max riding time of 2700s
# and one scenario per school
tableS1data %>% View()

# To compute the averages in the table (first half)
tableS1 %>%
  subset(max_riding_time==2700) %>%
  summary()

# Reading in and summarizing the results from table 2
# read in the data
tableS2data = read_csv("pnas-tableS2.csv") %>%
  mutate(instance = ((exp_id - 1) %/% 3) + 1)
# again, this table maps the experiment id to the experiment parameters
tableS2data %>% View()

tableS2 = tableS2data %>%
  mutate(instance = ((exp_id - 1) %/% 3) + 1) %>%
  group_by(instance) %>%
  select(-c(exp_id, iter)) %>%
  spread(key=exp_name, value=buses) %>%
  mutate(Z_LBH=LBH,
         Z_inf=one,
         Z_BiRD=many,
         LBH=NULL, many=NULL, one=NULL,
         improvement = (min(LBH, one)-many)/min(LBH, one))

# View the table from the paper
tableS2 %>% View()

# Compute summary statistics
tableS2 %>% summary()
