#GDFONTPATH="/usr/share/fonts/truetype"

#set xrange [-0.5:6.5] reverse
#set yrange [-80:20]
#set y2range [-80:20]

set tics front
set tics scale 3

set border linewidth 1.5

set xtics font "Droid Sans Fallback Bold, 24"
set ytics font "Droid Sans Fallback Bold, 24"
set y2tics font "Droid Sans Fallback Bold, 24"

set xtics 10
set ytics 5
set y2tics 5

set mxtics 2
#set xtics ("0" 0, "" 0.5 1, "1" 1, "" 1.5 1, "2" 2, "" 2.5 1, "3" 3, "" 3.5 1, "4" 4, "" 4.5 1, "5" 5, "" 5.5 1, "6" 6, "" 6.5 1, "7" 7, "" 7.5 1, "8" 8, "" 8.5 1, "9" 9)
set mytics 5

set bmargin 5
set lmargin 14
set rmargin 7

set xlabel "Travelling Progress (%)" font "Droid Sans Fallback Bold, 30" offset 0, -0.8
set ylabel "PMF (kcal/mol)" font "Droid Sans Fallback Bold, 30" offset -4.5, 0

set key font "Droid Sans Fallback Bold, 18"
set key at 6.2, 38
set key spacing 2
set key left

#set terminal pngcairo enhanced color transparent truecolor fontscale 1.0 linewidth 3.0 size 1600,800
set terminal pngcairo enhanced color truecolor fontscale 1.0 linewidth 3.0 size 1600,800
set output "09_pmf.png"

plot \
"08_pmfSum.txt" using 1:2 with lines linetype 1 linecolor rgb "#FF0000" title ""

#plot \
#"07_pmfBUD_25.txt" using 1:2 with lines linetype 1 linecolor rgb "#000000" title "25 bins/Å", \
#"07_pmfBUD_50.txt" using 1:2 with lines linetype 1 linecolor rgb "#670048" title "50", \
#"07_pmfBUD_100.txt" using 1:2 with lines linetype 1 linecolor rgb "#9600FF" title "100", \
#"07_pmfBUD_200.txt" using 1:2 with lines linetype 1 linecolor rgb "#FF0000" title "200"
