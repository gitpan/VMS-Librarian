7 # Copyright (c) 2003, Dick Munroe (munroe@csworks.com), 2 #                     Cottage Software Works, Inc.* #                     All rights reserved. # 2 # This program, comes with ABSOLUTELY NO WARRANTY.? # This is free software, and you are welcome to redistribute it D # under the conditions of the GNU GENERAL PUBLIC LICENSE, version 2. # ; # Specialize the behavior of VMS::Librarian for Text files.  #  # Revision History:  # 8 #   1.00    06-May-2003	Dick Munroe (munroe@csworks.com) #	    Initial Version Created. # 8 #   1.01    11-May-2003 Dick Munroe (munroe@csworks.com)7 #	    Allow get_module to return a concatenated string. 3 #	    Allow add_module to accept a string as a data > #	    argument.  Break the string into appropriately delimited #	    pieces.  # 8 #   1.02    11-May-2003 Dick Munroe (munroe@csworks.com)" #	    Fix a bug in replace_module. #	    Add documentation. #    package VMS::Librarian::Text ;   $VERSION = "1.01" ;    use strict ; use 5.6.1 ;   5 use VMS::Librarian qw(VLIB_CRE_MACTXTCAS VLIB_TEXT) ;   1 @VMS::Librarian::Text::ISA = qw(VMS::Librarian) ;   
 sub creopt {      my $self = shift ;        return $self->SUPER::creopt( 	TYPE=>VLIB_TEXT,  	IDXOPT=>VLIB_CRE_MACTXTCAS, 	KEYLEN=>39, 	ENTALL=>11, 	@_) ; }    # ? # Text in Perl is usually terminated with a new line.  The data D # inside OpenVMS Text Libraries is not.  This subtracts the newlines # from the module data.  #    sub add_module {      my $self = shift ;     my %theParams = @_ ;       if (ref($theParams{DATA}))     {  	foreach (@{$theParams{DATA}}) 	{ 	    chomp $_ ;  	}     }      else     {  	#8 	# Assume that it's a string with embedded new lines and 	# split it. 	#  - 	my @theLines = split /\n/,$theParams{DATA} ;    	if (@theLines)  	{$ 	    $theParams{DATA} = \@theLines ; 	}     }   1     return $self->SUPER::add_module(%theParams) ;  }    # ? # Text in Perl is usually terminated with a new line.  The data ? # inside OpenVMS Text Libraries is not.  This adds the newlines  # to the module data.  #    sub get_module {      my $self = shift ;  K     return (wantarray() ? (map { $_ .= "\n" } $self->SUPER::get_module(@_)) 9 			: ((join "\n",$self->SUPER::get_module(@_)) . "\n")) ;  }    sub new  {      my $thePackage = shift ;  8     return $thePackage->SUPER::new(@_,TYPE=>VLIB_TEXT) ; }    # ? # Text in Perl is usually terminated with a new line.  The data D # inside OpenVMS Text Libraries is not.  This subtracts the newlines # from the module data.  #    sub replace_module {      my $self = shift ;     my %theParams = @_ ;       if (ref($theParams{DATA}))     {  	foreach (@{$theParams{DATA}}) 	{ 	    chomp $_ ;  	}     }      else     {  	#8 	# Assume that it's a string with embedded new lines and 	# split it. 	#  - 	my @theLines = split /\n/,$theParams{DATA} ;    	if (@theLines)  	{$ 	    $theParams{DATA} = \@theLines ; 	}     }   5     return $self->SUPER::replace_module(%theParams) ;  }    1; __END__    =head1 NAME   @ VMS::Librarian::Text - Perl extension for OpenVMS Text Libraries   =head1 DESCRIPTION  ? This class is derived from VMS::Librarian and provides specific @ support for Text libraries.  In addition, this class acts as the; base class for any OpenVMS library containg text (currently  Macro and Help libraries).   =head2 Member Functions    =over 4    =item add_module  +     $status = $l->add_module(KEY   => name, ! 			     DATA  => array reference) +     $status = $l->add_module(KEY   => name,  			     DATA  => string)  @ Since text libraries (and libraries derived from text libraries)@ contain text data, the DATA parameter may be a string containing8 one or more lines delimited by "\n".  The string data isA converted to an array with the new lines removed and that data is  inserted in the library.  @ If the DATA parameter is an array reference, trailing new lines,> if any, are removed prior to adding the module to the library.   =item creopt  ?     $theCreopt = VMS::Librarian->creopt(TYPE   => library type,  					KEYLEN => integer,  					ALLOC  => integer,  					IDXMAX => integer,  					UHDMAX => integer,  					ENTALL => integer,  					LUHMAX => integer,  					VERTYP => integer,  					IDXOPT => bitmap)  ? creopt returns a hash reference containing the creation options " used to create a new text library.   =item get_module  ,     @theData = $l->get_module(KEY => string),     $theData = $l->get_module(KEY => string)  A The data returned from get_module has "\n" delimiters inserted at  the end of each record.   	 =item new   /     $l = new VMS::Librarian(LIBNAME  => string,  			    FUNCTION => integer,  			   [TYPE     => integer,]# 			   [CREOPT   => hash reference])   + The TYPE defaults to VLIB_TEXT if omitted..    =item replace_module  /     $status = $l->replace_module(KEY   => name,  				 DATA  => array reference)/     $status = $l->replace_module(KEY   => name,  				 DATA  => string)   > See add_module for the details of handling the DATA parameter.   =back 4    =head1 AUTHOR   , The author of this module was is Dick Munroe? (munroe@csworks.com).  Any support questions or fixes should be ! send to him at the above address.   B On another note, I'm looking for work (contract or permanent).  My resume is available at:   !     http://www.csworks.com/resume   D my CV (much more detailed, but too long for general distribution) is available at:        http://www.csworks.com/cv   D I do a lot more than hack the web and Perl so take a look and if youE think there's a match, drop me a note and let us see if we can't work  something out.   =head1 SEE ALSO   @ VMS::Librarian (which includes this module) may be downloaded as a zip file from:  :     http://www.csworks.com/download/vms-librarian-1_03.zip   =cut