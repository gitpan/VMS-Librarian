7 # Copyright (c) 2003, Dick Munroe (munroe@csworks.com), 2 #                     Cottage Software Works, Inc.* #                     All rights reserved. # 2 # This program, comes with ABSOLUTELY NO WARRANTY.? # This is free software, and you are welcome to redistribute it D # under the conditions of the GNU GENERAL PUBLIC LICENSE, version 2. # ; # Specialize the behavior of VMS::Librarian for Text files.  #  # Revision History:  # 8 #   1.00    06-May-2003	Dick Munroe (munroe@csworks.com) #	    Initial Version Created. # 8 #   1.01    11-May-2003 Dick Munroe (munroe@csworks.com)7 #	    Allow get_module to return a concatenated string. 3 #	    Allow add_module to accept a string as a data > #	    argument.  Break the string into appropriately delimited #	    pieces.  #    package VMS::Librarian::Text ;   $VERSION = "1.01" ;    use strict ; use 5.6.1 ;   5 use VMS::Librarian qw(VLIB_CRE_MACTXTCAS VLIB_TEXT) ;   1 @VMS::Librarian::Text::ISA = qw(VMS::Librarian) ;   
 sub creopt {      my $self = shift ;        return $self->SUPER::creopt( 	TYPE=>VLIB_TEXT,  	IDXOPT=>VLIB_CRE_MACTXTCAS, 	KEYLEN=>39, 	ENTALL=>11, 	@_) ; }    # ? # Text in Perl is usually terminated with a new line.  The data D # inside OpenVMS Text Libraries is not.  This subtracts the newlines # from the module data.  #    sub add_module {      my $self = shift ;     my %theParams = @_ ;       if (ref($theParams{DATA}))     {  	foreach (@{$theParams{DATA}}) 	{ 	    chomp $_ ;  	}     }      else     {  	#8 	# Assume that it's a string with embedded new lines and 	# split it. 	#  - 	my @theLines = split /\n/,$theParams{DATA} ;    	if (@theLines)  	{$ 	    $theParams{DATA} = \@theLines ; 	}     }   1     return $self->SUPER::add_module(%theParams) ;  }    # ? # Text in Perl is usually terminated with a new line.  The data ? # inside OpenVMS Text Libraries is not.  This adds the newlines  # to the module data.  #    sub get_module {      my $self = shift ;  K     return (wantarray() ? (map { $_ .= "\n" } $self->SUPER::get_module(@_)) 9 			: ((join "\n",$self->SUPER::get_module(@_)) . "\n")) ;  }    sub new  {      my $thePackage = shift ;  8     return $thePackage->SUPER::new(@_,TYPE=>VLIB_TEXT) ; }    # ? # Text in Perl is usually terminated with a new line.  The data D # inside OpenVMS Text Libraries is not.  This subtracts the newlines # from the module data.  #    sub replace_module {      my $self = shift ;     my %theParams = @_ ;  !     foreach (@{$theParams{DATA}})      {  	chomp $_ ;      }   1     return $self->SUPER::add_module(%theParams) ;  }    1; __END__ 