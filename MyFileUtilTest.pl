#!/usr/bin/perl -w
# vim:set foldmethod=marker:
# use {{{
use strict;
use warnings;
use FindBin;
use File::Remove qw(remove);
use Test::Unit::Procedural;
use MyFileUtil;
BEGIN { # 自作モジュール読込用
    use lib $FindBin::Bin;
    push(@INC, '/home/tocd/local/lib/perl5');
    push(@INC, '/home/tocd/local/lib/perl5/site_perl');
}#}}}

# global {{{
my $dir = "$FindBin::Bin/test_dir";
#}}}

MAIN: { #{{{
clean();
create_suite();
run_suite();
clean();
}#}}}

sub clean { #{{{
    remove \1, $dir;
}#}}}

sub set_up { #{{{
    clean();
    #print "\n==== start ====\n";
}#}}}

sub tear_down { #{{{
    #print "==== end ====\n";
}#}}}

sub test_make_path { #{{{
    assert(not -e $dir);
    assert(make_path($dir));
    assert(-e $dir and -d $dir);
}#}}}

sub test_touch { #{{{
    my $file = "$dir/test.txt";
    assert(not -e $file);
    assert(touch($file));
    assert(-e $file and -f $file);
}#}}}

sub test_load_and_save_config { #{{{
    my $file = "$dir/test.txt";
    my $config = load_config($file);
    $config->{'key'} = 'value';
    save_config($config, $file);
    #print "$file\n";
    assert(-e $file and -f $file);
    $config = undef;
    $config = load_config($file);
    assert($config->{'key'} eq 'value');
}#}}}

sub test_load_draft { #{{{
    my ($file, $message) = load_draft($dir);
    assert(not $file);
    assert(not $message);
}#}}}

sub test_load_and_save_draft { #{{{
    my $message = decode('utf-8',"テスト");
    save_draft($message, $dir);
    $message = undef;
    my $file;
    ($file, $message) = load_draft($dir);
    chomp $message;
#    print "$file: ".encode('utf-8',$message)."\n";
    assert(-e $file and -f $file);
    assert($message eq decode('utf-8',"テスト"));
}#}}}

sub test_rand_str { #{{{
    my $str = rand_str(8);
    assert($str);
    assert($str =~ /^[a-zA-Z0-9]{8}$/);
}#}}}

sub test_load_and_save_draft2 { #{{{
    my $draft = decode('utf-8',"テスト");
    save_draft($draft, $dir);
    save_draft($draft, $dir);
    save_draft($draft, $dir);
    save_draft($draft, $dir);
    save_draft($draft, $dir);
    save_draft($draft, $dir);
    for (my $i = 0; $i < 6; $i++) {
        my ($file, $message) = load_draft($dir);
        chomp $message;
#        print "$file: ".encode('utf-8',$message)."\n";
        assert(-e $file and -f $file);
        assert($message eq $draft);
        assert($file =~ /$i\_[a-zA-Z0-9]{8}\.txt$/);
        unlink $file;
        assert(not -e $file);
    }
}#}}}
