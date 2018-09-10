use strict;

# perl 03_1submitDTMD.pl 0 4 shellsub
#                        0 1 2

if($#ARGV != 2)
{
  print "perl 03_1submitDTMD.pl 0 1 2\n";
  print "0: first index of DTMD job\n";
  print "1: last index of DTMD job\n";
  print "2: the quening system submit command\n\n";
  exit;
}

my $first = $ARGV[0];
my $last = $ARGV[1];
my $qsCommand = $ARGV[2];
my $namdCommandFile = "03_1namdCommands.txt";
my $qsFile = "03_1queue.txt";
my $fileIn;
my $fileOut;
my $line;
my @word;
my $lastRouteIndex;
my @i;
my @winNum;
my @namd_com;
my $namd_comNum;
my $namd_comNumCounter;
my $jobName;
my $pathLine;

if($first < 0)
{
  print "ERROR: The first index ($first) should not less than zero\n";
  exit;
}

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
$lastRouteIndex = 0;
$lastRouteIndex = $word[2];
if($lastRouteIndex == 0)
{
  print "ERROR: something wrong in $fileIn?\n";
  exit;
}
$lastRouteIndex--;

if($last > $lastRouteIndex)
{
  print "ERROR: The last index ($last) should not larger than TMD job index ($lastRouteIndex)\n";
  exit;
}

print "Range of DTMD job index is from 0 to $lastRouteIndex\n";
print "Range of assigned DTMD job index is from $first to $last\n";

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
  for($i[2] = 0, $i[3] = $winNum[$i[0]]; $i[2] < $i[3]; $i[2]++)
  {
    $pathLine = "mdData/r$i[0]/w$i[2]/00_DTMD/";
    print "$pathLine\n";
    
    $fileOut = "03_namdCommand_${namd_comNumCounter}.txt";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open $fileOut\n";
      exit;
    }
    
    print FOUT '#namd_command';
    print FOUT "\n";
    print FOUT "$namd_com[$namd_comNumCounter]";
    
    close FOUT;
    
    $jobName = "03_r$i[0]w$i[2]";
    system("cp $fileOut $pathLine");
    system("cp $qsFile $pathLine");
    system("cd $pathLine; cat << EOF > $jobName.sh\nperl ../../../../03_2runDTMD.pl $fileOut > 03_2runDTMD.out\nEOF\n$qsCommand $jobName < $qsFile");
    $namd_comNumCounter++;
    if($namd_comNumCounter >= $namd_comNum)
    {
      $namd_comNumCounter = 0;
    }
  }
}

exit;
