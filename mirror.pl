#!/usr/bin/perl -w
# vim:set foldmethod=marker:

# use {{{
use strict;
use warnings;
use Encode;
use XML::RSS;
use FindBin;
use POSIX qw(strftime);
BEGIN {
    use lib $FindBin::Bin;
    push(@INC, '/home/tocd/local/lib/perl5');
    push(@INC, '/home/tocd/local/lib/perl5/site_perl');
} #自作モジュール読込用
use MyFileUtil;
use MyMirror2ch;
use MyTwitterClient;
#}}}

# global {{{
my $config_file = "$FindBin::Bin/mirror/config.cgi";
#}}}

#スレッドIDを指定してRSSフィードのアイテムを作成
sub add_item_to_rss {
    my ($rss_ref, $server, $ita, $thread, $dir) = @_; #{{{
    my $res_list_ref = get_res_list($server, $ita, $thread, $dir);
    $res_list_ref or return;
    my $res_ref = $$res_list_ref[0];
    my ($title, $author, $link);
    $title = $$res_ref{'title'};
    $author= $$res_ref{'name'};
    $link = "http://www.tocd.org/news2ch/r.cgi/$thread";
    my ($head, $body);
    $head = "$$res_ref{'number'}:$$res_ref{'name'}:$$res_ref{'date'} $$res_ref{'time'}";
    $head .= " $$res_ref{'id'}($$res_ref{'hisshido'})" if $$res_ref{'id'};
    $head .= " $$res_ref{'be'}" if $$res_ref{'be'};
    $body = $$res_ref{'body'};
    $body =~ s/^\s*//;
    $body =~ s/\s*$//;
    $body =~ s/(?!&amp;)&/&amp;/g;
    $body =~ s/(h?t?tp:\/\/([^\s<>]+))/<a href="http:\/\/$2">$1<\/a>/g;
    $body =~ s/\n/<br \/>/gi;
#   相対パスを絶対パスに
    $body =~ s/(<a href=")(\/[^\">]+">[^<]+<\/a>)/$1http:\/\/c.2ch.net$2/gi;
#   リンクの属性を設定
    $body =~ s/(<a\s)([^<>]+>)/$1rel="nofollow" target="_blank" $2/gi;
#   画像へのリンクをインライン表示
    $body =~ s/(<a\s[^<>]+>)(h?ttp:\/\/([^<>]+?\.(?:jpg|jpeg|png|gif|bmp)))(<\/a>)/$1<img src="http:\/\/$3" border="0" alt="[image]" \/>$4<br \/>$1$2$4/gi;
#   sssp 画像へのリンクをインライン表示
    $body =~ s/sssp:\/\/([^\s<>]+)\s*/<img src="http:\/\/$1" border="0" alt="[image]" \/>/gi;

    $$rss_ref->add_item(
        title => $title,
        link => $link,
        description => "$head<br />$body",
        author => $author,
        dc => {
            date => strftime("%Y-%m-%dT%R+00:00", gmtime($thread)),
        },
    );
#}}}
    $rss_ref;
}

# RSSフィードを作成
sub make_rss {
    my ($server, $ita, $dir) = @_; #{{{
    my $rss = new XML::RSS (version => '1.0');

    $rss->channel(
        title => decode('utf-8', "ν速レス1全文配信"),
        link => "http://www.tocd.org/news2ch/",
        description  => decode('utf-8', "2ちゃんねるニュース速報板のレス1を全文配信します。datから再構築しています。"),
    );

    my $i = 0;
    my $thread_list_ref = get_thread_list($server, $ita, $dir);
    foreach my $thread_ref (reverse sort {$$a{'id'}<=>$$b{'id'}} @$thread_list_ref) {
        add_item_to_rss(\$rss, $server, $ita, $$thread_ref{'id'}, $dir);
        $i++;
        last if $i >= 100;
    }
#}}}
    \$rss;
}

# icon画像のファイル名の整形
sub format_icon_filename {
    my ($icon) = @_; #{{{
    if ($icon =~ /sssp:\/\/([^\s<>]+)\s*/) {
        $icon = $1;
    } else {
        return undef;
    }
    $icon =~ s/^img\.2ch\.net\/ico\/([\w\-]+)\..+$/$1/;
    return $icon if $icon =~ /^[\d_]+$/;
    $icon =~ s/([a-z]+)\d+/$1/gi;
    $icon =~ s/\d+([a-z]+)/$1/gi;
    $icon =~ s/_+\d+_+/_/g;
    $icon =~ s/\d+_+//g;
    $icon =~ s/_+\d+//g;
    $icon =~ s/_+anime_+/_/gi;
    $icon =~ s/\banime_+//gi;
    $icon =~ s/_+anime\b//gi;
    $icon =~ s/_+[a-z]_+/_/gi;
    $icon =~ s/\b[a-z]_+//gi;
    $icon =~ s/_+[a-z]\b//gi;
    $icon =~ s/\b_+//g;
    $icon =~ s/_+\b//g;
#}}}
    return $icon;
}

# 草稿作成
sub make_draft {
    my ($server, $ita, $thread, $mirror_dir) = @_; #{{{
    my $config = load_config($config_file);
    my $res_list_ref = get_res_list($server, $ita, $thread, $mirror_dir);
    my $res_ref = $$res_list_ref[0];
    my $title = $$res_ref{'title'};
    my $body = $$res_ref{'body'};
    my $icon = format_icon_filename($body);
    $body =~ s/sssp:\/\/([^\s<>]+)\s*//gi;
    $body =~ s/h?t?tp:\/\/([^\s<>]+)\s*//gi;
    $body =~ s/\n+/\n/g;
    my $link = "http://www.tocd.org/news2ch/r.cgi/".$thread;
    my $message;
    if ($icon) {
        $message = "$title $link [$icon]\n".decode('utf-8',"◆")."\n$body";
    } else {
        $message = "$title $link\n".decode('utf-8',"◆")."\n$body";
    }
    my $mtc = MyTwitterClient->new(
            config_file => $config_file,
            draft_dir => $config->{'draft'},
            is_enable_oauth => 1,
            );
#}}}
    $mtc->save_draft_wrapper($mtc->shorten_message($message));
}

# すべてのdat(1さえ含んでいれば良い)を取得する
MAIN: {#{{{
    my $config = load_config($config_file);
    my ($server, $ita, $mirror_dir) = ($config->{'server'}, $config->{'ita'}, $config->{'mirror_dir'});
    unlink_old_dat($server, $ita, $mirror_dir);
    mirror_subject_txt($server, $ita, $mirror_dir);
    my $thread_list_ref = get_thread_list($server, $ita, $mirror_dir);
    my $i = 0;
    my $now = time;
    foreach my $thread_ref (sort {$$a{'id'}<=>$$b{'id'}} @$thread_list_ref) {
#       古いスレは飛ばす(12時間以内のスレ)
        next if ($now - $$thread_ref{'id'} >= 60 * 60 * 12);
#       取得済みなら飛ばす
        my $dat = "$mirror_dir/$server/$ita/dat/$$thread_ref{'id'}.dat";
        next if -e $dat;
        print "mirror_dat: $dat\n";
        mirror_dat($server, $ita, $$thread_ref{'id'}, $mirror_dir);
        make_draft($server, $ita, $$thread_ref{'id'}, $mirror_dir);
        $i++;
#       特定の回数でいったん終了
        last if $i >= 15;
    }
    my $mtc = MyTwitterClient->new(
            config_file => $config_file,
            draft_dir => $config->{'draft'},
            is_enable_oauth => 1,
            );
    for(my $i = 0; $i < 20; $i++){
        my $ret = $mtc->twit_oldest_draft;
        if($ret){
            print "twit_oldest_draft.\n";
        }else{
            last;
        }
    }
    if ($i > 0) {
        print "making rss ...\n";
        my $rss_ref = &make_rss($server, $ita, $mirror_dir);
        $$rss_ref->save($config->{'rss'});
        print "done.\n";
    }
}#}}}
