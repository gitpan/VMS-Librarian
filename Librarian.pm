package VMS::Librarian;

use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $AUTOLOAD);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);
@EXPORT = qw();

$VERSION = '0.01';

my $DEBUG = 0;

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.  If a constant is not found then control is passed
    # to the AUTOLOAD in AutoLoader.

    my $constname;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "& not defined" if $constname eq 'constant';
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
	if ($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
		croak "Your vendor has not defined VMS::Librarian macro $constname";
	}
    }
    *$AUTOLOAD = sub () { $val };
    goto &$AUTOLOAD;
}

bootstrap VMS::Librarian $VERSION;

# Preloaded methods go here.

sub new {
  my $class = shift;
  my %param = @_;
  my $status;
  my $tdebug = 0;

  my $self = {
    LIBNAME       => '',
    TYPE          => 4,   # default to text library
    FUNCTION      => 1,   #   and read access
    LIBINDEX      => 0,
    DEBUG         => 0,
  };

  if (exists $param{LIBNAME})  { $self->{LIBNAME}  = $param{LIBNAME};  delete $param{LIBNAME} }
  if (exists $param{TYPE})     { $self->{TYPE   }  = $param{TYPE};     delete $param{TYPE} }
  if (exists $param{FUNCTION}) { $self->{FUNCTION} = $param{FUNCTION}; delete $param{FUNCTION} }
  if (exists $param{DEBUG})    { $self->{DEBUG}    = $param{DEBUG};    delete $param{DEBUG} }

  $tdebug = $DEBUG | $self->{DEBUG};

  if ($tdebug & 1) {
    print "Entering new.\n";
    if (scalar %param) {
      display (\%param, "VMS::Librarian::new called with extra params, these will be ignored");
      undef %param;
    }
    print "Calling _new.\n";
  }

  $status = _new ($self->{LIBNAME},
                  $self->{FUNCTION},
                  $self->{TYPE},
                  $self->{LIBINDEX},
                  $tdebug);

  if ($tdebug & 1) { display ($self, "In new; result of _new; status = [$status]") }

  if (! $status) {
    if ($tdebug & 1) { print "Error [$!][$^E] from _new;  returning undef.\n" }
    return undef;
  }

  if ($tdebug & 1) { print "Leaving new.\n" }

  return bless $self, $class;
}

sub get_module {
  my $self = shift;
  my %param = @_;
  my $status;
  my $tdebug;

  my @lines = ();

  $param{DEBUG} = 0  if ! exists $param{DEBUG};

  $tdebug = $DEBUG | $self->{DEBUG} | $param{DEBUG};

  if ($tdebug & 1) {
    print "Entering get_module\n";
    display (\%param, "get_module called with:");
  }

  if (! exists $param{KEY}) {
    die "no KEY passed into get";
  }

  @lines = _get_module ($self->{LIBINDEX},
                        $param{KEY},
                        $tdebug);

  return map { $_ .= "\n" } @lines;
}

sub display {
  my ($hash, $header) = @_;
  $header  = $hash unless defined $header;

  my $tvalue;

  print "$header ", '-' x (60 - length($header)), "\n";
  foreach my $key (sort keys %$hash) {
    $tvalue = defined $$hash{$key} ? $$hash{$key} : "undef";
    print "  key = [$key],", ' ' x (15 - length($key)), " value = [$tvalue]";
    print "\n";
  }
  print '-' x 60, "\n";
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

VMS::Librarian - Perl extension for blah blah blah

=head1 SYNOPSIS

  use VMS::Librarian;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for VMS::Librarian was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
