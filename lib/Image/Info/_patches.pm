{
    package Image::Info;
    use POSIX qw(ceil);

    sub determine_file_format
    {
        local($_) = @_;
        return "JPEG" if /^\xFF\xD8/;
        return "PNG" if /^\x89PNG\x0d\x0a\x1a\x0a/;
        return "GIF" if /^GIF8[79]a/;
        return "TIFF" if /^MM\x00\x2a/;
        return "TIFF" if /^II\x2a\x00/;
        return "BMP" if /^BM/;
        return "ICO" if /^\000\000\001\000/;
        return "PPM" if /^P[1-6]/;
        return "XPM" if /(^\/\* XPM \*\/)|(static\s+char\s+\*\w+\[\]\s*=\s*{\s*"\d+)/;
        return "XBM" if /^(?:\/\*.*\*\/\n)?#define\s/;
        return "SVG" if /^(<\?xml|[\012\015\t ]*<svg\b)/;
        return "WEBP" if /^RIFF.{4}WEBP/s;
        return "JPEG2000" if /^\x00\x00\x00\x0CjP  /;
        return undef;
    }

}

1;