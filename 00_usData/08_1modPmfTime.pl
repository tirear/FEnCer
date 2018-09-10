use strict;

#perl 08_1modPmfTime.pl 0.01
#                    0

if($#ARGV != 0)
{
  print "perl 08_1modPmfTime.pl 0\n";
  print "0: time scale modification\n\n";
  exit;
}

my $timeScale = $ARGV[0];
my $fileIn;
my $fileOut;
my $line;
my @word;
my @i;
my @timePmfSet;
my $first;
my $last;
my $pointNum;
my $stepSize;

$fileIn = "07_pmfSum.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

$i[0] = 0;
while($line = <FIN>)
{
  chomp($line);
  @{$timePmfSet[$i[0]]} = split(/\s+/, "$line");
  $i[0]++;
}

close FIN;

$fileOut = "08_pmfSum.txt";
if(open(FOUT, "> $fileOut") != 1)
{
  print "ERROR: Can not open $fileOut\n";
  exit;
}

$first = 0;
$i[1] = $#timePmfSet + 1;
while($first < $i[1])
{
  for($i[0] = $first + 1; $i[0] < $i[1]; $i[0]++)
  {
    if($timePmfSet[$i[0]][0] != $timePmfSet[$first][0])
    {
      last;
    }
  }
  $last = $i[0] - 1;
  $pointNum = $last - $first + 1;
  if($first != 0)
  {
    $stepSize = ($timePmfSet[$first][1] - $timePmfSet[$first][0]) / $pointNum;
    for($i[2] = 1, $i[3] = $pointNum + 1; $i[2] < $i[3]; $i[2]++)
    {
      $i[4] = ($timePmfSet[$first][0] + $i[2] * $stepSize) * $timeScale;
      print FOUT "$i[4] $timePmfSet[$first+$i[2]-1][2]\n";
    }
  }
  else
  {
    $stepSize = ($timePmfSet[$first][1] - $timePmfSet[$first][0]) / ($pointNum - 1);
    for($i[2] = 0, $i[3] = $pointNum; $i[2] < $i[3]; $i[2]++)
    {
      $i[4] = ($timePmfSet[$first][0] + $i[2] * $stepSize) * $timeScale;
      print FOUT "$i[4] $timePmfSet[$first+$i[2]][2]\n";
    }
  }
  $first = $last + 1;
}

close FOUT;

exit;
