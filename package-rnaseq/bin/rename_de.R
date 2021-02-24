#!/usr/local/packages/r-3.4.0/bin Rscript
#Rename R script for DE Files.

args = commandArgs(trailingOnly=TRUE)
arg1<-args
#arg2=args[2]
#arg1[1]
outi<-length(args)
#outi
#arg1[outi]<-NULL
#typeof(arg1)
arg2<-arg1[outi]
arg1=arg1[1:outi-1]
#arg2
#arg2

#stopifnot(length(args) ==4)
#stopifnot(length(args) ==2)

CDeFiles<-list.files(arg1, pattern = "all_counts_noZero_normalized", full.names = TRUE)
#CDeFiles

RenameFiles<-list.files(arg1, pattern = ".de_genes.txt", full.names = TRUE)
#RenameFiles

names<-basename(RenameFiles)
names<-gsub("\\..*",".counts",names)

#names

for(i in 1:length(CDeFiles))
{
file.copy(from=CDeFiles[i], to=arg2)
file.rename(from=file.path(arg2, "all_counts_noZero_normalized"), to=file.path(arg2, names[i]))
#print("Following files renames and copied")
#print(names[i])
}



