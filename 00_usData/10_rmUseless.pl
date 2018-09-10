use strict;

# perl 10_1getData4whamS.pl 2 40
#                           0 1

if($#ARGV != 1)
{
  print "perl 10_1getData4whamS.pl 0 1\n";
  print "0: removing level (1 or 2)\n";
  print "1: number of USMD\n\n";
  exit;
}

my $level = $ARGV[0];
my $mdNum = $ARGV[1];
my @winNum;
my $line;
my @word;
my $fileIn;
my @i;
my $pathLine;

if($level > 2)
{
  print "ERROR: removing level ($level) should be 1 or 2\n;";
  exit;
}

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

if($level == 1)
{
  for($i[0] = 0, $i[1] = $#winNum + 1; $i[0] < $i[1]; $i[0]++)
  {
    print "Level 1, Route: $i[0]\n";
    for($i[2] = 0, $i[3] = $winNum[$i[0]]; $i[2] < $i[3]; $i[2]++)
    {
      $pathLine = "mdData/r$i[0]/w$i[2]/00_DTMD";
      system("rm $pathLine/02_dtmd_out_1.colvars.state $pathLine/02_dtmd_out_1.coor $pathLine/02_dtmd_out_1.vel $pathLine/02_dtmd_out_1.xsc $pathLine/*.BAK");
#       system("rm $pathLine/02_dtmd_out_1.coor");
#       system("rm $pathLine/02_dtmd_out_1.vel");
#       system("rm $pathLine/02_dtmd_out_1.xsc");
#       system("rm $pathLine/*.BAK");
      
      $pathLine = "mdData/r$i[0]/w$i[2]";
      for($i[4] = 1, $i[5] = $mdNum + 1; $i[4] < $i[5]; $i[4]++)
      {
        system("rm $pathLine/05_w$i[2]_out_$i[4].*.BAK $pathLine/05_w$i[2]_out_$i[4].colvars.state $pathLine/05_w$i[2]_out_$i[4].coor $pathLine/05_w$i[2]_out_$i[4].vel $pathLine/05_w$i[2]_out_$i[4].xsc $pathLine/05_w$i[2]_re_$i[4].*.old");
#         system("rm $pathLine/05_w$i[2]_out_$i[4].colvars.state");
#         system("rm $pathLine/05_w$i[2]_out_$i[4].coor");
#         system("rm $pathLine/05_w$i[2]_out_$i[4].vel");
#         system("rm $pathLine/05_w$i[2]_out_$i[4].xsc");
#         system("rm $pathLine/05_w$i[2]_re_$i[4].*.old");
      }
    }
  }
}

if($level == 2)
{
  for($i[0] = 0, $i[1] = $#winNum + 1; $i[0] < $i[1]; $i[0]++)
  {
    print "Level 2, Route: $i[0]\n";
    for($i[2] = 0, $i[3] = $winNum[$i[0]]; $i[2] < $i[3]; $i[2]++)
    {
      $pathLine = "mdData/r$i[0]/w$i[2]/00_DTMD";
      system("rm $pathLine/02_dtmd_out_1.xst $pathLine/02_dtmd_out_1.dcd");
#       system("rm $pathLine/02_dtmd_out_1.dcd");
      
      $pathLine = "mdData/r$i[0]/w$i[2]";
      system("rm $pathLine/05_r$i[0]w$i[2].* $pathLine/05_2runUS.out");
#       system("rm $pathLine/05_2runUS.out");
      
      for($i[4] = 1, $i[5] = $mdNum + 1; $i[4] < $i[5]; $i[4]++)
      {
        system("rm $pathLine/05_w$i[2]_$i[4].namd $pathLine/05_w$i[2]_$i[4].out $pathLine/05_w$i[2]_out_$i[4].dcd $pathLine/05_w$i[2]_out_$i[4].xst");
#         system("rm $pathLine/05_w$i[2]_$i[4].out");
#         system("rm $pathLine/05_w$i[2]_out_$i[4].dcd");
#         system("rm $pathLine/05_w$i[2]_out_$i[4].xst");
      }
      for($i[4] = 1, $i[5] = $mdNum; $i[4] < $i[5]; $i[4]++)
      {
        system("rm $pathLine/05_w$i[2]_re_$i[4].*");
      }
    }
  }
}

exit;
