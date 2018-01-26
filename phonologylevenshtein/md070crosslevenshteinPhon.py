'''
Created on Dec 3, 2013

@author: bogdan
requires python3
'''
import os, sys, re
from collections import defaultdict
import math
import md060graphonoLev


class clCrossLevenshtein(object):
    '''
    classdocs
    '''


    def __init__(self, SFInA, SFInB, SLangIDa, SLangIDb):
        '''
        Constructor
        '''
        FDebug = open('md050crosslevenshtein.debug', 'w')
        LWordsA = self.readWordList(SFInA)
        LWordsB = self.readWordList(SFInB) # graphonological object with phonological features over graphemes
        OGraphonolev = md060graphonoLev.clGraphonolev()

        
        LDistances = []
        ICounter = 0
        ICounterRec = 0
        for (SWordA, SPoSA, IFrqA) in LWordsA:
            LenA = len(SWordA)
            try:
                LogFrqA = math.log(IFrqA)
            except:
                LogFrqA = 0
            LCognates = []
            LCognates1 = []
            ICounter += 1
            if ICounter % 5 == 0:
                sys.stderr.write(SWordA + ' ' + str(ICounter) + '\n')

            
            ''' 
            # changed:
            for (SWordB, SPoSB, IFrqB) in LWordsB:
                LenB = len(SWordB)
                LenAve = (LenA + LenB) / 2
            
                ILev = self.computeLevenshtein(SWordA, SWordB)
                ALevNorm = ILev/LenAve
                if ALevNorm <= 0.30:
                    LCognates.append((ALevNorm, ILev, SWordB, SPoSB, IFrqB))
            '''
            for (SWordB, SPoSB, IFrqB) in LWordsB:
                (Lev0, Lev1, Lev0Norm, Lev1Norm) = OGraphonolev.computeLevenshtein(SWordA, SWordB, SLangIDa, SLangIDb)
                if Lev0Norm <= 0.36:
                    LCognates.append((Lev0Norm, Lev0, SWordB, SPoSB, IFrqB))
                if Lev1Norm <= 0.36:
                    LCognates1.append((Lev1Norm, Lev1, SWordB, SPoSB, IFrqB))
            
            
            LDistances.append((SWordA, SPoSA, IFrqA, LCognates))
            if (len(LCognates) > 0 or len(LCognates1) > 0):
                ICounterRec += 1
                ACognPerCent = ICounterRec / ICounter
                sys.stdout.write('\t{, %(ICounterRec)d, %(ICounter)d, %(SWordA)s, %(SPoSA)s, frq=%(IFrqA)d, ln=%(LogFrqA).2f, have-cognates: %(ACognPerCent).2f : \n' % locals())
                # sys.stdout.flush()
                self.printCognates(LCognates, LogFrqA, SPoSA)
                sys.stdout.write('\t\n')
                self.printCognates(LCognates1, LogFrqA, SPoSA)
            
        '''
        for (SWordA, SPoSA, IFrqA, LCognates) in LDistances:
            # sys.stdout.write('%(SWordA)s, %(SPoSA)s, %(IFrqA)d : \n' % locals())
            for (ALevNorm, SWordB, SPoSB, IFrqB) in LCognates:
                # FDebug.write('\t %(ALevNorm)f, %(SWordB)s, %(SPoSB)s, %(IFrqB)d\n')
                pass
        '''
                
        
                    
    def printCognates(self, LCognates, LogFrqA, SPoSA):
        ICogRank = 0
        for (ALevNorm, ILev, SWordB, SPoSB, IFrqB) in sorted(LCognates, reverse=False, key=lambda k: k[0]):
            try:
                LogFrqB = math.log(IFrqB)
            except:
                LogFrqB = 0
            try:
                AFrqRange = min(LogFrqB, LogFrqA) / max(LogFrqB, LogFrqA)
            except:
                AFrqRange = 0
            if (SPoSB == SPoSA) and (AFrqRange > 0.5 ):
                ICogRank += 1
                sys.stdout.write('\t\trank=%(ICogRank)d, %(AFrqRange).3f, %(ILev).3f, %(ALevNorm).3f, %(SWordB)s, %(SPoSB)s, %(IFrqB)d, ln=%(LogFrqB).2f\n' % locals())
            else:
                sys.stdout.write('\t\t--, %(AFrqRange).3f, %(ILev).3f, %(ALevNorm).3f, %(SWordB)s, %(SPoSB)s, %(IFrqB)d, ln=%(LogFrqB).2f\n' % locals())
        sys.stdout.write('\t}\n')
        sys.stdout.flush()

        
    def readWordList(self, SFIn):
        LWords = []
        for SLine in open(SFIn, 'rU'):
            try:
                LLine = re.split('\t', SLine)
                SWord = LLine[0] 
                SPoS = LLine[1]
                IFrq = int(LLine[2])
            except:
                continue
            
            LWords.append((SWord, SPoS, IFrq))
        return LWords
    
    
    def computeLevenshteinLocal(self, s1, s2):

        l1 = len(s1)
        l2 = len(s2)
    
        matrix = [list(range(l1 + 1))] * (l2 + 1)
        for zz in range(l2 + 1):
            matrix[zz] = list(range(zz,zz + l1 + 1))
        for zz in range(0,l2):
            for sz in range(0,l1):
                # here: 1. compare sets of features; add the minimal substitution score here...
                if s1[sz] == s2[zz]:
                    matrix[zz+1][sz+1] = min(matrix[zz+1][sz] + 1, matrix[zz][sz+1] + 1, matrix[zz][sz])
                else:
                    matrix[zz+1][sz+1] = min(matrix[zz+1][sz] + 1, matrix[zz][sz+1] + 1, matrix[zz][sz] + 1)
        return matrix[l2][l1]
        
                          
if __name__ == '__main__':
    OCrossLevenshtein = clCrossLevenshtein(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
    # dictionary1, dictionary2, langID1, langID2