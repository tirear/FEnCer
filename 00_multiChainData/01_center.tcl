# mol 0
mol new "../../../../q2_H.psf" type psf waitfor all
mol addfile "../../../../equi_re_01.coor" type namdbin waitfor all
set useTrans 1
set useSpin 0

# reference and corresponding
set frameNum [molinfo 0 get numframes]
set allSel [atomselect 0 "all"]
set refSeg "A"
set refRestAtomSeletion "resid 1 and name CA"
set refSel [atomselect 0 "segname $refSeg and $refRestAtomSeletion"]
set dummyCoor [measure center $refSel]
set axisName(0) "X"
set axisName(1) "Y"
set axisName(2) "Z"
set axis(0) "axis (1, 0, 0)"
set axis(1) "axis (0, 1, 0)"
set axis(2) "axis (0, 0, 1)"

# translation
set transSegRefList {A A A B B}
set transSegSelList {A A B B B}
set transRefList    {{resid 1 and name CA} {resid 1 and name CA} {resid 1 and name CA} {resid 1 and name CA} {resid 1 and name CA}}
set transSelList    {{resid 1 and name C}  {resid 1 and name CB} {resid 1 and name CA} {resid 1 and name C}  {resid 1 and name CB}}
set transPairNum [llength $transSegSelList]

# spin angle
set spinAngleSegSelList {A B}
set spinAngleSelList    {{resid 1 and name CA C O} {resid 1 and name CA C O}}
set spinAnglePairNum [llength $spinAngleSegSelList]
set refSpinAngleAtomSeletion "resid 1 and name CA C O"
set refSpinAngleSel [atomselect 0 "segname $refSeg and $refSpinAngleAtomSeletion"]

if {$useSpin == 1} {
  $allSel set occupancy 0
  $refSpinAngleSel set occupancy 2
  animate write pdb "orieRefSRO.pdb" beg 0 end 0 sel $allSel waitfor all 0
  
  $allSel set occupancy 0
  $refSpinAngleSel set occupancy 2
  # to avoid parallel problem
  $allSel move [trans center [measure center $refSpinAngleSel] axis z 90]
  $allSel move [trans center [measure center $refSpinAngleSel] axis y 90]
  animate write pdb "orieRefSR.pdb" beg 0 end 0 sel $allSel waitfor all 0
}

puts ""
puts "ref center atom number: [$refSel num]"
puts ""

set fileOut "multiChain.in"
if [catch {open $fileOut w} FOUT] {
  puts "Can not open $fileOut"
  exit
}

set fileOut "01_1settingsRef.txt"
if [catch {open $fileOut w} FOUT2] {
  puts "Can not open $fileOut"
  exit
}

puts $FOUT "colvarsTrajFrequency     1"
puts $FOUT "colvarsRestartFrequency  1000000"

if {$useTrans == 1} {
  puts $FOUT2 "refDataFile                  \[path to file multiChain_out.colvars.traj\]"
  puts $FOUT2 "segNameOfStopTranslation     $refSeg"
  puts $FOUT2 "atomselectOf_ST_Ref          $refRestAtomSeletion"
  puts $FOUT2 "TranslatableSegNameRef       $transSegRefList"
  puts $FOUT2 "TranslatableSegNameSel       $transSegSelList"
  
  for {set i 0} {$i < $transPairNum} {incr i 1} {
    set transRef [atomselect 0 "segname [lindex $transSegRefList $i] and [lindex $transRefList $i]"]
    set transRefSerial [$transRef get serial]
    $transRef delete
    set transSel [atomselect 0 "segname [lindex $transSegSelList $i] and [lindex $transSelList $i]"]
    set transSerial [$transSel get serial]
    $transSel delete
    
    puts $FOUT2 "atomselectOf_T_Ref$i          [lindex $transRefList $i]"
    puts $FOUT2 "atomselectOf_T_Sel$i          [lindex $transSelList $i]"
    
    for {set j 0} {$j < 3} {incr j 1} {
      puts $FOUT "colvar {"
      puts $FOUT "  name trans$axisName($j)_[lindex $transSegSelList $i]_${refSeg}_$i"
      puts $FOUT "  outputValue        on"
      puts $FOUT "  distanceZ {"
      puts $FOUT "    $axis($j)"
      puts $FOUT "    main {"
      puts $FOUT "      atomNumbers {"
      puts $FOUT "        $transSerial"
      puts $FOUT "      }"
      puts $FOUT "    }"
      puts $FOUT "    ref {"
      puts $FOUT "      atomNumbers {"
      puts $FOUT "        $transRefSerial"
      puts $FOUT "      }"
      puts $FOUT "      disableForces on"
      puts $FOUT "    }"
      puts $FOUT "  }"
      puts $FOUT "}"
    }
  }
  
  puts $FOUT2 "coordinateOfDummyAtom        $dummyCoor"
}

if {$useSpin == 1} {
  if {$spinAnglePairNum > 0} {
    puts $FOUT2 "segNameOfStopRotation        $refSeg"
    puts $FOUT2 "atomselectOf_SR_Ref          $refSpinAngleAtomSeletion"
    puts $FOUT2 "centerOfStopRotation         1 0 0 0"
    puts $FOUT2 "refPositionsFile_SR          \[path to file orieRefSR.pdb\]"
    puts -nonewline $FOUT2 "segNameOfOrientationPair    "
    for {set i 0} {$i < $spinAnglePairNum} {incr i 1} {
      puts -nonewline $FOUT2 " [lindex $spinAngleSegSelList $i] $refSeg"
    }
    puts $FOUT2 ""
  } else {
    puts $FOUT2 "segNameOfStopRotation        $refSeg"
    puts $FOUT2 "atomselectOf_SR_Ref          $refSpinAngleAtomSeletion"
    puts $FOUT2 "centerOfStopRotation         1 0 0 0"
    puts $FOUT2 "refPositionsFile_SR          \[path to file orieRefSR.pdb\]"
    puts $FOUT2 "segNameOfOrientationPair     "
  }
  
  for {set i 0} {$i < $spinAnglePairNum} {incr i 1} {
    set spinAngleSel [atomselect 0 "segname [lindex $spinAngleSegSelList $i] and [lindex $spinAngleSelList $i]"]
    set serialSA [$spinAngleSel get serial]
    $spinAngleSel delete
    
    puts $FOUT2 "atomselectOf_OP_Ref$i         [lindex $spinAngleSelList $i]"
    
    for {set j 0} {$j < 3} {incr j 1} {
      puts $FOUT "colvar {"
      puts $FOUT "  name spinAngle$axisName($j)_[lindex $spinAngleSegSelList $i]_$refSeg"
      puts $FOUT "  outputValue        on"
      puts $FOUT "  spinAngle {"
      puts $FOUT "    $axis($j)"
      puts $FOUT "    atoms {"
      puts $FOUT "      atomNumbers {"
      puts $FOUT "        $serialSA"
      puts $FOUT "      }"
      puts $FOUT "    }"
      puts $FOUT "    refPositionsFile     orieRefSR.pdb"
      puts $FOUT "    refPositionsCol      O"
      puts $FOUT "    refPositionsColValue 2"
      puts $FOUT "  }"
      puts $FOUT "}"
    }
  }
  
  for {set i 0} {$i < $spinAnglePairNum} {incr i 1} {
    puts $FOUT2 "refPositionsFile_OP$i         \[path to file orieRefSR.pdb\]"
  }
} else {
  puts $FOUT2 "segNameOfStopRotation        "
}

close $FOUT
close $FOUT2
exit
