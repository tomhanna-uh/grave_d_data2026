library(here)
library(tidygraph)

dyadic_target_active <- read_csv2(here("source_data","nags","dyadic_target_supporter_active.csv"))


mon_sup_act <- read_csv2(here("source_data","nags","mon_sup_act.csv"))

mon_reb_act_sup <- read_csv2(here("source_data","nags","mon_reb_act_supp.csv"))

summary(mon_reb_act_sup)

colnames(mon_reb_act_sup)
colnames(mon_sup_act)
colnames(dyadic_target_active)


custom <- read_csv2(here("source_data","nags","custom.csv"))
colnames(custom)



triadic <- read_csv(here("source_data","nags","triadic_data.csv"))
colnames(triadic)

# Use read_delim() with a specific locale
triadic <- read_delim(
        file = here("source_data","nags","triadic_data.csv"),
        delim = ";",
        locale = locale(decimal_mark = ",", grouping_mark = ".")
)

