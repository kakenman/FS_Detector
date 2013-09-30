#! /usr/bin/perl

open (MONO, $ARGV[1]) || die "$ARGV[1] : $!";

$i=0;
while(<MONO>){
    chomp;
    $monophone[$i++] = $_;
}

open (PROTO, $ARGV[0]) || die "$ARGV[0] : $!";

while(<PROTO>){
    if(/~h/){
	last;
    }
    print;
}
close(PROTO);

for($j=0;$j<$i;$j++){
    
    open (PROTO, $ARGV[0]) || die "$ARGV[0] : $!";
    
    $flag=0;
    while(<PROTO>){
	chomp;
	if($flag==1){
	    print "$_\n";
	}
	if($flag==0){
	    if(/~h/){
		$flag=1;
		print "~h \"$monophone[$j]\"\n";
	    }
	}
    }
    close(PROTO);
}
