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
