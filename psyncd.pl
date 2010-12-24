#!/usr/bin/env perl 
# vim: set ts=2 sw=2 sts=2 et si ai: 

# psyncd.pl - A Simple File Synchronizer Daemon
# =
# (c) 2010 Hewlett-Packard Mexico
# Andres Aquino <aquino@hp.com>
# All rights reserved.
# 

use IO::File;
use File::Find;
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);

my $debug = 0;
my $syncRecord;
my $syncDate = strftime('%Y%m%d-%H%M',localtime);


# 
# good!
sub readDirectory {
  my ($directory, $log)= @_;
  print "\nChange to $directory\n" if ( $debug );
  my @dirfiles = glob("$directory/*");
  foreach my $newfile (@dirfiles) {
    readDirectory($newfile) if ( -d $newfile );
    $syncRecord->print(md5_hex($newfile),": $newfile\n");
  } 

}

#
# better!
sub getDigestOf {
  my $object = $_;
  $syncRecord->print(md5_hex($object)," : $File::Find::name\n") if ( ! -d $object );
}


$syncRecord = new IO::File;
$syncName = "dpsync-$syncDate.dat";
$syncRecord->open("/Users/andresaquino/logs/$syncName", O_CREAT | O_RDWR);
#readDirectory("/Users/andresaquino/Dropbox/nextel.com.mx/*");
find(\&getDigestOf, "/Users/andresaquino/Dropbox/nextel.com.mx/");
$syncRecord->close();


# Refs
# Recursion in Perl
# http://pthree.org/2007/01/18/simple-recursion-in-perl/
# Using Digest functions MD5 
# http://perldoc.perl.org/Digest/MD5.html
# Get Date adn Tima formatted
# http://www.go4expert.com/forums/showthread.php?t=15533
# Using Regular Expression
# http://perldoc.perl.org/perlrequick.html#Search-and-replace
#
#
