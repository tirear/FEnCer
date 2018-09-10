#!/usr/bin/perl

use strict;

# perl 02_1buildDTMD.pl 1000 100 1000 10000 "deca-ala_H_v.psf" "helix-deca-ala_H_v.pdb" "par_all27_prot_na.txt" 300 0.05
#                       0    1   2    3     4                  5                        6                       7   8

if($#ARGV != 8)
{
  print "perl 02_1buildDTMD.pl 0 1 2 3 4 5 6 7 8\n";
  print "0: dcd output file saving period\n";
  print "1: collective varialbe saving period\n";
  print "2: minimization step\n";
  print "3: run step\n";
  print "4: psf file name\n";
  print "5: pdb file name\n";
  print "6: par file name\n";
  print "7: temprature (K)\n";
  print "8: force constant\n\n";
  exit;
}

my $dcdPeriod =    $ARGV[0];
my $colvarPeriod = $ARGV[1];
my $miniStep =     $ARGV[2];
my $runStep =      $ARGV[3];
my $psfName =      $ARGV[4];
my $pdbName =      $ARGV[5];
my $parName =      $ARGV[6];
my $temprature =   $ARGV[7];
my $fc =           $ARGV[8];
my $totalStep = $miniStep + $runStep;
my $line;
my @word;
my @i;
my $fileIn;
my $fileOut;
my $diheNum;
my $routeNum;
my @winNum;
my @diheSet;
my @diheRefLine1;
my @diheRefLine2;
my @diheRef1;
my @diheRef2;
my @diheRefStep;
my $diheRef;
my @colvarLine;
my @namdScriptLine;
my $inPre = "01_r";
my $namdScriptPre="02_dtmd";

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
chomp($line);
@word = split(/\s+/, "$line");
$routeNum = 0;
$routeNum = $word[2];
if($routeNum == 0)
{
  print "ERROR: something wrong in $fileIn? (1)\n";
  exit;
}

for($i[0] = 0, $i[1] = $diheNum; $i[0] < $i[1]; $i[0]++)
{
  $line = <FIN>;
  chomp($line);
  if($line eq "")
  {
    print "ERROR: something wrong in $fileIn? (2)\n";
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
    print "ERROR: something wrong in $fileIn? (3)\n";
    exit;
  }
  push(@diheRefLine1, $line);
  
  $line = <FIN>;
  chomp($line);
  if($line eq "")
  {
    print "ERROR: something wrong in $fileIn? (4)\n";
    exit;
  }
  push(@diheRefLine2, $line);
  
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
  chomp($line);
  push(@namdScriptLine, $line);
}

close FIN;

for($i[0] = 0, $i[1] = $routeNum; $i[0] < $i[1]; $i[0]++)
{
  @diheRef1 = split(/\s+/, "$diheRefLine1[$i[0]]");
  @diheRef2 = split(/\s+/, "$diheRefLine2[$i[0]]");
  undef @diheRefStep;
  for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
  {
    if(abs($diheRef2[$i[2]] - $diheRef1[$i[2]]) > 180)
    {
      if($diheRef1[$i[2]] < 0)
      {
        $diheRef1[$i[2]] += 360;
      }
      else
      {
        $diheRef2[$i[2]] += 360;
      }
    }
    $diheRefStep[$i[2]] = ($diheRef2[$i[2]] - $diheRef1[$i[2]]) / ($winNum[$i[0]] - 1);
  }
  for($i[6] = 0, $i[7] = $winNum[$i[0]]; $i[6] < $i[7]; $i[6]++)
  {
    $fileOut = "$namdScriptPre.in";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }
    
    print FOUT "colvarsTrajFrequency    $colvarPeriod\n";
    print FOUT "colvarsRestartFrequency $dcdPeriod\n";
    
    for($i[2] = 0, $i[3] = $diheNum; $i[2] < $i[3]; $i[2]++)
    {
      $diheRef = $diheRef1[$i[2]] + $i[6] * $diheRefStep[$i[2]];
      print FOUT "colvar {\n";
      print FOUT "  name MDDV$i[2]\n";
      print FOUT "  outputValue        on\n";
      print FOUT "  outputSystemForce  off\n";
      print FOUT "  outputAppliedForce off\n";
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
      print FOUT "  forceConstant $fc\n";
      print FOUT "  centers $diheRef\n";
      print FOUT "}\n";
    }
    
    foreach (@colvarLine)
    {
      print FOUT "$_\n";
    }
    
    close FOUT;
    
    $fileOut = "$namdScriptPre.namd";
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
        print FOUT "$_../../../../$psfName\n";
      }
      elsif($word[0] eq "coordinates" && $word[1] eq "")
      {
        print FOUT "$_../../../../$pdbName\n";
      }
      elsif($word[0] eq "extendedSystem" && $word[1] eq "")
      {
        print FOUT "$_${inPre}$i[0]w$i[6].xsc\n";
      }
      elsif($word[0] eq "bincoordinates" && $word[1] eq "")
      {
        print FOUT "$_${inPre}$i[0]w$i[6].coor\n";
      }
      elsif($word[0] eq "binvelocities" && $word[1] eq "")
      {
        print FOUT "$_${inPre}$i[0]w$i[6].vel\n";
      }
      elsif($word[0] eq "parameters" && $word[1] eq "")
      {
        print FOUT "$_../../../../$parName\n";
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
      elsif($word[0] eq "outputname" && $word[1] eq "")
      {
        print FOUT "$_${namdScriptPre}_out_1\n";
      }
      elsif($word[0] eq "restartname" && $word[1] eq "")
      {
        print FOUT "$_${namdScriptPre}_re_1\n";
      }
      elsif($word[0] eq "restartfreq" && $word[1] eq "")
      {
        print FOUT "$_$dcdPeriod\n";
      }
      elsif($word[0] eq "velDCDfile" && $word[1] eq "")
      {
        print FOUT "$_${namdScriptPre}_out_1.velDcd\n";
      }
      elsif($word[0] eq "velDCDfreq" && $word[1] eq "")
      {
        print FOUT "$_$dcdPeriod\n";
      }
      elsif($word[0] eq "colvarsConfig" && $word[1] eq "")
      {
        print FOUT "$_$namdScriptPre.in\n";
      }
      elsif($word[0] eq "firstTimeStep" && $word[1] eq "")
      {
        print FOUT "${_}0\n";
      }
      elsif($word[0] eq "run" && $word[1] eq "")
      {
        print FOUT "minimize $miniStep\n";
        print FOUT "$_$runStep\n";
      }
      else
      {
        print FOUT "$_\n";
      }
    }
    
    close FOUT;
    
    if(-e "mdData" == 0)
    {
      system("mkdir mdData");
    }
    if(-e "mdData/r$i[0]" == 0)
    {
      system("mkdir mdData/r$i[0]");
    }
    if(-e "mdData/r$i[0]/w$i[6]" == 0)
    {
      system("mkdir mdData/r$i[0]/w$i[6]");
    }
    if(-e "mdData/r$i[0]/w$i[6]/00_DTMD" == 0)
    {
      system("mkdir mdData/r$i[0]/w$i[6]/00_DTMD");
    }
    
    system("mv $inPre$i[0]w$i[6].coor $inPre$i[0]w$i[6].vel $inPre$i[0]w$i[6].xsc mdData/r$i[0]/w$i[6]/00_DTMD/");
    system("mv $namdScriptPre.in $namdScriptPre.namd mdData/r$i[0]/w$i[6]/00_DTMD/");
  }
}

exit;
