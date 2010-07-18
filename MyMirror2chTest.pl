#!/usr/bin/perl -w
# vim:set foldmethod=marker:
# use {{{
use strict;
use warnings;
use FindBin;
use File::Remove qw(remove);
use Test::Unit::Procedural;
use MyMirror2ch;
use MyFileUtil;
BEGIN { # 自作モジュール読込用
    use lib $FindBin::Bin;
    push(@INC, '/home/tocd/local/lib/perl5');
    push(@INC, '/home/tocd/local/lib/perl5/site_perl');
}#}}}

MAIN: { # {{{
clean();
create_suite();
run_suite();
clean();
}#}}}

sub clean { #{{{
    my $dir = "$FindBin::Bin/test_dir";
    remove \1, $dir;
}#}}}

sub set_up { #{{{
    #print "\n==== start ====\n";
}#}}}

sub tear_down { #{{{
    #print "==== end ====\n";
}#}}}

sub test_mirror_ua { # テスト {{{
    my $dir = "$FindBin::Bin/test_dir";
    assert(make_path($dir));
    assert(-e $dir and -d $dir);
    my $file = "$dir/index.html";
    mirror_ua("http://www.yahoo.com/", $file);
    assert(-e $file and -f $file and -s $file > 10);
    open HTML, $file or die "can't open: $file";
    my $is_found = 0;
    while (my $line = <HTML>) {
        if ($line =~ /Yahoo!/) {
            $is_found = 1;
            last;
        }
    }
    close HTML;
    assert($is_found);
}#}}}

sub test_get_subject_txt_path { #{{{
    my $server = "tsushima.2ch.net";
    my $ita = "news";
    my $dir = "$FindBin::Bin/test_dir";
    my ($remote, $local) = get_subject_txt_path($server, $ita, $dir);
    assert($remote eq "http://tsushima.2ch.net/news/subject.txt");
    assert($local eq "$dir/tsushima.2ch.net/news/subject.txt");
}#}}}

sub test_get_dat_path { #{{{
    my $server = "tsushima.2ch.net";
    my $ita = "news";
    my $thread = "1259162240";
    my $dir = "$FindBin::Bin/test_dir";
    my ($remote, $local) = get_dat_path($server, $ita, $thread, $dir);
    assert($remote eq "http://tsushima.2ch.net/news/dat/$thread.dat");
    assert($local eq "$dir/tsushima.2ch.net/news/dat/$thread.dat");
}#}}}

sub test_mirror_subject_txt { #{{{
    my $server = "tsushima.2ch.net";
    my $ita = "news";
    my $dir = "$FindBin::Bin/test_dir";
    assert(make_path($dir));
    assert(-e $dir and -d $dir);
    my ($remote, $local) = mirror_subject_txt($server, $ita, $dir);
    assert(-e $local and -f $local and -s $local > 10);
    open HTML, $local or die "can't open: $local";
    my $is_found = 0;
    while (my $line = <HTML>) {
        if ($line =~ /^\d+\.dat<>.+\(\d+\)/) {
            $is_found = 1;
            last;
        }
    }
    close HTML;
    assert($is_found);
}#}}}

sub test_get_thread_list { #{{{
    my $server = "tsushima.2ch.net";
    my $ita = "news";
    my $dir = "$FindBin::Bin/test_dir";
    my $thread_list_ref = get_thread_list($server, $ita, $dir);
    assert($thread_list_ref);
    foreach my $thread_ref (@$thread_list_ref) {
        assert($$thread_ref{'id'} =~ /^\d+$/);
        assert($$thread_ref{'title'});
        assert($$thread_ref{'res'} =~ /^\d{1,4}$/);
        assert($$thread_ref{'elapsed'} =~ /^\d+$/);
        assert($$thread_ref{'ikioi'} =~ /^\d+(?:\.\d+)?$/);
        assert($$thread_ref{'number'} =~ /^\d+$/);
    }
}#}}}

sub test_mirror_dat { #{{{
    my $server = "tsushima.2ch.net";
    my $ita = "news";
    my $dir = "$FindBin::Bin/test_dir";
    my $thread_list_ref = get_thread_list($server, $ita, $dir);
    my $thread_ref = $$thread_list_ref[0];
    my ($remote, $local) = mirror_dat($server, $ita, $$thread_ref{'id'}, $dir);
    assert(-e $local and -f $local and -s $local > 10);
    open HTML, $local or die "can't open: $local";
    my $is_found = 0;
    while (my $line = <HTML>) {
        #print "\n".encode('utf-8',decode('cp932',$line))."\n";
        if ($line =~ /<>.*<>.*<>.*<>/) {
            $is_found = 1;
            last;
        }
    }
    close HTML;
    assert($is_found);
}#}}}

sub test_get_res_list { #{{{
    my $server = "tsushima.2ch.net";
    my $ita = "news";
    my $dir = "$FindBin::Bin/test_dir";
    my $thread_list_ref = get_thread_list($server, $ita, $dir);
    my $thread_ref = $$thread_list_ref[0];
    mirror_dat($server, $ita, $$thread_ref{'id'}, $dir);
    my $res_list_ref = get_res_list($server, $ita, $$thread_ref{'id'}, $dir);
    assert($res_list_ref);
    foreach my $res_ref (@$res_list_ref) {
        assert($$res_ref{'name'});
        assert($$res_ref{'date'});
        assert($$res_ref{'time'});
        assert($$res_ref{'number'} =~ /^\d{1,4}$/);
        assert($$res_ref{'body'});
    }
}#}}}

sub test_unlink_old_dat { #{{{
    my $server = "tsushima.2ch.net";
    my $ita = "news";
    my $dir = "$FindBin::Bin/test_dir";
    my $temp_dat1 = "$dir/$server/$ita/dat/1.dat";
    my $temp_dat2 = "$dir/$server/$ita/dat/2.dat";
    MyFileUtil::touch $temp_dat1;
    MyFileUtil::touch $temp_dat2;
    assert(-e $temp_dat1 and -f $temp_dat1);
    assert(-e $temp_dat2 and -f $temp_dat2);
    unlink_old_dat($server, $ita, $dir);
    assert(not -e $temp_dat1);
    assert(not -e $temp_dat2);
}#}}}
