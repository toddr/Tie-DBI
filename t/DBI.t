# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

# change this if you need to

my $DRIVER = $ENV{DRIVER};
use constant USER   => $ENV{USER};
use constant PASS   => $ENV{PASS};
use constant DBNAME => $ENV{DB} || 'test';

BEGIN { $| = 1; print "1..29\n"; }
END {print "not ok 1\n" unless $loaded;}
use lib './lib','../lib';
use DBI;
use Tie::DBI;
$loaded = 1;

######################### End of black magic.

unless ($DRIVER) {
    local($^W)=0;  # kill uninitialized variable warning
    # I like mysql best, followed by Oracle and Sybase
    my ($count) = 0;
    my (%DRIVERS) = map { ($_,$count++) } qw(Informix Pg Ingres mSQL Sybase Oracle mysql ExampleP);
    ($DRIVER) = sort { $DRIVERS{$b}<=>$DRIVERS{$a} } DBI->available_drivers(1);
}

if ($DRIVER) {
    print STDERR "Using DBD driver $DRIVER...";
} else {
    die "Found no DBD driver to use.\n";
}

my %TABLES = (
	      'CSV' => <<END,
CREATE TABLE testTie (
produce_id       char(15),
price            real,
quantity         int,
description      char(30)
)
END
	      'mSQL' => <<END,
CREATE TABLE testTie (
produce_id       char(15),
price            real,
quantity         int,
description      char(30)
)
;
CREATE UNIQUE INDEX idx1 ON testTie (produce_id)
END
               'Pg'=><<END,
CREATE TABLE testTie (
produce_id       varchar(15) primary key,
price            real,
quantity         int,
description      varchar(30)
)
END
);

use constant DEFAULT_TABLE=><<END;
CREATE TABLE testTie (
produce_id       char(15) primary key,
price            real,
quantity         int,
description      char(30)
)
END
    ;


my @fields =   qw(produce_id     price quantity description);
my @test_data = (
		 ['strawberries',1.20,  8,      'Fresh Maine strawberries'],
		 ['apricots',    0.85,  2,      'Ripe Norwegian apricots'],
		 ['bananas',     1.30, 28,      'Sweet Alaskan bananas'],
		 ['kiwis',       1.50,  9,      'Juicy New York kiwi fruits'],
		 ['eggs',        1.00, 12,      'Farm-fresh Atlantic eggs']
		 );

sub test {
    local($^W) = 0;
    my($num, $true,$msg) = @_;
    print($true ? "ok $num\n" : "not ok $num $msg\n");
}

sub initialize_database {
    local($^W) = 0;
    my $dsn = "dbi:$DRIVER:${\DBNAME}";
    my $dbh = DBI->connect($dsn,USER,PASS,{Warn=>1,PrintError=>0,ChopBlanks=>1}) || return undef;
    $dbh->do("DROP TABLE testTie");
    return $dbh if $DRIVER eq 'ExampleP';
    my $table = $TABLES{$DRIVER} || DEFAULT_TABLE;
    foreach (split(';',$table)) {
      $dbh->do($_) || warn $DBI::errstr;
    }
    $dbh;
}

sub insert_data {
    my $h = shift;
    my ($record,$count);
    foreach $record (@test_data) {
	my %record = map { $fields[$_]=>$record->[$_] } (0..$#fields);
	$h->{$record{produce_id}} = \%record;
	$count++;
    }
    return $count == @test_data;
}

sub chopBlanks {
  my $a = shift;
  $a=~s/\s+$//;
  $a;
}

test 1,$loaded;
my $dbh = initialize_database;
{ local($^W)=0;
  test 2,$dbh,"Couldn't create test table: $DBI::errstr";
  die unless $dbh;
}
test 3,tie %h,Tie::DBI,{db=>$dbh,table=>'testTie',key=>'produce_id',CLOBBER=>3,WARN=>0};

%h=() unless $DRIVER eq 'ExampleP';
test 4,!scalar(keys %h);
test 5,insert_data(\%h);
test 6,exists($h{strawberries});
test 7,defined($h{strawberries});
test 8,join(" ",map {chopBlanks($_)} sort keys %h) eq "apricots bananas eggs kiwis strawberries";
test 9,$h{eggs}->{quantity} == 12;
test 10,$h{eggs}->{quantity} *= 2;
test 11,$h{eggs}->{quantity} == 24;

my $total_price = 0;
my $count = 0;
my ($key,$value);
while (($key,$value) = each %h) {
    $total_price += $value->{price} * $value->{quantity};
    $count++;
}
test 12,$count == 5;
test 13,abs($total_price - 85.2) < 0.01;

test 14,$h{'cherries'} = { description=>'Vine-ripened cherries',price=>2.50,quantity=>200 };
test 15,$h{'cherries'}{quantity} == 200;
test 16,$h{'cherries'} = { price => 2.75 };
test 17,$h{'cherries'}{quantity} == 200;
test 18,$h{'cherries'}{price} == 2.75;
test 19,join(" ",map {chopBlanks($_)} sort keys %h) eq "apricots bananas cherries eggs kiwis strawberries";

test 20,delete $h{'cherries'};
test 21,!$h{'cherries'};

test 22,my $array = $h{'eggs','strawberries'};
test 23,$array->[1]->{'description'} eq 'Fresh Maine strawberries';

test 24,my $another_array = $array->[1]->{'produce_id','quantity'};
test 25,"@{$another_array}" eq 'strawberries 8';

test 26,@fields = tied(%h)->select_where('quantity > 10');
test 27,join(" ",sort @fields) eq 'bananas eggs';

test 28,delete $h{strawberries}->{quantity};
if ($DRIVER eq 'CSV') {
	print STDERR "Skipping test 29 for CSV driver...";
	print "ok 29\n";
} else {
  test 29,!defined($h{strawberries}->{quantity});
}
