version 17
* Reproducible synthetic data, not empirical evidence. Arm 0 is control.
clear
set seed 20261018
set obs 120
generate long id=_n
generate byte arm=mod(_n,3)
generate double x=rnormal()
generate double xmiss=x
replace xmiss=. if mod(id,11)==0
generate double y1=.2*(arm==1)+.5*(arm==2)+.2*x+rnormal()
generate double y2=40+2*(arm==1)+3*(arm==2)+4*x+8*rnormal()
generate double y3=200+80*(arm==1)+110*(arm==2)+20*x+50*rnormal()
replace y2=. if mod(id,9)==0
