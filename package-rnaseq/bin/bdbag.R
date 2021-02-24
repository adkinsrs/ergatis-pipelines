#!/usr/local/packages/r-3.4.0/bin Rscript
library(rmarkdown)
library(knitr)
args = commandArgs(trailingOnly=TRUE)
ergatis=args[1]
output=args[2]
#listf=args[3]
pid=args[3]
#stopifnot(length(args) ==4)
#stopifnot(length(args) ==4)
#print(output)
#listf<-read.table(paste0(dir,"comp.list"))
#comp<-read.table(listf)
workpath<-paste0(ergatis,"/workflow/runtime/")
workpath<-gsub("//","/",workpath)
#workpath
#comp<-comp$V1
#head(comp)
replacepid<-paste0(pid,".*")
#replacepid
mainDir<-paste0(output,"/XML/")
#mainDir
#print("Starting Dir creation")
#args


#######################
#####COPY COMPONENT XML
#####################listf<-read.table(paste0(dir,"comp.list"))
if("cloud" %in% (args)){
comp<-read.table(paste0(output,"comp.list"))
comp<-comp$V1
for( i in comp)
{
  #print(i)
  str1<-i
  str1<-gsub("//","/",str1)
  #print(str1)
  str2<-gsub(workpath,"", str1)
  #print(str2)
  str3<-gsub(replacepid,"",str2)
  #print(str3)
  #mainDir<-output
  dir.create(file.path(mainDir, str3), showWarnings = FALSE)
  Nmaindir<-paste0(mainDir,str3)
  #print("NMaindir")
  #print(Nmaindir)
  dir.create(file.path(Nmaindir,"i1"),showWarnings = FALSE)
  copypath<-file.copy(str1, paste0(Nmaindir,"/","i1/"))
  #print( paste0(Nmaindir,"/","i1/"))
}


#######################
#####COPY i1.xml.gz
#######################
print ("Copying XML files as directed")

dir<-gsub("/XML","", output)
i1list<-read.table(paste0(dir,"i1.list"))
#i1list
output
i1list<-i1list$V1
for(j in i1list)
{
	str1<-j
	str1<-gsub("//","/",str1)
	str2<-gsub(workpath,"", str1)
	str3<-gsub(replacepid,"",str2)
#	print(str3)
	cpdir<-paste0(output,str3,"/i1")
#	print(cpdir)
	#dir.create(file.path(Nmaindir,"i1"),showWarnings = FALSE)
	copypath<-file.copy(str1, cpdir)
}

gall<-read.table(paste0(dir,"g_all.list"))
gall<-gall$V1
replaceg<-paste0(pid,".*/i")
for(k in gall)
{
	str1<-k
	str1<-gsub("//","/",str1)
	if(grepl("mate",str1)==TRUE)
	{
	str2<-gsub(workpath,"", str1)
	#print(str2)
	str3<-gsub(paste0(pid,"_"),"/i1/",str2)
	#print(str3)
	str4<-gsub("i1/g","g",str3);
	#print(str4)
	xmlname<-basename(str4)
	cpto<-gsub(xmlname, "", str4)
	#print(cpto)
	str5<-strsplit(cpto, "/(?=[^,]+$)", perl=TRUE)
        str5<-unlist(str5[[1]])
        len<-length(str5)
        gnum<-str5[len]
        #print(gnum)	
	matedir<-gsub(gnum,"",cpto)
	#print(matedir)
	splitM<-strsplit(matedir, "/(?=[^,]+$)", perl=TRUE)
	splitM<-unlist(splitM[[1]])
	lenM<-length(splitM)
	mateName<-splitM[lenM]
	#print(mateName)
	mateDir<-gsub(mateName,"",matedir)
	#print(mateDir)
	mkMate<-paste0(output,mateDir)
	#print(mkMate)	
	matedir1<-paste0(output,matedir)
	matedir1<-gsub("//","/",matedir1)
	#print(matedir1)
	dir.create(file.path(mkMate,mateName),showWarnings = FALSE)	
	dir.create(file.path(matedir1,gnum),showWarnings = FALSE)
	cpg<-paste0(matedir1,gnum)
	#print(cpg)
	copypath<-file.copy(str1,cpg)
	}
	if(grepl("mate",str1)==FALSE)
	{	
	str2<-gsub(workpath,"", str1)
	str3<-gsub(replaceg,"i",str2)
	#print(str3)
	xmlname<-basename(str3)
	cpto<-gsub(xmlname, "", str3)
	fullto<-paste0(mainDir,cpto)
	fulltoC<-gsub("//","/",fullto)
	fullto<-gsub("/g.*", "",fulltoC)
	#print(fullto)
	str4<-strsplit(cpto, "/(?=[^,]+$)", perl=TRUE)
	str4<-unlist(str4[[1]])
	len<-length(str4)
	gnum<-str4[len]
	#print(gnum)
	dir.create(file.path(fullto, gnum), showWarnings = FALSE)
	copypath<-file.copy(str1, fulltoC)
	#print(cpto)
	}
}
}

####SAM and BAM Files

if("bam" %in% (args))
{

print("Bam files being copied")

fpath<-gsub("/XML","",output)
print("This is what fpath variable has")
print(fpath)
dir.create(file.path(fpath, "Files"), showWarnings = FALSE)
fworking<-paste0(fpath,"Files/")
print(fworking)
bam_path_name<-paste0(fpath,"/sorted_by_name.bam.list")
bam_path_name<-gsub("//","/",bam_path_name)
print(bam_path_name)
bam<-read.table(bam_path_name)
bam<-bam$V1
#testprint<-paste0(fpath,"/sorted_by_position.bam.list")
#print(bam)
bam_position_name<-paste0(fpath,"/sorted_by_position.bam.list")
bam_position_name<-gsub("//","/",bam_position_name)
positionbam<-read.table(bam_position_name)
positionbam<-positionbam$V1

dir.create(file.path(fworking, "sorted_by_name"), showWarnings = FALSE)
dir.create(file.path(fworking, "sorted_by_position"), showWarnings = FALSE)
bamdir<- paste0(fworking,"sorted_by_name")
posdir<-paste0(fworking,"sorted_by_position")

bworkpath<-paste0(ergatis,"output_repository")
bworkpath<-gsub("//","/",bworkpath)
#bworkpath

for(l in bam)
{
print("Starting with sorted by name")
str1<-l
str1<-gsub("//","/",str1)
str2<-gsub(paste0(pid,".*/g"), "g", str1)
str2<-gsub(bworkpath,"",str2)
str3<-gsub("/samtools_file_convert/","/",str2)
fname<-basename(str3)
gnum<-gsub(fname,"",str3)
gnum<-basename(gnum)
dir.create(file.path(bamdir, gnum), showWarnings = FALSE)
bampath<-paste0(bamdir,"/", gnum)
copypath<-file.copy(l, bampath)

}

for(m in positionbam)
{
str1<-m
str1<-gsub("//","/",str1)
str2<-gsub(paste0(pid,".*/g"), "g", str1)
str2<-gsub(bworkpath,"",str2)
str3<-gsub("/samtools_file_convert/","/",str2)
fname<-basename(str3)
gnum<-gsub(fname,"",str3)
gnum<-basename(gnum)
dir.create(file.path(posdir, gnum), showWarnings = FALSE)
pospath<-paste0(posdir,"/", gnum)
#print(pospath)
copypath<-file.copy(m, pospath)

}

}

if("sam" %in% (args))
{
print("SAM files being copied");
fpath<-gsub("/XML","",output)
fpath
dir.create(file.path(fpath, "Files"), showWarnings = FALSE)
fworking<-paste0(fpath,"Files/")
fworking
sam<-read.table("sorted_by_name.sam.list")
sam<-sam$V1
head(sam)
dir.create(file.path(fworking, "sorted_by_name"), showWarnings = FALSE)
samdir<- paste0(fworking,"sorted_by_name")
bworkpath<-paste0(ergatis,"output_repository")

for(n in sam)
{
str1<-n
str1<-gsub("//","/",str1)
#print(str1)
str2<-gsub(paste0(pid,".*/g"), "g", str1)
str2<-gsub(bworkpath,"",str2)
str3<-gsub("/samtools_file_convert/","/",str2)
fname<-basename(str3)
gnum<-gsub(fname,"",str3)
gnum<-basename(gnum)
dir.create(file.path(samdir, gnum), showWarnings = FALSE)
sampath<-paste0(samdir,"/", gnum)
#print(sampath)
copypath<-file.copy(n, sampath)
#print(gnum)
#print(str3)

}


}
