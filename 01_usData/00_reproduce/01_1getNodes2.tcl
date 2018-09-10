
# vmd -dispdev text -e 01_getNodes.tcl -args "deca-ala_H_v.psf" "../../../../0_helix_f100.coor" "../../../../tmd_out_all.dcd" "../../../../tmd_out_all.xst" 50 32 25 10 15 20 6 10 no yes 0.8 0.4 new

if {$argc != 19} {
  puts "Wrong number of arguments ([expr {$argc - 1}])!"
  puts "Need 18 arguments"
  puts "1: psf file"
  puts "2: namdbin file of initial structure of TMD"
  puts "3: dcd file of TMD"
  puts "4: xst file"
  puts "5: maximal frequence for FFT low pass"
  puts "6: level of Butterworth filter"
  puts "7: half width of smoothing window"
  puts "8: repeat number of smoothing"
  puts "9: dihedral angle threshold between nodes"
  puts "10: minimal delta index between nodes"
  puts "11: dihedral angle step"
  puts "12: US window step"
  puts "13: apply periodic boundary conditions (yes/no)"
  puts "14: multiple chain (yes/no)"
  puts "15: processing mode (new/continued)"
  puts "16: dihedral angles difference limitation"
  puts "17: scaling of dihedral angles difference modification"
  puts "18: device id of CUDA chip (-1(do not use CUDA)/0/1/2/...)"
  exit
}

set inPsf             [lindex $argv 0]
set inNamdbin         [lindex $argv 1]
set inDcd             [lindex $argv 2]
set inXst             [lindex $argv 3]
set maxFreq           [lindex $argv 4]
set bwfLevel          [lindex $argv 5]
set halfAvgWinSize    [lindex $argv 6]
set smoothNum         [lindex $argv 7]
set minPeakCrestDiff  [lindex $argv 8]
set minNeighborFrame  [lindex $argv 9]
set diheStep          [lindex $argv 10]
set winStep           [lindex $argv 11]
set useXst            [lindex $argv 12]
set multiChain        [lindex $argv 13]
set procMode          [lindex $argv 14]
set diheDiffLimit     [lindex $argv 15]
set diheModScale      [lindex $argv 16]
set deviceId          [lindex $argv 17]
set refDataFile_location "none"
set segTransPair "none"
set segTransSel "none"
set segTransNum 0
set segOriePair "none"
set segOriePairNum 0
set transHalfAvgWinSize 0
set transSmoothNum 0
set transThre 0
set transStep 0
set transWinStep 0
set transAddWinAt2Ends 0
set spinAngleHalfAvgWinSize 0
set spinAngleSmoothNum 0
set spinAngleThre 0
set spinAngleStep 0 
set spinAngleWinStep 0
set spinAngleAddWinAt2Ends 0
set tiltHalfAvgWinSize 0
set tiltSmoothNum 0
set tiltThre 0
set tiltStep 0 
set tiltWinStep 0
set tiltAddWinAt2Ends 0


package require topotools

if {$halfAvgWinSize < 1} {
  puts "ERROR: half width of smoothing window should larger than 0"
  exit
}

if {$smoothNum < 0} {
  puts "ERROR: repeat number of smoothing should larger or equal to 0"
  exit
}

if {$minPeakCrestDiff < 0} {
  puts "ERROR: dihedral angle threshold between nodes should larger or equal to 0"
  exit
}

if {$minNeighborFrame < 0} {
  puts "ERROR: minimal delta index between nodes should larger or equal to 0"
  exit
}

# check dihedral angle step value
if {[format "%f" [expr {int([format "%f" [expr {180.0 / $diheStep}]]) * $diheStep}]] != 180.0 } {
  puts "ERROR: dihedral angle step ($diheStep) which can not exactly divide 180"
  exit
}
# finish checking dihedral angle step value

# check dihedral angle threshold value
if {[format "%f" [expr {int([format "%f" [expr {$minPeakCrestDiff / $diheStep}]]) * $diheStep}]] != $minPeakCrestDiff } {
  puts "ERROR: dihedral angle step ($diheStep) which can not exactly divide dihedral angle threshold ($minPeakCrestDiff)"
  exit
}
# finish checking dihedral angle threshold value

# check dihedral angle window step value
if {[format "%f" [expr {int([format "%f" [expr {$diheStep / $winStep}]]) * $winStep}]] != $diheStep } {
  puts "ERROR: dihedral angle window step ($winStep) which can not exactly divide dihedral angle step ($diheStep)"
  exit
}
# finish checking dihedral angle window step value

# check useXst value
if {$useXst ne "yes" && $useXst ne "no"} {
  puts "ERROR: apply XST setting ($useXst)? Please use word \"yes\" or \"no\""
  exit
}
# finish useXst value

# check multiple chain value
if {$multiChain ne "yes" && $multiChain ne "no"} {
  puts "ERROR: multiple chain ($multiChain)? Please use word \"yes\" or \"no\""
  exit
}
# finish checking multiple chain value

# check processing mode
if {$procMode ne "new" && $procMode ne "continued"} {
  puts "ERROR: processing mode ($procMode)? Please use word \"new\" or \"continued\""
  exit
}
# finish checking processing mode

# read setting file and apply settings
set fileIn "01_1settings.txt"
if [catch {open $fileIn r} FIN] {
  puts "ERROR: Can not open $fileIn"
  exit
}

## read atomselectOfDihedral
if {[gets $FIN line] >= 0} {
  if {[lindex $line 0] eq "atomselectOfDihedral"} {
    set diheAtomSel [lrange "$line" 1 end]
    puts "atomselectOfDihedral: $diheAtomSel"
  } else {
    puts "ERROR: can not get information of atomselectOfDihedral"
    exit
  }
} else {
  puts "ERROR: empty file?"
  exit
}
## finish reading atomselectOfDihedral

## read atomselectOfDihedral2
if {[gets $FIN line] >= 0} {
  if {[lindex $line 0] eq "atomselectOfDihedral2"} {
    set diheAtomSel2 [lrange "$line" 1 end]
    puts "atomselectOfDihedral2: $diheAtomSel2"
  } else {
    puts "ERROR: can not get information of atomselectOfDihedral2"
    exit
  }
} else {
  puts "ERROR: empty file?"
  exit
}
## finish reading atomselectOfDihedral2

## read keyFrames
if {[gets $FIN line] >= 0} {
  if {[lindex $line 0] eq "keyFrames"} {
    set keyFramesList [lrange "$line" 1 end]
    if {$keyFramesList != ""} {
      set keyFramesList [lsort -increasing -integer -unique $keyFramesList]
    }
    puts "keyFrames: $keyFramesList"
  } else {
    puts "ERROR: can not get information of keyFrames"
    exit
  }
} else {
  puts "ERROR: empty file?"
  exit
}
## finish reading keyFrames

## read atomselectOfFixWith1st
if {[gets $FIN line] >= 0} {
  if {[lindex $line 0] eq "atomselectOfFixWith1st"} {
    set fixWith1stAtomSel [lrange "$line" 1 end]
    puts "atomselectOfFixWith1st: $fixWith1stAtomSel"
  } else {
    puts "ERROR: can not get information of atomselectOfFixWith1st"
    exit
  }
} else {
  puts "ERROR: wrong file format?"
  exit
}
## finish reading atomselectOfFixWith1st

## read atomselectOfFixWithAvg
if {[gets $FIN line] >= 0} {
  if {[lindex $line 0] eq "atomselectOfFixWithAvg"} {
    set fixWithAvgAtomSel [lrange "$line" 1 end]
    puts "atomselectOfFixWithAvg: $fixWithAvgAtomSel"
  } else {
    puts "ERROR: can not get information of atomselectOfFixWithAvg"
    exit
  }
} else {
  puts "ERROR: wrong file format?"
  exit
}
## finish reading atomselectOfFixWithAvg

if {$multiChain eq "yes"} {
  ## read refDataFile
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "refDataFile"} {
      set refDataFile_location [lrange "$line" 1 end]
      puts "refDataFile: $refDataFile_location"
    } else {
      puts "ERROR: can not get information of refDataFile"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading refDataFile
  
  ## read segNameOfStopTranslation
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "segNameOfStopTranslation"} {
      set segStopTrans [lrange "$line" 1 end]
      puts "segNameOfStopTranslation: $segStopTrans"
    } else {
      puts "ERROR: can not get information of segNameOfStopTranslation"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading segNameOfStopTranslation

  ## read atomselectOf_ST_Ref
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "atomselectOf_ST_Ref"} {
      set stopTransRefAtomSel [lrange "$line" 1 end]
      puts "atomselectOf_ST_Ref: $stopTransRefAtomSel"
    } else {
      puts "ERROR: can not get information of atomselectOf_ST_Ref"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading atomselectOf_ST_Ref
  
  ## read TranslatableSegNameRef
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "TranslatableSegNameRef"} {
      set segTransRef [lrange "$line" 1 end]
      set segTransNum [llength "$segTransRef"]
      puts "TranslatableSegNameRef: $segTransRef"
      puts "number of translatable segments: $segTransNum"
    } else {
      puts "ERROR: can not get information of TranslatableSegNameRef"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading TranslatableSegNameRef
  
  ## read TranslatableSegNameSel
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "TranslatableSegNameSel"} {
      set segTransSel [lrange "$line" 1 end]
      puts "TranslatableSegNameSel: $segTransSel"
    } else {
      puts "ERROR: can not get information of TranslatableSegNameSel"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading TranslatableSegNameSel
  
  set segTransPair ""
  for {set i 0} {$i < $segTransNum} {incr i 1} {
    lappend segTransPair "[lindex $segTransRef $i]_[lindex $segTransSel $i]"
  }
  
  ## read atomselectOf_T_RefN atomselectOf_T_SelN
  for {set i 0} {$i < $segTransNum} {incr i 1} {
    if {[gets $FIN line] >= 0} {
      if {[lindex $line 0] eq "atomselectOf_T_Ref$i"} {
        set atomSelT_Ref($i) [lrange "$line" 1 end]
        puts "atomselectOf_T_Ref$i: $atomSelT_Ref($i)"
      } else {
        puts "ERROR: can not get information of atomselectOf_T_Ref$i"
        exit
      }
    } else {
      puts "ERROR: wrong file format?"
      exit
    }
    
    if {[gets $FIN line] >= 0} {
      if {[lindex $line 0] eq "atomselectOf_T_Sel$i"} {
        set atomSelT_Sel($i) [lrange "$line" 1 end]
        puts "atomselectOf_T_Sel$i: $atomSelT_Sel($i)"
      } else {
        puts "ERROR: can not get information of atomselectOf_T_Sel$i"
        exit
      }
    } else {
      puts "ERROR: wrong file format?"
      exit
    }
  }
  ## finish reading atomselectOf_T_RefN atomselectOf_T_SelN
  
  ## read coordinateOfDummyAtom
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "coordinateOfDummyAtom"} {
      set dummyCoor [lrange "$line" 1 end]
      puts "coordinateOfDummyAtom: $dummyCoor"
      if {[llength "$dummyCoor"] != 3} {
        puts "ERROR: wrong coordinate format. It should be X Y Z"
        exit
      }
    } else {
      puts "ERROR: can not get information of coordinateOfDummyAtom"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading coordinateOfDummyAtom
  
  ## read segNameOfStopRotation
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "segNameOfStopRotation"} {
      set segStopRota [lrange "$line" 1 end]
      puts "segNameOfStopRotation: $segStopRota"
    } else {
      puts "ERROR: can not get information of segNameOfStopRotation"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading segNameOfStopRotation
  
  if {$segStopRota ne ""} {
    ## read atomselectOf_SR_Ref
    if {[gets $FIN line] >= 0} {
      if {[lindex $line 0] eq "atomselectOf_SR_Ref"} {
        set stopRotaRefAtomSel [lrange "$line" 1 end]
        puts "atomselectOf_SR_Ref: $stopRotaRefAtomSel"
      } else {
        puts "ERROR: can not get information of atomselectOf_SR_Ref"
        exit
      }
    } else {
      puts "ERROR: wrong file format?"
      exit
    }
    ## finish reading atomselectOf_SR_Ref
    
    ## read centerOfStopRotation
    if {[gets $FIN line] >= 0} {
      if {[lindex $line 0] eq "centerOfStopRotation"} {
        set stopRotaCenter [lrange "$line" 1 end]
        puts "centerOfStopRotation: $stopRotaCenter"
        if {[llength "$stopRotaCenter"] != 4} {
          puts "ERROR: wrong rotation vector format. It should be A B C D"
          exit
        }
      } else {
        puts "ERROR: can not get information of centerOfStopRotation"
        exit
      }
    } else {
      puts "ERROR: wrong file format?"
      exit
    }
    ## finish reading centerOfStopRotation
    
    ## read refPositionsFile_SR
    if {[gets $FIN line] >= 0} {
      if {[lindex $line 0] eq "refPositionsFile_SR"} {
        set refPosiFileSR_location [lrange "$line" 1 end]
        set refPosiFileSR [lrange [string map {/ " "} "$refPosiFileSR_location"] end end]
        puts "refPositionsFile_SR: $refPosiFileSR_location"
        puts "refPositionsFile_SR name: $refPosiFileSR"
      } else {
        puts "ERROR: can not get information of refPositionsFile_SR"
        exit
      }
    } else {
      puts "ERROR: wrong file format?"
      exit
    }
    ## finish reading refPositionsFile_SR
    
    ## read segNameOfOrientationPair
    if {[gets $FIN line] >= 0} {
      if {[lindex $line 0] eq "segNameOfOrientationPair"} {
        if {[lindex $line 1] ne ""} {
          set segOriePair [lrange "$line" 1 end]
          set segOriePairNum [llength "$segOriePair"]
          puts "segNameOfOrientationPair: $segOriePair"
          if {[expr {$segOriePairNum % 2}] != 0} {
            puts "ERROR: wrong segNameOfOrientationPair format"
            exit
          }
          set segOriePairNum [expr {$segOriePairNum / 2}]
          puts "number of orientation pairs: $segOriePairNum"
        }
      } else {
        puts "ERROR: can not get information of segNameOfOrientationPair"
        exit
      }
    } else {
      puts "ERROR: wrong file format?"
      exit
    }
    ## finish reading segNameOfOrientationPair
    
    ## read atomselectOf_OP_RefN
    for {set i 0} {$i < $segOriePairNum} {incr i 1} {
      if {[gets $FIN line] >= 0} {
        if {[lindex $line 0] eq "atomselectOf_OP_Ref$i"} {
          set atomSelOP_Ref($i) [lrange "$line" 1 end]
          puts "atomselectOf_OP_Ref$i: $atomSelOP_Ref($i)"
        } else {
          puts "ERROR: can not get information of atomselectOf_OP_Ref$i"
          exit
        }
      } else {
        puts "ERROR: wrong file format?"
        exit
      }
    }
    ## finish reading atomselectOf_OP_RefN
    
    ## read refPositionsFile_OPN
    for {set i 0} {$i < $segOriePairNum} {incr i 1} {
      if {[gets $FIN line] >= 0} {
        if {[lindex $line 0] eq "refPositionsFile_OP$i"} {
          set refPosiFileOPN_location($i) [lrange "$line" 1 end]
          set refPosiFileOPN($i) [lrange [string map {/ " "} "$refPosiFileOPN_location($i)"] end end]
          puts "refPositionsFile_OP$i: $refPosiFileOPN_location($i)"
          puts "refPositionsFile_OP$i name: $refPosiFileOPN($i)"
        } else {
          puts "ERROR: can not get information of refPositionsFile_OP$i"
          exit
        }
      } else {
        puts "ERROR: wrong file format?"
        exit
      }
    }
    ## finish reading refPositionsFile_OPN
  }
  
  ## read translationHalfWidthSmoothWin
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "translationHalfWidthSmoothWin"} {
      set transHalfAvgWinSize [lrange "$line" 1 end]
      puts "translationHalfWidthSmoothWin: $transHalfAvgWinSize"
    } else {
      puts "ERROR: can not get information of translationHalfWidthSmoothWin"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading translationHalfWidthSmoothWin
  
  ## read translationSmoothNum
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "translationSmoothNum"} {
      set transSmoothNum [lrange "$line" 1 end]
      puts "translationSmoothNum: $transSmoothNum"
    } else {
      puts "ERROR: can not get information of translationSmoothNum"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading translationSmoothNum
  
  
  ## read translationThreshold
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "translationThreshold"} {
      set transThre [lrange "$line" 1 end]
      puts "translationThreshold: $transThre"
    } else {
      puts "ERROR: can not get information of translationThreshold"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading translationThreshold
  
  ## read translationStep
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "translationStep"} {
      set transStep [lrange "$line" 1 end]
      puts "translationStep: $transStep"
    } else {
      puts "ERROR: can not get information of translationStep"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ### check translationThreshold value
  if {[format "%f" [expr {int([format "%f" [expr {$transThre / $transStep}]]) * $transStep}]] != $transThre } {
    puts "ERROR: translationStep ($transStep) which can not exactly divide translationThreshold ($transThre)"
    exit
  }
  ### finish checking translationThreshold value
  ## finish reading translationStep
  
  ## read translationWinStep
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "translationWinStep"} {
      set transWinStep [lrange "$line" 1 end]
      puts "translationWinStep: $transWinStep"
    } else {
      puts "ERROR: can not get information of translationWinStep"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ### check translationWinStep value
  if {[format "%f" [expr {int([format "%f" [expr {$transStep / $transWinStep}]]) * $transWinStep}]] != $transStep } {
    puts "ERROR: translationWinStep ($transWinStep) which can not exactly divide translationStep ($transStep)"
    exit
  }
  ### finish checking translationWinStep value
  ## finish reading translationWinStep
  
  ## read translationCenterDisplacement
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "translationCenterDisplacement"} {
      set transCentDisp [lrange "$line" 1 end]
      puts "translationCenterDisplacement: $transCentDisp"
    } else {
      puts "ERROR: can not get information of translationCenterDisplacement"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading translationCenterDisplacement
  
  ## read translationHalfHeight
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "translationHalfHeight"} {
      set transHalfHeight [lrange "$line" 1 end]
      puts "translationHalfHeight: $transHalfHeight"
    } else {
      puts "ERROR: can not get information of translationHalfHeight"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading translationHalfHeight
  
  ## read translationAddWinAtBothEnds
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "translationAddWinAtBothEnds"} {
      set transAddWinAt2Ends [lrange "$line" 1 end]
      puts "translationAddWinAtBothEnds: $transAddWinAt2Ends"
    } else {
      puts "ERROR: can not get information of translationAddWinAtBothEnds"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading translationAddWinAtBothEnds
  
  ## read spinAngleHalfWidthSmoothWin
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "spinAngleHalfWidthSmoothWin"} {
      set spinAngleHalfAvgWinSize [lrange "$line" 1 end]
      puts "spinAngleHalfWidthSmoothWin: $spinAngleHalfAvgWinSize"
    } else {
      puts "ERROR: can not get information of spinAngleHalfWidthSmoothWin"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading spinAngleHalfWidthSmoothWin
  
  ## read spinAngleSmoothNum
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "spinAngleSmoothNum"} {
      set spinAngleSmoothNum [lrange "$line" 1 end]
      puts "spinAngleSmoothNum: $spinAngleSmoothNum"
    } else {
      puts "ERROR: can not get information of spinAngleSmoothNum"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading spinAngleSmoothNum
  
  ## read spinAngleThreshold
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "spinAngleThreshold"} {
      set spinAngleThre [lrange "$line" 1 end]
      puts "spinAngleThreshold: $spinAngleThre"
    } else {
      puts "ERROR: can not get information of spinAngleThreshold"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading spinAngleThreshold
  
  ## read spinAngleStep
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "spinAngleStep"} {
      set spinAngleStep [lrange "$line" 1 end]
      puts "spinAngleStep: $spinAngleStep"
    } else {
      puts "ERROR: can not get information of spinAngleStep"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ### check spinAngleStep value
  if {[format "%f" [expr {int([format "%f" [expr {180.0 / $spinAngleStep}]]) * $spinAngleStep}]] != 180.0 } {
    puts "ERROR: spinAngleStep ($spinAngleStep) which can not exactly divide 180"
    exit
  }
  ### finish checking spinAngleStep value
  
  ### check spinAngleThreshold value
  if {[format "%f" [expr {int([format "%f" [expr {$spinAngleThre / $spinAngleStep}]]) * $spinAngleStep}]] != $spinAngleThre } {
    puts "ERROR: spinAngleStep ($spinAngleStep) which can not exactly divide spinAngleThreshold ($spinAngleThre)"
    exit
  }
  ### finish checking spinAngleThreshold value
  ## finish reading spinAngleStep
  
  ## read spinAngleWinStep
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "spinAngleWinStep"} {
      set spinAngleWinStep [lrange "$line" 1 end]
      puts "spinAngleWinStep: $spinAngleWinStep"
    } else {
      puts "ERROR: can not get information of spinAngleWinStep"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ### check spinAngleWinStep value
  if {[format "%f" [expr {int([format "%f" [expr {$spinAngleStep / $spinAngleWinStep}]]) * $spinAngleWinStep}]] != $spinAngleStep } {
    puts "ERROR: spinAngleWinStep ($spinAngleWinStep) which can not exactly divide spinAngleStep ($spinAngleStep)"
    exit
  }
  ### finish checking spinAngleWinStep value
  ## finish reading spinAngleWinStep
  
  ## read spinAngleCenterDisplacement
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "spinAngleCenterDisplacement"} {
      set spinAngleCentDisp [lrange "$line" 1 end]
      puts "spinAngleCenterDisplacement: $spinAngleCentDisp"
    } else {
      puts "ERROR: can not get information of spinAngleCenterDisplacement"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading spinAngleCenterDisplacement
  
  ## read spinAngleHalfHeight
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "spinAngleHalfHeight"} {
      set spinAngleHalfHeight [lrange "$line" 1 end]
      puts "spinAngleHalfHeight: $spinAngleHalfHeight"
    } else {
      puts "ERROR: can not get information of spinAngleHalfHeight"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading spinAngleHalfHeight
  
  ## read spinAngleAddWinAtBothEnds
  if {[gets $FIN line] >= 0} {
    if {[lindex $line 0] eq "spinAngleAddWinAtBothEnds"} {
      set spinAngleAddWinAt2Ends [lrange "$line" 1 end]
      puts "spinAngleAddWinAtBothEnds: $spinAngleAddWinAt2Ends"
    } else {
      puts "ERROR: can not get information of spinAngleAddWinAtBothEnds"
      exit
    }
  } else {
    puts "ERROR: wrong file format?"
    exit
  }
  ## finish reading spinAngleAddWinAtBothEnds

#   ## read tiltHalfWidthSmoothWin
#   if {[gets $FIN line] >= 0} {
#     if {[lindex $line 0] eq "tiltHalfWidthSmoothWin"} {
#       set tiltHalfAvgWinSize [lrange "$line" 1 end]
#       puts "tiltHalfWidthSmoothWin: $tiltHalfAvgWinSize"
#     } else {
#       puts "ERROR: can not get information of tiltHalfWidthSmoothWin"
#       exit
#     }
#   } else {
#     puts "ERROR: wrong file format?"
#     exit
#   }
#   ## finish reading tiltHalfWidthSmoothWin
#   
#   ## read tiltSmoothNum
#   if {[gets $FIN line] >= 0} {
#     if {[lindex $line 0] eq "tiltSmoothNum"} {
#       set tiltSmoothNum [lrange "$line" 1 end]
#       puts "tiltSmoothNum: $tiltSmoothNum"
#     } else {
#       puts "ERROR: can not get information of tiltSmoothNum"
#       exit
#     }
#   } else {
#     puts "ERROR: wrong file format?"
#     exit
#   }
#   ## finish reading tiltSmoothNum
  
#   ## read tiltThreshold
#   if {[gets $FIN line] >= 0} {
#     if {[lindex $line 0] eq "tiltThreshold"} {
#       set tiltThre [lrange "$line" 1 end]
#       puts "tiltThreshold: $tiltThre"
#     } else {
#       puts "ERROR: can not get information of tiltThreshold"
#       exit
#     }
#   } else {
#     puts "ERROR: wrong file format?"
#     exit
#   }
#   ## finish reading tiltThreshold
#   
#   ## read tiltStep
#   if {[gets $FIN line] >= 0} {
#     if {[lindex $line 0] eq "tiltStep"} {
#       set tiltStep [lrange "$line" 1 end]
#       puts "tiltStep: $tiltStep"
#     } else {
#       puts "ERROR: can not get information of tiltStep"
#       exit
#     }
#   } else {
#     puts "ERROR: wrong file format?"
#     exit
#   }
#   ### check tiltStep value
#   if {[format "%f" [expr {int([format "%f" [expr {2.0 / $tiltStep}]]) * $tiltStep}]] != 2.0 } {
#     puts "ERROR: tiltStep ($tiltStep) which can not exactly divide 2"
#     exit
#   }
#   ### finish checking tiltStep value
#   
#   ### check tiltThreshold value
#   if {[format "%f" [expr {int([format "%f" [expr {$tiltThre / $tiltStep}]]) * $tiltStep}]] != $tiltThre } {
#     puts "ERROR: tiltStep ($tiltStep) which can not exactly divide tiltThreshold ($tiltThre)"
#     exit
#   }
#   ### finish checking tiltThreshold value
#   ## finish reading tiltStep
#   
#   ## read tiltWinStep
#   if {[gets $FIN line] >= 0} {
#     if {[lindex $line 0] eq "tiltWinStep"} {
#       set tiltWinStep [lrange "$line" 1 end]
#       puts "tiltWinStep: $tiltWinStep"
#     } else {
#       puts "ERROR: can not get information of tiltWinStep"
#       exit
#     }
#   } else {
#     puts "ERROR: wrong file format?"
#     exit
#   }
#   ### check tiltWinStep value
#   if {[format "%f" [expr {int([format "%f" [expr {$tiltStep / $tiltWinStep}]]) * $tiltWinStep}]] != $tiltStep } {
#     puts "ERROR: tiltWinStep ($tiltWinStep) which can not exactly divide tiltStep ($tiltStep)"
#     exit
#   }
#   ### finish checking tiltWinStep value
#   ## finish reading tiltWinStep
#   
#   ## read tiltCenterDisplacement
#   if {[gets $FIN line] >= 0} {
#     if {[lindex $line 0] eq "tiltCenterDisplacement"} {
#       set tiltCentDisp [lrange "$line" 1 end]
#       puts "tiltCenterDisplacement: $tiltCentDisp"
#     } else {
#       puts "ERROR: can not get information of tiltCenterDisplacement"
#       exit
#     }
#   } else {
#     puts "ERROR: wrong file format?"
#     exit
#   }
#   ## finish reading tiltCenterDisplacement
#   
#   ## read tiltHalfHeight
#   if {[gets $FIN line] >= 0} {
#     if {[lindex $line 0] eq "tiltHalfHeight"} {
#       set tiltHalfHeight [lrange "$line" 1 end]
#       puts "tiltHalfHeight: $tiltHalfHeight"
#     } else {
#       puts "ERROR: can not get information of tiltHalfHeight"
#       exit
#     }
#   } else {
#     puts "ERROR: wrong file format?"
#     exit
#   }
#   ## finish reading tiltHalfHeight
#   
#   ## read tiltAddWinAtBothEnds
#   if {[gets $FIN line] >= 0} {
#     if {[lindex $line 0] eq "tiltAddWinAtBothEnds"} {
#       set tiltAddWinAt2Ends [lrange "$line" 1 end]
#       puts "tiltAddWinAtBothEnds: $tiltAddWinAt2Ends"
#     } else {
#       puts "ERROR: can not get information of tiltAddWinAtBothEnds"
#       exit
#     }
#   } else {
#     puts "ERROR: wrong file format?"
#     exit
#   }
#   ## finish reading tiltAddWinAtBothEnds
}

close $FIN
# finish reading setting file and applying settings

# mol 0
mol new $inPsf type psf waitfor all
mol addfile $inNamdbin type namdbin waitfor all
mol addfile $inDcd type dcd waitfor all

set frameNum [molinfo 0 get numframes]
set allSel0 [atomselect 0 "all"]

if {$frameNum <= 1} {
  puts "ERROR : only $frameNum frame has been read\n"
  exit
}

if {$procMode eq "new"} {
  set allDiheAtomSel0 [atomselect 0 "$diheAtomSel and $diheAtomSel2"]
  set allDiheList [topo getdihedrallist -molid 0 -sel $allDiheAtomSel0]
  $allDiheAtomSel0 delete

  # pick nodes
  ## force the first node index is 0
  set allZeroSlopeIndexList "0"
  ## finish forcing the first node index is 0
  set diheNum 0
  set j1 [llength $allDiheList]
  for {set j0 0} {$j0 < $j1} {incr j0 1} {
    ## pick needed dihedral atom sets
    set diheAtomIndexList [lrange [lindex $allDiheList $j0] 1 4]
    set diheAtomNameList ""
    for {set k 0} {$k < 4} {incr k 1} {
      set diheAtomSel0 [atomselect 0 "index [lindex $diheAtomIndexList $k]"]
      lappend diheAtomNameList [$diheAtomSel0 get name]
      $diheAtomSel0 delete
    }
    
    puts -nonewline "$j0 ($diheNum): $diheAtomIndexList $diheAtomNameList"
    if {$diheAtomNameList eq "C N CA CB"} {
      ### skip C N CA CB and keep C N CA C dihedral atom set
      puts " \[skipped\]"
      continue
      ### finish skipping C N CA CB and keeping C N CA C dihedral atom set
    } elseif {$diheAtomNameList eq "O4' C4' C3' C2'" ||
              $diheAtomNameList eq "C5' C4' C3' O3'" ||
              $diheAtomNameList eq "C5' C4' C3' C2'" ||
              $diheAtomNameList eq "C3' C4' O4' C1'"} {
      ### keep 3 backbone and 1 ring dihedral atom sets
      ### finish keeping 3 backbone and 1 ring dihedral atom sets
    } elseif {$diheAtomNameList eq "C4' O4' C1' C2'" ||
              $diheAtomNameList eq "C1' C2' C3' C4'" ||
              $diheAtomNameList eq "O4' C4' C5' O5'" ||
              $diheAtomNameList eq "O4' C1' C2' C3'" ||
              $diheAtomNameList eq "C1' C2' C3' O3'" ||
              $diheAtomNameList eq "C5' C4' O4' C1'" ||
              $diheAtomNameList eq "O4' C4' C3' O3'" ||
              $diheAtomNameList eq "N9 C1' C2' C3'" ||
              $diheAtomNameList eq "N1 C1' C2' C3'"} {
      ### skip useless nucleic dihedral atom sets
      puts " \[skipped\]"
      continue
      ### finish skipping useless nucleic dihedral atom sets
    } elseif {$diheNum > 0} {
      ### skip repeats
      set atomSerial1 [expr {1 + [lindex $diheAtomIndexList 1]}]
      set atomSerial2 [expr {1 + [lindex $diheAtomIndexList 2]}]
      set repeatFlag 0
      for {set k 0} {$k < $diheNum} {incr k 1} {
        if {[lindex $diheAtomSerialList($k) 1] == $atomSerial1 && [lindex $diheAtomSerialList($k) 2] == $atomSerial2} {
          puts " \[skipped\]"
          set repeatFlag 1
          break
        }
      }
      if {$repeatFlag == 1} {
        continue
      }
      ### finish skipping repeats
    }
    puts ""
    set diheAtomSerialList($diheNum) ""
    foreach {dihe} $diheAtomIndexList {
      lappend diheAtomSerialList($diheNum) [expr {$dihe + 1}]
    }
    ## finish picking needed dihedral atom sets
    
    ## write original dihedral angle of all frames
    set fileOut "01_diheOri_$diheNum.txt"
    if [catch {open $fileOut w} FOUT] {
      puts "ERROR: Can not open $fileOut"
      exit
    }

    set diheList [measure dihed $diheAtomIndexList molid 0 frame all]
    set i1 [llength $diheList]
    for {set i0 0} {$i0 < $i1} {incr i0 1} {
      puts $FOUT "$i0 [lindex $diheList $i0]"
    }

    close $FOUT
    ## finish writing original dihedral angle of all frames
    incr diheNum 1
  }
  
  set fileOut "01_allDiheAtomSerial.txt"
  if [catch {open $fileOut w} FOUT] {
    puts "ERROR: Can not open $fileOut"
    exit
  }
  for {set i 0} {$i < $diheNum} {incr i 1} {
    puts $FOUT "$diheAtomSerialList($i)"
  }
  close $FOUT
  
  set fileOut "01_colvarSettings.txt"
  if [catch {open $fileOut w} FOUT] {
    puts "ERROR: Can not open $fileOut"
    exit
  }
  
  set tmpSel [atomselect 0 "$fixWith1stAtomSel"]
  set fixSerial [$tmpSel get serial]
  if {$fixSerial eq ""} {
    set fixSerial 0
  }
  puts $FOUT "FIX_WITH_1ST_atomNumbers $fixSerial"
  $tmpSel delete
  
  set tmpSel [atomselect 0 "$fixWithAvgAtomSel"]
  set fixSerial [$tmpSel get serial]
  if {$fixSerial eq ""} {
    set fixSerial 0
  }
  puts $FOUT "FIX_WITH_AVG_atomNumbers $fixSerial"
  $tmpSel delete
  
  if {$multiChain eq "yes"} {
    set stopTransSel [atomselect 0 "segname $segStopTrans and $stopTransRefAtomSel"]
    puts $FOUT "STOP_TRANSLATION_group1_atomNumbers [$stopTransSel get serial]"
    $stopTransSel delete
    
    for {set i 0} {$i < $segTransNum} {incr i 1} {
      set transRef [atomselect 0 "segname [lindex $segTransRef $i] and $atomSelT_Ref($i)"]
      puts $FOUT "TRANSLATION_ref_atomNumbers_$i [$transRef get serial]"
      $transRef delete
      set transSel [atomselect 0 "segname [lindex $segTransSel $i] and $atomSelT_Sel($i)"]
      puts $FOUT "TRANSLATION_main_atomNumbers_$i [$transSel get serial]"
      $transSel delete
    }
    
    if {$segStopRota ne ""} {
      set stopRotaSel [atomselect 0 "segname $segStopRota and $stopRotaRefAtomSel"]
      puts $FOUT "STOP_ROTATION_atoms_atomNumbers [$stopRotaSel get serial]"
      $stopRotaSel delete
    }
    
    for {set i 0} {$i < $segOriePairNum} {incr i 1} {
      set rotaSel [atomselect 0 "segname [lindex $segOriePair [expr $i * 2]] and $atomSelOP_Ref($i)"]
      puts $FOUT "ROTATION_atoms_atomNumbers_$i [$rotaSel get serial]"
      $rotaSel delete
    }
  }
  
  close $FOUT
} elseif {$procMode eq "continued"} {
  set fileIn "01_allDiheAtomSerial.txt"
  if [catch {open $fileIn r} FIN] {
    puts "ERROR: Can not open $fileIn"
    exit
  }
  
  set diheNum 0
  while {[gets $FIN line] >= 0} {
    set diheAtomSerialList($diheNum) $line
    incr diheNum 1
  }

  close $FIN
} else {
  puts "ERROR: you should not be here...."
  exit
}

if {$diheNum == 0} {
  puts "ERROR : none of dihedral angle has been selected\n"
  exit
}

set diheSkipIndexList " "
set fileIn "02_1fix1stDiheAtomSerial.txt"
if [catch {open $fileIn r} FIN] {
  puts "ERROR: Can not open $fileIn"
  exit
}
while {[gets $FIN line] >= 0} {
  for {set i 0} {$i < $diheNum} {incr i 1} {
    if {$diheAtomSerialList($i) == $line} {
      if {$diheSkipIndexList == " "} {
        set diheSkipIndexList $i
      } else {
        lappend diheSkipIndexList $i
      }
      break
    }
  }
}
close $FIN
set diheSkipIndexList [lsort -increasing -integer -unique $diheSkipIndexList]

puts "$procMode $multiChain $diheNum $frameNum \"$keyFramesList\" $halfAvgWinSize $smoothNum $minPeakCrestDiff \"$refDataFile_location\" \"$segTransPair\" \"$segOriePair\" $segTransNum $segOriePairNum $transHalfAvgWinSize $transSmoothNum $spinAngleHalfAvgWinSize $spinAngleSmoothNum $tiltHalfAvgWinSize $tiltSmoothNum $transThre $spinAngleThre $tiltThre $minNeighborFrame $diheStep $transStep $spinAngleStep $tiltStep $winStep $transWinStep $transAddWinAt2Ends $spinAngleWinStep $spinAngleAddWinAt2Ends $tiltWinStep $tiltAddWinAt2Ends $deviceId $maxFreq $bwfLevel \"$diheSkipIndexList\" $diheDiffLimit $diheModScale"

set status [catch {exec ./01_2getNodes $procMode $multiChain $diheNum $frameNum "$keyFramesList" $halfAvgWinSize $smoothNum $minPeakCrestDiff "$refDataFile_location" "$segTransPair" "$segOriePair" $segTransNum $segOriePairNum $transHalfAvgWinSize $transSmoothNum $spinAngleHalfAvgWinSize $spinAngleSmoothNum $tiltHalfAvgWinSize $tiltSmoothNum $transThre $spinAngleThre $tiltThre $minNeighborFrame $diheStep $transStep $spinAngleStep $tiltStep $winStep $transWinStep $transAddWinAt2Ends $spinAngleWinStep $spinAngleAddWinAt2Ends $tiltWinStep $tiltAddWinAt2Ends $deviceId $maxFreq $bwfLevel "$diheSkipIndexList" $diheDiffLimit $diheModScale >& 01_2getNodes.log} result]

if {$status != 0} {
  puts $result
  puts "ERROR: something wrong while executing 01_2getNodes"
  exit
}

if {[file size 01_2getNodes.log]} {
  puts "ERROR: something wrong in 01_2getNodes.log"
  exit
}

exit
