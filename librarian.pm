# Copyright (c) 2003, Dick Munroe (munroe@csworks.com),
#		      Cottage Software Works, Inc.
#		      All rights reserved.
#
# This program, comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under the conditions of the GNU GENERAL PUBLIC LICENSE, version 2.
#
# This code was originally written by Brad Hughes.  It's been
# extensively extended to more fully support the lbr routines by Dick
# Munroe.
#
# Revision History:
#
#   1.00    06-May-2003	Dick Munroe (munroe@csworks.com)
#	    Add a new function that can be called from any derived class.
#	    Allow the cloning of a librarian object.
#
#   1.01    10-May-2003	Dick Munroe (munroe@csworks.com)
#	    Add a factory method that can be used to get an "appropriate"
#	    object of "every" class of library.
#
#   1.02    11-May-2003	Dick Munroe (munroe@csworks.com)
#	    Allow get_module to return a concatenated string.
#	    Allow get_header to return either an array or a hash reference.
#
#   1.03    12-May-2003 Dick Munroe (munroe@csworks.com)
#	    Fix some documentation problems.  Add Help library class, fix
#	    a few small bugs in the derived classes.
#	    Fix debug flag order.
#	    Make DEBUG a package variable.
#	    Add perl level debugging information to close.
#
#   1.05    13-May-2003 Dick Munroe (munroe@csworks.com)
#	    Add a write_module method to allow capturing of data to a file.
#
#   1.06    13-May-2003 Dick Munroe (munroe@csworks.com)
#	    Fix a bug in text mode write_module.
#	    Add read_module.
#
#   1.07    14-May-2003 Dick Munroe (munroe@csworks.com)
#	    use Carp so that I can figure out where usage errors are coming
#	    from.
#	    While I'm at it, generate and "EXTRACT" and "INSERT" functions.
#

package VMS::Librarian;

use Carp;
use VMS::Stdio qw(:CONSTANTS :FUNCTIONS) ;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $AUTOLOAD);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);
@EXPORT = qw();

#
# The default object and image libraries are ALPHA format.
#

@EXPORT_OK = qw(
    VLIB_CREATE
    VLIB_READ
    VLIB_UPDATE

    VLIB_UNKNOWN
    VLIB_ALPHA_OBJECT
    VLIB_VAX_OBJECT
    VLIB_OBJECT
    VLIB_MACRO
    VLIB_HELP
    VLIB_TEXT
    VLIB_ALPHA_IMAGE
    VLIB_VAX_IMAGE
    VLIB_IMAGE

    VLIB_CRE_VMSV2
    VLIB_CRE_VMSV3
    VLIB_CRE_NOCASECMP
    VLIB_CRE_NOCASENTR
    VLIB_CRE_UPCASNTRY
    VLIB_CRE_HLPCASING
    VLIB_CRE_OBJCASING
    VLIB_CRE_MACTXTCAS

    extract
    factory
    insert
) ;

$VERSION = '1.07';

$DEBUG = 0;

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
    *$AUTOLOAD = sub { $val };
    goto &$AUTOLOAD;
}

bootstrap VMS::Librarian $VERSION;

# Preloaded methods go here.

#
# Utility functions intended to be called by themselves without an
# object reference.
#

sub extract
{
    my %theParams = @_ ;

    croak "FILENAME is required" unless (defined($theParams{FILENAME})) ;
    croak "KEY is required" unless (defined($theParams{KEY})) ;
    croak "LIBNAME is required" unless (defined($theParams{LIBNAME})) ;

    my $theDebug = VMS::Librarian->_debug_($theParams{DEBUG}) ;
    my $theStatus ;

    my $theObject = factory(LIBNAME => $theParams{LIBNAME}, FUNCTION => VLIB_READ(), DEBUG => $theDebug) ;

    if ($theObject)
    {
	my @theModule = $theObject->get_module(KEY => $theParams{KEY}, DEBUG => $theDebug) ;

	if (@theModule)
	{
	    $theStatus = $theObject -> write_module(FILENAME => $theParams{FILENAME}, DATA => \@theModule, DEBUG => $theDebug) ;
	}
    }

    return $theStatus ;
}

sub insert
{
    my %theParams = @_ ;

    croak "FILENAME is required" unless (defined($theParams{FILENAME})) ;
    croak "KEY is required" unless (defined($theParams{KEY})) ;
    croak "LIBNAME is required" unless (defined($theParams{LIBNAME})) ;

    my $theDebug = VMS::Librarian->_debug_($theParams{DEBUG}) ;
    my $theStatus ;

    my $theObject = factory(LIBNAME => $theParams{LIBNAME}, FUNCTION => VLIB_UPDATE(), DEBUG => $theDebug) ;

    if ($theObject)
    {
	my @theModule = $theObject->read_module(FILENAME => $theParams{FILENAME}, DEBUG => $theDebug) ;

	if (@theModule)
	{
	    my $theIndex = $theObject -> get_index_hash(DEBUG => $theDebug) ;

	    if ($theIndex)
	    {
		if (exists($theIndex->{$theParams{KEY}}))
		{
		    $theStatus = $theObject -> replace_module(KEY => $theParams{KEY}, DATA => \@theModule, DEBUG => $theDebug) ;
		}
		else
		{
		    $theStatus = $theObject -> add_module(KEY => $theParams{KEY}, DATA => \@theModule, DEBUG => $theDebug) ;
		}
	    }
	}
    }

    return $theStatus ;
}


#
# Private member functions go here.
#

#
# This enforces the debugging flag order as follows:
#
#   1. If the debug flag was passed, then use it.
#   2. If the SELF flag is defined, then use it.
#   3. If the package flag is defined, then use it.
#

sub _debug_
{
    return $_[1] if (defined($_[1])) ;
    return $_[0]->{DEBUG} if (defined($_[0]->{DEBUG})) ;
    return $DEBUG ;
}

#
# Accessors for various bits and pieces of the library object.
#

sub current_index
{
    my $self = shift ;

    return $self->{CURRENTINDEX} ;
}

sub header
{
    my $self = shift ;

    return $self->{HEADER} ;
}

sub library_index
{
    my $self = shift ;

    return $self->{LIBINDEX} ;
}

sub name
{
    my $self = shift ;

    return $self->{LIBNAME} ;
}

sub type
{
    my $self = shift ;

    return $SELF->{TYPE} ;
}

sub _clone
{
    my ($theObject, $theSource) = @_ ;

    foreach (keys %{$theSource})
    {
    $theObject->{$_} = $theSource->{$_} ;
    } ;

    return $theObject ;
} ;

sub _new {
    my $thePackage = shift ;

    my $theClass = ref($thePackage) || $thePackage ;
    my $theParent = ref($thePackage) && $thePackage ;

    my $self = bless {
	LIBNAME       => '',
	FUNCTION      => VLIB_READ(),			# default to read access
	LIBINDEX      => 0,
	CURRENTINDEX  => 1,				# Current key index (initially defaults to 1).
    }, $theClass ;

    if ($theParent)
    {
	return $self->_clone($theParent) ;
    } ;

    my %theParams = @_;
    my $theStatus;

    if (exists $theParams{LIBNAME})  
    {
	$self->{LIBNAME}  = $theParams{LIBNAME};  
	delete $theParams{LIBNAME} 
    }
    else
    {
	croak "no LIBNAME passed";
    }

    #
    # Type is required if we're creating a _new library.
    #

    if (exists $theParams{TYPE})     
    { 
	$self->{TYPE}  = $theParams{TYPE};     
	delete $theParams{TYPE} 
    }
    else
    {
	if (-e $self->{LIBNAME})
	{
	    #
	    # The library exists but the type isn't specified.  Get the
	    # type from the header and keep going.
	    #

	    my $theLibrary = new VMS::Librarian(LIBNAME=>$self->{LIBNAME}, 
						TYPE=>VLIB_UNKNOWN(),
						FUNCTION=>VLIB_READ()) ;

	    my $theHeader = $theLibrary->get_header() ;

	    $self->{TYPE} = $theHeader->{TYPE} ;

	    undef $theLibrary ;
	}
	else
	{
	    croak "VMS::Librarian::_new TYPE required for new library." ;
	}
    }

    if (exists($theParams{CREOPT}))
    {
	$self->{CREOPT} = $theParams{CREOPT} ;
	delete $theParams{CREOPT} ;
    }
    else
    {
	$self->{CREOPT} = $self->creopt() ;
    }

    if (exists $theParams{FUNCTION}) { $self->{FUNCTION} = $theParams{FUNCTION}; delete $theParams{FUNCTION} }
    if (exists $theParams{DEBUG})    { $self->{DEBUG}    = $theParams{DEBUG};    delete $theParams{DEBUG} }

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug & 1) {
	print "Entering _new.\n";
	if (scalar %theParams) {
	    display (\%theParams, "VMS::Librarian::_new called with extra params, these will be ignored");
	    undef %theParams;
	}
    }

    $theStatus = lbr_new ($self->{LIBNAME},
		       $self->{FUNCTION},
                       $self->{TYPE},
		       $self->{CREOPT},
                       $self->{LIBINDEX},
                       $theDebug);

    if (! $theStatus) {
	if ($theDebug & 1) { print "Error [$!][$^E] from lbr_new;.\n" }
	return $theStatus ;
    }

    if ($theDebug & 1) { print "Leaving _new.\n" }

    return $self ;
}

sub new
{
    my $thePackage = shift ;

    return $thePackage->_new(@_) ;
} ;

#
# The following is a "factory" that, given an EXISTING library,
# will return an object of the appropriate type (or an error for
# an unsupported type) to handle that library.
#
# This is NOT an object oriented call.
#

sub factory
{
    %theParams = @_ ;

    my $theDebug = VMS::Librarian->_debug_($theParams{DEBUG}) ;

    croak "Usage: VMS::Librarian::factory(LIBNAME=>filename, FUNCTION=>function)"
	unless (exists($theParams{LIBNAME}) && exists($theParams{FUNCTION})) ;
    
    croak $theParams{LIBNAME} . " does not exist." unless (-e $theParams{LIBNAME}) ;

    my $theLibrary = new VMS::Librarian(LIBNAME=>$theParams{LIBNAME},
					TYPE=>VLIB_UNKNOWN(),
					FUNCTION=>VLIB_READ(),
					DEBUG=>$theDebug) ;

    croak "Couldn't create library object" unless ($theLibrary) ;

    my $theHeader = $theLibrary->get_header(DEBUG=>$theDebug) ;

    croak "Couldn't get library header" unless ($theHeader) ;

    undef $theLibrary ;

    if ($theHeader->{TYPE} == VLIB_ALPHA_OBJECT())  { require VMS::Librarian::Object unless (defined(&VMS::Librarian::Object::new)) ;
						      return new VMS::Librarian::Object(LIBNAME=>$theParams{LIBNAME},
											FUNCTION=>$theParams{FUNCTION},
											TYPE=>VLIB_ALPHA_OBJECT(),
											DEBUG=>$theDebug) ; }
    if ($theHeader->{TYPE} == VLIB_VAX_OBJECT())  { require VMS::Librarian::Object unless (defined(&VMS::Librarian::Object::new)) ;
						    return new VMS::Librarian::Object(LIBNAME=>$theParams{LIBNAME},
										      FUNCTION=>$theParams{FUNCTION},
										      TYPE=>VLIB_VAX_OBJECT(),
										      DEBUG=>$theDebug) ; }
    if ($theHeader->{TYPE} == VLIB_HELP())  { require VMS::Librarian::Help unless (defined(&VMS::Librarian::Help::new)) ;
					      return new VMS::Librarian::Help(LIBNAME=>$theParams{LIBNAME},
									      FUNCTION=>$theParams{FUNCTION},
									      TYPE=>VLIB_HELP(),
									      DEBUG=>$theDebug) ; }
    if ($theHeader->{TYPE} == VLIB_MACRO())  { require VMS::Librarian::Macro unless (defined(&VMS::Librarian::Macro::new)) ;
					       return new VMS::Librarian::Macro(LIBNAME=>$theParams{LIBNAME},
										FUNCTION=>$theParams{FUNCTION},
										TYPE=>VLIB_MACRO(),
										DEBUG=>$theDebug) ; }
    if ($theHeader->{TYPE} == VLIB_TEXT())  { require VMS::Librarian::Text unless (defined(&VMS::Librarian::Text::new)) ;
					      return new VMS::Librarian::Text(LIBNAME=>$theParams{LIBNAME},
									      FUNCTION=>$theParams{FUNCTION},
									      TYPE=>VLIB_TEXT(),
									      DEBUG=>$theDebug) ; }
    if ($theHeader->{TYPE} == VLIB_ALPHA_IMAGE())  { require VMS::Librarian::Share unless (defined(&VMS::Librarian::Share::new)) ;
						     return new VMS::Librarian::Share(LIBNAME=>$theParams{LIBNAME},
										      FUNCTION=>$theParams{FUNCTION},
										      TYPE=>VLIB_ALPHA_IMAGE(),
										      DEBUG=>$theDebug) ; }
    if ($theHeader->{TYPE} == VLIB_VAX_IMAGE())  { require VMS::Librarian::Share unless (defined(&VMS::Librarian::Share::new)) ;
						   return new VMS::Librarian::Share(LIBNAME=>$theParams{LIBNAME},
										    FUNCTION=>$theParams{FUNCTION},
										    TYPE=>VLIB_VAX_IMAGE(),
										    DEBUG=>$theDebug) ; }
    return () ;
}

#
# Get the header information for the library.
#

sub get_header
{
    my $self = shift ;
    my %theParams = @_ ;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    print "Entering get_header.\n" if ($theDebug & 1) ;

    if ((defined($self->{'LIBINDEX'})) && ($self->{'LIBINDEX'} != 0))
    {
	my $theHeader = lbr_get_header($self->{'LIBINDEX'}, $theDebug) ;
	$self->{'HEADER'} = $theHeader ;
	print "Error [$!][$^E] from lbr_get_header;\n" if ((! $theHeader ) && ($theDebug & 1)) ; 
    }

    print "Exitting get_header.\n" if ($theDebug & 1) ;

    return (wantarray() ? @{$self->{HEADER}} : $self->{HEADER}) ; ;
}

#
# Connect modules in secondary indices.
#

sub connect_indices
{
    my $self = shift ;
    my %theParams = @_ ;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug & 1)
    {
	print "Entering connect_indices.\n" ;
	display(\%theParams, "Arguments for connect_indices ") ;
    }

    croak "KEY required in connect_indices" unless (exists($theParams{KEY})) ;
    croak "INDEX required in connect_indices" unless (exists($theParams{INDEX})) ;
    croak "KEYS required in connect_indices" unless (exists($theParams{KEYS})) ;
    croak "KEYS must be an array refference in connect_indices" unless (ref($theParams{KEYS}) eq "ARRAY") ;

    my $theStatus = lbr_connect_indices($self->{LIBINDEX},
					$theParams{KEY},
					$theParams{INDEX},
					$theParams{KEYS},
					$theDebug) ;


    print "Error [$!][$^E] from lbr_connect_indices;\n" if ((! $theStatus ) && ($theDebug & 1)) ; 

    $theStatus = lbr_set_index($self->{LIBINDEX}, $self->{CURRENTINDEX}, $theDebug) ;

    print "Error [$!][$^E] from lbr_set_index;\n" if ((! $theStatus ) && ($theDebug & 1)) ; 

    print "Exitting connect_indices;\n" if ($theDebug & 1) ;

    return $theStatus ;
}

#
# Close the current library.
#

sub close
{
    my $self = shift ;
    my %theParams = @_ ;

    my $theStatus ;
    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    print "Entering close\n" if ($theDebug & 1) ;

    return 1 if ((!defined($self->{'LIBINDEX'})) || ($self->{'LIBINDEX'} == 0)) ;

    $theStatus = lbr_close($self->{'LIBINDEX'}, $theDebug) ;

    if (! $theStatus) 
    {
	if ($theDebug & 1) { print "Error [$!][$^E] from lbr_close;\n" }
	return $theStatus ;
    }

    $self->{'LIBINDEX'} = 0 ;

    print "Exiting close\n" if ($theDebug & 1) ;

    return 1 ;
}

#
# Create options.
# Each library type is expected to override this function and
# substitute "real" values for the elements in the hash.
#

sub creopt
{
    my $self = shift ;
    my %theParams = @_ ;

    my %theCreopt = (
	    TYPE	=>  (defined($self->type()) ? $self->type() : VLIB_UNKNOWN()),
	    KEYLEN	=>  31,
	    ALLOC	=>  100,
	    IDXMAX	=>  1,
	    UHDMAX	=>  0,
	    ENTALL	=>  11,
	    LUHMAX	=>  20,
	    VERTYP	=>  VLIB_CRE_VMSV3(),
	    IDXOPT	=>  VLIB_CRE_MACTXTCAS()
	) ;

    foreach (keys %theCreopt)
    {
	if (exists($theParams{$_}))
	{
	    $theCreopt{$_} = $theParams{$_} ;
	    delete $theParams{$_} ;
	}
    }

    if (scalar(%theParams))
    {
	croak "Invalid parameter(s) in creopt" ;
    }

    return \%theCreopt ;
}

#
# Add a module to a library.
#
# The index must be set prior to calling this routine (set_index).
#

sub add_module
{
    my $self = shift ;
    my %theParams = @_ ;
    my $theStatus ;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug&1)
    {
	print "Entering add_module\n" ;
	display(\%theParams, "add_module called with ") ;
    }

    croak "KEY required in add_module" if (! exists($theParams{KEY})) ;
    croak "DATA required in add_module" if (! exists($theParams{DATA})) ;
    croak "DATA must be an array reference in add_module" if (ref($theParams{DATA}) ne "ARRAY") ;

    $theStatus = lbr_add_module($self->library_index(), $theParams{KEY}, $theParams{DATA}, $theDebug) ;

    print "Error [$!][$^E] from lbr_add_module;\n" if ((! $theStatus) && ($theDebug & 1)) ;

    return $theStatus ;
}

#
# Delete one or more modules from a library.
#
# The index must be set prior to calling this routine (set_index).
# All references to the module and its data are deleted from the
# library.  The index is restored before exit from this routine.
#

sub delete_module
{
    my $self = shift ;
    my %theParams = @_ ;
    my $theStatus ;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug&1)
    {
	print "Entering delete_module\n" ;
	display(\%theParams, "delete_module called with ") ;
    }

    croak "KEY required in delete_module" if (! exists($theParams{KEY})) ;

    if (ref($theParams{KEY}))
    {
	foreach (@{$theParams{KEY}})
	{
	    last if (! ($theStatus = lbr_delete_module($self->{LIBINDEX}, $_, $theDebug))) ;
	    lbr_set_index($self->{LIBINDEX}, $self->{INDEX}, $theDebug) ;
	}
    }
    else
    {
	$theStatus = lbr_delete_module($self->{LIBINDEX}, $theParams{KEY}, $theDebug) ;
    }
    
    print "Error [$!][$^E] from lbr_delete_module;\n" if ((! $theStatus) && ($theDebug & 1)) ;

    lbr_set_index($self->{LIBINDEX}, $self->{CURRENTINDEX}, $theDebug) ;

    return $theStatus ;
}

#
# Get all the modules in the specified index.  If the index is omitted, the
# current index is fetched.
#

sub get_index {
    my $self = shift;
    my %theParams = @_;
    my $theStatus;

    my @lines = ();

    $theParams{INDEX} = $self->{CURRENTINDEX} if ! exists $theParams{INDEX} ;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug & 1) {
	print "Entering get_index\n";
	display (\%theParams, "get_index called with:");
    }

    @lines = lbr_get_index ($self->{LIBINDEX},
                            $theParams{INDEX},
                            $theDebug);

    print "Error [$!][$^E] from _get_index;\n" if ((! @lines) && ($theDebug & 1)) ;

    
    print "exiting get_index\n" if ($theDebug & 1) ;

    return @lines ;
}

#
# Get all the modules in the specified index.  If the index is omitted, the
# current index is fetched.
#

sub get_index_hash {
    my $theObject = shift ;
    my $theStatus;

    my @lines = $theObject->get_index(@_) ;

    if (@lines)
    {
	my %lines ;

	foreach (@lines)
	{
	    $lines{$_} = undef ;
	}

	return \%lines ;
    }

    return () ;
}

#
# Get all keys for a given module in the current index.  
#
# The data structure returned is an array of hash references.
#

sub get_keys {
    my $self = shift;
    my %theParams = @_;

    croak "KEY required in get_keys" unless (exists($theParams{KEY})) ;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug & 1) {
	print "Entering get_keys\n";
	display (\%theParams, "get_keys called with:");
    }

    my $theKeys = lbr_get_keys($self->{LIBINDEX},
			       $theParams{KEY},
			       $theDebug);

    print "Error [$!][$^E] from lbr_get_keys;\n" if ((! $theKeys) && ($theDebug & 1)) ;

    my $theStatus = lbr_set_index($self->{LIBINDEX},
				  $self->{CURRENTINDEX},
				  $theDebug) ;

    print "Error [$!][$^E] from lbr_set_index;\n" if ((! $theStatus) && ($theDebug & 1)) ;

    print "exiting get_keys\n" if ($theDebug & 1) ;

    return (wantarray() ? @{$theKeys} : $theKeys) ;
}

#
# Get the contents of a module. 
#

sub get_module {
    my $self = shift;
    my %theParams = @_;
    my $theStatus;

    my @lines = ();

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug & 1) {
	print "Entering get_module\n";
	display (\%theParams, "get_module called with:");
    }

    if (! exists $theParams{KEY}) {
	croak "no KEY passed into get_module";
    }

    @lines = lbr_get_module ($self->{LIBINDEX},
			     $theParams{KEY},
			     $theDebug);

    print "Error [$!][$^E] from lbr_get_module;\n" if ((! @lines) && ($theDebug & 1)) ;

    return (wantarray() ? @lines : (join "",@lines)) ;
}

#
# Read a module from a file.
#
# Input is in binary mode.
# sysread treats EOF as a 0 length record.  Therefore no binary
# file may have a 0 length record or the code will think its
# at eof when the file hasn't been fully processed.
#

sub read_module {
    my $self = shift;
    my %theParams = @_;
    my $theStatus;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug & 1) {
	print "Entering read_module";
	display (\%theParams, "read_module called with:");
    }

    croak "FILENAME required in read_module" unless (defined($theParams{FILENAME})) ;

    my @theData ;
    my $theFileHandle = vmssysopen($theParams{FILENAME}, O_RDONLY, 0, "ctx=bin") ;

    if ($theFileHandle)
    {
	my $theBytesRead ;
	my $theDataRead ;

	while ($theBytesRead = sysread($theFileHandle, $theDataRead, 65535))
	{
	    push @theData, $theDataRead ;
	}
    }

    if (! defined($theFileHandle)) 
    {
	if ($theDebug & 1) { print "Error [$!][$^E] in read_module; returning undef\n" }
    }

    CORE::close($theFileHandle) ;

    if ($theDebug & 1) {
	display (\%theParams, "read_module returned with:");
	print "exiting read_module";
    }

    return @theData ;
}

#
# Replace a module in a library.
#
# The index must be set prior to calling this routine (set_index).
# Replacement is implemented as deletion followed by addition.
#

sub replace_module
{
    my $self = shift ;
    my %theParams = @_ ;
    my $theStatus ;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug&1)
    {
	print "Entering replace_module\n" ;
	display(\%theParams, "replace_module called with ") ;
    }

    croak "KEY required in replace_module" if (! exists($theParams{KEY})) ;
    croak "DATA required in replace_module" if (! exists($theParams{DATA})) ;
    croak "DATA must be an array reference in replace_module" if (ref($theParams{DATA}) ne "ARRAY") ;

    $theStatus = lbr_delete_module($self->library_index(), $theParams{KEY}, $theDebug) ;

    $theStatus = lbr_add_module($self->library_index(), $theParams{KEY}, $theParams{DATA}, $theDebug) if ($theStatus) ;

    print "Error [$!][$^E] in replace_module;\n" if ((! $theStatus) && ($theDebug & 1)) ;

    return $theStatus ;
}

sub set_index {
    my $self = shift;
    my %theParams = @_;
    my $theStatus;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug & 1) {
	print "Entering set_index\n";
	display (\%theParams, "set_index called with:");
    }

    if (! exists $theParams{INDEX}) {
	croak "no INDEX passed into set_index";
    }

    $theStatus = lbr_set_index ($self->{LIBINDEX},
                             $theParams{INDEX},
                             $theDebug);

    if ($theStatus) 
    {
	$self->{'CURRENTINDEX'} = $theParams{INDEX} ;
    }
    else
    {
	if ($theDebug & 1) { print "Error [$!][$^E] from lbr_set_index; returning undef\n" }
	return $theStatus ;
    }

    if ($theDebug & 1) {
	display (\%theParams, "set_index returned with:");
	print "exiting set_index\n";
    }

    return 1 ;
}

sub write_module {
    my $self = shift;
    my %theParams = @_;
    my $theStatus;

    my $theDebug = $self->_debug_($theParams{DEBUG}) ;

    if ($theDebug & 1) {
	print "Entering write_module";
	display (\%theParams, "write_module called with:");
    }

    croak "FILENAME required in write_module" unless (defined($theParams{FILENAME})) ;
    croak "DATA required in write_module" unless (defined($theParams{DATA})) ;
    croak "DATA must be an arrary reference in write_module" unless (ref($theParams{DATA}) eq "ARRAY") ;

    my $theFileHandle = vmssysopen($theParams{FILENAME}, O_TRUNC|O_CREAT|O_WRONLY, 0, "ctx=bin", "rfm=var") ;

    if ($theFileHandle)
    {
	foreach (@{$theParams{DATA}})
	{
	    $theStatus = syswrite($theFileHandle, $_, length($_)) ;
	    last if (! defined($theStatus)) ;
	}
    }

    if (! defined($theStatus)) 
    {
	if ($theDebug & 1) { print "Error [$!][$^E] in write_module; returning undef\n" }
	CORE::close($theFileHandle) ;
	return $theStatus ;
    }

    CORE::close($theFileHandle) ;

    if ($theDebug & 1) {
	display (\%theParams, "write_module returned with:");
	print "exiting write_module";
    }

    return 1 ;
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

sub DESTROY
{
    my $self = shift ;

    return $self->close() ;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

VMS::Librarian - Perl extension for LBR$ Utility routines.

=head1 SYNOPSIS

    #! perl -w

    use VMS::Librarian qw(VLIB_CREATE VLIB_READ VLIB_UPDATE) ;
    use VMS::Librarian::Object ;
    use VMS::Librarian::Text ;

    #
    # Demonstrate compatibility with Librarian created libraries.
    #

    $test_text1 = <<END;
    This is some text.
    And some more...

    Skipped a line.
	    Tabbed a line.
    END

    qx(create test1.txt);
    open F, ">>test1.txt" or die "error [$!][$^E] opening test1.txt";
    print F $test_text1;
    close F;

    qx(library/create/text test1 test1.txt);

    $libobj1 = new VMS::Librarian::Text (LIBNAME => 'test1.tlb');

    #
    # Get a list of the modules from the default index.
    #

    @lines = $libobj1->get_index() ;

    print "current Index = ",$libobj1->current_index()," ",$libobj1->name(),"\n" ;
    foreach (@lines)
    {
	print "    ",$_,"\n" ;
    }
    print "\n" ;

    #
    # Get modules from a non-existant index.
    #

    @lines = $libobj1->get_index(INDEX => 2) ;

    if (@lines)
    {
	#
	# this should never get executed.
	#

	print "Index = 2 in ",$libobj1->name(),"\n" ;
	foreach (@lines)
	{
	    print "    ",$_,"\n" ;
	}
	print "\n" ;
    }

    #
    # Get the library header.
    #

    $theHeader = $libobj1->get_header() ;

    print "Library header for ",$libobj1->name(),"\n" ;
    foreach (sort keys %$theHeader)
    {
	print "    ",$_," = ",$theHeader->{$_},"\n" ;
    }
    print "\n" ;

    #
    # Extract the specified module
    #

    @lines = $libobj1->get_module (KEY => 'test1');

    print "Module ",$libobj1->name,"(TEST1) is " ;
    if ($test_text1 ne (join "",@lines))
    {
	print "not " ;
    } ;
    print "equal to the test text\n" ;
    print "\n" ;

    #
    # Extract the specified module as scalar
    #

    $theLines = $libobj1->get_module (KEY => 'test1');

    print "Module ",$libobj1->name,"(TEST1) is " ;
    if ($test_text1 ne $theLines)
    {
	print "not " ;
    } ;
    print "equal to the test text\n" ;
    print "\n" ;

    #
    # Write the module and check for differences.
    #

    $theStatus = $libobj1->write_module(FILENAME=>'test1.txt', DATA=>\@lines) ;

    print "Module TEST1 ",($theStatus ? "wrote " : "did not write "),"correctly\n" ;
    print "\n" ;

    $theStatus = qx(diff test1.txt) ;

    print "Checking test1.txt for differences after write_module\n" ;
    print $theStatus ;
    print "\n" ;

    undef $libobj1 ;

    #
    # Delete a module and all its keys.
    # Use the factory interface to open the library.
    #

    $libobj1 = VMS::Librarian::factory(LIBNAME=>'test1.tlb', FUNCTION=>VLIB_UPDATE) ;

    print "factory ",(($libobj1 && (ref($libobj1) eq "VMS::Librarian::Text")) ? "returned" : "did not return")," a valid library object\n" ;
    print "\n" ;

    $status = $libobj1->delete_module(KEY => 'test1') ;

    print $libobj1->name(),"(TEST1) was ",($status ? "" : "not "),"deleted successfully\n" ;
    print "\n" ;

    if ($status)
    {
	my @theIndex = $libobj1->get_index() ;
	foreach (@theIndex)
	{
	    if ($_ eq "TEST1")
	    {
		print "Error: TEST1 not deleted properly from ",$libobj1->name(),"\n" ;
		print "\n" ;
		last ;
	    }
	}
    }

    undef $libobj1 ;

    while (unlink 'test1.tlb') {} ;
    while (unlink 'test1.txt') {} ;

    $test_text2 = <<END;
    This is some more text.
    And some more more text...

    No tab here...
    END

    @test_text2 = split "\n",$test_text2 ;

    #
    # Produce create options for a text library with two indices.
    #

    $creopt = VMS::Librarian::Text->creopt(IDXMAX=>2) ;

    $libobj2 = new VMS::Librarian::Text (LIBNAME => 'test2.tlb',FUNCTION=>VLIB_CREATE, CREOPT=>$creopt);

    if ($libobj2)
    {
	print $libobj2->name()," created successfully\n" ;
	print "\n" ;
    }

    #
    # Add the test data.
    #

    $status = $libobj2->add_module(KEY => 'TEST2', DATA => \@test_text2) ;

    print $libobj2->name(),"(TEST2) was ",($status ? "" : "not "),"added successfully.\n" ;
    print "\n" ;

    #
    # Get the module and verify it.
    #

    @lines = $libobj2->get_module (KEY => 'test2');

    print "Module ",$libobj2->name,"(TEST2) is " ;
    if ($test_text2 ne (join "",@lines))
    {
	print "not " ;
    } ;
    print "equal to the test text\n" ;
    print "\n" ;

    #
    # Add a couple of additional keys to the secondary index and link
    # them to a module.
    #

    @keys = ('TEST2A', 'TEST2B') ;

    $status = $libobj2->connect_indices(KEY=>'TEST2', INDEX=>2, KEYS => \@keys) ;

    print "Additional keys were ",($status ? "" : "not "),"added successfully.\n" ;
    print "\n" ;

    #
    # Get and verify the module by way of the secondary entry.
    #

    $libobj2->set_index(INDEX=>2) ;

    @lines = $libobj2->get_module (KEY => 'test2a');

    print "Module ",$libobj2->name,"(TEST2A) is " ;
    if ($test_text2 ne (join "",@lines))
    {
	print "not " ;
    } ;
    print "equal to the test text\n" ;
    print "\n" ;

    #
    # Get all keys in all indices for the TEST2B entry in the
    # secondary entry.
    #

    print "Getting modules keys for entry 'TEST2B'\n" ;

    @keys = $libobj2->get_keys(KEY=>'test2b') ;

    for ($i = 1; $i <= 8; $i++)
    {
	if (defined($keys[$i]))
	{
	    print "Index $i:\n" ;
	    foreach (@{$keys[$i]})
	    {
		print "    ",$_,"\n" ;
	    }
	}
    }
    print "\n" ;

    #
    # Add the test data using the string interface.
    #

    $status = $libobj2->add_module(KEY => 'TEST3', DATA => $test_text2) ;

    print $libobj2->name(),"(TEST3) was ",($status ? "" : "not "),"added successfully.\n" ;
    print "\n" ;

    #
    # Get the module and verify it.
    #

    $theLines = $libobj2->get_module (KEY => 'test3');

    print "Module ",$libobj2->name,"(TEST3) is " ;
    if ($test_text2 ne $theLines)
    {
	print "not " ;
    } ;
    print "equal to the test text\n" ;
    print "\n" ;

    undef $libobj2 ;

    while (unlink 'test2.tlb') {} ;

    #
    # Check package level debug flag.
    #

    print "Check package level debug flag.\n" ;

    $VMS::Librarian::DEBUG = 1 ;

    $libobj3 = new VMS::Librarian::Object(LIBNAME=>'sys$library:decc$crtl.olb',FUNCTION=>VLIB_READ) ;

    undef $libobj3 ;

    print "\n" ;

    $VMS::Librarian::DEBUG = 0 ;

    #
    # Check Object level override of debug flag.
    #

    print "Check object level override of debug flag.\n" ;

    $VMS::Librarian::DEBUG = 1 ;

    $libobj3 = new VMS::Librarian::Object(LIBNAME=>'sys$library:decc$crtl.olb',FUNCTION=>VLIB_READ,DEBUG=>0) ;

    $libobj3->set_index(INDEX=>2) ;

    undef $libobj3 ;

    $VMS::Librarian::DEBUG = 0 ;

    print "\n" ;

    #
    # Check member function level override of debug flag.
    #

    print "Check member function override of debug flag.\n" ;

    $libobj3 = new VMS::Librarian::Object(LIBNAME=>'sys$library:decc$crtl.olb',FUNCTION=>VLIB_READ,DEBUG=>1) ;

    $libobj3->set_index(INDEX=>2, DEBUG=>0) ;

    undef $libobj3 ;

    print "\n" ;

    #
    # Read the primary and secondary indices in DECC$CRTL and see
    # how many are there.
    #

    my $libobj3 = new VMS::Librarian::Object(LIBNAME=>'sys$library:decc$crtl.olb',FUNCTION=>VLIB_READ) ;

    $libobj3->set_index(INDEX=>2) ;
    @lines = $libobj3->get_index(INDEX=>1) ;

    print $libobj3->name()," has ",scalar(@lines)," keys in index 1\n" ;
    print "\n" ;

    @lines = $libobj3->get_index() ;

    print $libobj3->name()," has ",scalar(@lines)," keys in index ",$libobj3->current_index(),"\n" ;
    print "\n" ;

    #
    # Write the module and check for differences.
    #

    $theModule = 'C$WSTRINGS' ;

    print "Extracting ",$libobj3->name(),"($theModule)\n" ;
    print qx(libr/log/extract=$theModule/output=test3.obj sys\$library:decc\$crtl.olb) ;
    print "\n" ;

    $libobj3->set_index(INDEX => 1) ;

    @lines = $libobj3->get_module(KEY => $theModule) ;

    $theStatus = $libobj3->write_module(FILENAME=>'test3.obj', DATA=>\@lines) ;

    print 'Module C$WSTRINGS ',($theStatus ? "wrote " : "did not write "),"correctly\n" ;
    print "\n" ;

    $theStatus = qx(diff test3.obj) ;

    print "Checking test3.obj for differences after write_module\n" ;
    print $theStatus ;
    print "\n" ;

    @lines = $libobj3->read_module(FILENAME => 'test3.obj') ;

    print "File TEST3.OBJ ",(@lines ? "" : "did not "),"read correctly\n" ;
    print "\n" ;

    $theStatus = $libobj3->write_module(FILENAME=>'test3.obj', DATA=>\@lines) ;

    $theStatus = qx(diff test3.obj test3.obj;-2) ;

    print "Checking test3.obj for differences after read_module/write_module\n" ;
    print $theStatus ;
    print "\n" ;

    undef $libobj3 ;

    while (unlink 'test3.obj') {} ;

=head1 DESCRIPTION

VMS::Librarian provides an object oriented Perl interface to
OpenVMS librarys.  Using this interface any type of library
(macro, text, object, help, and user defined) may be created
and/or manipulated.

All routines accept a variable number of parameters using hash
notation, e.g.,

    $object->routine(P1=>value, P2=> value, ...) ;

Omitted required parameters cause an error message and your Perl
code to terminate.

VMS::Librarian is shipped with derived classes that provide
specialized support for image, macro, object, and text libraries.

=head2 Utility Functions

=over 4

=item extract

    $theStatus = VMS::Librarian::extract(LIBNAME    => string,
					 KEY	    => string,
					 FILENAME   => string)

Extract the specified module from the named library, storing the
contents of the module in the named file.

=item insert

    $theStatus = VMS::Librarian::extract(LIBNAME    => string,
					 KEY	    => string,
					 FILENAME   => string)

Place the contents of the named file in the named library as the
specified module.  If the module exists it is replaced, otherwise
the module is added.

=back 4

=head2 Class Functions

=over 4

=item factory

    $theObject = VMS::Librarian::factory(LIBNAME=>string,
					 FUNCTION=>integer)

The factory returns an appropriately typed object for processing
a library.  The library must already exist.  If the library is
not of a known type, then the returned object will be undefined.

=back 4

=head2 Accessors

Accessors provide read-only access to some of the internal state
of the library object.

=over 4

=item current_index

Return the current key index.  VMS::Librarian keeps track of the
current key index and makes sure that it remains current across
calls to the various external interfaces.

=item header

The contents of the library header as returned by get_header.  If
get_header hasn't been called, then header returns an undefined
value.

=item library_index

The LBR$ routine library index for this library object.

=item name

The name of the library.

=item type

The type of the library.  This is an integer value.  The
corresponding library type symbol can be found in LBRDEF.H.

=back 4

=head2 Member Functions

All member functions accept an optional DEBUG parameter.  The DEBUG
parameter is a bit map.  Bit 0 enables debug information from the
Perl side of the interface.  Bit 1 enables debug information from
the XS side of the interface.

=over 4

=item add_module

    $theStatus = $l->add_module(KEY   => name,
			        DATA  => array reference)

Add a module to the library.  The module key is added to the
current index.  The data to be added is contained in an array.
The size of the individual elements of the array varies depending
upon the type of the library, but the maximum length is 65535
bytes.

The key must not exist in the library.

If the module is inserted correctly, add_module returns true,
otherwise it returns false.  In the event of an error, additional
information is in $! and $^E.

=item close

    $theStatus = $l->close()

Close the library and disconnect the object from the library.
Once a library has been closed, the object may no longer be used
for library access.  To close and dispose of the object, use
undef, e.g.,

    undef $l

If the library closes properly the member function returns true,
otherwise it returns false.  If an error occurs, additional
information is in $! and $^E.

=item connect_indices

    $theStatus = $l->connect_indices(KEY	=> string,
				     INDEX	=> integer,
				     KEYS	=> array reference)

Connect the KEYS in the INDEX to the module KEY in the current
index.  The module KEY must exist in the library prior to calling
connect_indices.  The KEYS must not exist in the specified index.  If the
keys are properly inserted the member function returns true,
otherwise it returns false.  If an error occurs, additional
information is in $! and $^E.

=item creopt

    $theCreopt = VMS::Librarian->creopt(TYPE   => library type,
					KEYLEN => integer,
					ALLOC  => integer,
					IDXMAX => integer,
					UHDMAX => integer,
					ENTALL => integer,
					LUHMAX => integer,
					VERTYP => integer,
					IDXOPT => bitmap)

creopt returns a hash reference containing the creation options
used to create a new library.

The above are defined fully in the LBR$ Utility routine
documentation and credef.h.  All arguments to this routine are
optional.  Each specialization of VMS::Librarian is required to
implement a creopt routine.  Values specified in the
parameters to creopt override any defaults specified by creopt.

Symbolic constants for TYPE, VERTYP, and IDXOPT are exported by
VMS::Librarian (although not yet by any specializations of
VMS::Librarian).  See below for a list of the exported constants.

=item delete_module

    $theStatus = $l->delete_module(KEY=>string or array reference)

Delete one or more modules from a library.  The specified keys
must exist in the current index.  All secondary keys are removed
for each module deleted.  delete_module returns true if all
modules have been successfully deleted.  If an error of any type
occurs, delete_module returns.  If a set of modules was to be
delete, any modules following the error will B<not> have been
deleted.

Additional error information is available in $! and $^E.

=item get_header

    $theHeader = $l->get_header()
    @theHeader = $l->get_header()

Return a hash reference containing the library header.  The
current library header is also stored in the library object and
may be retrieved using the header accessor.

If an empty value is returned, additional error information is
available in $! and $^E.

In array context, the array version of the hash is returned.

=item get_index

    @theKeys = $l->get_index(INDEX => integer)

Return an array containing the modules for the specified index.
If the INDEX parameter is omitted, the current index is used.  If
an empty value is returned additional error information is
available in $! and $^E.

=item get_index_hash

    %theKeys = $l->get_index_hash(INDEX => integer)

Return a hash reference using the modules for the specified index
as keys.  If the INDEX parameter is omitted, the current index is
used.  If an empty value is returned additional error information
is available in $! and $^E.

=item get_keys

    @theKeys = $l->get_keys(KEY => string)

An array of arrays, containing all keys in all indices for the
specified module.  The array indices (1 to 8) match the library
key indices in the returned array.  If called in scalar context,
an array reference is returned.  If an empty value is returned,
additional error information is found in $! and $^E.

=item get_module

    @theData = $l->get_module(KEY => string)
    $theData = $l->get_module(KEY => string)

The data for the specified module is returned.  If an empty value
is returned, additional error information is available in $! and
$^E.

This member function is overriden for libraries containing text
to allow addition of a newline character to make the data more
"consistent" with Perl expectations.  The default implementation
of get_header in VMS::Librarian does not modify the data.

In array context, get_module returns an array of data records.
In scalar context, get_module returns a string containing the
concatenation of all the data records.

=item new

    $l = new VMS::Librarian(LIBNAME  => string,
			   [FUNCTION => integer],
			   [TYPE     => integer,]
			   [CREOPT   => hash reference])

Create a new library object and connect it to a library.  The
library TYPE is only required if a new library is to be created.
In all other circumstances, VMS::Librarian can figure out the
necessary additional library type information.  If the FUNCTION
parameter is omitted, it defaults to read access.  If a library is
to be created and the default creation options are not
appropriate, a creation options hash (see creopt, above) can be
provided for use.  If an error occurs nothing will be returned by
the new function and additional error information will be
available in $! anbd $^E.

=item replace_module

    $theStatus = $l->replace_module(KEY   => name,
				    DATA  => array reference)

replace_module is syntactic sugar.  It calls delete_module
before calling add_module.  The specified module must exist.  If
it doesn't, you should just call add_module.

=item set_index

    $theStatus = $l->set_index(INDEX => integer)

Set the current index for the library.  VMS::Librarian will
maintain this across calls to its member functions.  If an error
occurs when setting the index (and empty value is returned)
additional information will be available in $! and $^E.

=item write_module

    $theStatus = $l->write_module(FILENAME => string,
				  DATA => array reference)

Write the data to the specified file.  By default the output file
contains binary data stored in variable length records.

=back

=head2 Exported Constants

=over 4

=item Library Function Type

    VLIB_CREATE
    VLIB_READ
    VLIB_UPDATE

=item Library Type

    VLIB_UNKNOWN
    VLIB_ALPHA_OBJECT
    VLIB_VAX_OBJECT
    VLIB_OBJECT
    VLIB_MACRO
    VLIB_HELP
    VLIB_TEXT
    VLIB_ALPHA_IMAGE
    VLIB_VAX_IMAGE
    VLIB_IMAGE

=item Library Creation Constants

    VLIB_CRE_VMSV2
    VLIB_CRE_VMSV3
    VLIB_CRE_NOCASECMP
    VLIB_CRE_NOCASENTR
    VLIB_CRE_UPCASNTRY
    VLIB_CRE_HLPCASING
    VLIB_CRE_OBJCASING
    VLIB_CRE_MACTXTCAS

=back 4

=head2 Derived Classes

Shipped with VMS::Librarian are a number of additional classes.
These classes provide support for the standard set of OpenVMS
libraries.  These are:

    VMS::Librarian::Help
    VMS::Librarian::Macro
    VMS::Librarian::Object
    VMS::Librarian::Text

When creating a new standard library, just create a new object of
the appropriate type with the VLIB_CREATE function.

These object encapsulate all the details of creating and managing
data in these specialized libraries.  See the individual class
module documentation (if any) for details.

=head1 AUTHOR

The original author of this module was Brad Hughes.  It has been
completely rewritten by Dick Munroe (munroe@csworks.com).  Any support
questions or fixes should be send to Dick Munroe at the above address.

On another note, I'm looking for work (contract or permanent).  My
resume is available at:

    http://www.csworks.com/resume

my CV (much more detailed, but too long for general distribution) is
available at:

    http://www.csworks.com/cv

I do a lot more than hack the web and Perl so take a look and if you
think there's a match, drop me a note and let us see if we can't work
something out.

=head1 SEE ALSO

VMS::Librarian may be downloaded as a zip file from:

    http://www.csworks.com/download/vms-librarian-1_07.zip

=cut
