#!/usr/bin/perl
use strictures 1;
use AnyEvent;
use AnyEvent::SerialPort;
#use Data::Dump::Streamer 'Dump', 'Dumper';
use Data::Dumper 'Dumper';
use Daemon::Control;

my $gps_device = shift;
my $port_handle;


my $dc = Daemon::Control->new({
                               program     => sub {
                                my $master_cv = AnyEvent->condvar;
	                        setup();
                                $master_cv->wait
                               },
                               fork        => 2,
                               pid_file    => '/var/lock/gps_logger',
                               name        => 'gps_logger',
                              });
$dc->stdout_file("/tmp/gps_logger.stdout");
$dc->stderr_file("/tmp/gps_logger.stderr");

$dc->do_start;

sub setup {
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
  $year += 1900;
  my $logfile_name = "/var/log/gps_logger_$year-$mon-$mday-$hour-$min-$sec.log";
  print "Opening log file $logfile_name\n";
  open(my $log_fh, ">>", $logfile_name)
    or die "Can't open $logfile_name for appending ($!)";
  


  if (0) {
    # Talk directly to the gps on a serial port
    $port_handle = AnyEvent::SerialPort->new(
                                             serial_port => [$gps_device,
                                                             [baudrate => 9600]
                                                            ],
                                             no_delay => 1,
                                             on_error => sub {
                                               my ($handle, $fatal, $message) = @_;
                                               my $fatal_message = $fatal ? "Fatal" : "Non-fatal (but dying anyway)";
                                               die "$fatal_message error with serial port: $message\n";
                                             },
                                             on_read => sub {
                                               on_read($log_fh, @_);
                                             },
                                            );
  } else {
    # Talk to the gps via gpsd / gpspipe
    open my $gpspipefh, "-|", "gpspipe -r" or die "Can't open gpspipe: $!";
    $port_handle = AnyEvent::Handle->new(
                                         fh => $gpspipefh,
                                         no_delay => 1,
                                         on_error => sub {
                                           my ($handle, $fatal, $message) = @_;
                                           my $fatal_message = $fatal ? "Fatal" : "Non-fatal (but dying anyway)";
                                           die "$fatal_message error with gpspipe: $message\n";
                                         },
                                         on_read => sub {
                                           on_read($log_fh, @_);
                                         },
                                        );
  }
}

sub on_read {
  my ($log_fh, $handle) = @_;
  
  print $handle->{rbuf};
  print $log_fh $handle->{rbuf};
  $log_fh->flush;
  $handle->{rbuf} = "";
}
