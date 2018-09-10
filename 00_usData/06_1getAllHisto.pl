use strict;

# perl 06_1getAllHisto.pl 10000 10 4 10 0.1 no
#                         0     1  2 3  4   5
if($#ARGV != 5)
{
  print "perl 06_1getAllHisto.pl 0 1 2 3 4 5\n";
  print "0: number of steps in one USMD\n";
  print "1: number of USMD\n";
  print "2: number of skipped USMD\n";
  print "3: collective varialbe saving period\n";
  print "4: bin width of histogram\n";
  print "5: binary out?(yes or no)\n\n";
  exit;
}

my $runStep =      $ARGV[0];
my $mdNum =        $ARGV[1];
my $mdSkipNum =    $ARGV[2];
my $colvarPeriod = $ARGV[3];
my $widthHisto =   $ARGV[4];
my $binmode =      $ARGV[5];
my $fileIn;
my $line;
my @word;
my $routeNum;
my @vecLength;
my @winNum;
my @i;

$fileIn = "01_allWinNumOri.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "Can not open $fileIn\n";
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

if((-e "06_histo") != 1)
{
  system("mkdir 06_histo");
}

print "route:";
for($i[0] = 0, $i[1] = $routeNum; $i[0] < $i[1]; $i[0]++)
{
  print " $i[0]";
  system("perl 06_2getHisto.pl $i[0] $vecLength[$i[0]] $winNum[$i[0]] $runStep $mdNum $mdSkipNum $colvarPeriod $widthHisto $binmode > 06_2getHisto.log");
  
  $fileIn = "06_2getHisto.log";
  if(open(FIN, "$fileIn") != 1)
  {
    print "\n";
    print "Can not open $fileIn\n";
    exit;
  }
  
  while($line = <FIN>)
  {
    if($line =~ /error/i)
    {
      print "\n";
      print "Something wrong in $fileIn\n";
      exit;
    }
  }
  system("mv 06_histoR* 06_histo/");
}

print "\n";

exit;
