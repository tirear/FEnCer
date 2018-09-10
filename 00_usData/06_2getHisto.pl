use strict;

# perl 06_2getHisto.pl 0 15.513385728436374 4 10000 10 4 10 0.1 no
#                      0 1                  2 3     4  5 6  7   8
if($#ARGV != 8)
{
  print "perl 06_2getHisto.pl 0 1 2 3 4 5 6 7 8\n";
  print "0: index of this route\n";
  print "1: target dihedral vector length\n";
  print "2: window number\n";
  print "3: number of steps in one USMD\n";
  print "4: number of USMD\n";
  print "5: number of skipped USMD\n";
  print "6: collective varialbe saving period\n";
  print "7: bin width of histogram\n";
  print "8: binary out?(yes or no)\n\n";
  exit;
}

my $routeIndex =   $ARGV[0];
my $vecLength =    $ARGV[1];
my $winNum =       $ARGV[2] + 2;
my $runStep =      $ARGV[3];
my $mdNum =        $ARGV[4];
my $mdSkipNum =    $ARGV[5];
my $colvarPeriod = $ARGV[6];
my $widthHisto =   $ARGV[7];
my $binmode =      $ARGV[8];
my $totalFrame = $runStep * ($mdNum - $mdSkipNum)/ $colvarPeriod;
my $vecStep = $vecLength / ($winNum - 3);
my $minHisto = $vecStep * -3;
my $maxHisto = $vecLength + $vecStep * 3;
my $histoFilePre = "06_histoR";
my $fileIn;
my @i;
my @line;
my @word;
my @fileLine;
my @colorLine;
my @gnuLine;
my $gnline;
my $pathPre;
my $loadedTotalFrame;
my $counter;
my @histo;
my @histoAll;
my $histoSize;
my @index;
my @color;
my $fileOut;
my $ok;

$fileIn = "06_2histo_template.gnu";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Can not open $fileIn\n";
  exit;
}

while($line[0] = <FIN>)
{
  chomp($line[0]);
  if($line[0] =~ /^plot/)
  {
    while($line[0] = <FIN>)
    {
      @word = split(/\s+/, "$line[0]");
      push(@fileLine, $word[0]);
      push(@colorLine, $word[1]);
    }
  }
  else
  {
    push(@gnuLine, $line[0]);
  }
}

close FIN;

$fileOut = "$histoFilePre${routeIndex}_all.gnu";
if(open(GNUOUT, "> $fileOut") != 1)
{
  print "ERROR: Can not open $fileOut\n";
  exit;
}
foreach $gnline (@gnuLine)
{
  print GNUOUT "$gnline\n";
}

$line[0] = sprintf("%.10f", ($maxHisto - $minHisto) / $widthHisto);
@index = split(/\./, "$line[0]");
$histoSize = $index[0];
@histoAll = (0) x $histoSize;

for($i[0] = 0; $i[0] < $winNum; $i[0]++)
{
  $pathPre = "mdData/r${routeIndex}/w$i[0]";
  print " $pathPre";
  
#   $fileIn = "$pathPre/05_2runUS.out";
#   if(open(FIN, "$fileIn") != 1)
#   {
#     print "ERROR: Can not open $fileIn\n";
#     exit;
#   }
#   
#   $ok = 1;
#   while($line[0] = <FIN>)
#   {
#     if($line[0] =~ "ERROR")
#     {
#       $ok = 0;
#     }
#   }
#   
#   close FIN;
#   
#   if($ok != 1)
#   {
#     print "ERROR: USMD had problem!!\n";
#     close GNUOUT;
#     exit;
#   }
  
  @histo = (0) x $histoSize;
  $counter = 0;
  $loadedTotalFrame = 0;
  
  for($i[1] = $mdSkipNum + 1; $i[1] <= $mdNum; $i[1]++)
  {
    if($binmode eq "yes")
    {
      $fileIn = "$pathPre/05_w$i[0]_out_$i[1].vecLen.traj.bin";
      if(open(BFIN, "$fileIn") != 1)
      {
        print "ERROR: Can not open $fileIn\n";
        exit;
      }
      binmode(BFIN);
      
      sysread(BFIN, $line[0], 8);
      sysread(BFIN, $line[0], 8);
      sysread(BFIN, $line[0], 8);
      while(sysread(BFIN, $line[0], 8))
      {
        $word[0] = unpack("d", $line[0]);
        if($counter == 0)
        {
          if($word[0] >= $minHisto && $word[0] <= $maxHisto)
          {
            $line[1] = sprintf("%.10f", ($word[0] - $minHisto) / $widthHisto);
            @index = split(/\./, "$line[1]");
            $histo[$index[0]]++;
            $histoAll[$index[0]]++;
          }
          $loadedTotalFrame++;
          if($loadedTotalFrame == $totalFrame)
          {
            last;
          }
        }
        elsif($counter > 0)
        {
          print "ERROR: Something is wrong? Number of frame could be skipped (\$skip) is small than zero?\n";
          exit 1;
        }
        else
        {
          $counter++;
          $loadedTotalFrame++;
        }
        sysread(BFIN, $line[0], 8);
        if(sysread(BFIN, $line[0], 8) == 0)
        {
          print "ERROR: file corrupted?\n";
          exit;
        }
      }
      close BFIN;
    }
    elsif($binmode eq "no")
    {
      $fileIn = "$pathPre/05_w$i[0]_out_$i[1].vecLen.traj";
      if(open(FIN, "$fileIn") != 1)
      {
        print "ERROR: Can not open $fileIn\n";
        exit;
      }
      
      $line[0] = <FIN>;
      while($line[0] = <FIN>)
      {
        chomp($line[0]);
        @word = split(/\s+/, $line[0]);
        if($counter == 0)
        {
          if($word[0] >= $minHisto && $word[0] <= $maxHisto)
          {
            $line[1] = sprintf("%.10f", ($word[0] - $minHisto) / $widthHisto);
            @index = split(/\./, "$line[1]");
            $histo[$index[0]]++;
            $histoAll[$index[0]]++;
          }
          $loadedTotalFrame++;
          if($loadedTotalFrame == $totalFrame)
          {
            last;
          }
        }
        elsif($counter > 0)
        {
          print "ERROR: Something is wrong? Number of frame could be skipped (\$skip) is small than zero?\n";
          exit 1;
        }
        else
        {
          $counter++;
          $loadedTotalFrame++;
        }
      }
      close FIN;
    }
    else
    {}
  }
  if($loadedTotalFrame < $totalFrame)
  {
    print "ERROR: Not enough frames?! $loadedTotalFrame / $totalFrame.\n";
    exit;
  }
  
  if($i[0] == 0)
  {
    $fileOut = "$histoFilePre${routeIndex}.txt";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open file $fileOut\n";
      exit 1;
    }
    
    for($i[1] = 0; $i[1] < $histoSize; $i[1]++)
    {
      $i[2] = $minHisto + $widthHisto * 0.5;
      $line[0] = sprintf("%.6f", $i[2] + $widthHisto * $i[1]);
      print FOUT "$line[0] $histo[$i[1]]\n";
    }
    
    close FOUT;
  }
  else
  {
    $fileIn = "$histoFilePre${routeIndex}.txt";
    if(open(FIN, "$fileIn") != 1)
    {
      print "ERROR: Can not open file $fileIn\n";
      exit 1;
    }

    $fileOut = "$histoFilePre${routeIndex}.tmp";
    if(open(FOUT, "> $fileOut") != 1)
    {
      print "ERROR: Can not open file $fileOut\n";
      exit 1;
    }

    for($i[1] = 0; $i[1] < $histoSize; $i[1]++)
    {
      $line[0] = <FIN>;
      chomp($line[0]);
      print FOUT "$line[0] $histo[$i[1]]\n";
    }

    close FIN;
    close FOUT;
    system("mv $fileOut $fileIn");
  }
}

print "\n";

$fileOut = "$histoFilePre${routeIndex}_all.txt";
if(open(FOUT, "> $fileOut") != 1)
{
  print "ERROR: Can not open file $fileOut\n";
  exit 1;
}

$i[0] = 0;
for($i[1] = 0; $i[1] < $histoSize; $i[1]++)
{
  $i[2] = $minHisto + $widthHisto * 0.5;
  $line[0] = sprintf("%.6f", $i[2] + $widthHisto * $i[1]);
  print FOUT "$line[0] $histoAll[$i[1]]\n";
  if($i[0] < $histoAll[$i[1]])
  {
    $i[0] = $histoAll[$i[1]];
  }
}

close FOUT;

print GNUOUT "set arrow from 0,0 to 0,$i[0] nohead linecolor rgb \"#ffae00\"\n";
print GNUOUT "set arrow from $vecLength,0 to $vecLength,$i[0] nohead linecolor rgb \"#ffae00\"\n";
print GNUOUT "set output \"$histoFilePre${routeIndex}.png\"\nplot \\\n";
# print GNUOUT "20 with lines linetype 1 linecolor rgb \"#ffae00\" title \"\", \\\n";
for($i[0] = 0, $i[1] = 0; $i[0] < $winNum; $i[0]++)
{
  $i[2] = $i[0] + 2;
  print GNUOUT "\"$histoFilePre${routeIndex}.txt\" using 1:$i[2] with lines linetype 1 linecolor rgb \"$colorLine[$i[1]]\" title \"\", \\\n";
  $i[1]++;
  if($i[1] == $#fileLine)
  {
    $i[1] = 0;
  }
}
print GNUOUT "\"$histoFilePre${routeIndex}_all.txt\" using 1:2 with lines linetype 1 linecolor rgb \"$colorLine[$#fileLine]\" title \"\"\n";


close GNUOUT;
system "gnuplot $histoFilePre${routeIndex}_all.gnu";
exit;
