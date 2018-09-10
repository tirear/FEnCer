use strict;

#perl 05_1submitUS.pl 0 206 0.04 1 0.0004 2.5 0.25 5 0.5 10000 10 shellsub 0  "deca-ala_H_v.psf" "helix-deca-ala_H_v.pdb" "par_all27_prot_na.txt" no
#                     0 1   2    3 4      5   6    7 8   9     10 11       12 13                 14                       15                      16

if($#ARGV != 16)
{
  print "perl 05_1submitUS.pl 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16\n";
  print "0: first route index\n";
  print "1: last route index\n";
  print "2: initial force constant\n";
  print "3: maximum of force constant\n";
  print "4: minimum of force constant\n";
  print "5: maximal center displacement of sample distribution (Must >= 0)\n";
  print "6: minimum of maximal center displacement of sample distribution (Must >= 0)\n";
  print "7: the distance of half-height sample distribution (Must >= 0)\n";
  print "8: minimum of the distance of half-height sample distribution (Must >= 0)\n";
  print "9: number of steps in one USMD\n";
  print "10: number of USMD\n";
  print "11: the quening system submit command\n";
  print "12: standalone job data (1) or not (0)\n";
  print "13: psf file\n";
  print "14: pdb file name\n";
  print "15: parameter file name\n";
  print "16: binary out?(yes or no)\n\n";
  exit;
}

my $first =                 $ARGV[0];
my $last =                  $ARGV[1];
my $fc =                    $ARGV[2];
my $maxFc =                 $ARGV[3];
my $minFc =                 $ARGV[4];
my $centerDisplaceTol =     $ARGV[5];
my $minCenterDisplaceTol =  $ARGV[6];
my $widthFactorSampleDist = $ARGV[7];
my $minWidthFactorSamDist = $ARGV[8];
my $runStep =               $ARGV[9];
my $mdNum =                 $ARGV[10];
my $qsCommand =             $ARGV[11];
my $standalone =            $ARGV[12];
my $psf =                   $ARGV[13];
my $pdb =                   $ARGV[14];
my $par =                   $ARGV[15];
my $binmode =               $ARGV[16];
my $namdCommandFile = "05_1namdCommands.txt";
my $qsFile = "05_1queue.txt";
my $fileIn;
my $fileOut;
my $line;
my @word;
my $routeNum;
my @vecLength;
my @winNum;
my @i;
my @namd_com;
my $namd_comNum;
my $namd_comNumCounter;
my $jobName;
my $pathLine;

if($standalone != 1 && $standalone != 0)
{
  print "ERROR: standalone job data flag should be 1 or 0\n";
  exit;
}

$fileIn = "01_allWinNum.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

$routeNum = 0;
while($line = <FIN>)
{
  chomp($line);
  @word = split(/\s+/, "$line");
  push(@vecLength, $word[1]);
  push(@winNum, $word[2]);
  $routeNum++;
}

close FIN;

if($first < 0)
{
  print "ERROR: the first route index ($first) should not less than 0\n";
  exit;
}
if($last >= $routeNum)
{
  print "ERROR: the last route index ($last) should not larger or equal to routes number ($routeNum)\n";
  exit;
}

$i[0] = $routeNum - 1;
print "Range of route index is from 0 to $i[0]\n";
print "Range of assigned route index is from $first to $last\n";

$fileIn = "$namdCommandFile";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

while($line = <FIN>)
{
  chomp($line);
  if($line eq '#namd_command')
  {
    $namd_com[$namd_comNum] = <FIN>;
    $namd_comNum++;
  }
  else
  {
    print "ERROR: Something wrong within the namd command file $fileIn\n";
    exit;
  }
}

close FIN;

$namd_comNumCounter = 0;
for($i[0] = $first, $i[1] = $last + 1; $i[0] < $i[1]; $i[0]++)
{
#   $i[4] = $vecLength[$i[0]] / ($winNum[$i[0]] - 1);
  for($i[2] = 0, $i[3] = $winNum[$i[0]]; $i[2] < $i[3]; $i[2]++)
  {
    $pathLine = "mdData/r$i[0]/w$i[2]/";
    print "$pathLine\n";
    
    $fileOut = "05_namdCommand_${namd_comNumCounter}.txt";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }
    
    print FOUT '#namd_command';
    print FOUT "\n";
    print FOUT "$namd_com[$namd_comNumCounter]";
    
    close FOUT;
    
#     $i[5] = ($i[2] - 1) * $i[4];
    $jobName = "05_r$i[0]w$i[2]";
    system("cp $fileOut $pathLine");
    if($standalone == 1)
    {
      system("cp $psf $pdb $par 01_allWinNum.txt 01_allNodesAndRefOri.txt 01_allNodesAndRefOriM.txt 01_allRoutesUnit.txt 05_2runUS.pl $qsFile $pathLine");
      system("cd $pathLine; cat << EOF > $jobName.sh\nperl 05_2runUS.pl $fileOut $fc $maxFc $minFc $centerDisplaceTol $minCenterDisplaceTol $widthFactorSampleDist $minWidthFactorSamDist $runStep $mdNum $i[0] $i[2] $binmode $standalone > 05_2runUS.out\nEOF\n$qsCommand $jobName < $qsFile");
    }
    else
    {
      system("cd $pathLine; cat << EOF > $jobName.sh\nperl ../../../05_2runUS.pl $fileOut $fc $maxFc $minFc $centerDisplaceTol $minCenterDisplaceTol $widthFactorSampleDist $minWidthFactorSamDist $runStep $mdNum $i[0] $i[2] $binmode $standalone > 05_2runUS.out\nEOF\n$qsCommand $jobName < ../../../$qsFile");
    }
    $namd_comNumCounter++;
    if($namd_comNumCounter >= $namd_comNum)
    {
      $namd_comNumCounter = 0;
    }
  }
}

exit;
