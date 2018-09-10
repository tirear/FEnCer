#GDFONTPATH="/usr/share/fonts/truetype"

set xrange [:] reverse

set tics front
set tics scale 3

set border linewidth 1.5

set xtics font "Droid Sans Fallback Bold, 24"
set ytics font "Droid Sans Fallback Bold, 24"

#set mxtics 2
#set xtics ("3" 3, "" 3.5 1, "4" 4, "" 4.5 1, "5" 5, "" 5.5 1, "6" 6, "" 6.5 1, "7" 7, "" 7.5 1, "8" 8, "" 8.5 1, "9" 9, "" 9.5 1, "10" 10, "" 10.5 1, "11" 11, "" 11.5 1, "12" 12)
#set ytics ("0" 0, "" 20 1, "40" 40, "" 60 1, "80" 80, "" 100 1, "120" 120, "" 140 1, "160" 160)

set bmargin 5
set lmargin 20

set xlabel "MDDV (vector unit)" font "Droid Sans Fallback Bold, 30" offset 0, -0.8
set ylabel "Sample density (10/vector unit)" font "Droid Sans Fallback Bold, 30" offset -7.5, 0

#set terminal pngcairo enhanced color transparent truecolor fontscale 1.0 linewidth 3.0 size 1600,800
set terminal pngcairo enhanced color truecolor fontscale 1.0 linewidth 3.0 size 1600,800
#set output "11_histo_01_01.png"

plot \
11_histo_01_0.01.txt #000000
11_histo_01_0.01.txt #FF0000
11_histo_all_01_0.01.txt #0000FF
