#!/usr/bin/perl -w
# vim:set foldmethod=marker:
# use {{{
use strict;
use warnings;
use FindBin;
use File::Remove qw(remove);
use File::Copy;
use Test::Unit::Procedural;
use MyTwitterClient;
BEGIN { # 自作モジュール読込用
    use lib $FindBin::Bin;
    push(@INC, '/home/tocd/local/lib/perl5');
    push(@INC, '/home/tocd/local/lib/perl5/site_perl');
}
#}}}

# global {{{
my $dir = "$FindBin::Bin/test_dir";
my $message_139 = decode('utf-8',
    "１２３４５６７８９０１２３４５６７８９０１２３４５６７８９０".
    "１２３４５６７８９０１２３４５６７８９０１２３４５６７８９０".
    "１２３４５６７８９０１２３４５６７８９０１２３４５６７８９０".
    "１２３４５６７８９０１２３４５６７８９０１２３４５６７８９０".
    "１２３４５６７８９０１２３４５６７８９");
my $message_120 = decode('utf-8',
    "１２３４５６７８９０１２３４５６７８９０１２３４５６７８９０".
    "１２３４５６７８９０１２３４５６７８９０１２３４５６７８９０".
    "１２３４５６７８９０１２３４５６７８９０１２３４５６７８９０".
    "１２３４５６７８９０１２３４５６７８９０１２３４５６７８９０");
my $link = "http://www.tocd.org/news2ch/";
#}}}

MAIN: { #{{{
clean();
copy_config_file();
create_suite();
run_suite();
clean();
}#}}}

sub copy_config_file { #{{{
    make_path $dir;
    copy "$FindBin::Bin/MyTwitterClientTest/config.cgi", $dir;
}#}}}

sub clean { #{{{
    remove \1, $dir;
}#}}}

sub set_up { #{{{
    #print "\n==== start ====\n";
}#}}}

sub tear_down { #{{{
    #print "==== end ====\n";
}#}}}

sub test_new { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 0,
    );
    assert($mtc);
}#}}}

sub test_shorten_message_139 { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 0,
    );
    assert($mtc);
    my $message = $mtc->shorten_message($message_139);
    #print "\n".encode('utf-8',$message)."\n";
    assert((length($message) <= 140));
    assert($message eq $message_139);
}#}}}

sub test_shorten_message_140 { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 0,
    );
    assert($mtc);
    my $suffix = decode('utf-8',"０");
    my $message = $mtc->shorten_message($message_139.$suffix);
    #print "\n".encode('utf-8',$message)."\n";
    assert((length($message) <= 140));
    assert($message eq $message_139.$suffix);
}#}}}

sub test_shorten_message_141 { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 0,
    );
    assert($mtc);
    my $suffix = decode('utf-8',"０１");
    my $dash = decode('utf-8',"…");
    my $message = $mtc->shorten_message($message_139.$suffix);
    #print "\n".encode('utf-8',$message)."\n";
    assert((length($message) <= 140));
    assert($message eq $message_139.$dash);
}#}}}

sub test_shorten_message_120_link { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 0,
    );
    assert($mtc);
    my $message = $mtc->shorten_message($message_120, $link);
    #print "\n".encode('utf-8',$message)."\n";
    assert((length($message) <= 140));
    assert($message =~ m{^$message_120 http://j.mp/});
}#}}}

sub test_shorten_message_121_link { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 0,
    );
    assert($mtc);
    my $suffix = decode('utf-8',"１");
    my $message = $mtc->shorten_message($message_120.$suffix,$link);
    #print encode('utf-8',$message)."\n";
    assert((length($message) <= 140));
    assert($message =~ m{^$message_120(?:$suffix) http://j.mp/});
}#}}}

sub test_shorten_message_122_link { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 0,
    );
    assert($mtc);
    my $suffix = decode('utf-8',"１２");
    my $dash = decode('utf-8',"…");
    my $message = $mtc->shorten_message($message_120.$suffix,$link);
#    print encode('utf-8',$message)."\n";
    assert((length($message) <= 140));
    assert($message =~ m{^$message_120(?:$dash) http://j.mp/});
}#}}}

sub test_twit_without_oauth { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 0,
    );
    assert($mtc);
    my $ret = $mtc->twit(decode('utf-8',"ユーザ名とパスワードでつぶやくテスト ".rand_str(8)." (using twit() w/o OAuth)"));
    assert($ret);
}#}}}

sub test_twit_with_oauth { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 1,
    );
    assert($mtc);
    my $ret = $mtc->twit(decode('utf-8',"OAuth認証でつぶやくテスト ".rand_str(8)." (using twit() with OAuth)"));
    assert($ret);
}#}}}

sub print_draft_dir { # デバッグ用 {{{
    print "\n";
    opendir DIR, "$dir/Draft" or return;
    while (defined(my $file = readdir(DIR))) {
        print "$file\n";
    }
    closedir DIR;
}#}}}

sub test_twit_draft_with_oauth { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 1,
    );
    assert($mtc);
#    print "\ntest_twit_draft_with_oauth start.\n";
#    print_draft_dir();
    MyFileUtil::save_draft(decode('utf-8',"草稿フォルダからつぶやくテスト ".rand_str(8)." (using twit_draft() with OAuth)"),"$dir/Draft");
#    print_draft_dir();
    my $ret = $mtc->twit_draft;
#    print_draft_dir();
#    print "\ntest_twit_draft_with_oauth done.\n";
    assert($ret);
}#}}}

sub test_twit_queue_with_oauth { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 1,
    );
    assert($mtc);
#    print "\ntest_twit_queue_with_oauth start.\n";
#    print_draft_dir();
    my $ret = $mtc->twit_queue(decode('utf-8',"草稿フォルダからつぶやくテスト その2 ".rand_str(8)." (using twit_queue() with OAuth)"));
#    print_draft_dir();
#    print "\ntest_twit_queue_with_oauth done.\n";
    assert($ret);
}#}}}

sub test_twit_queue_with_oauth_and_link { #{{{
    my $mtc = MyTwitterClient->new(
        config_file => "$dir/config.cgi",
        draft_dir => "$dir/Draft",
        is_enable_oauth => 1,
    );
    assert($mtc);
    my $message = decode('utf-8',"リンク付きでつぶやくテスト")." ".rand_str(8)." ".$message_139;
#    print "\ntest_twit_queue_with_oauth start.\n";
#    print_draft_dir();
    my $ret = $mtc->twit_queue($mtc->shorten_message($message, $link));
#    print_draft_dir();
#    print "\ntest_twit_queue_with_oauth done.\n";
    assert($ret);
}#}}}
