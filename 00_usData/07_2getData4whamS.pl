# use Inline C;
use strict;

#perl 07_2getData4whamS.pl 0 0 3 10000 10 15 10 no
#                          0 1 2 3     4  5  6  7

if($#ARGV != 7)
{
  print "perl 07_2getData4whamS.pl 0 1 2 3 4 5 6 7\n";
  print "0: index of this route\n";
  print "1: the first index of window\n";
  print "2: the last index of window\n";
  print "3: number of steps in one USMD\n";
  print "4: first USMD index\n";
  print "5: last USMD index\n";
  print "6: collective varialbe saving period\n";
  print "7: binary out?(yes or no)\n\n";
  exit;
}

my $routeIndex =   $ARGV[0];
my $first =        $ARGV[1];
my $last =         $ARGV[2];
my $runStep =      $ARGV[3];
my $firstMdIndex = $ARGV[4];
my $lastMdIndex =  $ARGV[5];
my $colvarPeriod = $ARGV[6];
my $binmode =      $ARGV[7];
my $totalFrameNum = $runStep * ($lastMdIndex - $firstMdIndex + 1) / $colvarPeriod;
my $outPre = "07_2data4whamS";
my @routeVec;
my @i;
my $line;
my $usIndexFirst;
my $usIndexLast;
my $pathPre;
my @word;
my $counter;
my $energy;
my $resNum;
my $fileIn;
my $fileOut;
my $outLine1 = "";
my $outLine2 = "";
my $outLine3 = "";
my @fc;

$fileIn = "01_allRoutesUnit.txt";
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
    @routeVec = split(/\s+/, "$line");
    last;
  }
  $i[0]++;
}

close FIN;

for($i[0] = $first, $i[1] = $last + 1; $i[0] < $i[1]; $i[0]++)
{
  $counter = 0;
  for($i[2] = $firstMdIndex, $i[3] = $lastMdIndex + 1; $i[2] < $i[3]; $i[2]++)
  {
    $pathPre = "mdData/r${routeIndex}/w$i[0]";
    
    if($binmode eq "yes")
    {
      $fileIn = "$pathPre/05_w$i[0]_out_$i[2].vecLen.traj.bin";
      if(open(BFIN, "$fileIn") != 1)
      {
        print "ERROR: Can not open $fileIn\n";
        exit;
      }
      binmode(BFIN);
      
      sysread(BFIN, $line, 8);
      sysread(BFIN, $line, 8);
      sysread(BFIN, $line, 8);
      while(sysread(BFIN, $line, 8))
      {
        $outLine2 .= unpack("d", $line);
        $outLine2 .= "\n";
        sysread(BFIN, $line, 8);
        if(sysread(BFIN, $line, 8) == 0)
        {
          print "ERROR: file corrupted?\n";
          exit;
        }
        $energy = sprintf("%.14e", unpack("d", $line));
        $outLine3 .= "$energy\n";
        $counter++;
        if($counter % 1000 == 0)
        {
          print "file $fileIn ($counter)\n";
        }
      }
      
      close BFIN;
    }
    elsif($binmode eq "no")
    {
      $fileIn = "$pathPre/05_w$i[0]_out_$i[2].vecLen.traj";
      if(open(FIN, "$fileIn") != 1)
      {
        print "ERROR: Can not open $fileIn\n";
        exit;
      }
      
      $line = <FIN>;
      while($line = <FIN>)
      {
        chomp($line);
        @word = split(/\s+/, "$line");
        $outLine2 .= "$word[0]\n";

        $energy = $word[2];
        $energy = sprintf("%.14e", $energy);
        $outLine3 .= "$energy\n";
        $counter++;
        if($counter % 1000 == 0)
        {
          print "file $fileIn ($counter)\n";
        }
      }
      close FIN;
    }
    else
    {
      print "ERROR: binary out? ($binmode)\n";
      exit;
    }
  }
  
  print "file $fileIn ($counter) [finished]\n";
  if($counter != $totalFrameNum)
  {
    print "ERROR: Not enough frames?! $counter / $totalFrameNum.\n";
    exit;
  }
  $outLine1 .= "$counter\n";
}

$fileOut = "${outPre}_r$routeIndex.txt";
if(open(FOUT, "> $fileOut") != 1)
{
  print "ERROR: Can not open $fileOut\n";
  exit;
}

$i[0] = $last - $first + 1;
print FOUT "simulation_number $i[0]\n";
print FOUT "frame_number\n$outLine1";
print FOUT "value_on_the_reaction_coordinate\n$outLine2";
print FOUT "biasing_potential_energy\n$outLine3";

close FOUT;

exit;
# 
# __END__
# 
# __C__
# 
# double sumForce(AV* array, int n, AV* arrRmsdVec)
# {
#   int i;
#   double F;
#   
#   F = 0;
#   for(i = 0; i < n; i++)
#   {
#     SV** elem2 = av_fetch(array, 2 * i + 1, 0);
#     SV** rmsdVec = av_fetch(arrRmsdVec, i, 0);
#     if(elem2 != NULL)
#     {
#       F += SvNV(*elem2) * SvNV(*rmsdVec);
#     }
#   }
#   
# //  for(i = 0, d_sum = 0.0; i < n; i++)
# //  {
# //    SV** elem1 = av_fetch(array, 2 * i, 0);
# //    SV** elem2 = av_fetch(array, 2 * i + 1, 0);
# //    SV** rmsdRef = av_fetch(arrRmsdRef, i, 0);
# //    SV** rmsdRatio = av_fetch(arrRmsdVec, i, 0);
# ////    if(elem1 != NULL && elem2 != NULL)
# ////    {
# ////    d_pe = (SvNV(*elem1) - SvNV(*rmsdRef)) * SvNV(*elem2) * SvNV(*rmsdRatio);
# //    d_pe = (SvNV(*rmsdRef) - SvNV(*elem1)) * SvNV(*elem2) * SvNV(*rmsdRatio);
# ////    if(d_pe < 0)
# ////    {
# ////      d_pe *= -1;
# ////    }
# //    d_sum += d_pe;
# ////    printf("%e %e %e %e\n", SvNV(*elem1) , SvNV(*elem2), SvNV(*rmsdRef), d_sum);
# ////    }
# ////    else
# ////    {
# ////      printf("%d bad %d\n", i, n);
# ////    }
# //  }
#   return F * 0.5;
# }
