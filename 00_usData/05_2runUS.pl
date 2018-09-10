# use Inline C;
use strict;
use POSIX;

sub angleRangeMod
{
  my $arm = $_[0];
  
  if($arm > 180)
  {
    $arm -= 360;
  }
  elsif($arm <= -180)
  {
    $arm += 360;
  }
  
  return $arm;
}

sub angleRangeModArr
{
  my $arma = $_[0];
  my @arma_i;
  
  for($arma_i[0] = 0, $arma_i[1] = $#{$arma} + 1; $arma_i[0] < $arma_i[1]; $arma_i[0]++)
  {
    if(${$arma}[$arma_i[0]] > 180)
    {
      ${$arma}[$arma_i[0]] -= 360;
    }
    elsif(${$arma}[$arma_i[0]] <= -180)
    {
      ${$arma}[$arma_i[0]] += 360;
    }
  }
}

sub deltaAngleArr
{
  my $daa_a0 = $_[0];
  my $daa_a1 = $_[1];
  my @daArr;
  
  @daArr = map { ${$daa_a1}[$_] - ${$daa_a0}[$_] } 0..$#{$daa_a0};
  angleRangeModArr(\@daArr);
  
  return @daArr;
}

sub vecProjUnit
{
  my $vpu_coorNow = $_[0];
  my $vpu_refCoor = $_[1];
  my $vpu_routeVec = $_[2];
  my @vpu_routeVecNow;
  my $vpu_vecProjLen;
  my @vpu_i;
  
  @vpu_routeVecNow = deltaAngleArr(\@{$vpu_refCoor}, \@{$vpu_coorNow});

  $vpu_vecProjLen = 0;
  for($vpu_i[0] = 0, $vpu_i[1] = $#{$vpu_routeVec} + 1; $vpu_i[0] < $vpu_i[1]; $vpu_i[0]++)
  {
    $vpu_vecProjLen += ${$vpu_routeVec}[$vpu_i[0]] * $vpu_routeVecNow[$vpu_i[0]];
  }
  
  return $vpu_vecProjLen;
}

sub totalWork
{
  my $tw_refCoor =  $_[0];
  my $tw_coorNow =  $_[1];
  my $tw_forceNow = $_[2];
  my @tw_coorDeltaNow;
  my $tw_work;
  my @tw_i;

  @tw_coorDeltaNow = deltaAngleArr(\@{$tw_coorNow}, \@{$tw_refCoor});
  $tw_work = 0;
  for($tw_i[0] = 0, $tw_i[1] = $#{$tw_coorNow} + 1; $tw_i[0] < $tw_i[1]; $tw_i[0]++)
  {
    $tw_work += $tw_coorDeltaNow[$tw_i[0]] * ${$tw_forceNow}[$tw_i[0]] * 0.5;
  }
  
  return $tw_work;
}

#perl ../../05_2runUS.pl 05_namdCommand_0.txt 0.04 1 0.0004 2.5 0.25 5 0.5 10000 10 0  0  no 0
#                        0                    1    2 3      4   5    6 7   8     9  10 11 12 13

if($#ARGV != 13)
{
  print "perl 05_2runUS.pl 0 1 2 3 4 5 6 7 8 9 10 11 12 13\n";
  print "0: the file containing namd commands\n";
  print "1: initial force constant\n";
  print "2: maximum of force constant\n";
  print "3: minimum of force constant\n";
  print "4: maximal center displacement of sample distribution (Must >= 0)\n";
  print "5: minimum of maximal center displacement of sample distribution (Must >= 0)\n";
  print "6: the distance of half-height sample distribution (Must >= 0)\n";
  print "7: minimum of the distance of half-height sample distribution (Must >= 0)\n";
  print "8: number of steps in one USMD\n";
  print "9: number of USMD\n";
  print "10: index of this route\n";
  print "11: index of this window\n";
  print "12: binary out?(yes or no)\n";
  print "13: standalone job data (1) or not (0)\n\n";
  exit;
}

my $namdComFile =                 $ARGV[0];
my $allFc =                       $ARGV[1];
my $maxFc =                       $ARGV[2];
my $minFc =                       $ARGV[3];
my $vecCenterDisplaceTol =        $ARGV[4];
my $minVecCenterDisplaceTol =     $ARGV[5];
my $vecWidthFactorSampleDist =    $ARGV[6];
my $minVecWidthFactorSampleDist = $ARGV[7];
my $runStep =                     $ARGV[8];
my $mdNum =                       $ARGV[9];
my $routeIndex =                  $ARGV[10];
my $winIndex =                    $ARGV[11];
my $binmode =                     $ARGV[12];
my $standalone =                  $ARGV[13];
my $diheNum;
my $routeNum;
my @centerDisplaceTol;
my @halfWidthFactor;
my $skipNum;
my $mdNumNow;
my @stop;
my $fct;
my $prefixIn;
my $prefixOut;
my @digging;
my @stateLine;
my $namd_com;
my $recE;
my @routeVecUnit;
my @refVec;
my @nextRefVec;
my @refCoorOfThisWin;
my @modCenterOfThisWinLine;
my $fileIn;
my $fileOut;
my $line;
my @word;
my @diheNow;
my @forceNow;
my @recordLine;
my @i;
my @namd_scr_data;
my @namd_col_data;
my $stage2Index;
my $outOk;
my $tmp;
my @avg;
my @sd;
my @probDensCenter;
my @halfHightProbDensLowerLimit;
my @halfHightProbDensUpperLimit;
my @probDens;
my @fc;
my @new_fc;
my @old_fc;
my @elder_fc;
my $firstTimeStep;
my @recordWord;
my $finishSearching;
my $lastWinBut = 0;
my @nextRouteVecUnit;

if($standalone ne "1" && $standalone ne "0")
{
  print "ERROR: standalone job data flag should be 1 or 0\n";
  exit;
}

$skipNum = 0;
$mdNumNow = 0;
# $thresholdOfVerySmallFC = 2;
# $theVerySmallFCValue = pow(10, (log10($allFc) - $thresholdOfVerySmallFC));
$fct = 0.2;
$prefixIn = "04_w";
$prefixOut = "05_w";
$recE = 0;

$fileIn = "$namdComFile";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Cannot open $fileIn\n";
  exit;
}

while($line = <FIN>)
{
  chomp($line);
  if($line eq '#namd_command')
  {
    $namd_com = <FIN>;
    chomp($namd_com);
  }
  else
  {
    print "ERROR: Something wrong within the namd command file $fileIn\n";
    exit;
  }
}
close FIN;

if($standalone == 1)
{
  $fileIn = "01_allWinNum.txt";
}
else
{
  $fileIn = "../../../01_allWinNum.txt";
}
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Cannot open $fileIn\n";
  exit;
}

$i[0] = 0;
while($line = <FIN>)
{
  if($i[0] == $routeIndex)
  {
    chomp($line);
    @word = split(/\s+/, "$line");
    if($word[2] - 2 == $winIndex)
    {
      $lastWinBut = 1;
    }
    last;
  }
  $i[0]++;
}

close FIN;

if($standalone == 1)
{
  $fileIn = "01_allNodesAndRefOriM.txt";
  if(open(FIN, "$fileIn") != 1)
  {
    $fileIn = "01_allNodesAndRefOri.txt";
    if(open(FIN, "$fileIn") != 1)
    {
      print "ERROR: Cannot open $fileIn\n";
      exit;
    }
  }
}
else
{
  $fileIn = "../../../01_allNodesAndRefOriM.txt";
  if(open(FIN, "$fileIn") != 1)
  {
    $fileIn = "../../../01_allNodesAndRefOri.txt";
    if(open(FIN, "$fileIn") != 1)
    {
      print "ERROR: Cannot open $fileIn\n";
      exit;
    }
  }
}

$line = <FIN>;
chomp($line);
@word = split(/\s+/, "$line");
$diheNum = $word[2];
$line = <FIN>;
chomp($line);
@word = split(/\s+/, "$line");
$routeNum = $word[2];
foreach (1..$diheNum)
{
  $line = <FIN>;
}
$i[0] = 0;
while($line = <FIN>)
{
  if($i[0] == $routeIndex)
  {
    chomp($line);
    @refVec = split(/\s+/, "$line");
    shift(@refVec);
    shift(@refVec);
    if($lastWinBut == 1 && $routeNum - 1 > $routeIndex)
    {
      $line = <FIN>;
      chomp($line);
      @nextRefVec = split(/\s+/, "$line");
      shift(@nextRefVec);
      shift(@nextRefVec);
      $lastWinBut = 2;
    }
    last;
  }
  $i[0]++;
}

close FIN;

$i[0] = $diheNum - 1;
@digging = map {0} 0..$i[0];
@fc = map {$allFc} 0..$i[0];
@stateLine = map {"srcng"} 0..$i[0];
@stop = map {0} 0..$i[0];

if($standalone == 1)
{
  $fileIn = "01_allRoutesUnit.txt";
}
else
{
  $fileIn = "../../../01_allRoutesUnit.txt";
}
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
  if($i[0] == $routeIndex)
  {
    chomp($line);
    @routeVecUnit = split(/\s+/, "$line");
    if($lastWinBut == 2)
    {
      $line = <FIN>;
      chomp($line);
      @nextRouteVecUnit = split(/\s+/, "$line");
      shift(@nextRouteVecUnit);
      shift(@nextRouteVecUnit);
    }
    last;
  }
  $i[0]++;
}

close FIN;

@centerDisplaceTol = map {abs($routeVecUnit[$_] * $vecCenterDisplaceTol)} 0..$#digging;
for($i[0] = 0, $i[1] = $diheNum; $i[0] < $i[1]; $i[0]++)
{
  if($centerDisplaceTol[$i[0]] < $minVecCenterDisplaceTol)
  {
    $centerDisplaceTol[$i[0]] = $minVecCenterDisplaceTol;
  }
}

@halfWidthFactor = map {abs($routeVecUnit[$_] * $vecWidthFactorSampleDist)} 0..$#digging;
for($i[0] = 0, $i[1] = $diheNum; $i[0] < $i[1]; $i[0]++)
{
#   if($halfWidthFactor[$i[0]] < $minVecWidthFactorSampleDist)
#   {
    $halfWidthFactor[$i[0]] = $minVecWidthFactorSampleDist;
#   }
}


$fileIn = "${prefixIn}${winIndex}.namd";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Cannot open $fileIn\n";
  exit;
}

while($line = <FIN>)
{
  chomp($line);
  if($line eq "run           ")
  {
    $line .= "$runStep";
  }
  push(@namd_scr_data, $line);
}
close FIN;

$fileIn = "${prefixIn}${winIndex}.in";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Cannot open $fileIn\n";
  exit;
}

while($line = <FIN>)
{
  chomp($line);
  push(@namd_col_data, $line);
  if($line =~ /centers/)
  {
    @word = split(/\s+/, "$line");
    push(@refCoorOfThisWin, $word[2]);
  }
}
@{$modCenterOfThisWinLine[0]} = @refCoorOfThisWin;

close FIN;

$fileIn = "${prefixOut}${winIndex}.rec";
if(-e $fileIn)
{
  if(open(RECORDIN, "$fileIn") != 1)
  {
    print "ERROR: Cannot open $fileIn for reading\n";
    exit;
  }
  while($line = <RECORDIN>)
  {
    chomp($line);
    push(@recordLine, $line);
  }
  close RECORDIN;
  
  if($#recordLine > 0)
  {
    $recE = 1;
    undef @modCenterOfThisWinLine;
    $fileIn = "${prefixOut}${winIndex}.rec2";
    open(RECORDIN2, "$fileIn") or die "ERROR: Can not open $fileIn\n";
    while($line = <RECORDIN2>)
    {
      chomp($line);
      @word = split(/\s+/, "$line");
#       die "ERROR: wrong data number in file $fileIn\n" if($#word != $diheAndTransAndSpinNum);
      @{$modCenterOfThisWinLine[$#modCenterOfThisWinLine + 1]} = split(/\s+/, $line);
      shift(@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]});
    }
    close RECORDIN2;
  }
}

$i[2] = 1;

if($recE == 0)
{
  $stage2Index = 1;
  $fileOut = "${prefixOut}${winIndex}_${stage2Index}.namd";
  if(open(FOUT, "> $fileOut") != 1)
  {
    print "ERROR: Cannot open $fileOut\n";
    exit;
  }
  for($i[1] = 0; $i[1] <= $#namd_scr_data; $i[1]++)
  {
    if($standalone == 1)
    {
      if($namd_scr_data[$i[1]] =~ /^structure/ ||
         $namd_scr_data[$i[1]] =~ /^coordinates/ ||
         $namd_scr_data[$i[1]] =~ /^parameters/)
      {
        $line = $namd_scr_data[$i[1]];
        $line =~ s/..\///g;
        print FOUT "$line\n";
        next;
      }
    }
    if($namd_scr_data[$i[1]] eq "outputname       ")
    {
      print FOUT "$namd_scr_data[$i[1]]${prefixOut}${winIndex}_out_${stage2Index}\n";
    }
    elsif($namd_scr_data[$i[1]] eq "restartname      ")
    {
      print FOUT "$namd_scr_data[$i[1]]${prefixOut}${winIndex}_re_${stage2Index}\n";
    }
    elsif($namd_scr_data[$i[1]] eq "colvarsConfig  ")
    {
      print FOUT "$namd_scr_data[$i[1]]${prefixOut}${winIndex}_${stage2Index}.in\n";
    }
    elsif($namd_scr_data[$i[1]] eq "firstTimeStep ")
    {
       print FOUT "$namd_scr_data[$i[1]] 0\n";
    }
    else
    {
      print FOUT "$namd_scr_data[$i[1]]\n";
    }
  }
  close FOUT;
  $fileOut = "${prefixOut}${winIndex}_${stage2Index}.in";
  if(open(FOUT, "> $fileOut") != 1)
  {
    print "ERROR: Cannot open $fileOut\n";
    exit;
  }
  $i[4] = 0;
  for($i[1] = 0; $i[1] <= $#namd_col_data; $i[1]++)
  {
    if($namd_col_data[$i[1]] eq "  forceConstant ")
    {
      print FOUT "$namd_col_data[$i[1]]$fc[$i[4]]\n";
      $i[4]++;
    }
    else
    {
      print FOUT "$namd_col_data[$i[1]]\n";
    }
  }
  close FOUT;
  
  $fileOut = "${prefixOut}${winIndex}.rec2";
  open(RECORDOUT2, "> $fileOut") or die "ERROR: Can not open $fileOut\n";
  $line = join(" ", @{$modCenterOfThisWinLine[$i[2]-1]});
  print RECORDOUT2 "$i[2] $line\n";
  close RECORDOUT2;
  
  system("$namd_com ${prefixOut}${winIndex}_${stage2Index}.namd > ${prefixOut}${winIndex}_${stage2Index}.out");
  
  $fileIn = "${prefixOut}${winIndex}_${stage2Index}.out";
  if(open(FIN, "$fileIn") != 1)
  {
    print "ERROR: Can not open $fileIn\n";
    exit;
  }
  $line = <FIN>;
  $outOk = 0;
  while($line = <FIN>)
  {
    if($line =~ /error/i && $line !~ /^Info/)
    {
      print "ERROR: There are errors in $fileIn\n";
      print "US index: $i[2]\n";
      close FIN;
      exit;
    }
    elsif($line =~ /^Program finished/ || $line =~ /End of program$/)
    {
      $outOk = 1;
    }
  }
  close FIN;
  if($outOk != 1)
  {
    print "ERROR: Namd job does not normally finished (${prefixOut}${winIndex}_${stage2Index}.out)\n";
    print "US index: $i[2]\n";
    exit;
  }
  
  $fileOut = "${prefixOut}${winIndex}.rec";
  if(open(RECORDOUT, "> $fileOut") != 1)
  {
    print "ERROR: Cannot open $fileOut\n";
    exit;
  }
  
  $fileIn = "${prefixOut}${winIndex}_out_${stage2Index}.colvars.traj";
  if(open(FIN, "$fileIn") != 1)
  {
    print "ERROR: Can not open $fileIn\n";
    exit;
  }
  
  if($binmode eq "yes")
  {
    $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen.traj.bin";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }
    binmode(FOUT);
  }
  elsif($binmode eq "no")
  {
    $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen.traj";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }
  }
  else
  {
    print "ERROR: binary out? ($binmode)\n";
    exit;
  }
  
  if($lastWinBut == 2)
  {
    if($binmode eq "yes")
    {
      $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen2.traj.bin";
      if(open(FOUT2, "> $fileOut") != 1)
      {
        print "ERROR: Can not open $fileOut\n";
        exit;
      }
      binmode(FOUT2);
    }
    elsif($binmode eq "no")
    {
      $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen2.traj";
      if(open(FOUT2, "> $fileOut") != 1)
      {
        print "ERROR: Can not open $fileOut\n";
        exit;
      }
    }
    else
    {
      print "ERROR: binary out? ($binmode)\n";
      exit;
    }
  }
  
  @avg = map {0} 0..$#digging;
  @sd = map {0} 0..$#digging;
  $i[0] = -$skipNum;
  $line = <FIN>;
  while($line = <FIN>)
  {
    @word = split(/\s+/, "$line");
    if($word[0] eq "")
    {
      shift(@word);
      shift(@word);
      $i[3] = ($#word - 1) / 2;
      @diheNow = map {$word[$_*2]} 0..$i[3];
      if($i[0] >= 0)
      {
        for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
        {
          if(abs(angleRangeMod($diheNow[$i[4]] - $modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]])) >= 90)
          {
            print "ERROR: strange data dihedral: $diheNow[$i[4]]\n";
            print "       ref. dihedral: $modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]]\n";
            exit;
          }
          if($modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]] > 90 && $diheNow[$i[4]] < 0)
          {
            $diheNow[$i[4]] += 360;
          }
          elsif($modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]] == -90 && $diheNow[$i[4]] == 180)
          {
            $diheNow[$i[4]] -= 360;
          }
          elsif($modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]] < -90 && $diheNow[$i[4]] > 0)
          {
            $diheNow[$i[4]] -= 360;
          }
        }
        @avg = map {$avg[$_] + $diheNow[$_]} 0..$#avg;
        @sd = map {$sd[$_] + $diheNow[$_] * $diheNow[$_]} 0..$#avg;
        
        $tmp = vecProjUnit(\@diheNow, \@refVec, \@routeVecUnit);
        if($binmode eq "yes")
        {
          syswrite(FOUT, pack('d<', $tmp));
        }
        elsif($binmode eq "no")
        {
          $tmp = sprintf("%.14e", $tmp);
          print FOUT "$tmp";
        }
        
        if($lastWinBut == 2)
        {
          $tmp = vecProjUnit(\@diheNow, \@nextRefVec, \@nextRouteVecUnit);
          if($binmode eq "yes")
          {
            syswrite(FOUT2, pack('d<', $tmp));
          }
          elsif($binmode eq "no")
          {
            $tmp = sprintf("%.14e", $tmp);
            print FOUT2 "$tmp\n";
          }
        }
        
        $tmp = vecProjUnit(\@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]}, \@diheNow, \@routeVecUnit);
        if($binmode eq "yes")
        {
          syswrite(FOUT, pack('d<', $tmp));
        }
        elsif($binmode eq "no")
        {
          $tmp = sprintf("%.14e", $tmp);
          print FOUT " $tmp";
        }
        
        @forceNow = map { $word[$_*2 + 1] } 0..$i[3];
        $tmp = totalWork(\@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]}, \@diheNow, \@forceNow);
        if($binmode eq "yes")
        {
          syswrite(FOUT, pack('d<', $tmp));
        }
        elsif($binmode eq "no")
        {
          $tmp = sprintf("%.14e", $tmp);
          print FOUT " $tmp\n";
        }
        
        $i[0]++;
      }
    }
  }
  
  close FIN;
  close FOUT;
  close FOUT2;
  
  system("rm $fileIn");
  
  @avg = map {$avg[$_] / $i[0]} 0..$#avg;
  
  @{$modCenterOfThisWinLine[$#modCenterOfThisWinLine + 1]} = map {$modCenterOfThisWinLine[$#modCenterOfThisWinLine][$_] + $refCoorOfThisWin[$_] - $avg[$_]} 0..$#avg;
  angleRangeModArr(\@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]});
  
  $fileOut = "${prefixOut}${winIndex}.rec2";
  open(RECORDOUT2, ">> $fileOut") or die "ERROR: Can not open $fileOut\n";
  $line = join(" ", @{$modCenterOfThisWinLine[$i[2]]});
  $i[2]++;
  print RECORDOUT2 "$i[2] $line\n";
  $i[2]--;
  close RECORDOUT2;
  
  @sd = map {($sd[$_] / $i[0] - $avg[$_] * $avg[$_])**0.5} 0..$#avg;
  angleRangeModArr(\@avg);
  @probDensCenter = map {1/$sd[$_]/2.50662825325} 0 ..$#sd;
  @halfHightProbDensLowerLimit = map {$probDensCenter[$_] / 2 - $probDensCenter[$_] / 20} 0..$#probDensCenter;
  @halfHightProbDensUpperLimit = map {$probDensCenter[$_] / 2 + $probDensCenter[$_] / 20} 0..$#probDensCenter;
  @probDens = map {exp($halfWidthFactor[$_]*$halfWidthFactor[$_]/-2/$sd[$_]/$sd[$_]) * $probDensCenter[$_]} 0..$#probDensCenter;
  
  $i[4] = 0;
  print RECORDOUT sprintf("#allIndex usIndex state %-17s fc           targetMddv         mddvLowerLimt        mddvUpperLimt              mddvAvg               mddvSd       centerProbDens           hhProbDens  hhProbDensLowerLimt  hhProbDensUpperLimt", $i[4]);
  for($i[4] = 1, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
  {
    print RECORDOUT sprintf(" state %-17s fc           targetMddv        mddvLowerLimt        mddvUpperLimt              mddvAvg               mddvSd       centerProbDens           hhProbDens  hhProbDensLowerLimt  hhProbDensUpperLimt", $i[4]);
  }
  print RECORDOUT "\n";
  
  $i[4] = 0;
  if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]] && 0)
  {
    $digging[$i[4]] = 1;
    if($fc[$i[4]] >= $maxFc)
    {
      $stateLine[$i[4]] = "thrRe";
      $new_fc[$i[4]] = $maxFc;
      print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
    }
    else
    {
      $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
      if($new_fc[$i[4]] > $maxFc)
      {
        $new_fc[$i[4]] = $maxFc;
      }
      print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
    }
  }
  else
  {
    if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
    {
      $digging[$i[4]] = 1;
      if($fc[$i[4]] >= $maxFc)
      {
        $stateLine[$i[4]] = "thrRe";
        $new_fc[$i[4]] = $maxFc;
        print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
      }
      else
      {
        $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
        if($new_fc[$i[4]] > $maxFc)
        {
          $new_fc[$i[4]] = $maxFc;
        }
        print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
      }
    }
    elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
    {
      $digging[$i[4]] = -1;
#       if($verySmallFC[$i[4]] >= $thresholdOfVerySmallFC)
      if($fc[$i[4]] <= $minFc)
      {
        $stateLine[$i[4]] = "thrRe";
        $new_fc[$i[4]] = $minFc;
        print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
      }
      else
      {
        print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
        
        $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) - 1));
        if($new_fc[$i[4]] < $minFc)
        {
          $new_fc[$i[4]] = $minFc;
        }
#         $verySmallFC[$i[4]]++;
      }
    }
    else
    {
      $stateLine[$i[4]] = "optmz";
      $new_fc[$i[4]] = $fc[$i[4]];
      print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
    }
  }
  for($i[4] = 1, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
  {
    if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]] && 0)
    {
      $digging[$i[4]] = 1;
      if($fc[$i[4]] >= $maxFc)
      {
        $stateLine[$i[4]] = "thrRe";
        $new_fc[$i[4]] = $maxFc;
        print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
      }
      else
      {
        $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
        if($new_fc[$i[4]] > $maxFc)
        {
          $new_fc[$i[4]] = $maxFc;
        }
        
        print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
      }
    }
    else
    {
      if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
      {
        $digging[$i[4]] = 1;
        if($fc[$i[4]] >= $maxFc)
        {
          $stateLine[$i[4]] = "thrRe";
          $new_fc[$i[4]] = $maxFc;
          print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
        }
        else
        {
          $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
          if($new_fc[$i[4]] > $maxFc)
          {
            $new_fc[$i[4]] = $maxFc;
          }
          print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
        }
      }
      elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
      {
        $digging[$i[4]] = -1;
#         if($verySmallFC[$i[4]] >= $thresholdOfVerySmallFC)
        if($fc[$i[4]] <= $minFc)
        {
          $stateLine[$i[4]] = "thrRe";
          $new_fc[$i[4]] = $minFc;
          print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
        }
        else
        {
          print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
          
          $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) - 1));
          if($new_fc[$i[4]] < $minFc)
          {
            $new_fc[$i[4]] = $minFc;
          }
#           $verySmallFC[$i[4]]++;
        }
      }
      else
      {
        $stateLine[$i[4]] = "optmz";
        $new_fc[$i[4]] = $fc[$i[4]];
        print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
      }
    }
  }
  print RECORDOUT "\n";
  
  $finishSearching = 1;
  for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
  {
    if($stateLine[$i[4]] eq "srcng")
    {
      $finishSearching = 0;
      last;
    }
  }
  if($finishSearching == 1)
  {
    $stage2Index++;
    $mdNumNow++;
  }
}
elsif($recE == 1)
{
  $fileOut = "${prefixOut}${winIndex}.rec";
  if(open(RECORDOUT, ">> $fileOut") != 1)
  {
    print "Cannot open $fileOut\n";
    exit;
  }
  
  @recordWord = split(/\s+/, "$recordLine[$i[2]]");
  $stage2Index = $recordWord[2];
  $i[4] = 0;
  $stateLine[$i[4]] = $recordWord[3];
  $fc[$i[4]] = $recordWord[4];
  $avg[$i[4]] = $recordWord[8];
  $sd[$i[4]] = $recordWord[9];
  $probDensCenter[$i[4]] = $recordWord[10];
  $probDens[$i[4]] = $recordWord[11];
  $halfHightProbDensLowerLimit[$i[4]] = $recordWord[12];
  $halfHightProbDensUpperLimit[$i[4]] = $recordWord[13];
  
  if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]] && 0)
  {
    $digging[$i[4]] = 1;
    if($fc[$i[4]] >= $maxFc)
    {
      $new_fc[$i[4]] = $maxFc;
    }
    else
    {
      $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
      if($new_fc[$i[4]] > $maxFc)
      {
        $new_fc[$i[4]] = $maxFc;
      }
    }
  }
  else
  {
    if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
    {
      $digging[$i[4]] = 1;
      if($fc[$i[4]] >= $maxFc)
      {
        $new_fc[$i[4]] = $maxFc;
      }
      else
      {
        $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
        if($new_fc[$i[4]] > $maxFc)
        {
          $new_fc[$i[4]] = $maxFc;
        }
      }
    }
    elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
    {
      $digging[$i[4]] = -1;
#       if($verySmallFC[$i[4]] >= $thresholdOfVerySmallFC)
      if($fc[$i[4]] <= $minFc)
      {
        $new_fc[$i[4]] = $minFc;
      }
      else
      {
        $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) - 1));
        if($new_fc[$i[4]] < $minFc)
        {
          $new_fc[$i[4]] = $minFc;
        }
#         $verySmallFC[$i[4]]++;
      }
    }
    else
    {
      $new_fc[$i[4]] = $fc[$i[4]];
    }
  }
  for($i[4] = 1, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
  {
    $stateLine[$i[4]] = $recordWord[3+$i[4]*11];
    $fc[$i[4]] = $recordWord[4+$i[4]*11];
    $avg[$i[4]] = $recordWord[8+$i[4]*11];
    $sd[$i[4]] = $recordWord[9+$i[4]*11];
    $probDensCenter[$i[4]] = $recordWord[10+$i[4]*11];
    $probDens[$i[4]] = $recordWord[11+$i[4]*11];
    $halfHightProbDensLowerLimit[$i[4]] = $recordWord[12+$i[4]*11];
    $halfHightProbDensUpperLimit[$i[4]] = $recordWord[13+$i[4]*11];
    
    if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]] && 0)
    {
      $digging[$i[4]] = 1;
      if($fc[$i[4]] >= $maxFc)
      {
        $new_fc[$i[4]] = $maxFc;
      }
      else
      {
        $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
        if($new_fc[$i[4]] > $maxFc)
        {
          $new_fc[$i[4]] = $maxFc;
        }
      }
    }
    else
    {
      if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
      {
        $digging[$i[4]] = 1;
        if($fc[$i[4]] >= $maxFc)
        {
          $new_fc[$i[4]] = $maxFc;
        }
        else
        {
          $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
          if($new_fc[$i[4]] > $maxFc)
          {
            $new_fc[$i[4]] = $maxFc;
          }
        }
      }
      elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
      {
        $digging[$i[4]] = -1;
#         if($verySmallFC[$i[4]] >= $thresholdOfVerySmallFC)
        if($fc[$i[4]] <= $minFc)
        {
          $new_fc[$i[4]] = $minFc;
        }
        else
        {
          $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) - 1));
          if($new_fc[$i[4]] < $minFc)
          {
            $new_fc[$i[4]] = $minFc;
          }
#           $verySmallFC[$i[4]]++;
        }
      }
      else
      {
        $new_fc[$i[4]] = $fc[$i[4]];
      }
    }
  }
  
  $finishSearching = 1;
  for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
  {
    if($stateLine[$i[4]] eq "srcng")
    {
      $finishSearching = 0;
      last;
    }
  }
  if($finishSearching == 1)
  {
    $stage2Index++;
    $mdNumNow++;
  }
}
else
{
  print "ERROR: How could.....?\n";
  exit;
}

@old_fc = @fc;
@fc = @new_fc;
$i[2]++;
if($finishSearching == 0)
{
  while($i[2] <= $#recordLine)
  {
    @recordWord = split(/\s+/, "$recordLine[$i[2]]");
    $stage2Index = $recordWord[2];
    $i[4] = 0;
    $stateLine[$i[4]] = $recordWord[3];
    $fc[$i[4]] = $recordWord[4];
    $avg[$i[4]] = $recordWord[8];
    $sd[$i[4]] = $recordWord[9];
    $probDensCenter[$i[4]] = $recordWord[10];
    $probDens[$i[4]] = $recordWord[11];
    $halfHightProbDensLowerLimit[$i[4]] = $recordWord[12];
    $halfHightProbDensUpperLimit[$i[4]] = $recordWord[13];
    
    if($stateLine[$i[4]] eq "srcng")
    {
      if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]] && 0)
      {
        if($digging[$i[4]] == 1)
        {
          if($fc[$i[4]] >= $maxFc)
          {
            $new_fc[$i[4]] = $maxFc;
            $stop[$i[4]] = 1;
          }
          else
          {
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
            if($new_fc[$i[4]] > $maxFc)
            {
              $new_fc[$i[4]] = $maxFc;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] = $fc[$i[4]];
          }
        }
        elsif($digging[$i[4]] == -1)
        {
          $digging[$i[4]] = 2;
          $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
          $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
          if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
          {
            $stop[$i[4]] = 1;
          }
          $elder_fc[$i[4]] = $old_fc[$i[4]];
          $old_fc[$i[4]] =  $fc[$i[4]];
        }
        else
        {
          if($elder_fc[$i[4]] > $old_fc[$i[4]])
          {
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $old_fc[$i[4]] = $fc[$i[4]];
          }
          else
          {
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] =  $fc[$i[4]];
          }
        }
        if($stop[$i[4]] == 1)
        {
          $fc[$i[4]] = $new_fc[$i[4]];
        }
      }
      else
      {
        if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
        {
          if($digging[$i[4]] == 1)
          {
            if($fc[$i[4]] >= $maxFc)
            {
              $new_fc[$i[4]] = $maxFc;
              $stop[$i[4]] = 1;
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
              if($new_fc[$i[4]] > $maxFc)
              {
                $new_fc[$i[4]] = $maxFc;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
            }
          }
          elsif($digging[$i[4]] == -1)
          {
            $digging[$i[4]] = 2;
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] = $fc[$i[4]];
          }
          else
          {
            if($elder_fc[$i[4]] > $old_fc[$i[4]])
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $old_fc[$i[4]] = $fc[$i[4]];
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] =  $fc[$i[4]];
            }
          }
          if($stop[$i[4]] == 1)
          {
            $fc[$i[4]] = $new_fc[$i[4]];
          }
        }
        elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
        {
          if($digging[$i[4]] == -1)
          {
            $digging[$i[4]] = -1;
#             if($verySmallFC[$i[4]] >= $thresholdOfVerySmallFC)
            if($fc[$i[4]] <= $minFc)
            {
              $new_fc[$i[4]] = $minFc;
              $stop[$i[4]] = 1;
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) - 1));
              if($new_fc[$i[4]] < $minFc)
              {
                $new_fc[$i[4]] = $minFc;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
#               $verySmallFC[$i[4]]++;
            }
          }
          elsif($digging[$i[4]] == 1)
          {
            $digging[$i[4]] = 2;
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] = $fc[$i[4]];
          }
          else
          {
            if($elder_fc[$i[4]] < $old_fc[$i[4]])
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $old_fc[$i[4]] = $fc[$i[4]];
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] =  $fc[$i[4]];
            }
          }
          if($stop[$i[4]] == 1)
          {
            $fc[$i[4]] = $new_fc[$i[4]];
          }
        }
        else
        {
        }
      }
      $fc[$i[4]] = $new_fc[$i[4]];
    }
    for($i[4] = 1, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
    {
      $stateLine[$i[4]] = $recordWord[3+$i[4]*11];
      $fc[$i[4]] = $recordWord[4+$i[4]*11];
      $avg[$i[4]] = $recordWord[8+$i[4]*11];
      $sd[$i[4]] = $recordWord[9+$i[4]*11];
      $probDensCenter[$i[4]] = $recordWord[10+$i[4]*11];
      $probDens[$i[4]] = $recordWord[11+$i[4]*11];
      $halfHightProbDensLowerLimit[$i[4]] = $recordWord[12+$i[4]*11];
      $halfHightProbDensUpperLimit[$i[4]] = $recordWord[13+$i[4]*11];
      
      if($stateLine[$i[4]] eq "srcng")
      {
        if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]] && 0)
        {
          if($digging[$i[4]] == 1)
          {
            if($fc[$i[4]] >= $maxFc)
            {
              $new_fc[$i[4]] = $maxFc;
              $stop[$i[4]] = 1;
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
              if($new_fc[$i[4]] > $maxFc)
              {
                $new_fc[$i[4]] = $maxFc;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
            }
          }
          elsif($digging[$i[4]] == -1)
          {
            $digging[$i[4]] = 2;
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] =  $fc[$i[4]];
          }
          else
          {
            if($elder_fc[$i[4]] > $old_fc[$i[4]])
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $old_fc[$i[4]] = $fc[$i[4]];
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] =  $fc[$i[4]];
            }
          }
          if($stop[$i[4]] == 1)
          {
            $fc[$i[4]] = $new_fc[$i[4]];
          }
        }
        else
        {
          if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
          {
            if($digging[$i[4]] == 1)
            {
              if($fc[$i[4]] >= $maxFc)
              {
                $new_fc[$i[4]] = $maxFc;
                $stop[$i[4]] = 1;
              }
              else
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
                if($new_fc[$i[4]] > $maxFc)
                {
                  $new_fc[$i[4]] = $maxFc;
                }
                $elder_fc[$i[4]] = $old_fc[$i[4]];
                $old_fc[$i[4]] = $fc[$i[4]];
              }
            }
            elsif($digging[$i[4]] == -1)
            {
              $digging[$i[4]] = 2;
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
            }
            else
            {
              if($elder_fc[$i[4]] > $old_fc[$i[4]])
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
                $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
                if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
                {
                  $stop[$i[4]] = 1;
                }
                $old_fc[$i[4]] = $fc[$i[4]];
              }
              else
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
                $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
                if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
                {
                  $stop[$i[4]] = 1;
                }
                $elder_fc[$i[4]] = $old_fc[$i[4]];
                $old_fc[$i[4]] =  $fc[$i[4]];
              }
            }
            if($stop[$i[4]] == 1)
            {
              $fc[$i[4]] = $new_fc[$i[4]];
            }
          }
          elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
          {
            if($digging[$i[4]] == -1)
            {
              $digging[$i[4]] = -1;
#               if($verySmallFC[$i[4]] >= $thresholdOfVerySmallFC)
              if($fc[$i[4]] <= $minFc)
              {
                $new_fc[$i[4]] = $minFc;
                $stop[$i[4]] = 1;
              }
              else
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) - 1));
                if($new_fc[$i[4]] < $minFc)
                {
                  $new_fc[$i[4]] = $minFc;
                }
                $elder_fc[$i[4]] = $old_fc[$i[4]];
                $old_fc[$i[4]] = $fc[$i[4]];
#                 $verySmallFC[$i[4]]++;
              }
            }
            elsif($digging[$i[4]] == 1)
            {
              $digging[$i[4]] = 2;
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
            }
            else
            {
              if($elder_fc[$i[4]] < $old_fc[$i[4]])
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
                $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
                if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
                {
                  $stop[$i[4]] = 1;
                }
                $old_fc[$i[4]] = $fc[$i[4]];
              }
              else
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
                $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
                if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
                {
                  $stop[$i[4]] = 1;
                }
                $elder_fc[$i[4]] = $old_fc[$i[4]];
                $old_fc[$i[4]] =  $fc[$i[4]];
              }
            }
            if($stop[$i[4]] == 1)
            {
              $fc[$i[4]] = $new_fc[$i[4]];
            }
          }
          else
          {
          }
        }
        $fc[$i[4]] = $new_fc[$i[4]];
      }
    }
    $i[2]++;
    
    $finishSearching = 1;
    for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
    {
      if($stateLine[$i[4]] eq "srcng")
      {
        $finishSearching = 0;
        last;
      }
    }
    if($finishSearching == 1)
    {
      $stage2Index++;
      $mdNumNow++;
      last;
    }
  }
}

$firstTimeStep = 0;
if($finishSearching == 0)
{
  while(1)
  {
    $fileOut = "${prefixOut}${winIndex}_${stage2Index}.namd";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Cannot open $fileOut\n";
      exit;
    }
    for($i[1] = 0; $i[1] <= $#namd_scr_data; $i[1]++)
    {
      if($standalone == 1)
      {
        if($namd_scr_data[$i[1]] =~ /^structure/ ||
           $namd_scr_data[$i[1]] =~ /^coordinates/ ||
           $namd_scr_data[$i[1]] =~ /^parameters/)
        {
          $line = $namd_scr_data[$i[1]];
          $line =~ s/..\///g;
          print FOUT "$line\n";
          next;
        }
      }
      if($namd_scr_data[$i[1]] =~ /^bincoordinates/)
      {
        print FOUT "bincoordinates  ${prefixOut}${winIndex}_re_${stage2Index}.coor\n";
      }
      elsif($namd_scr_data[$i[1]] =~ /^binvelocities/)
      {
        print FOUT "binvelocities   ${prefixOut}${winIndex}_re_${stage2Index}.vel\n";
      }
      elsif($namd_scr_data[$i[1]] =~ /^extendedSystem/)
      {
        print FOUT "extendedSystem  ${prefixOut}${winIndex}_re_${stage2Index}.xsc\n";
      }
      elsif($namd_scr_data[$i[1]] eq "outputname       ")
      {
        print FOUT "$namd_scr_data[$i[1]]${prefixOut}${winIndex}_out_${stage2Index}\n";
      }
      elsif($namd_scr_data[$i[1]] eq "restartname      ")
      {
        print FOUT "$namd_scr_data[$i[1]]${prefixOut}${winIndex}_re_${stage2Index}\n";
      }
      elsif($namd_scr_data[$i[1]] eq "colvarsConfig  ")
      {
        print FOUT "$namd_scr_data[$i[1]]${prefixOut}${winIndex}_${stage2Index}.in\n";
      }
      elsif($namd_scr_data[$i[1]] eq "firstTimeStep ")
      {
         print FOUT "$namd_scr_data[$i[1]]$firstTimeStep\n";
      }
      else
      {
        print FOUT "$namd_scr_data[$i[1]]\n";
      }
    }
    close FOUT;
    
    $fileOut = "${prefixOut}${winIndex}_${stage2Index}.in";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Cannot open $fileOut\n";
      exit;
    }
    $i[4] = 0;
    for($i[1] = 0; $i[1] <= $#namd_col_data; $i[1]++)
    {
      if($namd_col_data[$i[1]] eq "  forceConstant ")
      {
        print FOUT "$namd_col_data[$i[1]]$fc[$i[4]]\n";
      }
      elsif($namd_col_data[$i[1]] =~ /^  centers / && $i[4] <= $#{$modCenterOfThisWinLine[$i[2]-1]} && $namd_col_data[$i[1]-2] !~ /STOP_/)
      {
        print FOUT "  centers $modCenterOfThisWinLine[$i[2]-1][$i[4]]\n";
        $i[4]++;
      }
      else
      {
        print FOUT "$namd_col_data[$i[1]]\n";
      }
    }
    close FOUT;
    system("$namd_com ${prefixOut}${winIndex}_${stage2Index}.namd > ${prefixOut}${winIndex}_${stage2Index}.out");
    
    $fileIn = "${prefixOut}${winIndex}_${stage2Index}.out";
    if(open(FIN, "$fileIn") != 1)
    {
      print "ERROR: Can not open $fileIn\n";
      exit;
    }
    $line = <FIN>;
    $outOk = 0;
    while($line = <FIN>)
    {
      if($line =~ /error/i && $line !~ /^Info/)
      {
        print "ERROR: There are errors in ${prefixOut}${winIndex}_${stage2Index}.out\n";
        print "US index: $i[2]\n";
        close FIN;
        exit;
      }
      elsif($line =~ /^Program finished/ || $line =~ /End of program$/)
      {
        $outOk = 1;
      }
    }
    close FIN;
    if($outOk != 1)
    {
      print "ERROR: namd job does not normally finished (${prefixOut}${winIndex}_${stage2Index}.out)\n";
      print "US index: $i[2]\n";
      exit;
    }
    
    $fileIn = "${prefixOut}${winIndex}_out_${stage2Index}.colvars.traj";
    if(open(FIN, "$fileIn") != 1)
    {
      print "ERROR: Can not open $fileIn\n";
      exit;
    }
    
    if($binmode eq "yes")
    {
      $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen.traj.bin";
      if(open(FOUT, "> $fileOut") != 1)
      {
        print "ERROR: Can not open $fileOut\n";
        exit;
      }
      binmode(FOUT);
    }
    elsif($binmode eq "no")
    {
      $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen.traj";
      if(open(FOUT, "> $fileOut") != 1)
      {
        print "ERROR: Can not open $fileOut\n";
        exit;
      }
    }
    else
    {
      print "ERROR: binary out? ($binmode)\n";
      exit;
    }
  
    if($lastWinBut == 2)
    {
      if($binmode eq "yes")
      {
        $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen2.traj.bin";
        if(open(FOUT2, "> $fileOut") != 1)
        {
          print "ERROR: Can not open $fileOut\n";
          exit;
        }
        binmode(FOUT2);
      }
      elsif($binmode eq "no")
      {
        $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen2.traj";
        if(open(FOUT2, "> $fileOut") != 1)
        {
          print "ERROR: Can not open $fileOut\n";
          exit;
        }
      }
      else
      {
        print "ERROR: binary out? ($binmode)\n";
        exit;
      }
    }
    
    @avg = map {0} 0..$#digging;
    @sd = map {0} 0..$#digging;
    $i[0] = -$skipNum;
    $line = <FIN>;
    while($line = <FIN>)
    {
      @word = split(/\s+/, "$line");
      if($word[0] eq "")
      {
        shift(@word);
        shift(@word);
        $i[3] = ($#word - 1) / 2;
        @diheNow = map { $word[$_*2] } 0..$i[3];
        if($i[0] >= 0)
        {
          for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
          {
            if(abs(angleRangeMod($diheNow[$i[4]] - $modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]])) >= 90)
            {
              print "ERROR: strange data dihedral: $diheNow[$i[4]]\n";
              print "       ref. dihedral: $modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]]\n";
              exit;
            }
            if($modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]] > 90 && $diheNow[$i[4]] < 0)
            {
              $diheNow[$i[4]] += 360;
            }
            elsif($modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]] == -90 && $diheNow[$i[4]] == 180)
            {
              $diheNow[$i[4]] -= 360;
            }
            elsif($modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]] < -90 && $diheNow[$i[4]] > 0)
            {
              $diheNow[$i[4]] -= 360;
            }
          }
          @avg = map {$avg[$_] + $diheNow[$_]} 0..$#avg;
          @sd = map {$sd[$_] + $diheNow[$_] * $diheNow[$_]} 0..$#avg;
          
          $tmp = vecProjUnit(\@diheNow, \@refVec, \@routeVecUnit);
          if($binmode eq "yes")
          {
            syswrite(FOUT, pack('d<', $tmp));
          }
          elsif($binmode eq "no")
          {
            $tmp = sprintf("%.14e", $tmp);
            print FOUT "$tmp";
          }
          
          if($lastWinBut == 2)
          {
            $tmp = vecProjUnit(\@diheNow, \@nextRefVec, \@nextRouteVecUnit);
            if($binmode eq "yes")
            {
              syswrite(FOUT2, pack('d<', $tmp));
            }
            elsif($binmode eq "no")
            {
              $tmp = sprintf("%.14e", $tmp);
              print FOUT2 "$tmp\n";
            }
          }
          
          $tmp = vecProjUnit(\@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]}, \@diheNow, \@routeVecUnit);
          if($binmode eq "yes")
          {
            syswrite(FOUT, pack('d<', $tmp));
          }
          elsif($binmode eq "no")
          {
            $tmp = sprintf("%.14e", $tmp);
            print FOUT " $tmp";
          }
          
          @forceNow = map { $word[$_*2 + 1] } 0..$i[3];
          $tmp = totalWork(\@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]}, \@diheNow, \@forceNow);
          if($binmode eq "yes")
          {
            syswrite(FOUT, pack('d<', $tmp));
          }
          elsif($binmode eq "no")
          {
            $tmp = sprintf("%.14e", $tmp);
            print FOUT " $tmp\n";
          }
          
          $i[0]++;
        }
      }
    }
    
    close FIN;
    close FOUT;
    close FOUT2;
    
    system("rm $fileIn");
    
    @avg = map {$avg[$_] / $i[0]} 0..$#avg;
    
    @{$modCenterOfThisWinLine[$#modCenterOfThisWinLine + 1]} = map {$modCenterOfThisWinLine[$#modCenterOfThisWinLine][$_] + $refCoorOfThisWin[$_] - $avg[$_]} 0..$#avg;
    angleRangeModArr(\@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]});
    
    $fileOut = "${prefixOut}${winIndex}.rec2";
    if(open(RECORDOUT2, ">> $fileOut") != 1)
    {
      print "ERROR: Cannot open $fileOut\n";
      exit;
    }
    $line = join(" ", @{$modCenterOfThisWinLine[$i[2]]});
    $i[2]++;
    print RECORDOUT2 "$i[2] $line\n";
    $i[2]--;
    close RECORDOUT2;
    
    @sd = map {($sd[$_] / $i[0] - $avg[$_] * $avg[$_])**0.5} 0..$#avg;
    angleRangeModArr(\@avg);
    @probDensCenter = map {1/$sd[$_]/2.50662825325} 0 ..$#sd;
    @halfHightProbDensLowerLimit = map {$probDensCenter[$_] / 2 - $probDensCenter[$_] / 20} 0..$#probDensCenter;
    @halfHightProbDensUpperLimit = map {$probDensCenter[$_] / 2 + $probDensCenter[$_] / 20} 0..$#probDensCenter;
    @probDens = map {exp($halfWidthFactor[$_]*$halfWidthFactor[$_]/-2/$sd[$_]/$sd[$_]) * $probDensCenter[$_]} 0..$#probDensCenter;
    
    $i[4] = 0;
    if($stateLine[$i[4]] eq "srcng")
    {
      if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]] && 0)
      {
        if($digging[$i[4]] == 1)
        {
          if($fc[$i[4]] >= $maxFc)
          {
            $new_fc[$i[4]] = $maxFc;
            $stop[$i[4]] = 1;
          }
          else
          {
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
            if($new_fc[$i[4]] > $maxFc)
            {
              $new_fc[$i[4]] = $maxFc;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] =  $fc[$i[4]];
          }
        }
        elsif($digging[$i[4]] == -1)
        {
          $digging[$i[4]] = 2;
          $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
          $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
          if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
          {
            $stop[$i[4]] = 1;
          }
          $elder_fc[$i[4]] = $old_fc[$i[4]];
          $old_fc[$i[4]] =  $fc[$i[4]];
        }
        else
        {
          if($elder_fc[$i[4]] > $old_fc[$i[4]])
          {
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $old_fc[$i[4]] = $fc[$i[4]];
          }
          else
          {
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] =  $fc[$i[4]];
          }
        }
        if($stop[$i[4]] == 1)
        {
          $stateLine[$i[4]] = "thrRe";
          print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
          
          $fc[$i[4]] = $new_fc[$i[4]];
        }
      }
      else
      {
        if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
        {
          if($digging[$i[4]] == 1)
          {
            if($fc[$i[4]] >= $maxFc)
            {
              $new_fc[$i[4]] = $maxFc;
              $stop[$i[4]] = 1;
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
              if($new_fc[$i[4]] > $maxFc)
              {
                $new_fc[$i[4]] = $maxFc;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
            }
          }
          elsif($digging[$i[4]] == -1)
          {
            $digging[$i[4]] = 2;
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] =  $fc[$i[4]];
          }
          else
          {
            if($elder_fc[$i[4]] > $old_fc[$i[4]])
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $old_fc[$i[4]] = $fc[$i[4]];
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
            }
          }
          if($stop[$i[4]] == 1)
          {
            $stateLine[$i[4]] = "thrRe";
            print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
            
            $fc[$i[4]] = $new_fc[$i[4]];
          }
        }
        elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
        {
          if($digging[$i[4]] == -1)
          {
            $digging[$i[4]] = -1;
#             if($verySmallFC[$i[4]] >= $thresholdOfVerySmallFC)
            if($fc[$i[4]] <= $minFc)
            {
              $new_fc[$i[4]] = $minFc;
              $stop[$i[4]] = 1;
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) - 1));
              if($new_fc[$i[4]] < $minFc)
              {
                $new_fc[$i[4]] = $minFc;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
#               $verySmallFC[$i[4]]++;
            }
          }
          elsif($digging[$i[4]] == 1)
          {
            $digging[$i[4]] = 2;
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] = $fc[$i[4]];
          }
          else
          {
            if($elder_fc[$i[4]] < $old_fc[$i[4]])
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $old_fc[$i[4]] =  $fc[$i[4]];
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
            }
          }
          if($stop[$i[4]] == 1)
          {
            $stateLine[$i[4]] = "thrRe";
            print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
            
            $fc[$i[4]] = $new_fc[$i[4]];
          }
        }
        else
        {
          $stateLine[$i[4]] = "optmz";
          print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
        }
      }
      if($stateLine[$i[4]] eq "srcng")
      {
        print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
        $fc[$i[4]] = $new_fc[$i[4]];
      }
    }
    else
    {
      print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
    }
    for($i[4] = 1, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
    {
      if($stateLine[$i[4]] eq "srcng")
      {
        if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]])
        {
          if($digging[$i[4]] == 1)
          {
            if($fc[$i[4]] >= $maxFc)
            {
              $new_fc[$i[4]] = $maxFc;
              $stop[$i[4]] = 1;
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
              if($new_fc[$i[4]] > $maxFc)
              {
                $new_fc[$i[4]] = $maxFc;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] =  $fc[$i[4]];
            }
          }
          elsif($digging[$i[4]] == -1)
          {
            $digging[$i[4]] = 2;
            $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
            $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
            if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
            {
              $stop[$i[4]] = 1;
            }
            $elder_fc[$i[4]] = $old_fc[$i[4]];
            $old_fc[$i[4]] =  $fc[$i[4]];
          }
          else
          {
            if($elder_fc[$i[4]] > $old_fc[$i[4]])
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $old_fc[$i[4]] = $fc[$i[4]];
            }
            else
            {
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] =  $fc[$i[4]];
            }
          }
          if($stop[$i[4]] == 1)
          {
            $stateLine[$i[4]] = "thrRe";
            print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
            
            $fc[$i[4]] = $new_fc[$i[4]];
          }
        }
        else
        {
          if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
          {
            if($digging[$i[4]] == 1)
            {
              if($fc[$i[4]] >= $maxFc)
              {
                $new_fc[$i[4]] = $maxFc;
                $stop[$i[4]] = 1;
              }
              else
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + 1));
                if($new_fc[$i[4]] > $maxFc)
                {
                  $new_fc[$i[4]] = $maxFc;
                }
                $elder_fc[$i[4]] = $old_fc[$i[4]];
                $old_fc[$i[4]] = $fc[$i[4]];
              }
            }
            elsif($digging[$i[4]] == -1)
            {
              $digging[$i[4]] = 2;
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] =  $fc[$i[4]];
            }
            else
            {
              if($elder_fc[$i[4]] > $old_fc[$i[4]])
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
                $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
                if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
                {
                  $stop[$i[4]] = 1;
                }
                $old_fc[$i[4]] = $fc[$i[4]];
              }
              else
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
                $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
                if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
                {
                  $stop[$i[4]] = 1;
                }
                $elder_fc[$i[4]] = $old_fc[$i[4]];
                $old_fc[$i[4]] = $fc[$i[4]];
              }
            }
            if($stop[$i[4]] == 1)
            {
              $stateLine[$i[4]] = "thrRe";
              print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
              
              $fc[$i[4]] = $new_fc[$i[4]];
            }
          }
          elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
          {
            if($digging[$i[4]] == -1)
            {
              $digging[$i[4]] = -1;
#               if($verySmallFC[$i[4]] >= $thresholdOfVerySmallFC)
              if($fc[$i[4]] <= $minFc)
              {
                $new_fc[$i[4]] = $minFc;
                $stop[$i[4]] = 1;
              }
              else
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) - 1));
                if($new_fc[$i[4]] < $minFc)
                {
                  $new_fc[$i[4]] = $minFc;
                }
                $elder_fc[$i[4]] = $old_fc[$i[4]];
                $old_fc[$i[4]] = $fc[$i[4]];
#                 $verySmallFC[$i[4]]++;
              }
            }
            elsif($digging[$i[4]] == 1)
            {
              $digging[$i[4]] = 2;
              $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
              $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
              if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
              {
                $stop[$i[4]] = 1;
              }
              $elder_fc[$i[4]] = $old_fc[$i[4]];
              $old_fc[$i[4]] = $fc[$i[4]];
            }
            else
            {
              if($elder_fc[$i[4]] < $old_fc[$i[4]])
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($elder_fc[$i[4]]))/2);
                $i[6] = ($fc[$i[4]] + $elder_fc[$i[4]]) / 2 * $fct;
                if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
                {
                  $stop[$i[4]] = 1;
                }
                $old_fc[$i[4]] =  $fc[$i[4]];
              }
              else
              {
                $new_fc[$i[4]] = pow(10, (log10($fc[$i[4]]) + log10($old_fc[$i[4]]))/2);
                $i[6] = ($fc[$i[4]] + $old_fc[$i[4]]) / 2 * $fct;
                if(abs($new_fc[$i[4]] - $fc[$i[4]]) < $i[6])
                {
                  $stop[$i[4]] = 1;
                }
                $elder_fc[$i[4]] = $old_fc[$i[4]];
                $old_fc[$i[4]] = $fc[$i[4]];
              }
            }
            if($stop[$i[4]] == 1)
            {
              $stateLine[$i[4]] = "thrRe";
              print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
              
              $fc[$i[4]] = $new_fc[$i[4]];
            }
          }
          else
          {
            $stateLine[$i[4]] = "optmz";
            print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
          }
        }
        if($stateLine[$i[4]] eq "srcng")
        {
          print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
          $fc[$i[4]] = $new_fc[$i[4]];
        }
      }
      else
      {
        print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
      }
    }
    print RECORDOUT "\n";
    $i[2]++;
    
    $finishSearching = 1;
    for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
    {
      if($stateLine[$i[4]] eq "srcng")
      {
        $finishSearching = 0;
        last;
      }
    }
    if($finishSearching == 1)
    {
      $stage2Index++;
      $mdNumNow++;
      last;
    }
  }
}

$firstTimeStep += $runStep;
while($i[2] <= $#recordLine)
{
  @recordWord = split(/\s+/, "$recordLine[$i[2]]");
  
  $stage2Index = $recordWord[2];
  $i[4] = 0;
  $stateLine[$i[4]] = $recordWord[3];
  $fc[$i[4]] = $recordWord[4];
  $avg[$i[4]] = $recordWord[8];
  $sd[$i[4]] = $recordWord[9];
  $probDensCenter[$i[4]] = $recordWord[10];
  $probDens[$i[4]] = $recordWord[11];
  $halfHightProbDensLowerLimit[$i[4]] = $recordWord[12];
  $halfHightProbDensUpperLimit[$i[4]] = $recordWord[13];
  
  if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]])
  {
    $new_fc[$i[4]] = $fc[$i[4]] * 1.25;
    if($new_fc[$i[4]] >= $maxFc)
    {
      $new_fc[$i[4]] = $maxFc;
    }
  }
  else
  {
    if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
    {
      $new_fc[$i[4]] = $fc[$i[4]] * 1.25;
      if($new_fc[$i[4]] >= $maxFc)
      {
        $new_fc[$i[4]] = $maxFc;
      }
    }
    elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
    {
      $new_fc[$i[4]] = $fc[$i[4]] * 0.8;
      if($fc[$i[4]] <= $minFc)
      {
        $new_fc[$i[4]] = $minFc;
      }
    }
    else
    {
      $new_fc[$i[4]] = $fc[$i[4]];
    }
  }
  $fc[$i[4]] = $new_fc[$i[4]];
  for($i[4] = 1, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
  {
    $stateLine[$i[4]] = $recordWord[3+$i[4]*11];
    $fc[$i[4]] = $recordWord[4+$i[4]*11];
    $avg[$i[4]] = $recordWord[8+$i[4]*11];
    $sd[$i[4]] = $recordWord[9+$i[4]*11];
    $probDensCenter[$i[4]] = $recordWord[10+$i[4]*11];
    $probDens[$i[4]] = $recordWord[11+$i[4]*11];
    $halfHightProbDensLowerLimit[$i[4]] = $recordWord[12+$i[4]*11];
    $halfHightProbDensUpperLimit[$i[4]] = $recordWord[13+$i[4]*11];
    
    if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]])
    {
      $new_fc[$i[4]] = $fc[$i[4]] * 1.25;
      if($new_fc[$i[4]] >= $maxFc)
      {
        $new_fc[$i[4]] = $maxFc;
      }
    }
    else
    {
      if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
      {
        $new_fc[$i[4]] = $fc[$i[4]] * 1.25;
        if($new_fc[$i[4]] >= $maxFc)
        {
          $new_fc[$i[4]] = $maxFc;
        }
      }
      elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
      {
        $new_fc[$i[4]] = $fc[$i[4]] * 0.8;
        if($fc[$i[4]] <= $minFc)
        {
          $new_fc[$i[4]] = $minFc;
        }
      }
      else
      {
        $new_fc[$i[4]] = $fc[$i[4]];
      }
    }
    $fc[$i[4]] = $new_fc[$i[4]];
  }
  
  $i[2]++;
  $stage2Index++;
  $mdNumNow++;
  $firstTimeStep += $runStep;
}

while($mdNumNow < $mdNum)
{
  $fileOut = "${prefixOut}${winIndex}_${stage2Index}.namd";
  if(open(FOUT, "> $fileOut") != 1)
  {
    print "ERROR: Cannot open $fileOut\n";
    exit;
  }
  $tmp = ${stage2Index} - 1;
  for($i[1] = 0; $i[1] <= $#namd_scr_data; $i[1]++)
  {
    if($standalone == 1)
    {
      if($namd_scr_data[$i[1]] =~ /^structure/ ||
         $namd_scr_data[$i[1]] =~ /^coordinates/ ||
         $namd_scr_data[$i[1]] =~ /^parameters/)
      {
        $line = $namd_scr_data[$i[1]];
        $line =~ s/..\///g;
        print FOUT "$line\n";
        next;
      }
    }
    if($namd_scr_data[$i[1]] =~ /^bincoordinates/)
    {
      print FOUT "bincoordinates  ${prefixOut}${winIndex}_re_${tmp}.coor\n";
    }
    elsif($namd_scr_data[$i[1]] =~ /^binvelocities/)
    {
      print FOUT "binvelocities   ${prefixOut}${winIndex}_re_${tmp}.vel\n";
    }
    elsif($namd_scr_data[$i[1]] =~ /^extendedSystem/)
    {
      print FOUT "extendedSystem  ${prefixOut}${winIndex}_re_${tmp}.xsc\n";
    }
    elsif($namd_scr_data[$i[1]] eq "outputname       ")
    {
      print FOUT "$namd_scr_data[$i[1]]${prefixOut}${winIndex}_out_${stage2Index}\n";
    }
    elsif($namd_scr_data[$i[1]] eq "restartname      ")
    {
      print FOUT "$namd_scr_data[$i[1]]${prefixOut}${winIndex}_re_${stage2Index}\n";
    }
    elsif($namd_scr_data[$i[1]] eq "colvarsConfig  ")
    {
      print FOUT "$namd_scr_data[$i[1]]${prefixOut}${winIndex}_${stage2Index}.in\n";
    }
    elsif($namd_scr_data[$i[1]] eq "firstTimeStep ")
    {
       print FOUT "$namd_scr_data[$i[1]]$firstTimeStep\n";
    }
    else
    {
      print FOUT "$namd_scr_data[$i[1]]\n";
    }
  }
  close FOUT;
  
  $fileOut = "${prefixOut}${winIndex}_${stage2Index}.in";
  if(open(FOUT, "> $fileOut") != 1)
  {
    print "ERROR: Cannot open $fileOut\n";
    exit;
  }
  $i[4] = 0;
  for($i[1] = 0; $i[1] <= $#namd_col_data; $i[1]++)
  {
    if($namd_col_data[$i[1]] eq "  forceConstant ")
    {
      print FOUT "$namd_col_data[$i[1]]$fc[$i[4]]\n";
    }
    elsif($namd_col_data[$i[1]] =~ /^  centers / && $i[4] <= $#{$modCenterOfThisWinLine[$i[2]-1]} && $namd_col_data[$i[1]-2] !~ /STOP_/)
    {
      print FOUT "  centers $modCenterOfThisWinLine[$i[2]-1][$i[4]]\n";
      $i[4]++;
    }
    else
    {
      print FOUT "$namd_col_data[$i[1]]\n";
    }
  }
  close FOUT;
  system("$namd_com ${prefixOut}${winIndex}_${stage2Index}.namd > ${prefixOut}${winIndex}_${stage2Index}.out");
  
  $fileIn = "${prefixOut}${winIndex}_${stage2Index}.out";
  if(open(FIN, "$fileIn") != 1)
  {
    print "ERROR: Can not open $fileIn\n";
    exit;
  }
  $line = <FIN>;
  $outOk = 0;
  while($line = <FIN>)
  {
    if($line =~ /error/i && $line !~ /^Info/)
    {
      print "ERROR: There are errors in ${prefixOut}${winIndex}_${stage2Index}.out\n";
      print "US index: $i[2]\n";
      close FIN;
      exit;
    }
    elsif($line =~ /^Program finished/ || $line =~ /End of program$/)
    {
      $outOk = 1;
    }
  }
  close FIN;
  if($outOk != 1)
  {
    print "ERROR: namd job does not normally finished (${prefixOut}${winIndex}_${stage2Index}.out)\n";
    print "US index: $i[2]\n";
    exit;
  }
  
  $fileIn = "${prefixOut}${winIndex}_out_${stage2Index}.colvars.traj";
  if(open(FIN, "$fileIn") != 1)
  {
    print "ERROR: Can not open $fileIn\n";
    exit;
  }
  
  if($binmode eq "yes")
  {
    $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen.traj.bin";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }
    binmode(FOUT);
  }
  elsif($binmode eq "no")
  {
    $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen.traj";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }
  }
  else
  {
    print "ERROR: binary out? ($binmode)\n";
    exit;
  }
  
  if($lastWinBut == 2)
  {
    if($binmode eq "yes")
    {
      $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen2.traj.bin";
      if(open(FOUT2, "> $fileOut") != 1)
      {
        print "ERROR: Can not open $fileOut\n";
        exit;
      }
      binmode(FOUT2);
    }
    elsif($binmode eq "no")
    {
      $fileOut = "${prefixOut}${winIndex}_out_${stage2Index}.vecLen2.traj";
      if(open(FOUT2, "> $fileOut") != 1)
      {
        print "ERROR: Can not open $fileOut\n";
        exit;
      }
    }
    else
    {
      print "ERROR: binary out? ($binmode)\n";
      exit;
    }
  }
  
  @avg = map {0} 0..$#digging;
  @sd = map {0} 0..$#digging;
  $i[0] = -$skipNum;
  $line = <FIN>;
  while($line = <FIN>)
  {
    @word = split(/\s+/, "$line");
    if($word[0] eq "")
    {
      shift(@word);
      shift(@word);
      $i[3] = ($#word - 1) / 2;
      @diheNow = map { $word[$_*2] } 0..$i[3];
      if($i[0] >= 0)
      {
        for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
        {
          if(abs(angleRangeMod($diheNow[$i[4]] - $modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]])) >= 90)
          {
            print "ERROR: strange data dihedral: $diheNow[$i[4]]\n";
            print "       ref. dihedral: $modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]]\n";
            exit;
          }
          if($modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]] > 90 && $diheNow[$i[4]] < 0)
          {
            $diheNow[$i[4]] += 360;
          }
          elsif($modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]] == -90 && $diheNow[$i[4]] == 180)
          {
            $diheNow[$i[4]] -= 360;
          }
          elsif($modCenterOfThisWinLine[$#modCenterOfThisWinLine][$i[4]] < -90 && $diheNow[$i[4]] > 0)
          {
            $diheNow[$i[4]] -= 360;
          }
        }
        @avg = map {$avg[$_] + $diheNow[$_]} 0..$#avg;
        @sd = map {$sd[$_] + $diheNow[$_] * $diheNow[$_]} 0..$#avg;
        
        $tmp = vecProjUnit(\@diheNow, \@refVec, \@routeVecUnit);
        if($binmode eq "yes")
        {
          syswrite(FOUT, pack('d<', $tmp));
        }
        elsif($binmode eq "no")
        {
          $tmp = sprintf("%.14e", $tmp);
          print FOUT "$tmp";
        }
        
        if($lastWinBut == 2)
        {
          $tmp = vecProjUnit(\@diheNow, \@nextRefVec, \@nextRouteVecUnit);
          if($binmode eq "yes")
          {
            syswrite(FOUT2, pack('d<', $tmp));
          }
          elsif($binmode eq "no")
          {
            $tmp = sprintf("%.14e", $tmp);
            print FOUT2 "$tmp\n";
          }
        }
        
        $tmp = vecProjUnit(\@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]}, \@diheNow, \@routeVecUnit);
        if($binmode eq "yes")
        {
          syswrite(FOUT, pack('d<', $tmp));
        }
        elsif($binmode eq "no")
        {
          $tmp = sprintf("%.14e", $tmp);
          print FOUT " $tmp";
        }
        
        @forceNow = map { $word[$_*2 + 1] } 0..$i[3];
        $tmp = totalWork(\@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]}, \@diheNow, \@forceNow);
        if($binmode eq "yes")
        {
          syswrite(FOUT, pack('d<', $tmp));
        }
        elsif($binmode eq "no")
        {
          $tmp = sprintf("%.14e", $tmp);
          print FOUT " $tmp\n";
        }
        
        $i[0]++;
      }
    }
  }
  
  close FIN;
  close FOUT;
  close FOUT2;
  
  system("rm $fileIn");
  
  @avg = map {$avg[$_] / $i[0]} 0..$#avg;
  
  @{$modCenterOfThisWinLine[$#modCenterOfThisWinLine + 1]} = map {$modCenterOfThisWinLine[$#modCenterOfThisWinLine][$_] + $refCoorOfThisWin[$_] - $avg[$_]} 0..$#avg;
  angleRangeModArr(\@{$modCenterOfThisWinLine[$#modCenterOfThisWinLine]});
  
  $fileOut = "${prefixOut}${winIndex}.rec2";
  if(open(RECORDOUT2, ">> $fileOut") != 1)
  {
    print "ERROR: Cannot open $fileOut\n";
    exit;
  }
  $line = join(" ", @{$modCenterOfThisWinLine[$i[2]]});
  $i[2]++;
  print RECORDOUT2 "$i[2] $line\n";
  $i[2]--;
  close RECORDOUT2;
  
  @sd = map {($sd[$_] / $i[0] - $avg[$_] * $avg[$_])**0.5} 0..$#avg;
  angleRangeModArr(\@avg);
  @probDensCenter = map {1/$sd[$_]/2.50662825325} 0 ..$#sd;
  @halfHightProbDensLowerLimit = map {$probDensCenter[$_] / 2 - $probDensCenter[$_] / 20} 0..$#probDensCenter;
  @halfHightProbDensUpperLimit = map {$probDensCenter[$_] / 2 + $probDensCenter[$_] / 20} 0..$#probDensCenter;
  @probDens = map {exp($halfWidthFactor[$_]*$halfWidthFactor[$_]/-2/$sd[$_]/$sd[$_]) * $probDensCenter[$_]} 0..$#probDensCenter;
  
  $i[4] = 0;
  if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]] && 0)
  {
    $new_fc[$i[4]] = $fc[$i[4]] * 1.25;
    if($new_fc[$i[4]] >= $maxFc)
    {
      $new_fc[$i[4]] = $maxFc;
    }
  }
  else
  {
    if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
    {
      $new_fc[$i[4]] = $fc[$i[4]] * 1.25;
      if($new_fc[$i[4]] >= $maxFc)
      {
        $new_fc[$i[4]] = $maxFc;
      }
    }
    elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
    {
      $new_fc[$i[4]] = $fc[$i[4]] * 0.8;
      if($fc[$i[4]] <= $minFc)
      {
        $new_fc[$i[4]] = $minFc;
      }
    }
    else
    {
      $new_fc[$i[4]] = $fc[$i[4]];
    }
  }
  print RECORDOUT sprintf("%9d %7d %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $i[2], $stage2Index, $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
  $fc[$i[4]] = $new_fc[$i[4]];
  for($i[4] = 1, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
  {
    if(abs(angleRangeMod($avg[$i[4]] - $refCoorOfThisWin[$i[4]])) > $centerDisplaceTol[$i[4]])
    {
      $new_fc[$i[4]] = $fc[$i[4]] * 1.25;
      if($new_fc[$i[4]] >= $maxFc)
      {
        $new_fc[$i[4]] = $maxFc;
      }
    }
    else
    {
      if($probDens[$i[4]] > $halfHightProbDensUpperLimit[$i[4]])
      {
        $new_fc[$i[4]] = $fc[$i[4]] * 1.25;
        if($new_fc[$i[4]] >= $maxFc)
        {
          $new_fc[$i[4]] = $maxFc;
        }
      }
      elsif($probDens[$i[4]] < $halfHightProbDensLowerLimit[$i[4]])
      {
        $new_fc[$i[4]] = $fc[$i[4]] * 0.8;
        if($fc[$i[4]] <= $minFc)
        {
          $new_fc[$i[4]] = $minFc;
        }
      }
      else
      {
        $new_fc[$i[4]] = $fc[$i[4]];
      }
    }
    print RECORDOUT sprintf(" %s %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E %.14E", $stateLine[$i[4]], $fc[$i[4]], $refCoorOfThisWin[$i[4]], angleRangeMod($refCoorOfThisWin[$i[4]]-$centerDisplaceTol[$i[4]]), angleRangeMod($refCoorOfThisWin[$i[4]]+$centerDisplaceTol[$i[4]]), $avg[$i[4]], $sd[$i[4]], $probDensCenter[$i[4]], $probDens[$i[4]], $halfHightProbDensLowerLimit[$i[4]], $halfHightProbDensUpperLimit[$i[4]]);
  }
  print RECORDOUT "\n";
  
  $i[2]++;
  $mdNumNow++;
  $stage2Index++;
  $firstTimeStep += $runStep;
}
close RECORDOUT;

exit;

# __END__
# 
# __C__
# 
# double vecProjUnit(int n, AV* vecNow, AV* refVec, AV* routeVec)
# {
#   int i;
#   double D;
#   double X;
#   
#   X = 0;
#   for(i = 0; i < n; i++)
#   {
#     SV** vn = av_fetch(vecNow, i, 0);
#     SV** rv = av_fetch(refVec, i, 0);
#     D = SvNV(*vn) - SvNV(*rv);
#     if(D > 180)
#     {
#       D -= 360;
#     }
#     else if(D <= -180)
#     {
#       D += 360;
#     }
#     
#     SV** rov = av_fetch(routeVec, i, 0);
#     X += SvNV(*rov) * D;
#   }
#   
#   return X;
# }
# 
# double forceVecProjUnit(int n, AV* forceVecNow, AV* routeVec)
# {
#   int i;
#   double F;
#   
#   F = 0;
#   for(i = 0; i < n; i++)
#   {
#     SV** fvn = av_fetch(forceVecNow, i, 0);
#     SV** rov = av_fetch(routeVec, i, 0);
#     F += SvNV(*rov) * SvNV(*fvn);
#   }
#   
#   return F;
# }
