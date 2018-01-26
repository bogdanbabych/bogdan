#!/usr/bin/perl
# v01-1
# 
# GET LATEST UPDATES FROM
# http://www.comp.leeds.ac.uk/bogdan/evalMT.html
# 
# NOTE: v01-1 AT THE MOMENT EACH FILE IS TREATED AS A SINGLE TEXT (THEREFORE NO TEXT/SEGMENT MARKUP IS REQUIRED)
# IF YOU EVALUATE A LARGE COLLECTION OF TEXTS, PUT EACH TEXT INTO A DIFFERENT FILE AND COMPUTE AVERAGE SCORES
#
############################################################################################
# WNM (Weighted N-gram model) MT evaluation
# 	authors: Bogdan Babych <bogdan@comp.leeds.ac.uk>, Tony Hartley <a.hartley@leeds.ac.uk>
# 	University of Leeds, Centre for Translation Studies
#
# extends BLEU MT evaluation method (Papineni et al., 2002) 
# (implemented as bleu-1.03.pl (c) IBM Corp., 2001, author Kishore Papineni)
# with statistical salience scores from the vector space model;
# computes N-gram precision and recall scores 
# weighted by S-scores (similar to TF.IDF scores)
#	F-score weighted by S-scores correlates with FLUENCY
# 	Recall weighted by S-scores correlates with ADEQUACY
#	(see Babych and Hartley, 2004b)
#
############################################################################################
# requires: a corpus statistics file in the following format:
# word;FrequencyInCorpus;NumberOfTextsWhereFound
#
# the header of the corpus statistics file:
# <CorpStat>;NumberOfTokensInCorpus;NumberOfTextsInCorpus
#
############################################################################################
# usage: perl wnm-01-1.pl evaluatedText.txt humanRefTranslation.txt corpusStatisticsFile.txt
############################################################################################

# declaring array variables...
# max N-gram size...
$ngrSize = 4;

# hash for CORPUS frequency dictionary read from a corpus statistics file
# $dictCorp{$wd}{"frq"} = abs frq in corpus
# $dictCorp{$wd}{"txt"} = number of texts where found
%dictCorp;
# raw frequencies in the evaluated reference text
%dictFrqRf;

# the dictionary of S-Scores for each word in the evaluated reference text...
# dictSC{$wd} = S-Score for this word in a reference text...
%dictSC;

# main sequence of calls
&openFiles;
&genSC;
&ngr;
&compNgr;


sub openFiles{
	open TF, ">>debug-tmp.txt"; 
	# open TF2, ">>debug2.tmp"; 
	# $OFN = "02_" . $ARGV[0];	open OF, ">$OFN";
	
	$EVf = $ARGV[0]; # evaluated file
	$REf = $ARGV[1]; # reference file
	$COf = $ARGV[2]; # corpus statistics file
	
	open IF1, $EVf; 
	open IF2, $REf; 
	open SF, $COf; 
	
	# reading frequency dictionary file...
	while(<SF>){
		# printf STDERR ".";
		chomp; @flds = split(';', $_);
		if($flds[0] eq "<CorpStat>"){
			# number of words ; number of texts in the ref corpus...
			# (used for computing tf.idf and S-scores)
			$cWd = $flds[1]; $cTxt = $flds[2];
			next;
		}
		
		$dictCorp{$flds[0]}{"frq"} = $flds[1]; # abs frq in corpus
		$dictCorp{$flds[0]}{"txt"} = $flds[2]; # no of text where used
	}
	
	
	# reading eval file and reference file; counting statistics...
	@ev = <IF1>; @rf1 = <IF2>; $cWdEv = 0; $cWdRf = 0; # counts of words in both texts...
	@rf = @rf1; # copy of a reference file
	
	
	
}

sub genSC{  # while(<IF1>){$i++;} printf OF "$i\n";
	
	# collecting statistics on a text: raw frequencies and number of tokens (i, o, o)
	&getTextStat(\@rf1, \%dictFrqRf, \$cWdRf); # the same for reference 
	
	# sets the array of S-Scores : only ref file is relevant, MT output file gets the scores from the reference file
	&compSC(\%dictFrqRf, $cWdRf, \%dictSC);
}



sub ngr{
	

	foreach (@ev){
		if ($_ =~ /doc_ID=\"(\d+)\"/){			#"
			$TxtN = $1 ;
		}
		chomp;	$Ln = $_; &NormaliseText(\$Ln); my @words = split(/\s+/, $Ln); my $numW  = @words;
		# returns a set of N-grams as keys and their counts/their cummulative salience weights as values (i,i,o,o)
		&Str2Ngrams($TxtN, \$Ln, \%NgramsT, \%NgramsTW);
	}
	
	
	foreach (@rf){
		if ($_ =~ /doc_ID=\"(\d+)\"/){			#"
			$TxtN = $1 ;
		}
		chomp;	$Ln = $_; &NormaliseText(\$Ln); my @words = split(/\s+/, $Ln); my $numW  = @words;
		# returns a set of N-grams as keys and their counts/their cummulative salience weights as values (i,i,o,o)
		&Str2Ngrams($TxtN, \$Ln, \%NgramsR, \%NgramsRW);
	}
	

}


sub compNgr{
	foreach $keyT (keys %NgramsT){
		if (exists $NgramsR{$keyT}){
			# intersection of N-grams in MT output and reference: min. number of a matched N-grams
			$Min = &findMin($NgramsR{$keyT},$NgramsT{$keyT});
			$NgramsI{$keyT} = $Min; # intersection set of N-grams / their counts
		}
	}
	
	foreach $keyTW (keys %NgramsTW){
		if (exists $NgramsRW{$keyTW}){
			# intersection of N-grams in MT output and reference: min. weight of a matched N-gram
			$Min = &findMin($NgramsRW{$keyTW},$NgramsTW{$keyTW});
			$NgramsIW{$keyTW} = $Min; # intersection set of N-grams / their weights
		}
	}

	
	$SumT = sumOfValues(\%NgramsT); # sum of N-gram counts in MT output
	$SumR = sumOfValues(\%NgramsR); # sum of N-gram counts in reference
	$SumI = sumOfValues(\%NgramsI); # sum of N-gram counts in their intersection

	$SumTW = sumOfValues(\%NgramsTW); # sum of N-gram weights in MT output
	$SumRW = sumOfValues(\%NgramsRW); # sum of N-gram weights in reference
	$SumIW = sumOfValues(\%NgramsIW); # sum of N-gram weights in their intersection

	
	# computing precision and recall scores for N-gram counts
	if ($SumT != 0){$P = $SumI / $SumT;}else{$P = 0;}
	if ($SumR != 0){$R = $SumI / $SumR;}else{$R = 0;}
	if (($P + $R) != 0){
		$F = (2 * $P * $R) / ($P + $R);
	}else{$F = 0}

	# computing precision and recall scores for N-gram weights
	if ($SumTW != 0){$PW = $SumIW / $SumTW;}else{$PW = 0;}
	if ($SumRW != 0){$RW = $SumIW / $SumRW;}else{$RW = 0;}
	if (($PW + $RW) != 0){
		$FW = (2 * $PW * $RW) / ($PW + $RW);
	}else{$FW = 0}

	# printing the results
	printf "MT-TEXT:$EVf;wnm-RECALL-ADEQUACY:%.4f;wnm-FSCORE-FLUENCY:%.4f\n", $RW, $FW;
	printf ";DETAILS:\n;$EVf;bP:%.4f;bR:%.4f;bF:%.4f\n;$EVf;wP:%.4f;wR:%.4f;wF:%.4f\n\n\n", $P, $R, $F, $PW, $RW, $FW;

	printf TF "$EVf;$PW;$RW;$FW;$R;$P;$F\n";

#	printf OFN "$SumT;$SumR;$SumI;%.4f;%.4f;%.4f;--;$SumTW;$SumRW;$SumIW;%.4f;%.4f;%.4f\n", $P, $R, $F, $PW, $RW, $FW;
#	printf OF "$OFN;%d;%d;%d;%.4f;%.4f;%.4f;--;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f\n", $SumT, $SumR, $SumI, $P, $R, $F, $SumTW, $SumRW, $SumIW, $PW, $RW, $FW;
#	printf "$OFN;%d;%d;%d;%.4f;%.4f;%.4f;--;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f\n", $SumT, $SumR, $SumI, $P, $R, $F, $SumTW, $SumRW, $SumIW, $PW, $RW, $FW;

}





#
# subroutines
# 

sub sumOfValues{
	my ($h2Sum) = @_;
	my $Sum;
	foreach my $key (keys %$h2Sum){
		$Sum += $$h2Sum{$key};
	}
	return $Sum;
}


sub Str2Ngrams {
    my ($TxtN, $strPtr, $hashPtr, $hashPtrW) = @_;
    my @words = split(/\s+/, $$strPtr);
    for ($i = 0; $i < @words; $i++) {
	my $phr;
	for ($j = 0; $j < $ngrSize; $j++) {
	    last unless $i + $j < @words;
	    $WORD = $words[$i+$j];
	    $WEIGHT = 0;
	    if (exists $dictSC{$WORD}){$WEIGHT = $dictSC{$WORD};}
	    
	    $phr .= $words[$i+$j] . " ";
	    $$hashPtr{$phr}++;
	    $$hashPtrW{$phr}+= $WEIGHT;
	    
	}
    }
    return 0 + @words;
}






sub compSC{ # computing S-scores
	my ($dictFrqRf, $cWdRf, $dictSC) = @_;
	# new temporary arrays: in line with 01CorpSt.awk
	my %tmpText; my %tmpCorp; my $tmpNoWdCorp;
	
	# a. merging the doc to corpus and calculating stat for the entire corpus
		# tmpCorp{$wd}{$n}; $n=	
		# 1 of 8 abs frq in a corpus
		# 2 of 8 rel frq in a corpus
		# 3 of 8 in how many texts is present
		# 4 of 8 in how many texts NOT present
		# 5 of 8 proportion of texts where is present
		# 6 of 8 proportion of texts where NOT present
		# 7 of 8 "Stability coef." normalised by RelFrq: [5]/[2]
		# 8 of 8 "Instability coef." normalised by RelFrq: [6]/[2]
	
	# copy %dictCorp to %tmpCorp (empirical counts...)
	foreach $wd (sort keys %dictCorp){
		$tmpCorp{$wd}{1} = $dictCorp{$wd}{"frq"};
		$tmpCorp{$wd}{3} = $dictCorp{$wd}{"txt"};
	}
	
	# add information from attached reference file...
	foreach $wd (sort keys %$dictFrqRf){
		$tmpCorp{$wd}{1} += $$dictFrqRf{$wd};
		$tmpCorp{$wd}{3}++;
	}
	# updating the number of words / texts in a new corpus:
	$tmpNoWdCorp = $cWdRf + $cWd;
	$tmpNoTxtCorp = $cTxt + 1;
	
	foreach $wd (sort keys %tmpCorp){
		if($tmpNoWdCorp != 0) {
			$tmpCorp{$wd}{2} = $tmpCorp{$wd}{1} / $tmpNoWdCorp * 100; 	# 2 of 8
		}	

			$tmpCorp{$wd}{4} = $tmpNoTxtCorp - $tmpCorp{$wd}{3};	# 4 of 8

		if($tmpNoTxtCorp != 0) {
			$tmpCorp{$wd}{5} = $tmpCorp{$wd}{3} / $tmpNoTxtCorp;	# 5 of 8
			$tmpCorp{$wd}{6} = $tmpCorp{$wd}{4} / $tmpNoTxtCorp;	# 6 of 8
		}
		if($tmpCorp{$wd}{2} != 0){
			$tmpCorp{$wd}{7} = $tmpCorp{$wd}{5} / $tmpCorp{$wd}{2};	# 7 of 8
			$tmpCorp{$wd}{8} = $tmpCorp{$wd}{6} / $tmpCorp{$wd}{2}; # 8 of 8
		}
		
	}
	
	# testing:
#	foreach $wd (sort keys %tmpCorp){
#		printf TF2 "\nCorp;$wd;";
#		foreach $fld (sort keys %{$tmpCorp{$wd}}){
#			printf TF2 "$fld;$tmpCorp{$wd}{$fld};";
#		}
#		
#	}
	

	# b. calculating stat for the document
		# tmpText{$wd}{$n}; $n=
		# 1 of 7 abs frq in document 
		# 2 of 7 abs frq in the rest of the corpus
		# 3 of 7 rel frq in document
		# 4 of 7 rel frq in the rest of the corpus
		# 5 of 7 difference: [3]-[4] (Distance of RelFrqs)
		# 6 of 7 "Threshold coef.": arrWordInContCorp[$i,SysID,8]*[5] ("Instability coef." normalised by RelFrq * [5])
		# 7 of 7 "Significance score" for a word = ln([6])

	# copy values to a new array:
	foreach $wd (sort keys %$dictFrqRf){
			$tmpText{$wd}{1} = $$dictFrqRf{$wd};			# 1 of 7
			$tmpText{$wd}{2} = $tmpCorp{$wd}{1} - $$dictFrqRf{$wd};	# 2 of 7 
		
		if($cWdRf != 0){
			$tmpText{$wd}{3} = $tmpText{$wd}{1} / $cWdRf * 100;		# 3 of 7
		}
		if($cWd != 0){
			$tmpText{$wd}{4} = $tmpText{$wd}{2} / $cWd * 100;		# 4 of 7
		}
		
			$tmpText{$wd}{5} = $tmpText{$wd}{3} - $tmpText{$wd}{4};	# 5 of 7
			$tmpText{$wd}{6} = $tmpCorp{$wd}{8} * $tmpText{$wd}{5};	# 6 of 7
		
		if($tmpText{$wd}{6} > 0){
			$tmpText{$wd}{7} = log($tmpText{$wd}{6});		# 7 of 7
		}else{
			$tmpText{$wd}{7} = 0;
		}
					
		# saving the result...			
		$$dictSC{$wd} = $tmpText{$wd}{7}; # the resulting SC value for the ref text...
	
	}
	
	# testing:
#	foreach $wd (sort keys %tmpText){
#		printf TF2 "\nTxt:$wd;";
#		foreach $fld (sort keys %{$tmpText{$wd}}){
#			printf TF2 "$fld:$tmpText{$wd}{$fld};";
#		}
#	}

}


# computes raw frequencies and counts tokens in the evaluated text
sub getTextStat{
	my ($arRef, $dictRef, $cWd) = @_; 
	foreach $Ln (@$arRef){
		chomp($Ln); &NormaliseText(\$Ln); my @words = split(/\s+/, $Ln);

		foreach $wd (@words){
			$$dictRef{$wd}++; # this frequency is now used
			$$cWd++; # counts words in the text;
		
		}
	
	}

}



sub NormaliseText {
    my $strPtr = shift;

    $$strPtr =~ s/<\/?[^>]+>/ /g; # remove information in tags
# text normalisation module: the same as in bleu-1.03.pl   
# language-independent part:
    $$strPtr =~ s/^\s+//;
    $$strPtr =~ s/\n/ /g; # join lines
    $$strPtr =~ s/(\d)\s+(\d)/$1$2/g;  #join digits

# language-dependent part (assuming Western languages):
    $$strPtr =~ tr/[A-Z]/[a-z]/ unless $casesensitive;
    $$strPtr =~ s/([^A-Za-z0-9\-\'\.,\xc0-\xff\x8a\x9a\xaa\xba\x8c-\x8f\x9c-\x9f\xac-\xaf\xbc-\xbf\xa1-\xa5\xb1-\xb5\xa8\xb8])/ $1 /g; 
    # tokenize punctuation (except for alphanumerics, "-", "'", ".", ",")
    # $$strPtr =~ s/([^0-9])([\.,])/$1 $2 /g; # tokenize period and comma unless preceded by a digit
    $$strPtr =~ s/([^0-9])([\.,])/$1 /g;
    $$strPtr =~ s/([\.,])([^0-9])/ $1 $2/g; # tokenize period and comma unless followed by a digit
    $$strPtr =~ s/([0-9])(-)/$1 $2 /g; # tokenize dash when preceded by a digit
    $$strPtr =~ s/[\x22'\-\.:;!\?\(\)\,\_<>\=]/ /g; # remove punctuation
    $$strPtr =~ s/\s+/ /g; # one space only between words
    $$strPtr =~ s/^\s+//;  # no leading space
    $$strPtr =~ s/\s+$//;  # no trailing space
}


sub findMin{
	my ($r1, $r2) = @_; my $Min;
	if($r1 < $r2){$Min = $r1;}
	else {$Min = $r2;}
	
	return $Min;
}

