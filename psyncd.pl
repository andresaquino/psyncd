#!/usr/bin/env perl 
# vim: set ts=2 sw=2 sts=2 et si ai: 

# psyncd.pl - A Simple File Synchronizer Daemon
# =
# (c) 2010 Hewlett-Packard Mexico
# Andres Aquino <aquino@hp.com>
# All rights reserved.
# 

#use strict;
#use warnings FATAL => 'none';

use Socket;
use Config;
use IO::File;
use IO::Socket;
use File::Find;
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use Sys::Syslog;
use Time::HiRes qw(usleep sleep time);
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use Env qw(PATH HOME);

use constant {
  APP_NAME    => 'pSyncd',
  APP_VERSION => '0.01',
  APP_CONFIG  => 'psyncd.conf',
  APP_FGMODE  => 1,
  APP_BGMODE  => 2
};

my $env;
my $verbose = 0;

my $syncFiles;
my $config;
my $syncDate = strftime('%Y%m%d-%H%M', localtime);
my ($baseName, $dirName, $sfxName) = fileparse($0, '.pl');


#
#
sub appStart {
  my 
  # starting application
  printf("Starting %s v%s",($env{"app.name"},$env{"app.version"}));
  exit(0);
}

sub startAsServer {
  # starting services...
  printf 'Starting %s v%s!\n',(APP_NAME, APP_VERSION);
  #printf "Starting up %s in %s port..!",$config{"app.servers"},$config{"app.listen"};

  # go!
  $server = IO::Socket::INET->new(
    Listen    => $cfg{'app.clients'},
    LocalAddr => $cfg{'app.address'},
    LocalPort => $cfg{'app.port'},
    Proto     => 'tcp',
    Reuse     => 1
  ) or 
    die "Couldn't be a tcp server on port $server_port : $@\n";

  while ($client = $server->accept()) {
    $client->autoflush(1);
    if (($child = fork()) == 0) {
      print $client "Welcome to $0; type help for command list.\n";
      $hostinfo = gethostbyaddr($client->peeraddr(), AF_INET);
      printf "[Connect from %s]\n", $hostinfo || $client->peerhost;
      print $client "Command? ";
      while ( <$client>) {
        next unless /\S/;       # blank line
        if    (/quit|exit/i)    { print $client "bayin!\n"; close($client);last; }
          elsif (/date|time/i)    { print $client "%s\n", scalar localtime;  }
          elsif (/who/i )         { print $client `who 2>&1`;                }
          elsif (/cookie/i )      { print $client `/usr/games/fortune 2>&1`; }
          elsif (/motd/i )        { print $client `cat /etc/motd 2>&1`;      }
        else {
          print $client "Commands: quit date who cookie motd\n";
        }
      } continue {
        print $client "Command? ";
      }
    }
    close($client);
    printf "listo!\n"
  }
  close($server);
}


#
#
sub startAsClient {
  # load configuration
  loadConfig();

  use IO::Socket;
  $socket = IO::Socket::INET->new(
    PeerAddr => "127.0.0.1",
    PeerPort => "34026",
    Proto    => "tcp",
    Type     => SOCK_STREAM)
  or 
    die "Couldn't connect to 127.0.0.1:34026 : $@\n";
  # ... do something with the socket 
  print $socket "Why don't you call me anymore?\n";  
  $answer = <$socket>;  
  # and terminate the connection when we're done 
  close($socket);

}

#
# start App
sub startMainApp {
  #$syncFiles = new IO::File;
  #$syncName = "/Users/andresaquino/logs/dpsync-".strftime('%Y%m%d-%H%M',localtime).".dat";
  #$syncFiles->open($syncName, O_CREAT | O_RDWR);
  startAsClient();
  print "Save results in $syncName\n";
  find(\&getDigestOf, "/Users/andresaquino/Dropbox/nextel.com.mx");
  #$syncFiles->close();
  exit(0);
}

#
# init as daemon
sub startAsDaemon {
  print "start as daemon\n";
  exit(0);
}

#
# stop App
sub stopDaemon {
  print "stop application\n";
  exit(0);
}


#
# setEnvironment
# Read psyncd.conf file and set application's environment
# Params:
#   -
# Returns:
#   -
sub setEnvironment {
  my $fileEnv = new IO::File;

  $fileEnv->open(APP_CONFIG, O_RDONLY);
  while ( $_ = $fileEnv->getline() ) {
    # dont need empty lines as wall as lines starting with # 
    next if (/^\s*\#/ || /^\s*$/);

    # so, PARAM (spaces) = (spaces)VALUE 
    if (/^(\S+)\s*=\s*(\S+)$/) {
      my ($hash, $value) = ($1, $2);
      # fill apConfig hash 
      $env{$hash} = $value;
    }
  }
  $fileEnv->close();

  # and another values
  $env{"app.name"}    = APP_NAME;
  $env{"app.version"} = APP_VERSION;
  $env{"app.home"}    = $HOME . "/" . $env{"app.home"};
  $env{"app.log"}     = $HOME . "/" . $env{"app.log"};
  $env{"app.osname"}  = $Config{osname};
  $env{"app.osarch"}  = $Config{archname};
  $env{"app.man"}     = $env{"app.home"} . "man1/" . $env{"app.name"} . ".pod";

}


#
# showEnvironment
# Show application's environment
# Params:
#   -
# Returns:
#   -
sub showEnvironment {
  foreach(sort keys %env) { 
    printf("%-16s : %s\n", ($_, $env{$_}));
  }
  exit(0);
}


#
# show application's version
sub showVersion {
  printf("%s v%s\n",(APP_NAME, APP_VERSION));
  exit(0);
}


#
# getDigestOf
# Get a digest sum of a file
# Params:
#   -
# Returns:
#   -
sub getDigestOf {
  my $object = $_;
  printf("%s : %s", (md5_hex($object), File::Find::name)) if ( -f $object );
}



#
# MAIN

# setup environment
openlog(APP_NAME, "ndelay,pid", LOG_USER);
syslog(LOG_NOTICE, "Starting " . APP_NAME . " v." . APP_VERSION);
setEnvironment();

# get options from command line
GetOptions(
  "start"       =>  sub { appStart(APP_FGMODE); },
  "stop"        =>  sub { appStop(); },
  "daemon"      =>  sub { appStart(APP_BGMODE); },
  "environment" =>  sub { showEnvironment(); },
  "version"     =>  sub { showVersion(); },
  "help"        =>  sub { $verbose = 1; },
  "manual"      =>  sub { $verbose = 2; }
);

# show help to user 
closelog();
pod2usage(-verbose => $verbose, -input => $env{"app.man"});
exit(0);

# --
# Refs
# Recursion in Perl
# http://pthree.org/2007/01/18/simple-recursion-in-perl/
# Using Digest functions MD5 
# http://perldoc.perl.org/Digest/MD5.html
# Get Date adn Tima formatted
# http://www.go4expert.com/forums/showthread.php?t=15533
# Using Regular Expression
# http://perldoc.perl.org/perlrequick.html#Search-and-replace
# High resolution alarm, sleep, gettimeofday, interval timers
# http://perldoc.perl.org/Time/HiRes.html
#
