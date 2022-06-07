ccaca <- read.table(file="Gbox_CO_from_HOMER.motif", 
           sep = "\t", fill = TRUE, header = TRUE)

head(ccaca)

ccaca <- t(ccaca[,1:4])

rownames(ccaca) <- NULL
head(ccaca)

write.table(ccaca, file="Gbox_CO.motif", sep = " ", col.names = F,
            row.names = F)
