use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'	    => 'VMS::Librarian',
    'VERSION_FROM'  => './librarian.pm', # finds $VERSION
    'PREREQ_PM'	    => {'VMS::Stdio' => 2.2},
    'LIBS'	    => [''],   # e.g., '-lm' 
    'DEFINE'	    => '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	    => '',     # e.g., '-I/usr/include/other' 
    'XSOPT'	    => '-prototypes', # generate prototypes (required in 5.8 and up)
    ($[ >= 5.005) ?
        (AUTHOR	    => 'Dick Munroe (munroe@csworks.com)',
         ABSTRACT   => 'Perl support for OpenVMS LBR$ Utility Routines') : (),
    'dist'	    => {COMPRESS=>'gzip',SUFFIX=>'gz'},
    'TYPEMAPS'	    => [ './typemap' ],
);
