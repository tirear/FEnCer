use strict;

#perl 03_2runDTMD.pl 03_namdCommands_0.txt
#                     0

if($#ARGV != 0)
{
  print "ERROR\n";
  print "perl 03_2runDTMD.pl 0\n";
  print "0: the file containing namd commands\n\n";
  exit;
}

my $namdComFile = "$ARGV[0]";
my $namd_com;
my $ok;
my $failRepeat = 3;
my $fileIn;
my $i;
my @line;
my $namdScriptPre="02_dtmd";

$fileIn = "$namdComFile";
if(open(FIN, "$fileIn") != 1)
{
  print "ERROR: Cannot open $fileIn\n";
  exit;
}

while($line[0] = <FIN>)
{
  chomp($line[0]);
  if($line[0] eq '#namd_command')
  {
    $namd_com = <FIN>;
    chomp($namd_com);
  }
  else
  {
    print "ERROR: Something wrong within the namd command file $fileIn\n";
    exit 1;
  }
}

close FIN;

$ok = 0;
for($i = 0; $i < $failRepeat; $i++)
{
  system("$namd_com $namdScriptPre.namd > $namdScriptPre.out");
  
  $fileIn = "$namdScriptPre.out";
  if(open(FIN, "$fileIn") != 1)
  {
    print "ERROR: Can not open $fileIn\n";
    exit;
  }
  
  while($line[0] = <FIN>)
  {
    if($line[0] =~ /error/i && $line[0] !~ /^Info/)
    {
      print "ERROR: There are errors in $fileIn\n";
      close FIN;
      exit;
    }
    elsif($line[0] eq "Program finished.\n")
    {
      $ok = 1;
    }
  }
  
  close FIN;
  
  if($ok == 1)
  {
    last;
  }
}

exit;
