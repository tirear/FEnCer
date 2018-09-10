use strict;

#perl 07_1getPmf.pl 0 206 10000 10 2 10 0.000001 1000000 300 0.0019872041 10 wham_s1 1  10 no
#                   0 1   2     3  4 5  6        7       8   9            10 11      12 13 14

if($#ARGV != 14)
{
  print "perl 07_1getPmf.pl 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14\n";
  print "0: first route index\n";
  print "1: last route index\n";
  print "2: number of steps in one USMD\n";
  print "3: number of USMD\n";
  print "4: number of skipped USMD\n";
  print "5: collective varialbe saving period\n";
  print "6: tolerance of energy\n";
  print "7: maximal iteration number\n";
  print "8: temperature (K)\n";
  print "9: Boltzmann's constant multiply by number\n";
  print "10: bin density (1/degree)\n";
  print "11: WHAM program command\n";
  print "12: USMD number in a sample pool\n";
  print "13: the distance of half-height sample distribution (Must >= 0)\n";
  print "14: binary out?(yes or no)\n\n";
  exit;
}

my $first =         $ARGV[0];
my $last =          $ARGV[1];
my $runStep =       $ARGV[2];
my $mdNum =         $ARGV[3];
my $skipMdNum =     $ARGV[4];
my $colvarPeriod =  $ARGV[5];
my $tolE =          $ARGV[6];
my $maxIter =       $ARGV[7];
my $tempK =         $ARGV[8];
my $kBN =           $ARGV[9];
my $binDen =        $ARGV[10];
my $wham =          $ARGV[11];
my $numMdInPool =   $ARGV[12];
my $widthFactorSampleDist = $ARGV[13];
my $binmode =       $ARGV[14];
my $numTotalPool;
my $numPool;
my $routeNum;
my @winNum;
my @targVecEndPoint;
my @nodeFrameIndex;
my $binNum;
my $fileIn;
my $fileOut;
my @i;
my $line;
my $line2;
my @word;
my @pmf;
my @lastValue;
my $firstUsmdIndex;
my $lastUsmdIndex;
my @lastSampCenOnOriVec;
my @lastSampCenOnNextVec;
my @sampleNum;

# autoflush on
$| = 1;

if($mdNum <= $skipMdNum)
{
  print "ERROR: number of USMD ($mdNum) should be larger than number of skipped USMD ($skipMdNum)\n";
  exit;
}

$numTotalPool =  $mdNum / $numMdInPool;
$numPool = ($mdNum - $skipMdNum) / $numMdInPool;

if((($mdNum - $skipMdNum) % $numMdInPool) != 0 || (($mdNum % $numMdInPool) != 0 && $numPool != 1))
{
  print "ERROR: bad USMD number ($numMdInPool) of a sample pool\n";
  print "number of USMD: $mdNum\n";
  print "number of skipped USMD: $skipMdNum\n";
  exit;
}

$fileIn = "01_allWinNumOri.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

$routeNum = 0;
while($line = <FIN>)
{
  chomp($line);
  @word = split(/\s+/, $line);
  push(@winNum, $word[2]);
  push(@targVecEndPoint, $word[1]);
  $routeNum++;
}

close FIN;

$fileIn = "01_allNodes.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

while($line = <FIN>)
{
  chomp($line);
  push(@nodeFrameIndex, $line);
}

close FIN;

for($i[4] = 1, $i[5] = $numPool + 1; $i[4] < $i[5]; $i[4]++)
{
  print "Sample pool $i[4] of $numPool\n";
  
  $firstUsmdIndex = 1 + ($i[4] - 1) * $numMdInPool + $skipMdNum;
  $lastUsmdIndex = $i[4] * $numMdInPool + $skipMdNum;
  
  if($numPool == 1)
  {
    $fileOut = "07_pmfSum.txt";
  }
  else
  {
    $fileOut = "07_pmfSumSp$i[4].txt";
  }
  
  if(-e $fileOut == 1)
  {
   print "$fileOut is already exist, skipped\n";
  }
  else
  {
    print "Getting target reaction coordinate end points\n";
    for($i[0] = $first, $i[1] = $last + 1; $i[0] < $i[1]; $i[0]++)
    {
      print "$i[0] ";
      $lastSampCenOnOriVec[$i[0]] = 0;
      $sampleNum[$i[0]] = 0;
      $lastSampCenOnNextVec[$i[0]] = 0;
      
      for($i[2] = $firstUsmdIndex, $i[3] = $lastUsmdIndex + 1; $i[2] < $i[3]; $i[2]++)
      {
        if($binmode eq "yes")
        {
          $fileIn = "mdData/r$i[0]/w$winNum[$i[0]]/05_w$winNum[$i[0]]_out_$i[2].vecLen.traj.bin";
          if(open(BFIN, "$fileIn") != 1)
          {
            print "ERROR: Can not open $fileIn\n";
            exit;
          }
          binmode(BFIN);
          
          $i[6] = 0;
          while(sysread(BFIN, $line, 8))
          {
            if($i[6] % 3 == 0)
            {
              $lastSampCenOnOriVec[$i[0]] += unpack("d", $line);
              $sampleNum[$i[0]]++;
              $i[6] = 1;
            }
            else
            {
              $i[6]++;
            }
          }
          
          close BFIN;
          
          $fileIn = "mdData/r$i[0]/w$winNum[$i[0]]/05_w$winNum[$i[0]]_out_$i[2].vecLen2.traj.bin";
          if(open(BFIN, "$fileIn") != 1)
          {
            print "ERROR: Can not open $fileIn\n";
            exit;
          }
          binmode(BFIN);
          
          while(sysread(BFIN, $line, 8))
          {
            $lastSampCenOnNextVec[$i[0]] += unpack("d", $line);
          }
          
          close BFIN;
        }
        elsif($binmode eq "no")
        {
          $fileIn = "mdData/r$i[0]/w$winNum[$i[0]]/05_w$winNum[$i[0]]_out_$i[2].vecLen.traj";
          if(open(FIN, "$fileIn") != 1)
          {
            print "ERROR: Can not open $fileIn\n";
            exit;
          }
          
          while($line = <FIN>)
          {
            @word = split(/\s+/, "$line");
            $lastSampCenOnOriVec[$i[0]] += $word[0];
            $sampleNum[$i[0]]++;
          }
          
          close FIN;
          
          $fileIn = "mdData/r$i[0]/w$winNum[$i[0]]/05_w$winNum[$i[0]]_out_$i[2].vecLen2.traj";
          if(open(FIN, "$fileIn") != 1)
          {
            print "ERROR: Can not open $fileIn\n";
            exit;
          }
          
          while($line = <FIN>)
          {
            chomp($line);
            $lastSampCenOnNextVec[$i[0]] += $line;
          }
          
          close FIN;
        }
        else
        {
          print "ERROR: binary out? ($binmode)\n";
          exit;
        }
      }
      $lastSampCenOnOriVec[$i[0]] /= $sampleNum[$i[0]];
      $lastSampCenOnNextVec[$i[0]] /= $sampleNum[$i[0]];
      
      if($i[0] != $last)
      {
        $i[2] = abs($targVecEndPoint[$i[0]] - $lastSampCenOnOriVec[$i[0]]);
        if($i[2] > $widthFactorSampleDist)
        {
          print "\nWARNING: the sample coverage at $lastSampCenOnOriVec[$i[0]] needed check\n";
        }
        if($lastSampCenOnNextVec[$i[0]] < -$widthFactorSampleDist)
        {
          print "\nWARNING: the sample coverage on next vector at $lastSampCenOnNextVec[$i[0]] needed check\n";
        }
#         $targVecEndPoint[$i[0]] = $lastSampCenOnOriVec[$i[0]];;
      }
    }
    print "\n";
    
    print "route";
    for($i[0] = $first, $i[1] = $last + 1; $i[0] < $i[1]; $i[0]++)
    {
      print " $i[0]";
      
      $i[2] = $winNum[$i[0]] + 1;
      system("perl 07_2getData4whamS.pl $i[0] 0 $i[2] $runStep $firstUsmdIndex $lastUsmdIndex $colvarPeriod $binmode > 07_2getData4whamS.log");
      
      $fileIn = "07_2getData4whamS.log";
      if(open(FIN, "$fileIn") != 1)
      {
        print "ERROR: Can not open $fileIn\n";
        exit;
      }
      
      while($line = <FIN>)
      {
        if($line =~ /ERROR/)
        {
          print "There is an error in $fileIn\n";
          close FIN;
          exit;
        }
      }
      
      close FIN;
      
      if($i[0] == $first)
      {
        $binNum = int($targVecEndPoint[$i[0]] * $binDen + 1);
        if($binNum == 1)
        {
          $binNum++;
        }
        system("$wham 07_2data4whamS_r$i[0].txt 0 $targVecEndPoint[$i[0]] $binNum $tolE $maxIter $tempK $kBN > 07_pmfR$i[0].tmp");
      }
      else
      {
        $binNum = int(($targVecEndPoint[$i[0]] - 0) * $binDen + 1);
        if($binNum == 1)
        {
          $binNum++;
        }
        system("$wham 07_2data4whamS_r$i[0].txt 0 $targVecEndPoint[$i[0]] $binNum $tolE $maxIter $tempK $kBN > 07_pmfR$i[0].tmp");
      }
      
      $fileIn = "07_pmfR$i[0].tmp";
      if(open(FIN, "$fileIn") != 1)
      {
        print "ERROR: Can not open $fileIn\n";
        exit;
      }
      
      while($line = <FIN>)
      {
        if($line =~ /Results/)
        {
          $line = <FIN>;
          $line = <FIN>;
          while($line = <FIN>)
          {
            @word = split(/\s+/, $line);
            push(@{$pmf[$i[0]]}, $word[2]);
          }
        }
      }
      close FIN;
    }

    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }

    $i[0] = $first;
    $i[2] = 0;
    @word = map {$i[2] + $pmf[$i[0]][$_]} 0..$#{$pmf[$i[0]]};
    if($i[0] + 1 <= $last)
    {
      $i[2] = $word[$#word] - $pmf[$i[0] + 1][0];
    }
    @word = map {"$nodeFrameIndex[$i[0]] $nodeFrameIndex[$i[0]+1] $word[$_]"} 0..$#word;
    $line = join("\n", @word);
    print FOUT "$line\n";
    for($i[0] = $first + 1, $i[1] = $last + 1; $i[0] < $i[1]; $i[0]++)
    {
      @word = map {$i[2] + $pmf[$i[0]][$_]} 1..$#{$pmf[$i[0]]};
      if($i[0] + 1 <= $last)
      {
        $i[2] = $word[$#word] - $pmf[$i[0] + 1][0];
      }
      @word = map {"$nodeFrameIndex[$i[0]] $nodeFrameIndex[$i[0]+1] $word[$_]"} 0..$#word;
      $line = join("\n", @word);
      print FOUT "$line\n";
    }

    close FOUT;
  }
  
  print "\n";
  undef @pmf;
}

if($numPool > 1)
{
  for($i[4] = 1, $i[5] = $numPool + 1; $i[4] < $i[5]; $i[4]++)
  {
    print "PMF data reading $i[4] of $numPool\n";
    
    $fileIn = "07_pmfSumSp$i[4].txt";
    if(open(FIN, "$fileIn") != 1)
    {
      print "ERROR: Can not open $fileIn\n";
      exit;
    }
    
    while($line = <FIN>)
    {
      $line2 = $line;
    }
    
    close FIN;
    
    chomp($line2);
    @word = split(/\s+/, "$line2");
    push(@lastValue, pop(@word));
  }

  $fileOut = "07_pmfStablity.txt";
  if(open(FOUT, "> $fileOut") != 1)
  {
    print "ERROR: Can not open $fileOut\n";
    exit;
  }
  
  for($i[4] = 1, $i[5] = $numPool + 1; $i[4] < $i[5]; $i[4]++)
  {
    print FOUT "$i[4] @lastValue[$i[4]-1]\n";
  }
  
  close FOUT;
  
  $fileOut = "07_pmfStablity.gnu";
  if(open(FOUT, "> $fileOut") != 1)
  {
    print "ERROR: Can not open $fileOut\n";
    exit;
  }
  
  print FOUT "set tics front\n";
  print FOUT "set tics scale 3\n";
  print FOUT "set border linewidth 1.5\n";
  print FOUT "set xtics font \"Droid Sans Fallback Bold, 24\"\n";
  print FOUT "set ytics font \"Droid Sans Fallback Bold, 24\"\n";
  print FOUT "set xlabel \"Sample Pool Index\" font \"Droid Sans Fallback Bold, 30\" offset 0, -0.8\n";
  print FOUT "set ylabel \"PMF (kcal/mol)\" font \"Droid Sans Fallback Bold, 30\" offset -7.5, 0\n";
  print FOUT "set terminal pngcairo enhanced color truecolor fontscale 1.0 linewidth 3.0 size 1600,800\n";
  print FOUT "set output \"07_pmfStablity.png\"\n";
  print FOUT "plot \"07_pmfStablity.txt\" using 1:2 with lines linetype 1 linecolor rgb \"#FF0000\" title \"\"\n";
  
  close FOUT;
  
  system("gnuplot $fileOut");
}

exit;
