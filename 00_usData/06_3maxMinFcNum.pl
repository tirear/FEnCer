use strict;

# perl 06_3maxMinFcNum.pl 1 0.003 40
#                      0 1     2
if($#ARGV != 2)
{
  print "perl 06_3maxMinFcNum.pl 0 1 2\n";
  print "0: maximum of force constant\n";
  print "0: minimum of force constant\n";
  print "1: number of USMD\n\n";
  exit;
}

my $maxFc = $ARGV[0];
my $minFc = $ARGV[1];
my $mdNum = $ARGV[2];
my $thre = int($mdNum * 0.8);
my $diheNum;
my @winNum;
my $line;
my $line2;
my @word;
my $fileIn;
my $fileOut;
my @i;
my @maxNum;
my @minNum;

$fileIn = "01_allRoutes.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Cannot open $fileIn\n";
  exit;
}

$line = <FIN>;
chomp($line);
@word = split(/\s+/, $line);
$diheNum = $word[2];

close FIN;

$fileIn = "01_allWinNum.txt";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Cannot open $fileIn\n";
  exit;
}

while($line = <FIN>)
{
  chomp($line);
  @word = split(/\s+/, $line);
  push(@winNum, $word[2]);
}

close FIN;

$fileOut = "06_3maxFcNum.txt";
if(open(FOUT, "> $fileOut") != 1)
{
  print "ERROR: Cannot open $fileOut\n";
  exit;
}

$fileOut = "06_3minFcNum.txt";
if(open(FOUT2, "> $fileOut") != 1)
{
  print "ERROR: Cannot open $fileOut\n";
  exit;
}

for($i[0] = 0, $i[1] = $#winNum + 1; $i[0] < $i[1]; $i[0]++)
{
  print "Route $i[0]\n";
  for($i[2] = 0, $i[3] = $winNum[$i[0]]; $i[2] < $i[3]; $i[2]++)
  {
    $fileIn = "mdData/r$i[0]/w$i[2]/05_w$i[2].rec";
    if(open(FIN, "$fileIn") != 1)
    {
      print "ERROR: Cannot open $fileIn\n";
      exit;
    }
    
    @maxNum = (0) x $diheNum;
    @minNum = (0) x $diheNum;
    while($line = <FIN>)
    {
      @word = split(/\s+/, $line);
      if($word[2] == 2)
      {
        @word = split(/\s+/, $line2);
        for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
        {
          $i[6] = 4 + $i[4] * 11;
          if($word[$i[6]] == $maxFc)
          {
            $maxNum[$i[4]]++;
          }
          elsif($word[$i[6]] == $minFc)
          {
            $minNum[$i[4]]++;
          }
        }
        @word = split(/\s+/, $line);
        for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
        {
          $i[6] = 4 + $i[4] * 11;
          if($word[$i[6]] == $maxFc)
          {
            $maxNum[$i[4]]++;
          }
          elsif($word[$i[6]] == $minFc)
          {
            $minNum[$i[4]]++;
          }
        }
        while($line = <FIN>)
        {
          @word = split(/\s+/, $line);
          for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
          {
            $i[6] = 4 + $i[4] * 11;
            if($word[$i[6]] == $maxFc)
            {
              $maxNum[$i[4]]++;
            }
            elsif($word[$i[6]] == $minFc)
            {
              $minNum[$i[4]]++;
            }
          }
        }
        $i[6] = 0;
        $i[7] = 0;
        for($i[4] = 0, $i[5] = $diheNum; $i[4] < $i[5]; $i[4]++)
        {
          if($maxNum[$i[4]] >= $thre)
          {
            $i[6]++;
          }
          elsif($minNum[$i[4]] >= $thre)
          {
            $i[7]++;
          }
        }
        print FOUT "r$i[0],w$i[2]: $i[6]/$diheNum\n";
        print FOUT2 "r$i[0],w$i[2]: $i[7]/$diheNum\n";
      }
      else
      {
        $line2 = $line;
      }
    }
  }
  undef @maxNum;
  undef @minNum;
}

close FOUT;
close FOUT2;

exit;
