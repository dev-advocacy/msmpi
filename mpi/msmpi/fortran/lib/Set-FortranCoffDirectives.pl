use strict;
use warnings;

my $path = shift @ARGV or die "Expected a COFF object path\n";
open my $input, '<:raw', $path or die "Cannot read $path: $!\n";
my $bytes = do { local $/; <$input> };
close $input or die "Cannot close $path: $!\n";
length($bytes) >= 20 or die "Truncated COFF object: $path\n";
my ($machine, $count) = unpack 'vv', $bytes;
($machine == 0x014c || $machine == 0x8664)
    or die "Unsupported COFF object machine: $machine\n";
my $sections = 20 + unpack('v', substr($bytes, 16, 2));
$sections + 40 * $count <= length($bytes)
    or die "Truncated COFF section table: $path\n";
for my $index (0 .. $count - 1) {
    my $offset = $sections + 40 * $index;
    next unless substr($bytes, $offset, 8) eq '.drectve';
    my ($size, $raw) = unpack 'VV', substr($bytes, $offset + 16, 8);
    $raw + $size <= length($bytes)
        or die "Truncated COFF directive section: $path\n";
    my $directives = substr($bytes, $raw, $size);
    # MSVC has never supported GNU common-alignment hints; it ignores them.
    $directives =~ s/-aligncomm:"[^"\r\n]+",[0-9]+/' ' x length($&)/ge;
    substr($bytes, $raw, $size) = $directives;
    # Match MSVC: linker information, removed from the image, byte-aligned.
    substr($bytes, $offset + 36, 4) = pack 'V', 0x00100A00;
    open my $output, '>:raw', $path or die "Cannot write $path: $!\n";
    print {$output} $bytes or die "Cannot write $path: $!\n";
    close $output or die "Cannot close $path: $!\n";
    exit 0;
}
die "Expected GNU Fortran .drectve section not found: $path\n";
