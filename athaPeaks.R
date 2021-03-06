### Peak visualizer for Arabidopsis thaliana

##Authors: 
# Pedro de los Reyes Rodríguez pedro.reyes@ibvf.csic.es
# Francisco José Romero Campero fran@us.es
# Ana Belén Romero Losada arlosada@us.es

## This script allows you to visualize peaks and dense binding profiles of TFs to the genome.
## This Peak visualizer is a tool developed from an ATTRACTOR (https://github.com/fran-romero-campero/ATTRACTOR)
## and ALGAEFUN (https://github.com/fran-romero-campero/AlgaeFUN) module.  

## Load libraries
library(ChIPpeakAnno)
library(rtracklayer)
library(TxDb.Athaliana.BioMart.plantsmart28)
library(Biostrings)
library(seqinr)
library(org.At.tair.db)


## Load and extract Arabidopsis thaliana annotation regarding genes, exons and cds 
txdb <- TxDb.Athaliana.BioMart.plantsmart28
genes.data <- subset(genes(txdb), seqnames %in% c("1","2","3","4","5")) ## only nuclear genes are considered
genes.data <- as.data.frame(genes.data)
exons.data <- as.data.frame(exons(txdb))
cds.data <- as.data.frame(cds(txdb))

## Load all genes
my.key <- keys(org.At.tair.db, keytype="ENTREZID")
my.col <- c("SYMBOL", "TAIR")
alias2symbol.table <- AnnotationDbi::select(org.At.tair.db, keys=my.key, columns=my.col, keytype="ENTREZID")
alias <- alias2symbol.table$SYMBOL
names(alias) <- alias2symbol.table$TAIR
alias[is.na(alias)] <- "" 
genes <- paste(names(alias), alias, sep=" - ")

## Color vectors
line.colors <- c("blue","red", "darkgreen","black","#663300","#99003d","#b3b300","#4d0039","#4d2600","#006666","#000066","#003300","#333300","#660066")
area.colors <- c("skyblue","salmon", "lightgreen","lightgrey","#ffcc99","#ff99c2","#ffffb3","#ffe6f9","#ffe6cc","#80ffff","#b3b3ff","#99ff99","#e6e600","#ffb3ff")

## Load chromosome sequences
chr1 <- getSequence(read.fasta(file = "data/athaliana_genome/chr1.fa",seqtype = "AA"))[[1]]
chr2 <- getSequence(read.fasta(file = "data/athaliana_genome/chr2.fa",seqtype = "AA"))[[1]]
chr3 <- getSequence(read.fasta(file = "data/athaliana_genome/chr3.fa",seqtype = "AA"))[[1]]
chr4 <- getSequence(read.fasta(file = "data/athaliana_genome/chr4.fa",seqtype = "AA"))[[1]]
chr5 <- getSequence(read.fasta(file = "data/athaliana_genome/chr5.fa",seqtype = "AA"))[[1]]

## Function to compute the reverse complement
reverse.complement <- function(dna.sequence)
{
  return(c2s(comp(rev(s2c(dna.sequence)),forceToLower = FALSE)))
}

## Load Position Weight Matrices
## Open file connection
con <- file("data/jaspar_motifs/pfm_plants_20180911_Pedro.txt",open = "r")

## Empty list for storing PWM
pwms <- read.table(file="data/jaspar_motifs/pfm_plants_20180911_Pedro.txt", sep = "\t")
motifs.pwm <- vector(mode="list",length = nrow(pwms)/5)
motif.ids <- vector(mode="character",length= nrow(pwms)/5)
motif.names <- vector(mode="character",length= nrow(pwms)/5)

## Load all PWMs
for(j in 1:(nrow(pwms)/5))
{
  ## First line contains motif id and name
  first.line <- readLines(con,1)
  
  motif.ids[j] <- strsplit(first.line,split=" ")[[1]][1]
  motif.names[j] <- strsplit(first.line,split=" ")[[1]][2]
  
  ## Next four line contains probabilites for each nucleotide
  a.row <- as.numeric(strsplit(readLines(con,1),split="( )+")[[1]])
  c.row <- as.numeric(strsplit(readLines(con,1),split="( )+")[[1]])
  g.row <- as.numeric(strsplit(readLines(con,1),split="( )+")[[1]])
  t.row <- as.numeric(strsplit(readLines(con,1),split="( )+")[[1]])
  
  ## Construct PWM
  motif.pwm <- matrix(nrow = 4,ncol=length(a.row))
  
  motif.pwm[1,] <- a.row
  motif.pwm[2,] <- c.row 
  motif.pwm[3,] <- g.row
  motif.pwm[4,] <- t.row
  
  rownames(motif.pwm) <- c("A","C","G","T")
  
  motifs.pwm[[j]] <- prop.table(motif.pwm,2)
}

## Close file connection
close(con)

## Naming list with PWM
names(motifs.pwm) <- motif.names
names(motif.ids) <- motif.names

bigwig.files <- list.files(path="data/bw_files/")
bw.names <- sapply(bigwig.files, strsplit, split=".bw")
names(bigwig.files) <- bw.names

bed.files <- list.files("data/bed_files/")
bed.names <- sapply(bed.files, strsplit, split="_peaks.narrowPeak")
names(bed.files) <- bed.names

## TF binding sites colors and symbol shapes
symbol.shapes <- c(17, 18, 19, 15)
symbol.color <- c("blue", "red", "darkgreen", "magenta")

## Variables to modify
promoter.length <- 2000
fiveprime.length <- 500
min.score.pwm <- 95
target.gene <- "AT5G24770"
common.name <- "VSP2"
# Here you select the TFs whose binding will be plotted. This names have to
# match with the names of the files (bed.files and bigwig.files)
names.tfs <- c("TF1","input_TF1") 

# Here you select the DNA elements to be searched in the binding sites
selected.motifs <- c("G-box","CCACA-box",
                     "CORE1", "CORE2")

image.height <- 4 #image height in inches
image.width <- 8 #image width in inches

## Specifying number of bed files and number of peak files. Sometimes
## we could want to to include experiments without bigwig file or
## bed file. For example, those that come from a ChIP-on-chip experiment
## and it doesn't have dense file (bw). And if we include the input
## of a chip experiment we have to plot its binding profile (bw file)
## but it does not have bed file. 

beds.to.use <- bed.files[names.tfs]
number.beds <- length(beds.to.use[!is.na(beds.to.use)])

bw.to.use <- bigwig.files[names.tfs]
number.bw <- length(bw.to.use[!is.na(bw.to.use)])


## Extract target gene annotation 
gene.name <- target.gene

target.gene.body <- genes.data[gene.name,]
target.gene.chr <- as.character(target.gene.body$seqnames)
target.gene.start <- target.gene.body$start
target.gene.end <- target.gene.body$end

target.gene.strand <- as.character(target.gene.body$strand)

## Extract cds annotation
cds.data.target.gene <- subset(cds.data, seqnames == target.gene.chr & (start >= target.gene.start & end <= target.gene.end))

## Extract exons annotation
exons.data.target.gene <- subset(exons.data, seqnames == target.gene.chr & (start >= target.gene.start & end <= target.gene.end))

## Determine the genome range to plot including promoter, gene body and 5' UTR
## This depends on whether the gene is on the forward or reverse strand
range.to.plot <- target.gene.body

if(target.gene.strand == "+")
{
  range.to.plot$start <- range.to.plot$start - promoter.length
  range.to.plot$end <- range.to.plot$end + fiveprime.length
} else if (target.gene.strand == "-")
{
  range.to.plot$end <- range.to.plot$end + promoter.length
  range.to.plot$start <- range.to.plot$start - fiveprime.length
}

## Compute the length of the genome range to represent
current.length <- range.to.plot$end - range.to.plot$start

## Determine upper limit of the graph
number.tfs <- length(names.tfs)
upper.lim <- 25 * number.tfs

## Draw DNA strand
gene.height <- -25
cord.x <- 1:current.length


png(paste0(target.gene,"_", common.name, ".png"), height = image.height, width = image.width,
     units = 'in', res=300)

plot(cord.x, rep(gene.height,length(cord.x)),type="l",col="black",lwd=3,ylab="",
     cex.lab=2,axes=FALSE,xlab="",main="",cex.main=2,
     ylim=c(-30,upper.lim),xlim=c(-3000,max(cord.x)))

## Extract exons for target gene
exons.data.target.gene <- subset(exons.data, seqnames == target.gene.chr & (start >= target.gene.start & end <= target.gene.end))

## Transform exon coordinates to current range
min.pos <- min(exons.data.target.gene$start)

if(target.gene.strand == "+")
{
  exons.data.target.gene$start <- exons.data.target.gene$start - min.pos + promoter.length
  exons.data.target.gene$end <- exons.data.target.gene$end - min.pos + promoter.length
} else if(target.gene.strand == "-")
{
  exons.data.target.gene$start <- exons.data.target.gene$start - min.pos + fiveprime.length
  exons.data.target.gene$end <- exons.data.target.gene$end - min.pos + fiveprime.length
}

## Represent exons
exon.width <- 2
for(i in 1:nrow(exons.data.target.gene))
{
  # Determine start/end for each exon
  current.exon.start <- exons.data.target.gene$start[i]
  current.exon.end <- exons.data.target.gene$end[i]
  
  ## Determine coordinates for each exon polygon and represent it
  exon.x <- c(current.exon.start,current.exon.end,current.exon.end,current.exon.start)
  exon.y <- c(gene.height + exon.width, gene.height + exon.width, gene.height - exon.width, gene.height - exon.width)
  
  polygon(x = exon.x, y = exon.y, col = "gray28",border = "gray28")
}

## Extract cds for target gene
cds.data.target.gene <- subset(cds.data, seqnames == target.gene.chr & (start >= target.gene.start & end <= target.gene.end))

## Transform cds coordinates to current range
if(target.gene.strand == "+")
{
  cds.data.target.gene$start <- cds.data.target.gene$start - min.pos + promoter.length
  cds.data.target.gene$end <- cds.data.target.gene$end - min.pos + promoter.length
} else if (target.gene.strand == "-")
{
  cds.data.target.gene$start <- cds.data.target.gene$start - min.pos + fiveprime.length
  cds.data.target.gene$end <- cds.data.target.gene$end - min.pos + fiveprime.length
}

cds.width <- 3
for(i in 1:nrow(cds.data.target.gene))
{
  # Determine current cds start/end
  current.cds.start <- cds.data.target.gene$start[i]
  current.cds.end <- cds.data.target.gene$end[i]
  
  # Determine curret cds coordinates for the polygon and represent it
  cds.x <- c(current.cds.start,current.cds.end,current.cds.end,current.cds.start)
  cds.y <- c(gene.height + cds.width, gene.height + cds.width, gene.height - cds.width, gene.height - cds.width)
  
  polygon(x = cds.x, y = cds.y, col = "gray28",border = "gray28")
}

## Draw arrow to represent transcription direction 
if(target.gene.strand == "+")
{
  lines(c(promoter.length,promoter.length,promoter.length+100),y=c(gene.height,gene.height+5,gene.height+5),lwd=3)
  lines(c(promoter.length+50,promoter.length+100),y=c(gene.height+6,gene.height+5),lwd=3)
  lines(c(promoter.length+50,promoter.length+100),y=c(gene.height+4,gene.height+5),lwd=3)
} else if (target.gene.strand == "-")
{
  lines(c(current.length - promoter.length, current.length - promoter.length, current.length - promoter.length-100),y=c(gene.height,gene.height+5,gene.height+5),lwd=3)
  lines(c(current.length - promoter.length-50, current.length - promoter.length - 100),y=c(gene.height + 6, gene.height + 5),lwd=3)
  lines(c(current.length - promoter.length-50, current.length - promoter.length - 100),y=c(gene.height + 4, gene.height + 5),lwd=3)
}

## Draw promoter range
if(target.gene.strand == "+")
{
  axis(side = 1,labels = c(- promoter.length, - promoter.length / 2,"TSS"),at = c(1,promoter.length/2,promoter.length),lwd=2,cex=1.5,las=2,cex=2)
} else if(target.gene.strand == "-")
{
  axis(side = 1,labels = c("TSS",- promoter.length / 2,- promoter.length),at = c(current.length-promoter.length,current.length-promoter.length/2, current.length),lwd=2,cex=1.5,las=2,cex=2)
}

## Get the selected files
selected.bigwig.files <- bigwig.files[names.tfs][c(1:number.bw)]
selected.bed.files <- bed.files[names.tfs][c(1:number.beds)]

## Since ChIPpeakAnno needs more than one region to plot our region
## is duplicated 
regions.plot <- GRanges(rbind(range.to.plot,range.to.plot))

## Import signal from the bigwig files
cvglists <- sapply(paste0("data/bw_files/",selected.bigwig.files), import, 
                   format="BigWig", 
                   which=regions.plot, 
                   as="RleList")

names(cvglists) <- names.tfs[c(1:number.bw)] 

## Compute signal in the region to plot
chip.signal <- featureAlignedSignal(cvglists, regions.plot, 
                                    upstream=ceiling(current.length/2), 
                                    downstream=ceiling(current.length/2),
                                    n.tile=current.length) 



## Compute mean signal 
chip.signal.means <- matrix(nrow=number.tfs, ncol=ncol(chip.signal[[1]]))

for(i in 1:(number.bw))  
{
  if(target.gene.strand == "+")
  {
    chip.signal.means[i, ] <- colMeans(chip.signal[[i]],na.rm = TRUE)
  } else if (target.gene.strand == "-")
  {
    chip.signal.means[i, ] <- rev(colMeans(chip.signal[[i]],na.rm = TRUE))
  }
}

## Draw peak regions for each TF and determing TF binding sequences

selected.motifs.pwm <- motifs.pwm[selected.motifs]
selected.motif.names <- names(selected.motifs.pwm)
selected.motif.ids <- motif.ids[selected.motif.names]

## Initialize data frame containing TF binding sequences in the peak regions
df.hits <- data.frame(0,0,"","","")
colnames(df.hits) <- c("tf_number","position","id","name","seq")

## Width of the rectangule representing the peak region
peak.width <- 1
for(i in 1:number.beds)
{
  ## Extract bed file name 1 and read it
  current.bed.file <- paste0("data/bed_files/", selected.bed.files[i])
  current.peaks <- read.table(file=current.bed.file,header = F, as.is = T)
  peak.coordinates <- subset(current.peaks, V1 == range.to.plot$seqnames & V2 >= range.to.plot$start & V3 <= range.to.plot$end) 
  current.peaks.to.plot <- peak.coordinates[,2:3]
  
  ## Transform coordinates 
  current.peaks.to.plot <- current.peaks.to.plot - range.to.plot$start
  
  ## Check if there are peaks for the target gene
  if(nrow(current.peaks.to.plot) > 0)
  {
    ## Normalization
    chip.signal.means[i, ] <- 10 * chip.signal.means[i, ] / max(chip.signal.means[i, ])
    
    #motifs.in.peaks <- vector(mode="list", length=nrow(current.peaks.to.plot))
    for(j in 1:nrow(current.peaks.to.plot))
    {
      ## Extract start and end point of each peak region
      current.peak.start <- current.peaks.to.plot[j,1]
      current.peak.end <- current.peaks.to.plot[j,2]
      
      ## Computer coordinates for polygon and draw it
      peak.x <- c(current.peak.start,current.peak.end,
                  current.peak.end,current.peak.start)
      peak.y <- c(25*(i - 1) - 5 + peak.width, 25*(i - 1) - 5 + peak.width, 
                  25*(i - 1) - 5 - peak.width, 25*(i - 1) - 5 - peak.width)  
      
      polygon(x = peak.x, y = peak.y, col = area.colors[i], border = line.colors[i],lwd=2)
      
      ## Identify TF binding DNA motifs 
      peak.chr <- peak.coordinates[j, 1]
      peak.start <- peak.coordinates[j, 2]
      peak.end <- peak.coordinates[j, 3]
      
      ## Extract peak sequence
      if(peak.chr == "1")
      {
        peak.sequence <- c2s(chr1[peak.start:peak.end])
      } else if(peak.chr == "2")
      {
        peak.sequence <- c2s(chr2[peak.start:peak.end])
      } else if(peak.chr == "3")
      {
        peak.sequence <- c2s(chr3[peak.start:peak.end])
      } else if(peak.chr == "4")
      {
        peak.sequence <- c2s(chr4[peak.start:peak.end])
      } else if(peak.chr == "5")
      {
        peak.sequence <- c2s(chr5[peak.start:peak.end])
      }
      
      peak.rev.comp.sequence <- reverse.complement(peak.sequence)
      
      for(k in 1:length(selected.motifs.pwm))
      {
        motif.pwm <- selected.motifs.pwm[[k]]
        
        hits.fw <- matchPWM(motif.pwm, peak.sequence, 
                            min.score = paste0(min.score.pwm,"%"))
        hits.fw.seqs <- as.data.frame(hits.fw)[["seq"]]
        hits.fw <- as(hits.fw, "IRanges")
        hits.fw.start <- start(hits.fw)
        hits.fw.end <- end(hits.fw)
        
        if(length(hits.fw.start) > 0)
        {
          df.hits.fw <- data.frame(rep(i,length(hits.fw.start)),
                                   ((hits.fw.start+hits.fw.end)/2) + current.peak.start,
                                   rep(selected.motif.ids[k],length(hits.fw.start)),
                                   rep(selected.motif.names[k],length(hits.fw.start)),
                                   hits.fw.seqs)
          colnames(df.hits.fw)  <- c("tf_number","position","id","name","seq")
          df.hits <- rbind(df.hits,df.hits.fw)
        }
        
        hits.rev <- matchPWM(motif.pwm, peak.rev.comp.sequence, 
                             min.score = paste0(min.score.pwm,"%"))
        hits.rev.seqs <- as.data.frame(hits.rev)[["seq"]]
        hits.rev.seqs <- sapply(hits.rev.seqs,reverse.complement)
        names(hits.rev.seqs) <- NULL
        
        hits.rev <- as(hits.rev, "IRanges")
        hits.rev.start <- nchar(peak.sequence) - end(hits.rev) + 1
        hits.rev.end <- nchar(peak.sequence) - start(hits.rev) + 1
        
        if(length(hits.rev.start) > 0)
        {
          df.hits.rev <- data.frame(rep(i,length(hits.rev.start)),
                                    ((hits.rev.start+hits.rev.end)/2) + current.peak.start,
                                    rep(selected.motif.ids[k],length(hits.rev.start)),
                                    rep(selected.motif.names[k],length(hits.rev.start)),
                                    hits.rev.seqs)
          colnames(df.hits.rev)  <- c("tf_number","position","id","name","seq")
          df.hits <- rbind(df.hits,df.hits.rev)
        }
        
      }
      
    }
  }
}

## Remove first line of the data frame added just for technical reason
df.hits <- df.hits[-1,]

## Draw TF binding sites
detected.tfbs <- unique(as.vector(df.hits$name))

number.of.shapes <- ceiling(length(detected.tfbs) / length(symbol.color))

necessary.shapes <- rep(symbol.shapes[1:number.of.shapes],each = length(detected.tfbs)/number.of.shapes)
necessary.colors <- rep(symbol.color,number.of.shapes)

if(length(detected.tfbs) > 0)
{
  for(i in 1:length(detected.tfbs))
  {
    current.tfbs <- detected.tfbs[i]
    current.shape <- necessary.shapes[i]
    current.color <- necessary.colors[i]
    
    positions <- subset(df.hits, name == current.tfbs)
    
    for(j in 1:nrow(positions))
    {
      tf.to.draw <- positions$tf_number[j]
      pos.to.draw <- positions$position[j]
      
      points(x = pos.to.draw, y = 25*(tf.to.draw - 1) - 5 - 5*peak.width,
             pch = current.shape, col = current.color, cex = 1)
    }
  }
  
  ## Add legend for TFBS
  legend.step <- 10
  for(i in 1:length(detected.tfbs))
  {
    points(x = -3000, y = upper.lim - (i-1)*legend.step, 
           pch=necessary.shapes[i], col = necessary.colors[i],cex = 1)
    
    
    current.seq <- as.character(subset(df.hits,name == detected.tfbs[i])[["seq"]][[1]])
    current.label <- paste(c(detected.tfbs[i], "  -  ", current.seq ),collapse="")
    
    text(x = -2900, y = upper.lim - (i-1)*legend.step, labels = current.label,
         adj = 0,cex = 0.7)
  }
}

## Draw profiles for TF binding
# for(i in 1:number.tfs)
for(i in 1:number.bw) 
{
  ## Compute base line for current TF
  current.base.line <- 25 * (i - 1)
  
  ## Represent signal from the current TF
  lines(chip.signal.means[i,]+current.base.line,type="l",col=line.colors[i],lwd=3)
  
  ## Determine polygon coordinates and represent it
  cord.y <- c(current.base.line,chip.signal.means[i,]+current.base.line,current.base.line)
  cord.x <- 1:length(cord.y)
  
  polygon(cord.x,cord.y,col=area.colors[i])
  
}

## Add legend for each TF
for (i in 1:number.tfs)
{
  text(x = -50,y = 25*(i-1) + 12,labels = names.tfs[i],adj = 1,col = line.colors[i],font = 2)
  
}

dev.off()




