#!/usr/bin/perl -w
# vim:set foldmethod=marker:

# use {{{
use strict;
use warnings;
use Encode;
use YAML::Tiny;
use File::Path;
use File::Basename;
use FindBin;
#}}}

# global {{{
package MyFileUtil;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(load_config save_config load_draft save_draft make_path touch rand_str);
my $config_file = "$FindBin::Bin/MyFileUtil/config.cgi";
my $draft_dir = "$FindBin::Bin/MyFileUtil/Draft";
my $draft_count = 0;
my $random_call_count = 0;
#}}}

# ディレクトリ作成
sub make_path {
    my ($path) = @_; #{{{
    if (not -e $path) {
        eval { File::Path::mkpath $path; };
        if ($@) { die "Can't mkpath: ".$@; }
    } elsif (-e $path and not -d $path) {
        die "$path is not a directory.";
    }
#}}}
    1;
}

# 空のファイル作成
sub touch {
    my ($file) = @_; #{{{
    make_path(File::Basename::dirname($file));
    if (not -e $file) {
        open FILE, ">$file" or die "Can't open $file";
        print FILE "\n";
        close FILE;
    } elsif (-e $file and not -f $file) {
        die "$file is not a file.";
    }
#}}}
    1;
}

# 設定読み込み
sub load_config {
    my ($file) = @_;#{{{
    $file = $config_file unless $file;
    touch $file;
#}}}
    return (YAML::Tiny->read($file))->[0];
}

# 設定保存
sub save_config {
    my ($config, $file) = @_; #{{{
    $file = $config_file unless $file;
    touch $file;
#}}}
    YAML::Tiny::DumpFile($file, $config);
}

# ランダムな文字列
sub rand_str {
    my ($length) = @_;#{{{
    my ($result,$intval)=('','');
    srand(time+($random_call_count++));
    while (length($result) < $length ) {
        # ASCII英数字の文字コードを生成(48から122)
        $intval = int( rand(75) ) + 48;

        # 文字コード91から96、58から64は英数字以外の文字
        # なので、文字コードの生成処理をやり直す
        next if ($intval >= 91 and $intval <= 96 )
            or ($intval >= 58 and $intval <= 64);
        $result .= sprintf("%c", $intval);
    }
#}}}
    return $result;
}

# *.txtのうち一番古いものを読み込む
sub load_oldest_text {
    my ($dir) = @_; #{{{
    $dir or die;
    my @key;
    opendir DIR, $dir or return (undef, undef);
    while (defined(my $file = readdir(DIR))) {
        my $filename = File::Basename::basename $file;
        if ($filename =~ /\.txt$/) {
            push @key, $filename;
        }
    }
    closedir DIR;
    @key or return (undef, undef);
    my $filename = (sort @key)[0];
    open TXT, "$dir/$filename" or die;
    my $message = Encode::decode('utf-8',join('', <TXT>));
    close TXT;
#}}}
    ("$dir/$filename", $message);
}

# 下書きのうち一番古いものを読み込む
sub load_draft {
    my ($dir) = @_;
    $dir = $draft_dir unless $dir;
    load_oldest_text($dir);
}

# 下書きを保存
sub save_draft {
    my ($message, $dir) = @_; # $messageはすでにバイト列になっていること {{{
    $dir = $draft_dir unless $dir;
    make_path $dir or die;
    my $file = sprintf("%s/%d_%03d_%s.txt",$dir,time,$draft_count,rand_str(8));
    open TXT, ">$file";
    print TXT Encode::encode('utf-8',"$message\n");
    close TXT;
    $draft_count++;
#}}}
    1;
}

1;
