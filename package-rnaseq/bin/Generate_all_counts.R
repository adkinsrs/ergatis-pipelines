counts_list<-list.files("Counts/", pattern = ".counts", full.names = TRUE)
all_counts_merge<-read.table(counts_list[1], check.names=FALSE, sep="\t", as.is = TRUE, header = F)
count_name1<-basename(counts_list[1])
count_name1<-gsub("\\..*","",count_name1)
names(all_counts_merge)[2]=count_name1

for (i in 2: length(counts_list))
{
  count2<-read.table(counts_list[i], check.names=FALSE, sep="\t", as.is = TRUE, header = F)
  count_name<-basename(counts_list[i])
  count_name<-gsub("\\..*","",count_name)
  names(count2)[2]=count_name
  all_counts_merge<-merge(all_counts_merge, count2, by.x='V1', by.y='V1', all=TRUE)
}
all_counts_merge<-all_counts_merge[-c(1,2,3,4,5), ]
#rownames(all_counts_merge) <- c()
names(all_counts_merge)[1]<-"ID"
write.table(all_counts_merge, file = "all_counts.txt", sep = "\t", row.names = F)

