# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

# change this if you need to

my $DRIVER = $ENV{DRIVER};
use constant USER => $ENV{USER};
use constant PASS => $ENV{PASS};
use constant DBNAME => $ENV{DB} || 'test';

BEGIN { $| = 1; print "1..20\n"; }
END {print "not ok 1\n" unless $loaded;}
use lib './lib','../lib';
use DBI;
use Tie::RDBM;
$loaded = 1;

######################### End of black magic.

sub test {
    local($^W) = 0;
    my($num, $true,$msg) = @_;
    print($true ? "ok $num\n" : "not ok $num $msg\n");
}

unless ($DRIVER) {
    local($^W)=0;  # kill uninitialized variable warning
# Test using the mysql, sybase, oracle and mSQL databases respectively
    my ($count) = 0;
    my (%DRIVERS) = map { ($_,$count++) } qw(Informix Pg Ingres mSQL Sybase Oracle mysql); # ExampleP doesn't work
    ($DRIVER) = sort { $DRIVERS{$b}<=>$DRIVERS{$a} } DBI->available_drivers(1);
}

if ($DRIVER) {
    print STDERR "Using DBD driver $DRIVER...";
} else {
    die "Found no DBD driver to use.\n";
}

my($dsn) = "dbi:$DRIVER:${\DBNAME}";
print "ok 1\n";
test 2,tie %h,Tie::RDBM,$dsn,{create=>1,drop=>1,table=>'PData','warn'=>0,user=>USER,password=>PASS};
%h=();
test 3,!scalar(keys %h);
test 4,$h{'fred'} = 'ethel';
test 5,$h{'fred'} eq 'ethel';
test 6,$h{'ricky'} = 'lucy';
test 7,$h{'ricky'} eq 'lucy';
test 8,$h{'fred'} = 'lucy';
test 9,$h{'fred'} eq 'lucy';
test 10,exists($h{'fred'});
test 11,delete $h{'fred'};
test 12,!exists($h{'fred'});
if (tied(%h)->{canfreeze})
{
  local($^W) = 0;  # avoid uninitialized variable warning
  test 13,$h{'fred'}={'name'=>'my name is fred','age'=>34};
  test 14,$h{'fred'}->{'age'} == 34;
} else {
  print STDERR "Skipping tests 13-14 on this platform...";
  print "ok 13 (skipped)\n"; #skip
  print "ok 14 (skipped)\n"; #skip
  $h{'fred'} = 'junk';
}

test 15,join(" ",sort keys %h) eq "fred ricky";
test 16,$h{'george'}=42;
test 17,join(" ",sort keys %h) eq "fred george ricky";
untie %h;

test 18,tie %i,Tie::RDBM,$dsn,{table=>'PData',user=>USER,password=>PASS};
test 19,$i{'george'}==42;
test 20,join(" ",sort keys %i) eq "fred george ricky";
