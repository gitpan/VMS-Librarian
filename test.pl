#! perl -w

use VMS::Librarian;

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

$libobj1 = new VMS::Librarian (LIBNAME => 'test1.tlb',
                              DEBUG   => 3);

@lines = $libobj1->get_module (KEY => 'test1',
                              DEBUG => 3);

print "Test text = [$test_text1]\n";
print "Lib1 text = [";
for $line (@lines) {
  print "$line";
}

$test_text2 = <<END;
This is some more text.
And some more more text...

No tab here...
END

qx(create test2.txt);
open F, ">>test2.txt" or die "error [$!][$^E] opening test2.txt";
print F $test_text2;
close F;

qx(library/create/text test2 test2.txt);

$libobj2 = new VMS::Librarian (LIBNAME => 'test2.tlb',
                              DEBUG   => 3);

@lines = $libobj2->get_module (KEY => 'test2',
                              DEBUG => 3);

print "Test text = [$test_text2]\n";
print "Lib2 text = [";
for $line (@lines) {
  print "$line";
}
