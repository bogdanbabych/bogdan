# version 0.1 -- alpha!
# preliminary results: future refinements of the algorithm and evaluation results will be published shortly!


# command line arguments
# the script requires 4 files:

# ARGV[1] - tested document(s) = MT (possibly produced by multiple systems)
# ARGV[2] - reference document(s) = Human Translation (possibly produced by different translators)
# ARGV[3] - tested corpus = MT output corpus produced by the tested system(s)
# ARGV[4] - reference corpus = Human Translation corpus; monolingual corpus in the Target Language

# data structures:
# "words in contrasted documents"
# arrWordInCont[wd,DocID,SysID, 1*] - AbsFrq in a Doc
# 				2  - AbsFrq in the rest of the Corp (for a given Doc)
# 				3  - RelFrq in a Doc
# 				4  - RelFrq in the rest of the Corp (for a given Doc)
# 				5  - the difference: [3]-[4] (Distance of RelFrqs)
# 				6  - "Threshold coef.": arrWordInContCorp[$i,SysID,8]*[5]
# 				7  - "Significance score" for a word = ln([6])

# "words in a contrasted corpus"
# arrWordInContCorp[wd,SysID,	1*] - AbsFrq in a corpus
#				2  - RelFrq in a corpus
#				3@  - In how many texts this word is present
#				4  - In how many texts this word is NOT present
#				5  - Proportion of texts where the word is present
#				6  - Proportion of texts where the word is NOT present
#				7  - "Stability coef." normalised by RelFrq: [5]/[2]
#				8  - "Instability coef." normalised by RelFrq: [6]/[2]

# "documents in a contrastive corpus"
# arrDocsInContCorp[DocID,SysID,1*] - How many words in each document
# 				2@  - How many words in the rest of the corpus (for a given Doc)

# "parameters of a contrastive corpus"
# arrContCorp[SysID,	1*] - How many words in a corpus
# 			2@  - How many Docs in a corpus

# arrDocVector[SysID,DocID,Significance score,wd] - all information is in index! (just for sorting and testing)
# arrDocVect[SysID,DocID,wd] = Significance score - main framework for comparison

# arrComWords[SysID1,SysID2,DocID,wd] = ModDiffSignifSc # list of common  words: stores modules of differences in signif.scores
# arrOvgWords[SysID1,SysID2,DocID,wd] = SignifScore # list of the words overgenerated in the first system;
# arrUngWords[SysID1,SysID2,DocID,wd] = SignifScore # list of the words overgenerated in the first system;

# final scores:
# cntComDocs[SysID1,SysID2,DocID] - number of common words wor a given doc
# arrComDocs[SysID1,SysID2,DocID] - cummulative score (sum) for score differences between common words in docs

# cntComSys[SysID1,SysID2] - number of common words for two systems
# arrComSys[SysID1,SysID2] - cummulative score (sum) for score differences between common words for two systems


# cntOvgDocs[SysID1,SysID2,DocID] - number of overgenerated words wor a given doc
# arrOvgDocs[SysID1,SysID2,DocID] - cummulative score (sum) for overgenerated words in docs

# cntOvgSys[SysID1,SysID2] - number of overgenerated words for two systems
# arrOvgSys[SysID1,SysID2] - cummulative score (sum) for overgenerated words for two systems


# cntUngDocs[SysID1,SysID2,DocID] - number of undergenerated words wor a given doc
# arrUngDocs[SysID1,SysID2,DocID] - cummulative score (sum) for undergenerated words in docs

# cntUngSys[SysID1,SysID2] - number of undergenerated words for two systems
# arrUngSys[SysID1,SysID2] - cummulative score (sum) for undergenerated words for two systems

# arrResOvgDocs[SysID1,SysID2,DocID] - sum of overgeneration results for each document
# arrResOvgSys[SysID1,SysID2] - sum of overgeneration results for systems

# arrResUngDocs[SysID1,SysID2,DocID] - sum of undergeneration results for each document
# arrResUngSys[SysID1,SysID2] - sum of undergeneration results for systems



# dev note: 20.10.2002
# reimplementing the original setup first; porting to GAWK; corp/text intrfc later
# implementing separate passes: for collecting corpus statistics; text statistics:
# is this text a part of the corpus or not? >> adding its statistics for the corpus.
# to do everything in the BEGIN block: better controll over input arguments!
# to implement separate loops for txtStatistics & corpStatistics
# in order to be able to process 2 files, put the statistical analysis into f(x)=
# prevent writing the same piece of software twice
# divide prg into function to maintain changes more easily: not in several places


# called by function tokeniseWoTags(Str)
function tokenise(Str){
	gsub("'"," ",Str);
	gsub(/['\|\@\*\\\.\(\)\?\,;:\"\{\}\<\>]/,"",Str);
	Str=tolower(Str);
	return Str
}

# tokenisation without tags
function tokeniseWoTags(Str){
	ResStr = "";
	while(length(Str)>0){
		if(match(Str,/<[^ >][^>]+>/) > 0){
			NTagStr = substr(Str,1,RSTART-1);
			NTagStr = tokenise(NTagStr);
			TagStr = substr(Str,RSTART,RLENGTH);

			ResStr = ResStr NTagStr TagStr;
			Str = substr(Str,RSTART+RLENGTH);
		}
		else {
			Str = tokenise(Str);
			ResStr = ResStr Str;
			Str = ""
		}
	}
	return ResStr
}


function getTagAttrValue(Tag,Attr){
	split(Tag,arrAttr);
	for(i in arrAttr){
		if(match(arrAttr[i],Attr)>0){
			AttrVal = arrAttr[i];
			gsub(Attr,"",AttrVal)
			gsub(/[=\>\<\"]/,"",AttrVal)
			break;
		}
	}
	return AttrVal;
}

function getTagInfo(){ # sets variables DocID and SysID, and removes tags from $0
	# stage 0 tokenisation: tokenise  string without document tags
	$0 = tokeniseWoTags($0);
	# debug print
	printf "%s\n", $0 > "debug.tmp"

	# stage 1 setting text variables
	if(match($0,/<DOC[^>]+doc_ID=\"([A-Za-z0-9]+)\"[^>]*>/) > 0){
		Tag=substr($0,RSTART,RLENGTH);
		DocID = getTagAttrValue(Tag,"doc_ID");
		SysID = getTagAttrValue(Tag,"sys_ID")
		printf "%s\n", DocID > "debug.tmp";
		printf "%s\n", SysID > "debug.tmp";
		# $0 = substr($0,RSTART+RLENGTH)
	}
		
	if(match($0,/<\/DOC>/) > 0){
		# $0 = substr($0,1,RSTART-1)		
	}
	
	# removing tags from $0
	gsub(/<[^ >][^>]+>/," ")
	return $0
} # CLOSING FUNCTION getTagInfo


# sets the matrix of statistics for a given document and the system
# different systems (human translation/mt) are compared later
# unlike in the initial version, SysID is the part of the table - new dimension
# alows to hold simultaneous computations on comparison of statistical models
function getEvalFrqs(FileNm){
	while(getline < FileNm >0){ # THE MAIN READING LOOP
		$0 = getTagInfo();

		for(i=1;i<=NF;i++){
			arrWordInEval[$i,DocID,SysID,1]++; # AbsFrq of a word in Docs in question
			arrDocsInEvalCorp[DocID,SysID,1]++;    # Length of Docs in question
		}

		# OBSOLETE
		# for(i=1;i<=NF;i++){
		#	WordArr[$i][DocID][SysID][1]++
		# }


		# put this after processing the string! >> call a closing f(x)
		# finalising parameters: the same as with the EOF!
		# make the script annotation independent: 
		#	only corpus needs to be segmented into texts!!!
		# if (match($0,/</DOC/)>0)
		# ... routines for processing separate texts
		# goal: produce the score for every text

		# don't forget: REMOVE THE CLOSING DOC TAG from the string!
		# gsub(/<\/DOC>/,"")

	} # CLOSING THE MAIN READING LOOP
} # CLOSING FUNCTION getDocsFrqs(FileNm)



# counting frequencies must be independent for a text and for the corpus!
# recount word frequencies in text, this time -- for the corpus purposes, in a separate array!
function getContFrqs(FileNm){
	while(getline < FileNm >0){ # THE MAIN READING LOOP
		$0 = getTagInfo();

		for(i=1;i<=NF;i++){
			arrWordInCont[$i,DocID,SysID,1]++; # AbsFrq of a word in each Doc in Corp
			arrDocsInContCorp[DocID,SysID,1]++;# Length of each Doc in Corp (how many words)

			arrWordInContCorp[$i,SysID,1]++; # AbsFrq of a word in Corp (for a System)
			arrContCorp[SysID,1]++;          # Length of Corp (how many words) [2] -- (how many docs)
			# length of corpus in words; number of docs in corpus?
			# how to get info : in how many docs the word was found
		}
	} # CLOSING THE MAIN READING LOOP

	# "words in a contrasted corpus,3of8"
	# arrWordInContCorp[$i,SysID,3]
	# in how many texts in the corpus the word wd is found?
	for (combined in arrWordInCont){
		split(combined, sep, SUBSEP);
		wd = sep[1]; DocID = sep[2]; SysID = sep[3]; N = sep[4];
		if(N == 1){
			arrWordInContCorp[wd,SysID,3]++;
		}
	}

	# "parameters of a contrastive corpus,2of2"
	# arrContCorp[SysID,2] 
	# Length of Corp (how many docs)
	for (combined in arrDocsInContCorp){
		split(combined, sep, SUBSEP);
		DocID = sep[1]; SysID = sep[2]; N = sep[3];
		if(N == 1){
			arrContCorp[SysID,2]++; # length of Corp (how many docs)
		}
	}
	
	# "documents in a contrastive corpus,2of2"
	# arrDocsInContCorp[DocID,SysID,1*]
	# the length for the rest of the corpus for a given text:
	for (combined in arrDocsInContCorp){
		split(combined, sep, SUBSEP);
		DocID = sep[1]; SysID = sep[2]; N = sep[3];
		if(N == 1){
			arrDocsInContCorp[DocID,SysID,2] = arrContCorp[SysID,1] - arrDocsInContCorp[DocID,SysID,1];
			# length of the rest of the corpus = total length of the corpus minus length of the text
		}
	}
	
	# "words in a contrasted corpus"
	# arrWordInContCorp[wd,SysID,X]
	for(comb in arrWordInContCorp){
		split(comb, sep, SUBSEP);
		wd = sep[1]; SysID = sep[2]; N = sep[3];
		if(N == 1){
		
			# 2of8": RelFrq in a corpus
			# arrWordInContCorp[$i,SysID,2]
			if(arrContCorp[SysID,1] !=0){
				RelFrq = arrWordInContCorp[wd,SysID,1] / arrContCorp[SysID,1] * 100;
			}else{RelFrq = 0}
			arrWordInContCorp[wd,SysID,2] = RelFrq;
		
			# 4of8 In how many texts this word is NOT present:
			# arrWordInContCorp[$i,SysID,4] = text count [minus] the number of texts where it is present
			arrWordInContCorp[wd,SysID,4] = arrContCorp[SysID,2] - arrWordInContCorp[wd,SysID,3];
			
			# 5of8 Proportion of texts where the word is present:
			# arrWordInContCorp[$i,SysID,5] = number of texts where it is present [div] text count
			if(arrContCorp[SysID,2] !=0){
				arrWordInContCorp[wd,SysID,5] = arrWordInContCorp[wd,SysID,3] / arrContCorp[SysID,2]
			}else{arrWordInContCorp[wd,SysID,5] = 0}
			
			# 6of8 Proportion of texts where the word is NOT present:
			# arrWordInContCorp[$i,SysID,5] = number of texts where it is NOT present [div] text count
			if(arrContCorp[SysID,2] !=0){
				arrWordInContCorp[wd,SysID,6] = arrWordInContCorp[wd,SysID,4] / arrContCorp[SysID,2]
			}else{arrWordInContCorp[wd,SysID,6] = 0}
			
			# 7of8 "Stability coef." normalised by RelFrq: [5]/[2]
			# arrWordInContCorp[wd,SysID,7] = Proportion of texts where present [div] RelFrq
			# 8of8 "Instability coef." normalised by RelFrq: [6]/[2]
			# arrWordInContCorp[wd,SysID,8] = Proportion of texts where NOT present [div] RelFrq
			if(arrWordInContCorp[wd,SysID,2]!=0){
				arrWordInContCorp[wd,SysID,7] = arrWordInContCorp[wd,SysID,5] / arrWordInContCorp[wd,SysID,2];
				arrWordInContCorp[wd,SysID,8] = arrWordInContCorp[wd,SysID,6] / arrWordInContCorp[wd,SysID,2];
			}
			else{
				arrWordInContCorp[wd,SysID,7] = 0;
				arrWordInContCorp[wd,SysID,8] = 0;
			}
		}
	}
	
	# "words in contrasted documents"
	# arrWordInCont[wd,DocID,SysID,X]
	for(comb in arrWordInCont){
		split(comb, sep, SUBSEP);
		wd = sep[1]; DocID = sep[2]; SysID = sep[3]; N = sep[4];
		if(N == 1){
			# 2of7 AbsFrq in the rest of the Corp (for a given Doc)
			# arrWordInCont[wd,DocID,SysID,2] = AbsFrq in corp [minus] AbsFrq in this doc
			arrWordInCont[wd,DocID,SysID,2] = arrWordInContCorp[wd,SysID,1] - arrWordInCont[wd,DocID,SysID,1];
			
			# 3of7 RelFrq in a Doc
			# arrWordInCont[wd,DocID,SysID,3] = AbsFrq in this Doc [div] Length of the Doc
			if(arrDocsInContCorp[DocID,SysID,1] !=0){
				arrWordInCont[wd,DocID,SysID,3] = arrWordInCont[wd,DocID,SysID,1] / arrDocsInContCorp[DocID,SysID,1] * 100; 
			}else{arrWordInCont[wd,DocID,SysID,3] = 0}
			
			# 4of7 RelFrq in the rest of the corpus (for this Doc)
			# arrWordInCont[wd,DocID,SysID,4] = AbsFrq in the rest of the corp [div] Length of the rest of the corp
			if(arrDocsInContCorp[DocID,SysID,2] !=0){
				arrWordInCont[wd,DocID,SysID,4] = arrWordInCont[wd,DocID,SysID,2] / arrDocsInContCorp[DocID,SysID,2] * 100;
			}else{arrWordInCont[wd,DocID,SysID,4] = 0}
			
			# 5of7 the difference: [3]-[4] (Distance of RelFrqs)
			# arrWordInCont[wd,DocID,SysID,5] = RelFrq in a Doc [minus] RelFrq in the rest of the Corp
			arrWordInCont[wd,DocID,SysID,5] = arrWordInCont[wd,DocID,SysID,3] - arrWordInCont[wd,DocID,SysID,4];
			
			# 6of7 "Threshold coef.": arrWordInContCorp[$i,SysID,8]*[5]
			# arrWordInCont[wd,DocID,SysID,6] = "Instability coef." normalised by RelFrq [mult] Distance of RelFrqs
			arrWordInCont[wd,DocID,SysID,6] = arrWordInContCorp[wd,SysID,8] * arrWordInCont[wd,DocID,SysID,5]
			
			# 7of7 "Significance score" for a word = ln([6])
			# arrWordInCont[wd,DocID,SysID,7] = [natural logarithm of] "Threshold coef."
			if(arrWordInCont[wd,DocID,SysID,6] > 0){
				arrWordInCont[wd,DocID,SysID,7] = log(arrWordInCont[wd,DocID,SysID,6]);
			}else{arrWordInCont[wd,DocID,SysID,7] = 0}
			
			
		}
	}
	printf "counted %s;", FileNm > "con";
	
} # CLOSING FUNCTION getCorpFrqs(FileNm)


# selects significant words that are less subject to legitimate variation
# selection criteria: Used more that once in a document; Significance score > 1
function selectWords(){
	for(comb in arrWordInCont){
		split(comb, sep, SUBSEP);
		wd = sep[1]; DocID = sep[2]; SysID = sep[3]; N = sep[4];
		
		if(N == 1){
			AbsFrqInDoc = arrWordInCont[wd,DocID,SysID,1];
			DistRelFrqs = arrWordInCont[wd,DocID,SysID,5];
			SignifScore = arrWordInCont[wd,DocID,SysID,7];
			
			if(AbsFrqInDoc > 1 && DistRelFrqs > 0 &&  SignifScore >= 1){
				arrDocVector[SysID,DocID,SignifScore,wd];
				arrDocVect[SysID,DocID,wd] = SignifScore;
			}
			
		}
	
	}
	printf "words selected;" > "con"

}

function compareVect(SysID1,SysID2){
	for(comb in arrDocVect){
		split(comb,sep,SUBSEP);
		SysID = sep[1]; DocID = sep[2]; wd = sep[3];
		if(SysID == SysID1){# checking overgeneration issues:
			if((SysID2,DocID,wd) in arrDocVect){ # if in both, compare the scores
				SignifScore1 = arrDocVect[SysID1,DocID,wd];
				SignifScore2 = arrDocVect[SysID2,DocID,wd];
				DiffSignifSc = SignifScore1 - SignifScore2;
				ModDiffSignifSc = sqrt(DiffSignifSc ^ 2);
				arrComWords[SysID1,SysID2,DocID,wd] = ModDiffSignifSc;
			}
			else{ # overgenerated words: add to the overgeneration score
				SignifScore1 = arrDocVect[SysID1,DocID,wd];
				arrOvgWords[SysID1,SysID2,DocID,wd] = SignifScore1;
				
			}
		
		}
		
		if(SysID == SysID2){# checking undergeneration issues
			if((SysID1,DocID,wd) in arrDocVect){ # if in both, compare the scores
				SignifScore2 = arrDocVect[SysID2,DocID,wd];
				SignifScore1 = arrDocVect[SysID1,DocID,wd];
				DiffSignifSc = SignifScore2 - SignifScore1;
				ModDiffSignifSc = sqrt(DiffSignifSc ^ 2);
				arrComWords[SysID1,SysID2,DocID,wd] = ModDiffSignifSc;
			}
			else{ # overgenerated words: add to the overgeneration score
				SignifScore2 = arrDocVect[SysID2,DocID,wd];
				arrUngWords[SysID1,SysID2,DocID,wd] = SignifScore2;
				
			}
			
		}
	
	}
	printf "lists compared;" > "con"

}

# dev note 23.10.2003: in future: to put common, overgenerated and undergenerated into one array
function genScores(){ # computes final scores for individual texts and for the systems
	for(comb in arrComWords){ # processing common words
		split(comb,sep,SUBSEP);
		SysID1 = sep[1]; SysID2 = sep[2]; DocID = sep[3]; wd = sep[4];
		cntComDocs[SysID1,SysID2,DocID]++;
		arrComDocs[SysID1,SysID2,DocID] += arrComWords[SysID1,SysID2,DocID,wd];
		
		cntComSys[SysID1,SysID2]++;
		arrComSys[SysID1,SysID2] += arrComWords[SysID1,SysID2,DocID,wd];
	}
	
	for(comb in arrOvgWords){ # procesing overgenerated words
		split(comb,sep,SUBSEP);
		SysID1 = sep[1]; SysID2 = sep[2]; DocID = sep[3]; wd = sep[4];
		cntOvgDocs[SysID1,SysID2,DocID]++;
		arrOvgDocs[SysID1,SysID2,DocID] += arrOvgWords[SysID1,SysID2,DocID,wd];
		
		cntOvgSys[SysID1,SysID2]++;
		arrOvgSys[SysID1,SysID2] += arrOvgWords[SysID1,SysID2,DocID,wd];
	}
	

	for(comb in arrUngWords){ # procesing undergenerated words
		split(comb,sep,SUBSEP);
		SysID1 = sep[1]; SysID2 = sep[2]; DocID = sep[3]; wd = sep[4];
		cntUngDocs[SysID1,SysID2,DocID]++;
		arrUngDocs[SysID1,SysID2,DocID] += arrUngWords[SysID1,SysID2,DocID,wd];
			
		cntUngSys[SysID1,SysID2]++;
		arrUngSys[SysID1,SysID2] += arrUngWords[SysID1,SysID2,DocID,wd];
	}
	
	# putting results together
	for(comb in arrComDocs){ # first -- cummulative common scores
		split(comb,sep,SUBSEP);
		SysID1 = sep[1];SysID2 = sep[2];DocID = sep[3];
		arrResOvgDocs[SysID1,SysID2,DocID] += arrComDocs[SysID1,SysID2,DocID]; # += in case the order changes
		arrResUngDocs[SysID1,SysID2,DocID] += arrComDocs[SysID1,SysID2,DocID];
		arrResOvgSys[SysID1,SysID2] += arrComDocs[SysID1,SysID2,DocID];
		arrResUngSys[SysID1,SysID2] += arrComDocs[SysID1,SysID2,DocID];
		
	}

	for(comb in arrOvgDocs){ # cummulative overgeneration scores
		split(comb,sep,SUBSEP);
		SysID1 = sep[1];SysID2 = sep[2];DocID = sep[3];
		arrResOvgDocs[SysID1,SysID2,DocID] += arrOvgDocs[SysID1,SysID2,DocID];
		# final o-score for each doc
		arrResOvgDocsRel[SysID1,SysID2,DocID] = arrResOvgDocs[SysID1,SysID2,DocID] / (cntComDocs[SysID1,SysID2,DocID] + cntOvgDocs[SysID1,SysID2,DocID])
		
		# counting for the system
		arrResOvgSys[SysID1,SysID2] += arrOvgDocs[SysID1,SysID2,DocID];
		
	}

	for(comb in arrUngDocs){ # cummulative undergeneration scores
		split(comb,sep,SUBSEP);
		SysID1 = sep[1];SysID2 = sep[2];DocID = sep[3];
		arrResUngDocs[SysID1,SysID2,DocID] += arrUngDocs[SysID1,SysID2,DocID];
		# final o-score for each doc
		arrResUngDocsRel[SysID1,SysID2,DocID] = arrResUngDocs[SysID1,SysID2,DocID] / (cntComDocs[SysID1,SysID2,DocID] + cntUngDocs[SysID1,SysID2,DocID]);
		
		# counting for the system
		arrResUngSys[SysID1,SysID2] += arrUngDocs[SysID1,SysID2,DocID];
		
	}
	
	# calculations for the system pair:
	for (comb in arrResOvgSys){ # overgeneration
		split(comb,sep,SUBSEP);
		SysID1 = sep[1]; SysID2 = sep[2];
		# final overgeneration for the system
		arrResOvgSysRelI[SysID1,SysID2] = 1 / (arrResOvgSys[SysID1,SysID2] / (cntComSys[SysID1,SysID2] + cntOvgSys[SysID1,SysID2]));
	}
	for (comb in arrResUngSys){ # undergeneration
		split(comb,sep,SUBSEP);
		SysID1 = sep[1]; SysID2 = sep[2];
		# final overgeneration for the system
		arrResUngSysRelI[SysID1,SysID2] = 1 / (arrResUngSys[SysID1,SysID2] / (cntComSys[SysID1,SysID2] + cntUngSys[SysID1,SysID2]));
		arrResFMSysRelI[SysID1,SysID2] = (2 * arrResOvgSysRelI[SysID1,SysID2] * arrResUngSysRelI[SysID1,SysID2]) / (arrResOvgSysRelI[SysID1,SysID2] + arrResUngSysRelI[SysID1,SysID2]);
	}
	printf "scores generated;" > "con"

}


BEGIN{
# OfnVa = "csVa_" ARGV[1]
# AllWcount = 0
DocID=0
SysID="default.txt"


getContFrqs(ARGV[1]); # return frq table for contrasted corpus;
getContFrqs(ARGV[2]); # return frq table for contrasted corpus;

selectWords();
compareVect(ARGV[1],ARGV[2]);
genScores();



# getEvalFrqs(ARGV[1]); # return frq table for tested documents;


# debug: printing out the DocFrqs tables: WordArr[...] and TextArr
for(combined in arrWordInEval){
	split(combined, sep, SUBSEP)
	if(sep[4]==1){
		printf "%s;%s;%s;%d\n", sep[1], sep[2], sep[3], arrWordInEval[sep[1],sep[2],sep[3],1] > "arrWordInEval1.tmp" 
		# wd, DocID, SysID, AbsFrq of it
	}
}
# debug:
for(combined in arrDocsInEvalCorp){
	split(combined, sep, SUBSEP)
	if(sep[3]==1){
		printf "%s;%s;%d\n", sep[1], sep[2], arrDocsInEvalCorp[sep[1],sep[2],1] > "arrDocsInEvalCorp1.tmp" 
		# DocID, SysID, Length of Doc
	}
}




# debug: printing out the DocFrqs tables: WordArr[...] and TextArr
for(combined in arrWordInCont){
	split(combined, sep, SUBSEP)
	wd = sep[1]; DocID = sep[2]; SysID = sep[3]; N = sep[4];
	if(sep[4]==1){
		printf "%s;%s;%s;%d;%d;%f;%f;%f;%f;%f\n", wd, DocID, SysID, arrWordInCont[wd,DocID,SysID,1], arrWordInCont[wd,DocID,SysID,2], arrWordInCont[wd,DocID,SysID,3], arrWordInCont[wd,DocID,SysID,4], arrWordInCont[wd,DocID,SysID,5], arrWordInCont[wd,DocID,SysID,6], arrWordInCont[wd,DocID,SysID,7] > "arrWordInCont7.tmp" 
		# wd, DocID, SysID, AbsFrq of it
	}
}
# debug:
for(combined in arrDocsInContCorp){
	split(combined, sep, SUBSEP)
	DocID = sep[1]; SysID = sep[2]; N = sep[3]
	if(N == 1){
		printf "%s;%s;%d;%d\n", DocID, SysID, arrDocsInContCorp[DocID,SysID,1], arrDocsInContCorp[DocID,SysID,2] > "arrDocsInContCorp2.tmp" 
		# DocID, SysID, Length of Doc / Rest Corp
	}
}


for(combined in arrWordInContCorp){
	split(combined, sep, SUBSEP)
	wd = sep[1]; SysID = sep[2]; N = sep[3];
	if(N == 1){
		printf "%s;%s;%d;%f;%d;%d;%f;%f;%f;%f\n", wd, SysID, arrWordInContCorp[wd,SysID,1], arrWordInContCorp[wd,SysID,2], arrWordInContCorp[wd,SysID,3], arrWordInContCorp[wd,SysID,4], arrWordInContCorp[wd,SysID,5], arrWordInContCorp[wd,SysID,6], arrWordInContCorp[wd,SysID,7], arrWordInContCorp[wd,SysID,8] > "arrWordInContCorp8.tmp" 
		# wd, SysID, AbsFrq / Number of texts where it was found
	}
}


for(combined in arrContCorp){
	split(combined, sep, SUBSEP)
	SysID = sep[1]; N = sep[2];
	if(N == 1){
		printf "%s;%d;%d\n", SysID, arrContCorp[SysID,1], arrContCorp[SysID,2] > "arrContCorp2.tmp" 
		# SysID, NumberOfWords in corp / Number of texts in corp
	}
}

for(comb in arrDocVector){
	split(comb, sep, SUBSEP);
	SysID = sep[1]; DocID = sep[2];  SignifScore = sep[3]; wd = sep[4];
	printf "%s;%s;%f;%s\n", SysID, DocID, SignifScore, wd > "arrDocVector.tmp"
}


for(comb in arrComWords){
	split(comb, sep, SUBSEP);
	SysID1 = sep[1]; SysID2 = sep[2]; DocID = sep[3]; wd = sep[4];
	printf "%s;%s;%s;%s;%f\n", SysID1, SysID2, DocID, wd, arrComWords[SysID1,SysID2,DocID,wd] > "arrComWords.tmp"
}

for(comb in arrOvgWords){
	split(comb, sep, SUBSEP);
	SysID1 = sep[1]; SysID2 = sep[2]; DocID = sep[3]; wd = sep[4];
	printf "%s;%s;%s;%s;%f\n", SysID1, SysID2, DocID, wd, arrOvgWords[SysID1,SysID2,DocID,wd] > "arrOvgWords.tmp"
}

for(comb in arrUngWords){
	split(comb, sep, SUBSEP);
	SysID1 = sep[1]; SysID2 = sep[2]; DocID = sep[3]; wd = sep[4];
	printf "%s;%s;%s;%s;%f\n", SysID1, SysID2, DocID, wd, arrUngWords[SysID1,SysID2,DocID,wd] > "arrUngWords.tmp"
}



for(comb in arrResOvgSysRelI){
	split(comb, sep, SUBSEP);
	SysID1 = sep[1]; SysID2 = sep[2]; 
	printf "%s;%s;OvgAv:%f\n", SysID1, SysID2, arrResOvgSysRelI[SysID1,SysID2]
}

for(comb in arrResUngSysRelI){
	split(comb, sep, SUBSEP);
	SysID1 = sep[1]; SysID2 = sep[2]; DocID = sep[3]
	printf "%s;%s;UngAv:%f\n", SysID1, SysID2, arrResUngSysRelI[SysID1,SysID2]
}

for(comb in arrResFMSysRelI){
	split(comb, sep, SUBSEP);
	SysID1 = sep[1]; SysID2 = sep[2];
	printf "%s;%s;FMAv:%f\n", SysID1, SysID2, arrResFMSysRelI[SysID1,SysID2]
}



} # CLOSING THE BEGIN BLOCK

