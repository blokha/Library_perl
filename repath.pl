#!/usr/bin/perl

use Encode;
use DBI;
use Data::Dumper;

my $path_to_library="/media/bivan/9e0c31fb-f991-49da-82db-9b5adf1ad62a/ivan";

my $dbh=DBI->connect("dbi:SQLite:dbname=Library.db","","") or die $_;
my $dbh_new=DBI->connect("dbi:SQLite:dbname=Library_new.db","","") or die $_;

my $sth=$dbh->prepare("select Id,Author,Name,Genre,Year,Read,Filename from books");
$sth->execute();

my $sth_new=$dbh_new->prepare("insert into books (Id,Author,Name,Genre,Year,Read,Filename) values(?,?,?,?,?,?,?)");



while (my @rows=$sth->fetchrow_array()){
	my $str1=substr($rows[6],10);
	#~ print $str1,"\n";
	$sth_new->execute($rows[0],$rows[1],$rows[2],$rows[3],$rows[4],$rows[5],$path_to_library.$str1);
	
}
print "Job is Done";
