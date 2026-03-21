names(spine_conflict)[grepl("\\.x$|\\.y$", names(spine_conflict))]


names(spine_ideology)[grepl("\\.x$|\\.y$", names(spine_ideology))]


names(spine_controls)[grepl("\\.x$|\\.y$", names(spine_controls))]


grave_d <- readRDS(here("data", "GRAVE_D_Master.rds"))
names(grave_d)[grepl("\\.x$|\\.y$", names(grave_d))]