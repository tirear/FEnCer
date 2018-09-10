proc meanAngle {angles} {
  set toRadians [expr {atan2(0,-1) / 180}]
  set sumSin [set sumCos 0.0]
  foreach a $angles {
    set sumSin [expr {$sumSin + sin($a * $toRadians)}]
    set sumCos [expr {$sumCos + cos($a * $toRadians)}]
  }
  # Don't need to divide by counts; atan2() cancels that out
  return [expr {atan2($sumSin, $sumCos) / $toRadians}]
}

proc smoothAngle {angleList halfWinSize} {
  set i1 [expr [llength $angleList] - 1]
  for {set i0 0} {$i0 <= $i1} {incr i0 1} {
    set i2 [expr $i0 - $halfWinSize]
    set i3 [expr $i0 + $halfWinSize]
    if {$i2 < 0} {
      set winList [lindex $angleList 0]
      incr i2 1
      while {$i2 < 0} {
        lappend winList [lindex $angleList 0]
        incr i2 1
      }
    }
    if {$i3 > $i1} {
      if {[llength $angleList] < 1} {
        set winList [lindex $angleList $i2]
      } else {
        lappend winList [lindex $angleList $i2]
      }
      incr i2 1
      while {$i2 <= $i1} {
        lappend winList [lindex $angleList $i2]
        incr i2 1
      }
      while {$i2 <= $i3} {
        lappend winList [lindex $angleList $i1]
        incr i2 1
      }
    } else {
      if {[llength $angleList] < 1} {
        set winList [lindex $angleList $i2]
        incr i2 1
      }
      while {$i2 <= $i3} {
        lappend winList [lindex $angleList $i2]
        incr i2 1
      }
    }
    if {$i0 == 0} {
      set angleList2 [list [meanAngle $winList]]
    } else {
      lappend angleList2 [meanAngle $winList]
    }
    unset winList
  }
  return $angleList2
}

proc deltaAngle {angles} {
  set da [expr [lindex $angles 1] - [lindex $angles 0]]
  if {$da > 180} {
    set da [expr $da - 360]
  } elseif {$da <= -180} {
    set da [expr $da + 360]
  }
  return $da
}

proc getZeroSlopeIndex {angles} {
  set zeroSlopeIndex ""
  set finalIndex [expr [llength $angles] - 2]
  set da0 [deltaAngle [lrange $angles 0 1]]
  for {set i0 1} {$i0 <= $finalIndex} {incr i0 1} {
    set da1 [deltaAngle [lrange $angles $i0 [expr $i0 + 1]]]
    if {[expr $da0 * $da1] < 0} {
      lappend zeroSlopeIndex $i0
    }
    set da0 $da1
  }
  return $zeroSlopeIndex
}

proc diffFilter {angle angleIndex minDiff} {
  set refIndexOfIndex 0
  set refAngle [lindex $angle [lindex $angleIndex $refIndexOfIndex]]
  set filteredAngleIndex [lrange $angleIndex $refIndexOfIndex $refIndexOfIndex]
  set finalIndex [llength $angleIndex]
  for {set i0 1} {$i0 < $finalIndex} {incr i0 1} {
    if {[expr abs([deltaAngle [list [lindex $angle [lindex $angleIndex $i0]] $refAngle]])] >= $minDiff} {
      lappend filteredAngleIndex [lindex $angleIndex $i0]
      set refAngle [lindex $angle [lindex $angleIndex $i0]]
    }
  }
  return $filteredAngleIndex
}

proc rmNeighborFrame {indexList min} {
  if {$min < 1} {
    puts "index neighber distance should larger than 1"
    exit
  }
  set i1 [expr [llength $indexList] - 1]
  for {set i0 0} {$i0 < $i1} {incr i0 1} {
    set i2 [expr $i0 + 1]
    while {[expr [lindex $indexList $i2] - [lindex $indexList $i0]] < $min} {
      set indexList [lreplace $indexList $i2 $i2]
      set i1 [expr [llength $indexList] - 1]
      if {$i2 == [expr $i1 + 1]} {
        break
      }
    }
  }
  return $indexList
}

# vmd -dispdev text -e 01_getNodes.tcl -args "deca-ala_H_v.psf" "../../../../0_helix_f100.coor" "../../../../tmd_out_all.dcd" 25 10 15 20 "backbone" "../../../../0_helix_f100.vel" "../../../../tmd_vel_all.dcd" "../../../../tmd_out_all.xst" 5 new
if {$argc != 14} {
  puts "Wrong number of arguments ([expr $argc - 1])!"
  puts "Need 13 arguments"
  puts "1: psf file"
  puts "2: namdbin file of initial structure of TMD"
  puts "3: dcd file of TMD"
  puts "4: half width of smoothing window"
  puts "5: repeat number of smoothing"
  puts "6: dihedral threshold between nodes"
  puts "7: index threshold between nodes"
  puts "8: VMD atom selection for dihedral calculation"
  puts "9: namdbin file of initial velocity of TMD"
  puts "10: velocity dcd file of TMD"
  puts "11: xst file"
  puts "12: US window step"
  puts "13: processing mode (new/modify)"
  exit
}

set inPsf             [lindex $argv 0]
set inNamdbin         [lindex $argv 1]
set inDcd             [lindex $argv 2]
set halfAvgWinSize    [lindex $argv 3]
set smoothNum         [lindex $argv 4]
set minPeakCrestDiff  [lindex $argv 5]
set minNeighborFrame  [lindex $argv 6]
set diheAtomSel       [lindex $argv 7]
set replaceUnderline [list _ " "]
set diheAtomSel [string map $replaceUnderline "$diheAtomSel"]
set inVelNamdbin      [lindex $argv 8]
set inVelDcd          [lindex $argv 9]
set inXst             [lindex $argv 10]
set winStep           [lindex $argv 11]
set procMode          [lindex $argv 12]

package require topotools

# check processing mode
if {$procMode ne "new" && $procMode ne "modify"} {
  puts "ERROR: processing mode ($procMode)? Please use word \"yes\" or \"no\""
  exit
}
# finish checking processing mode

#mol 0
mol new $inPsf type psf waitfor all
mol addfile $inNamdbin type namdbin waitfor all
mol addfile $inDcd type dcd waitfor all

set frameNum [molinfo 0 get numframes]
set allSel0 [atomselect 0 "all"]

if {$procMode eq "new"} {
  set allDiheAtomSel0 [atomselect 0 "$diheAtomSel and noh and not ((resname ARG and name NH1 NH2) or (resname ASN and name OD1 ND2) or (resname ASP and name OD1 OD2) or (resname GLN and name OE1 NE2) or (resname GLU and name OE1 OE2) or (resname HSD HSE HSP and name ND1 CE1 NE2 CD2) or (resname ILE and name CD) or (resname LEU and name CD1 CD2) or (resname LYS and name NZ) or (resname MET and name CE) or (resname PHE and name CD1 CE1 CZ CE2 CD2) or (resname PRO and name CD CG CB) or (resname SER and name OG) or (resname THR and name OG1 CG2) or (resname TRP and name CD1 NE1 CE2 CD2 CE3 CZ3 CH2 CZ2) or (resname TYR and name CD1 CD2 CE2 CZ CE1 OH) or (resname VAL and name CG1 CG2) or (name CAY OY OT1 OT2  CT) or (name O NT CAT and same residue as name NT))"]
  set allDiheAtomIndexList [$allDiheAtomSel0 list]
  set allDiheList [topo getdihedrallist -molid 0 -sel $allDiheAtomSel0]
  $allDiheAtomSel0 delete

  set allZeroSlopeIndexList "0"
  set diheNum 0
  set j1 [llength $allDiheList]
  for {set j0 0} {$j0 < $j1} {incr j0 1} {
    set diheAtomIndexList [lrange [lindex $allDiheList $j0] 1 4]
    set diheAtomNameList ""
    for {set k 0} {$k < 4} {incr k 1} {
      set diheAtomSel0 [atomselect 0 "index [lindex $diheAtomIndexList $k]"]
      lappend diheAtomNameList [$diheAtomSel0 get name]
      $diheAtomSel0 delete
    }
    
    puts -nonewline "$j0 ($diheNum): $diheAtomIndexList $diheAtomNameList"
    if {[string equal [lindex $diheAtomNameList 1] "N"] && [string equal [lindex $diheAtomNameList 2] "CA"]} {
    } elseif {$diheNum > 0} {
      set atomSerial1 [expr 1 + [lindex $diheAtomIndexList 1]]
      set atomSerial2 [expr 1 + [lindex $diheAtomIndexList 2]]
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
    }
  puts ""
      set diheAtomSerialList($diheNum) ""
    foreach {dihe} $diheAtomIndexList {
      lappend diheAtomSerialList($diheNum) [expr $dihe + 1]
    }
    set diheList [measure dihed $diheAtomIndexList molid 0 frame all]
    
    set fileOut "01_diheOri_$diheNum.txt"
    if [catch {open $fileOut w} FOUT] {
      puts "Can not open $fileOut"
      exit
    }

    set i1 [llength $diheList]
    for {set i0 0} {$i0 < $i1} {incr i0 1} {
      puts $FOUT "$i0 [lindex $diheList $i0]"
    }

    close $FOUT
    
    set smoothedDiheList($diheNum) [smoothAngle $diheList 1]
    for {set i0 1} {$i0 < $smoothNum} {incr i0 1} {
      set smoothedDiheList($diheNum) [smoothAngle $smoothedDiheList($diheNum) 1]
    }
    set k1 [expr $halfAvgWinSize + 1]
    for {set k0 1} {$k0 < $k1} {incr k0 1} {
      set smoothedDiheList($diheNum) [smoothAngle $smoothedDiheList($diheNum) $k0]
      for {set i0 1} {$i0 < $smoothNum} {incr i0 1} {
        set smoothedDiheList($diheNum) [smoothAngle $smoothedDiheList($diheNum) $k0]
      }
    }

    set fileOut "01_diheSmooth_$diheNum.txt"
    if [catch {open $fileOut w} FOUT] {
      puts "Can not open $fileOut"
      exit
    }

    set i1 [llength $smoothedDiheList($diheNum)]
    for {set i0 0} {$i0 < $i1} {incr i0 1} {
      puts $FOUT "$i0 [lindex $smoothedDiheList($diheNum) $i0]"
    }

    close $FOUT
    
    set zeroSlopeIndexList [diffFilter $smoothedDiheList($diheNum) [getZeroSlopeIndex $smoothedDiheList($diheNum) ] $minPeakCrestDiff]
    
    set fileOut "01_diheNodes_$diheNum.txt"
    if [catch {open $fileOut w} FOUT] {
      puts "Can not open $fileOut"
      exit
    }

    set i1 [llength $zeroSlopeIndexList]
    for {set i0 0} {$i0 < $i1} {incr i0 1} {
      puts $FOUT "[lindex $zeroSlopeIndexList $i0] [lindex $smoothedDiheList($diheNum) [lindex $zeroSlopeIndexList $i0]]"
    }

    close $FOUT
    
    if {[llength $zeroSlopeIndexList] > 0} {
      if {[llength $allZeroSlopeIndexList] > 0} {
        set allZeroSlopeIndexList "$allZeroSlopeIndexList $zeroSlopeIndexList"
      } else {
        set allZeroSlopeIndexList $zeroSlopeIndexList
      }
    }
    incr diheNum 1
  }
  
  set allZeroSlopeIndexList [rmNeighborFrame [lsort -integer -unique $allZeroSlopeIndexList] $minNeighborFrame]
  if {[lindex $allZeroSlopeIndexList [expr [llength $allZeroSlopeIndexList] - 1]] != [expr $frameNum - 1]} {
    set allZeroSlopeIndexList "$allZeroSlopeIndexList [expr $frameNum - 1]"
  }
  
  for {set ii1 0} {$ii1 < $diheNum} {incr ii1 1} {
    set fileOut "01_diheNodesAll_$ii1.txt"
    if [catch {open $fileOut w} FOUT] {
      puts "Can not open $fileOut"
      exit
    }

    set i1 [llength $allZeroSlopeIndexList]
    for {set i0 0} {$i0 < $i1} {incr i0 1} {
      puts $FOUT "[lindex $allZeroSlopeIndexList $i0] [lindex $smoothedDiheList($ii1) [lindex $allZeroSlopeIndexList $i0]]"
    }

    close $FOUT
    
    set fileOut "01_diheDraw_$ii1.gnu"
    if [catch {open $fileOut w} FOUT] {
      puts "Can not open $fileOut"
      exit
    }

    puts $FOUT "set terminal pngcairo enhanced color truecolor fontscale 1.0 linewidth 3.0 size 1600,800"
    puts $FOUT "set output \"01_diheDraw_${ii1}_1.png\""
    puts $FOUT "plot \\"
    puts $FOUT "\"01_diheOri_$ii1.txt\" using 1:2 with lines linetype 1 linecolor rgb \"#000000\" title \"\", \\"
    puts $FOUT "\"01_diheSmooth_$ii1.txt\" using 1:2 with lines linetype 1 linecolor rgb \"#ff0000\" title \"\", \\"
    puts $FOUT "\"01_diheNodesAll_$ii1.txt\" using 1:2 with points pointtype 7 linecolor rgb \"#35b4ff\" title \"\", \\"
    if {[file size 01_diheNodes_$ii1.txt] > 0} {
      puts $FOUT "\"01_diheNodes_$ii1.txt\" using 1:2 with points pointtype 7 linecolor rgb \"#ffae00\" title \"\""
    }
    
    puts $FOUT "set polar"
    puts $FOUT "set grid polar"
    puts $FOUT "set angles degrees"
    puts $FOUT "set size square"
    puts $FOUT "set terminal pngcairo enhanced color truecolor fontscale 1.0 linewidth 3.0 size 1600,1600"
    puts $FOUT "set output \"01_diheDraw_${ii1}_2.png\""
    puts $FOUT "plot \\"
    puts $FOUT "\"01_diheOri_$ii1.txt\" using 2:1 with lines linetype 1 linecolor rgb \"#000000\" title \"\", \\"
    puts $FOUT "\"01_diheSmooth_$ii1.txt\" using 2:1 with lines linetype 1 linecolor rgb \"#ff0000\" title \"\", \\"
    puts $FOUT "\"01_diheNodesAll_$ii1.txt\" using 2:1 with points pointtype 7 linecolor rgb \"#35b4ff\" title \"\", \\"
    if {[file size 01_diheNodes_$ii1.txt] > 0} {
      puts $FOUT "\"01_diheNodes_$ii1.txt\" using 2:1 with points pointtype 7 linecolor rgb \"#ffae00\" title \"\""
    }

    close $FOUT
    
    exec gnuplot 01_diheDraw_$ii1.gnu
  }
  
  set fileOut "01_allNodes.txt"
  if [catch {open $fileOut w} FOUT] {
    puts "Can not open $fileOut"
    exit
  }
  
  set i1 [llength $allZeroSlopeIndexList]
  for {set i0 0} {$i0 < $i1} {incr i0 1} {
    puts $FOUT "[lindex $allZeroSlopeIndexList $i0]"
  }
  
  close $FOUT
  
  set fileOut "01_allNodesAndRefOri.txt"
  if [catch {open $fileOut w} FOUT] {
    puts "Can not open $fileOut"
    exit
  }
  
  set i1 [llength $allZeroSlopeIndexList]
  puts $FOUT "dihedral number: $diheNum"
  puts $FOUT "node number: $i1"
  for {set i0 0} {$i0 < $diheNum} {incr i0 1} {
    puts $FOUT "$diheAtomSerialList($i0)"
  }
  for {set i0 0} {$i0 < $i1} {incr i0 1} {
    puts -nonewline $FOUT "$i0 [lindex $allZeroSlopeIndexList $i0]"
    for {set i2 0} {$i2 < $diheNum} {incr i2 1} {
      puts -nonewline $FOUT " [lindex $smoothedDiheList($i2) [lindex $allZeroSlopeIndexList $i0]]"
      lappend pickedSmooDiheList($i2) [lindex $smoothedDiheList($i2) [lindex $allZeroSlopeIndexList $i0]]
    }
    puts $FOUT ""
  }
  
  close $FOUT
} elseif {$procMode eq "modify"} {
  set fileIn "01_allNodesM.txt"
  if [catch {open $fileIn r} FIN] {
    puts "Can not open $fileIn"
    exit
  }
  
  while {[gets $FIN line] >= 0} {
    lappend allZeroSlopeIndexList $line
  }
  
  close $FIN
  
  set fileIn "01_allNodesAndRefOriM.txt"
  if [catch {open $fileIn r} FIN] {
    puts "Can not open $fileIn"
    exit
  }
  
  if {[gets $FIN line] >= 0} {
    set diheNum [lindex $line 2]
  } else {
    puts "ERROR: not enough data in $fileIn?(1)"
    exit
  }
  
  if {[gets $FIN line] >= 0} {
  } else {
    puts "ERROR: not enough data in $fileIn?(2)"
    exit
  }
  
  for {set i0 0} {$i0 < $diheNum} {incr i0 1} {
    if {[gets $FIN line] >= 0} {
      set diheAtomSerialList($i0) [split $line " "]
    } else {
      puts "ERROR: not enough data in $fileIn?(5)"
      exit
    }
  }
  
  set i1 [llength $allZeroSlopeIndexList]
  for {set i0 0} {$i0 < $i1} {incr i0 1} {
    if {[gets $FIN line] >= 0} {
      set tmpList [split $line " "]
      for {set i2 0} {$i2 < $diheNum} {incr i2 1} {
        lappend pickedSmooDiheList($i2) [lindex $tmpList [expr {$i2 + 2}]]
      }
    } else {
      puts "ERROR: not enough data in $fileIn?(8)"
      exit
    }
  }
  
  close $FIN
} else {
  puts "ERROR: you should not be here...."
  exit
}

set fileOut "01_allRoutesOri.txt"
if [catch {open $fileOut w} FOUT] {
  puts "Can not open $fileOut"
  exit
}

set fileOut "01_allRoutesUnit.txt"
if [catch {open $fileOut w} FOUT2] {
  puts "Can not open $fileOut"
  exit
}

set fileOut "01_allWinNumOri.txt"
if [catch {open $fileOut w} FOUT3] {
  puts "Can not open $fileOut"
  exit
}

set fileOut "01_allWinNum.txt"
if [catch {open $fileOut w} FOUT4] {
  puts "Can not open $fileOut"
  exit
}

set i1 [llength $allZeroSlopeIndexList]
incr i1 -1
puts $FOUT "dihedral number: $diheNum"
puts $FOUT "route number: $i1"
puts $FOUT2 "dihedral number: $diheNum"
puts $FOUT2 "route number: $i1"
for {set i0 0} {$i0 < $i1} {incr i0 1} {
  set routeList($i0) ""
  set i3 [expr $i0 + 1]
  set da [deltaAngle [list [lindex $pickedSmooDiheList(0) $i0] [lindex $pickedSmooDiheList(0) $i3]]]
  set sumDa2 [expr $da * $da]
  puts -nonewline $FOUT "$da"
  lappend routeList($i0) $da
  for {set i2 1} {$i2 < $diheNum} {incr i2 1} {
    set da [deltaAngle [list [lindex $pickedSmooDiheList($i2) $i0] [lindex $pickedSmooDiheList($i2) $i3]]]
    set sumDa2 [expr $sumDa2 + $da * $da]
    puts -nonewline $FOUT " $da"
    lappend routeList($i0) $da
  }
  puts $FOUT ""
  set vecLength($i0) [expr sqrt($sumDa2)]
  if {$vecLength($i0) == [expr int($vecLength($i0))] && [expr int($vecLength($i0))] % $winStep == 0} {
    set winNum($i0) [expr int($vecLength($i0) / $winStep) + 1]
  } else {
    set winNum($i0) [expr int($vecLength($i0) / $winStep) + 2]
  }
  puts $FOUT3 "$i0 $vecLength($i0) $winNum($i0)"
  puts $FOUT4 "$i0 [expr $vecLength($i0) / ($winNum($i0) - 1) * ($winNum($i0) + 1)] [expr $winNum($i0) + 2]"
  
  set daUnit [expr [deltaAngle [list [lindex $pickedSmooDiheList(0) $i0] [lindex $pickedSmooDiheList(0) $i3]]] / $vecLength($i0)]
  puts -nonewline $FOUT2 "$daUnit"
  for {set i2 1} {$i2 < $diheNum} {incr i2 1} {
    set daUnit [expr [deltaAngle [list [lindex $pickedSmooDiheList($i2) $i0] [lindex $pickedSmooDiheList($i2) $i3]]] / $vecLength($i0)]
    puts -nonewline $FOUT2 " $daUnit"
  }
  puts $FOUT2 ""
}

close $FOUT
close $FOUT2
close $FOUT3
close $FOUT4

set fileOut "01_allRoutes.txt"
if [catch {open $fileOut w} FOUT] {
  puts "Can not open $fileOut"
  exit
}

set i1 [llength $allZeroSlopeIndexList]
incr i1 -1
puts $FOUT "dihedral number: $diheNum"
puts $FOUT "route number: $i1"
for {set i0 0} {$i0 < $i1} {incr i0 1} {
  puts -nonewline $FOUT "[expr [lindex $routeList($i0) 0] / ($winNum($i0) - 1) * ($winNum($i0) + 1)]"
  for {set i2 1} {$i2 < $diheNum} {incr i2 1} {
    puts -nonewline $FOUT " [expr [lindex $routeList($i0) $i2] / ($winNum($i0) - 1) * ($winNum($i0) + 1)]"
  }
  puts $FOUT " [expr $vecLength($i0) / ($winNum($i0) - 1) * ($winNum($i0) + 1)]"
}

close $FOUT

set fileOut "01_allDTMD_Ref.txt"
if [catch {open $fileOut w} FOUT] {
  puts "Can not open $fileOut"
  exit
}

set i1 [llength $allZeroSlopeIndexList]
incr i1 -1
puts $FOUT "dihedral number: $diheNum"
puts $FOUT "route number: $i1"
for {set i0 0} {$i0 < $diheNum} {incr i0 1} {
  puts $FOUT "$diheAtomSerialList($i0)"
}
for {set i0 0} {$i0 < $i1} {incr i0 1} {
  set i3 [expr [lindex $routeList($i0) 0] / ($winNum($i0) - 1)]
  puts -nonewline $FOUT "[deltaAngle [list $i3 [lindex $pickedSmooDiheList(0) $i0]]]"
  for {set i2 1} {$i2 < $diheNum} {incr i2 1} {
    set i3 [expr [lindex $routeList($i0) $i2] / ($winNum($i0) - 1)]
    puts -nonewline $FOUT " [deltaAngle [list $i3 [lindex $pickedSmooDiheList($i2) $i0]]]"
  }
  puts $FOUT ""
  set i3 [expr [lindex $routeList($i0) 0] / ($winNum($i0) - 1) * $winNum($i0)]
  puts -nonewline $FOUT "[deltaAngle [list -$i3 [lindex $pickedSmooDiheList(0) $i0]]]"
  for {set i2 1} {$i2 < $diheNum} {incr i2 1} {
    set i3 [expr [lindex $routeList($i0) $i2] / ($winNum($i0) - 1) * $winNum($i0)]
    puts -nonewline $FOUT " [deltaAngle [list -$i3 [lindex $pickedSmooDiheList($i2) $i0]]]"
  }
  puts $FOUT ""
}

close $FOUT

set fileOut "01_allWinIndex.txt"
if [catch {open $fileOut w} FOUT] {
  puts "Can not open $fileOut"
  exit
}

set i1 [llength $allZeroSlopeIndexList]
incr i1 -1
set numWinIndexPair 0
for {set i0 0} {$i0 < $i1} {incr i0 1} {
  animate write namdbin 01_r${i0}w0.coor beg [lindex $allZeroSlopeIndexList $i0] end [lindex $allZeroSlopeIndexList $i0] sel $allSel0 waitfor all 0
  set winIndexPair($numWinIndexPair) [list r${i0}w0 [lindex $allZeroSlopeIndexList $i0]]
  puts $FOUT "$winIndexPair($numWinIndexPair)"
  incr numWinIndexPair 1
  set firstWinFrameIndex [lindex $allZeroSlopeIndexList $i0]
  set lastWinFrameIndex [lindex $allZeroSlopeIndexList [expr $i0 + 1]]
  set winFrameIndexStep [expr ($lastWinFrameIndex - $firstWinFrameIndex) / ($winNum($i0) - 1.0)]
  set i3 [expr $winNum($i0) + 1]
  for {set i2 1} {$i2 < $i3} {incr i2 1} {
    set i4 [expr int($firstWinFrameIndex + ($i2 - 1) * $winFrameIndexStep)]
    animate write namdbin 01_r${i0}w$i2.coor beg $i4 end $i4 sel $allSel0 waitfor all 0
    set winIndexPair($numWinIndexPair) [list r${i0}w$i2 $i4]
    puts $FOUT "$winIndexPair($numWinIndexPair)"
    incr numWinIndexPair 1
  }
  animate write namdbin 01_r${i0}w$i3.coor beg $i4 end $i4 sel $allSel0 waitfor all 0
  set winIndexPair($numWinIndexPair) [list r${i0}w$i3 $i4]
  puts $FOUT "$winIndexPair($numWinIndexPair)"
  incr numWinIndexPair 1
}

close $FOUT

animate delete beg 0 end -1 0

# to get initial velocity file of every route
#to mol 0
mol addfile $inVelNamdbin type namdbin waitfor all
mol addfile $inVelDcd type dcd first 0 last -1 waitfor all

for {set i0 0} {$i0 < $numWinIndexPair} {incr i0 1} {
  animate write namdbin "01_[lindex $winIndexPair($i0) 0].vel" beg [lindex $winIndexPair($i0) 1] end [lindex $winIndexPair($i0) 1] sel $allSel0 waitfor all 0
}

animate delete beg 0 end -1 0

# to get initial cell size file of every routs
if [catch {open $inXst r} FIN] {
  puts "ERROR: Cannot open $inXst"
  exit 1
}

if {[gets $FIN line] < 0} {
  puts "ERROR: Empty $inXst file?"
  exit
}
if {[gets $FIN line] >= 0} {
  if {[string equal $line "#\$LABELS step o_x o_y o_z"] == 1} {
    puts "in vacuum"
    set enviroment 0
  } elseif {[string equal $line "#\$LABELS step a_x a_y a_z b_x b_y b_z c_x c_y c_z o_x o_y o_z s_x s_y s_z s_u s_v s_w"] == 1} {
    puts "in solution"
    set enviroment 1
  } else {
    puts "ERROR: new xst file format?"
    exit
  }
}

set i0 0
set i2 0
gets $FIN line
if {$enviroment == 0} {
  while {1} {
    if {$i2 == [lindex $winIndexPair($i0) 1]} {
      set outName "01_[lindex $winIndexPair($i0) 0].xsc"
      if [catch {open $outName w} FOUT] {
        puts "ERROR: Can not open $outName"
        exit
      }
      puts $FOUT "# NAMD extended system configuration output file"
      puts $FOUT "#\$LABELS step o_x o_y o_z"
      puts $FOUT "$line"
      close $FOUT
      
      incr i0 1
      if {$i0 == $numWinIndexPair} {
        break;
      }
    } else {
      incr i2 1
      gets $FIN line
    }
  }
} elseif {$enviroment == 1} {
  while {1} {
    if {$i2 == [lindex [lindex $winIndexPair($i0) 1]} {
      set outName "01_[lindex $winIndexPair($i0) 0].xsc"
      if [catch {open $outName w} FOUT] {
        puts "ERROR: Can not open $outName"
        exit
      }
      puts $FOUT "# NAMD extended system configuration output file"
      puts $FOUT "#\$LABELS step a_x a_y a_z b_x b_y b_z c_x c_y c_z o_x o_y o_z s_x s_y s_z s_u s_v s_w"
      puts $FOUT "$line"
      close $FOUT
      
      incr i0 1
      if {$i0 == $numWinIndexPair} {
        break;
      }
    } else {
      incr i2 1
      gets $FIN line
    }
  }
} else {
  puts "ERROR: wrong script?"
  exit
}

close $FIN


exit
