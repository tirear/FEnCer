use strict;
use warnings;

# perl 02_npt2nvt4xst.pl "../../../tmd_out_all.xst" "02_npt2nvt.xst"
#                        0                          1

if($#ARGV != 1)
{
  print "perl 02_1relaxingTraj.pl 0 1\n";
  print "0: namd xst file name\n";
  print "1: output file name\n\n";
  exit;
}

my $xstIn =     $ARGV[0];
my $xstOut =    $ARGV[1];
my $line;
my $line2;
my @word;
my $dataNum;
my @xstTitle;
my @xstArrArr;
my @avgXstArr;

open(FIN, "$xstIn") or die "ERROR: Can not open $xstIn\n";

$line = <FIN>;
chomp($line);
push(@xstTitle, $line);
$line = <FIN>;
chomp($line);
push(@xstTitle, $line);
@avgXstArr = (0) x 9;
$dataNum = 0;
while($line = <FIN>)
{
  chomp($line);
  @{$xstArrArr[$dataNum]} = split(/\s+/, $line);
  @avgXstArr = map {$avgXstArr[$_] + $xstArrArr[$dataNum][$_+1]} (0..8);
  $dataNum++;
}

close FIN;

@avgXstArr = map {$avgXstArr[$_] / $dataNum} (0..8);
$line = join(' ', @avgXstArr);

open(FOUT, "> $xstOut") or die "ERROR: Can not open $xstOut\n";

print FOUT "$xstTitle[0]\n$xstTitle[1]\n";
foreach(@xstArrArr)
{
  $line2 = join(' ', splice(@{$_}, 10, 9));
  print FOUT "${$_}[0] $line $line2\n";
}

close FOUT;

exit;
