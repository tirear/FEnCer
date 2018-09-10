use strict;

# perl 04_1buildUS.pl vmd "deca-ala_H_v.psf" "helix-deca-ala_H_v.pdb" "par_all27_prot_na.txt" 0.1 10000 10 300
#                     0   1                  2                        3                       4   5     6  7

if($#ARGV != 7)
{
  print "perl 04_1buildUS.pl 0 1 2 3 4 5 6 7\n";
  print "0: vmd path\n";
  print "1: psf file name\n";
  print "2: pdb file name\n";
  print "3: parameter file name\n";
  print "4: dihedral step size between windows\n";
  print "5: dcd output file saving period\n";
  print "6: collective varialbe saving period\n";
  print "7: temprature (K)\n\n";
#   print "8: force constant for the distance restraint\n\n";
  exit;
}

my $vmd =          $ARGV[0];
my $psf =          $ARGV[1];
my $pdb =          $ARGV[2];
my $par =          $ARGV[3];
my $winStep =      $ARGV[4];
my $dcdPeriod =    $ARGV[5];
my $colvarPeriod = $ARGV[6];
my $temprature =   $ARGV[7];
# my $d2mddvFc =     $ARGV[8];
# my $d2mddvFc = 0;
my $fileIn;
my $fileOut;
my $line;
my @word;
my @word2;
my @i;
my $routeNum;
my @angleVecCmpnts;
my @angleVecLength;
my @angleVecCmpntSteps;
my @winNum;
my $diheNum;
my @diheSet;
my @diheRefLine;
my $namdScriptPre = "04_w";
my @colvarLine;
my @namdScriptLine;
my $center;
my $bad;
my @routeVecUnit;

$fileIn = "01_allRoutes.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

$line = <FIN>;
$line = <FIN>;
chomp($line);
@word = split(/\s+/, "$line");
$routeNum = 0;
$routeNum = $word[2];
if($routeNum == 0)
{
  print "ERROR: something wrong in $fileIn?\n";
  exit;
}

$i[0] = 0;
while($line = <FIN>)
{
  chomp($line);
  @{$angleVecCmpnts[$i[0]]} = split(/\s+/, "$line");
  $angleVecLength[$i[0]] = pop(@{$angleVecCmpnts[$i[0]]});
  $i[0]++;
}

close FIN;

$fileIn = "01_allWinNum.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

while($line = <FIN>)
{
  chomp($line);
  @word = split(/\s+/, "$line");
  push(@winNum, $word[2]);
}

close FIN;

if($i[0] != $routeNum)
{
  print "ERROR: not enough route vector lines ($i[0]) in $fileIn\n";
  exit;
}

close FIN;

$fileIn = "01_allDTMD_Ref.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

$line = <FIN>;
chomp($line);
@word = split(/\s+/, "$line");
$diheNum = 0;
$diheNum = $word[2];
if($diheNum == 0)
{
  print "ERROR: something wrong in $fileIn? (0)\n";
  exit;
}

$line = <FIN>;
for($i[0] = 0, $i[1] = $diheNum; $i[0] < $i[1]; $i[0]++)
{
  $line = <FIN>;
  chomp($line);
  if($line eq "")
  {
    print "ERROR: something wrong in $fileIn? (1)\n";
    exit;
  }
  push(@diheSet, $line);
}

for($i[0] = 0, $i[1] = $routeNum; $i[0] < $i[1]; $i[0]++)
{
  $line = <FIN>;
  chomp($line);
  if($line eq "")
  {
    print "ERROR: something wrong in $fileIn? (2)\n";
    exit;
  }
  push(@diheRefLine, $line);
  $line = <FIN>;
}

close FIN;

$fileIn = "01_allRoutesUnit.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Cannot open $fileIn\n";
  exit;
}

$line = <FIN>;
$line = <FIN>;
$i[0] = 0;
while($line = <FIN>)
{
  chomp($line);
  @{$routeVecUnit[$i[0]]} = split(/\s+/, "$line");
  $i[0]++;
}

close FIN;

$fileIn = "02_colvar_template.in";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

while($line = <FIN>)
{
  chomp($line);
  push(@colvarLine, $line);
}

close FIN;

$fileIn = "02_namd_template.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

while($line = <FIN>)
{
  if($line =~ /velDCDfile/ || $line =~ /velDCDfreq/)
  {}
  else
  {
    chomp($line);
    push(@namdScriptLine, $line);
  }
}

close FIN;

$bad = 0;
for($i[0] = 0, $i[1] = $routeNum; $i[0] < $i[1]; $i[0]++)
{
  for($i[6] = 0, $i[7] = $winNum[$i[0]]; $i[6] < $i[7]; $i[6]++)
  {
    print " r$i[0]w$i[6]";
    
    $fileIn = "mdData/r$i[0]/w$i[6]/00_DTMD/02_dtmd.out";
    if(open(FIN, "$fileIn") != 1)
    {
      print "ERROR: Can not open $fileIn\n";
      exit;
    }
    
    while($line = <FIN>)
    {
      if($line =~ /error/i && $line !~ /^Info/)
      {
        print "ERROR: There are errors in $fileIn\n";
        $bad = 1;
      }
    }
    if($bad == 1)
    {
      next;
    }
    
    close FIN;
    
    @angleVecCmpntSteps = map {$_ / ($winNum[$i[0]] - 1)} @{$angleVecCmpnts[$i[0]]};
    
    $fileOut = "mdData/r$i[0]/w$i[6]/$namdScriptPre$i[6].in";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }
    
    print FOUT "colvarsTrajFrequency    $colvarPeriod\n";
    print FOUT "colvarsRestartFrequency $dcdPeriod\n";
    
#     print FOUT "colvar {\n";
#     print FOUT "  name DIST2MDDV\n";
#     print FOUT "  outputValue        on\n";
#     print FOUT "  outputSystemForce  off\n";
#     print FOUT "  outputAppliedForce off\n";
#     print FOUT "  width 1\n";
#     print FOUT "\n";
#     print FOUT "  scriptedFunction stayWarm\n";
#     for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
#     {
#       $i[5] = $i[2] + 1;
#       print FOUT "  dihedral {\n";
#       print FOUT "    componentExp $i[5]\n";
#       $i[4] = 1;
#       foreach (split(/\s+/, "$diheSet[$i[2]]"))
#       {
#         print FOUT "    group$i[4] {\n";
#         print FOUT "      atomNumbers {$_}\n";
#         print FOUT "    }\n";
#         $i[4]++;
#       }
#       print FOUT "  }\n";
#     }
#     print FOUT "}\n";
#     print FOUT "harmonic {\n";
#     print FOUT "  colvars DIST2MDDV\n";
#     print FOUT "  forceConstant $d2mddvFc\n";
#     print FOUT "  centers 0.0\n";
#     print FOUT "}\n";
    
    @word = split(/\s+/, "$diheRefLine[$i[0]]");
    for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
    {
      $center = $word[$i[2]] + $angleVecCmpntSteps[$i[2]] * $i[6];
      if($center > 180)
      {
        $center -= 360;
      }
      elsif($center <= -180)
      {
        $center += 360;
      }
      print FOUT "colvar {\n";
      print FOUT "  name MDDV$i[2]\n";
      print FOUT "  outputValue        on\n";
      print FOUT "  outputSystemForce  off\n";
      print FOUT "  outputAppliedForce on\n";
      print FOUT "  width 1\n";
      print FOUT "  lowerboundary -180.0\n";
      print FOUT "  upperboundary 180.0\n";
      print FOUT "  dihedral {\n";
      $i[4] = 1;
      foreach (split(/\s+/, "$diheSet[$i[2]]"))
      {
        print FOUT "    group$i[4] {\n";
        print FOUT "      atomNumbers {$_}\n";
        print FOUT "    }\n";
        $i[4]++;
      }
      print FOUT "  }\n";
      print FOUT "}\n";
      print FOUT "harmonic {\n";
      print FOUT "  colvars MDDV$i[2]\n";
      print FOUT "  forceConstant \n";
      print FOUT "  centers $center\n";
      print FOUT "}\n";
    }
    
    foreach (@colvarLine)
    {
      print FOUT "$_\n";
    }
    
    close FOUT;
    
    $fileOut = "mdData/r$i[0]/w$i[6]/$namdScriptPre$i[6].namd";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }
    
    foreach (@namdScriptLine)
    {
      @word = split(/\s+/, "$_");
      if($word[0] eq "structure" && $word[1] eq "")
      {
        print FOUT "$_../../../$psf\n";
      }
      elsif($word[0] eq "coordinates" && $word[1] eq "")
      {
        print FOUT "$_../../../$pdb\n";
      }
      elsif($word[0] eq "extendedSystem" && $word[1] eq "")
      {
        print FOUT "${_}00_DTMD/02_dtmd_re_1.xsc\n";
      }
      elsif($word[0] eq "bincoordinates" && $word[1] eq "")
      {
        print FOUT "${_}00_DTMD/02_dtmd_re_1.coor\n";
      }
      elsif($word[0] eq "binvelocities" && $word[1] eq "")
      {
        print FOUT "${_}00_DTMD/02_dtmd_re_1.vel\n";
      }
      elsif($word[0] eq "parameters" && $word[1] eq "")
      {
        print FOUT "$_../../../$par\n";
      }
      elsif($word[0] eq "xstFreq" && $word[1] eq "")
      {
        print FOUT "$_$dcdPeriod\n";
      }
      elsif($word[0] eq "dcdFreq" && $word[1] eq "")
      {
        print FOUT "$_$dcdPeriod\n";
      }
      elsif($word[0] eq "langevinTemp" && $word[1] eq "")
      {
        print FOUT "$_$temprature\n";
      }
      elsif($word[0] eq "langevinPistonTemp" && $word[1] eq "")
      {
        print FOUT "$_$temprature\n";
      }
      elsif($word[0] eq "restartfreq" && $word[1] eq "")
      {
        print FOUT "$_$dcdPeriod\n";
      }
#       elsif($word[0] eq "run" && $word[1] eq "")
#       {
#         print FOUT "tclForces on\n";
#         print FOUT "tclForcesScript {\n";
#         print FOUT "  proc calcforces {} {}\n";
#         print FOUT "\n";
#         print FOUT "  proc deltaAngle {angles} {\n";
#         print FOUT "    set da [expr [lindex \$angles 1] - [lindex \$angles 0]]\n";
#         print FOUT "    if {\$da > 180} {\n";
#         print FOUT "      set da [expr \$da - 360]\n";
#         print FOUT "    } elseif {\$da <= -180} {\n";
#         print FOUT "      set da [expr \$da + 360]\n";
#         print FOUT "    }\n";
#         print FOUT "    return \$da\n";
#         print FOUT "  }\n";
#         print FOUT "\n";
#         print FOUT "  proc calc_stayWarm {pB0";
#         $i[3] = $diheNum - 1;
#         print FOUT " pB$_" foreach (1..$i[3]);
#         print FOUT "} {\n";
#         for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
#         {
#           print FOUT "    set uvAC$i[2] $routeVecUnit[$i[0]][$i[2]]\n";
#         }
#         @word2 = split(/\s+/, "$diheRefLine[$i[0]]");
#         for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
#         {
#           $center = $word2[$i[2]] + $angleVecCmpntSteps[$i[2]] * $i[6];
#           if($center > 180)
#           {
#             $center -= 360;
#           }
#           elsif($center <= -180)
#           {
#             $center += 360;
#           }
#           print FOUT "    set pA$i[2] $center\n";
#         }
#         for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
#         {
#           print FOUT "    set vAB$i[2] [deltaAngle \"\$pA$i[2] \$pB$i[2]\"]\n";
#         }
#         print FOUT "    set vAB_length2 [expr \$vAB0*\$vAB0";
#         $i[3] = $diheNum - 1;
#         print FOUT " + \$vAB$_*\$vAB$_" foreach (1..$i[3]);
#         print FOUT "]\n";
#         print FOUT "    set vAB_dot_uvAC [expr \$vAB0*\$uvAC0";
#         $i[3] = $diheNum - 1;
#         print FOUT "  + \$vAB$_*\$uvAC$_" foreach (1..$i[3]);
#         print FOUT "]\n";
#         print FOUT "    set vAC_length2 [expr \$vAB_dot_uvAC*\$vAB_dot_uvAC]\n";
#         print FOUT "    set vBC_length [expr sqrt(\$vAB_length2 - \$vAC_length2)]\n";
#         print FOUT "    set vBC_lengthMod [expr pow(\$vBC_length, 4)]\n";
#         print FOUT "    return \$vBC_length\n";
#         print FOUT "  }\n";
#         print FOUT "\n";
#         print FOUT "  proc calc_stayWarm_gradient {pB0";
#         $i[3] = $diheNum - 1;
#         print FOUT " pB$_" foreach (1..$i[3]);
#         print FOUT "} {\n";
#         for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
#         {
#           print FOUT "    set uvAC$i[2] $routeVecUnit[$i[0]][$i[2]]\n";
#         }
#         @word2 = split(/\s+/, "$diheRefLine[$i[0]]");
#         for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
#         {
#           $center = $word2[$i[2]] + $angleVecCmpntSteps[$i[2]] * $i[6];
#           if($center > 180)
#           {
#             $center -= 360;
#           }
#           elsif($center <= -180)
#           {
#             $center += 360;
#           }
#           print FOUT "    set pA$i[2] $center\n";
#         }
#         for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
#         {
#           print FOUT "    set vAB$i[2] [deltaAngle \"\$pA$i[2] \$pB$i[2]\"]\n";
#         }
#         print FOUT "    set vAB_dot_uvAC [expr \$vAB0*\$uvAC0";
#         $i[3] = $diheNum - 1;
#         print FOUT " + \$vAB$_*\$uvAC$_" foreach (1..$i[3]);
#         print FOUT "]\n";
#         print FOUT "#    set t [expr \$vAB_dot_uvAC / 1]\n";
#         for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
#         {
#           print FOUT "    set pC$i[2] [deltaAngle \"-\$pA$i[2] [expr \$vAB_dot_uvAC * \$pA$i[2]]\"]\n";
#         }
#         for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
#         {
#           print FOUT "    set vBC$i[2] [deltaAngle \"\$pB$i[2] \$pA$i[2]\"]\n";
#         }
#         print FOUT "    set vBC_length [expr sqrt(\$vBC0*\$vBC0";
#         $i[3] = $diheNum - 1;
#         print FOUT "  + \$vBC$_*\$vBC$_" foreach (1..$i[3]);
#         print FOUT ")]\n";
#         print FOUT "\n";
#         print FOUT "    if {\$vBC_length == 0} {\n";
#         print FOUT "      return \"0";
#         $i[3] = $diheNum - 1;
#         print FOUT " 0" foreach (1..$i[3]);
#         print FOUT "\"\n";
#         print FOUT "    }\n";
#         print FOUT "    return \"[expr -\$vBC0*pow(\$vBC_length,3)]";
#         $i[3] = $diheNum - 1;
#         print FOUT " [expr -\$vBC$_*pow(\$vBC_length,3)]" foreach (1..$i[3]);
#         print FOUT "\"\n";
#         print FOUT "  }\n";
#         print FOUT "}\n";
#         print FOUT "$_\n";
#       }
      else
      {
        print FOUT "$_\n";
      }
    }
    
    close FOUT;
  }
}

print "\n";

exit;
