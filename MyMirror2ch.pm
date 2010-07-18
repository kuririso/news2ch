#!/usr/bin/perl -w
# vim:set foldmethod=marker:
# 概要 {{{
#
#   2chのsubject.txtとdatをミラーリングします。
#
# ファイル構成
#
#   ./MyMirror2ch.pm
#       このファイル
#   (dat_dir)/(server_name)/(ita_name)/subject.txt
#   (dat_dir)/(server_name)/(ita_name)/dat/(thread_id).dat
#       ミラーしたファイル
#}}}

# use {{{
use strict;
use warnings;
use Encode;
use LWP::UserAgent;
use FindBin;
use File::Remove qw(remove);
use MyFileUtil;
#}}}

# global {{{
package MyMirror2ch;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(mirror_ua get_subject_txt_path get_dat_path mirror_subject_txt mirror_dat get_thread_list get_res_list unlink_old_dat);
my $dat_dir = "$FindBin::Bin/MyMirror2ch/Dat";
my $product_id = "Monazilla/1.00 (MyMirror2ch.pm/1.0)";
#my $product_id = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_8; ja-jp) AppleWebKit/531.21.8 (KHTML, like Gecko) Version/4.0.4 Safari/531.21.10";
my @wait = (2,3,5,7,11,13,17,19);
#}}}

# UserAgentを指定してmirror
sub mirror_ua {
    my ($remote, $local, $id) = @_; #{{{
    #print "mirror $remote to $local ...\n";
    my $ua = LWP::UserAgent->new;
    $id = $product_id unless $id;
    $ua->timeout(10);
    $ua->agent($id);
    my $is_success = 0;
    for(my $i = 0; $i < @wait; $i++) {
      File::Remove::remove $local;
      MyFileUtil::make_path(File::Basename::dirname($local));
      my $ret = $ua->mirror($remote, $local);
      if ($ret and -e $local and -f $local and -s $local > 1) {
        $is_success = 1;
        last;
      }
      print "retry...\n";
      sleep $wait[$i];
    }
    #print "done\n";
    $is_success or die "mirror_ua failure.";
#}}}
    ($remote, $local);
}

sub get_subject_txt_path {
    my ($server, $ita, $dir) = @_; #{{{
    $dir = $dat_dir unless $dir;
    my $remote = "http://$server/$ita/subject.txt";
    my $local = "$dir/$server/$ita/subject.txt";
#}}}
    ($remote, $local);
}

sub get_dat_path {
    my ($server, $ita, $thread, $dir) = @_; #{{{
    $thread or die;
    $dir = $dat_dir unless $dir;
    my $remote = "http://$server/$ita/dat/$thread.dat";
    my $local = "$dir/$server/$ita/dat/$thread.dat";
#}}}
    ($remote, $local);
}

# subject.txt取得
sub mirror_subject_txt {
    my ($server, $ita, $dir) = @_;
    mirror_ua(get_subject_txt_path($server, $ita, $dir));
}

# dat取得
sub mirror_dat {
    my ($server, $ita, $thread, $dir) = @_;
    mirror_ua(get_dat_path($server, $ita, $thread, $dir));
}

# subject.txtを指定してスレッドリストを取得
sub get_thread_list {
    my ($server, $ita, $dir) = @_; #{{{
    my ($remote, $subject_txt) = get_subject_txt_path($server, $ita, $dir);
    #print "parse $subject_txt ...\n";
    my $now = time;
    my @thread_list = ();
    my $number = 1;
    #open SUBJECT_TXT, $subject_txt or die "can't open: $subject_txt";
    open SUBJECT_TXT, $subject_txt or return 0;
    my $file = join '<><>', <SUBJECT_TXT>;
    my @original = ($file =~ /(\d+\.dat<>[^<>]+)/g);
    #print "thread_num: ".($#original + 1)."\n";
    foreach my $orig (@original){
        my $line = Encode::decode('cp932', $orig);
        my %thread = ();
        if($line =~ /^(\d+)\.dat<>(.*)\s*\((\d+)\)$/){
            ($thread{'id'}, $thread{'title'}, $thread{'res'}) = ($1, $2, $3);
            $thread{'elapsed'} = $now - $thread{'id'};
            if ($thread{'elapsed'} > 0) {
                $thread{'ikioi'} = $thread{'res'}*60*60*24 / $thread{'elapsed'};
            } else {
                $thread{'elapsed'} = 0;
                $thread{'ikioi'} = 0;
            }
            $thread{'number'} = $number;
            push @thread_list, \%thread;
        } else {
            print STDERR "parse error.\nsubject_txt: $subject_txt\nnum: $number\norig: $orig\nline: $line\n";
        }
        $number++;
    }
    close SUBJECT_TXT;
    #print "done.\n";
#}}}
    (\@thread_list);
}

# スレッドを指定してレスリストを取得
sub get_res_list {
    my ($server, $ita, $thread, $dir) = @_; #{{{
    my ($remote, $dat) = get_dat_path($server, $ita, $thread, $dir);
    #print "parse $dat ...\n";
    my @res_list = ();
    my %id_count = ();#必死度チェック
    my $number = 1;
    unless(open DAT, $dat) { print STDERR "can't open: $dat"; return; }
    while(<DAT>){
        $_ = Encode::decode('cp932', $_);
        my %res = ();
        my $date_etc;
        ($res{'name'}, $res{'mail'}, $date_etc, $res{'body'}, $res{'title'}) = split(/<>/, $_);
        $res{'name'} =~ s/^\s+//g;
        $res{'name'} =~ s/\s+$//g;
        $res{'name'} =~ s/<\/?b>//g;
        $res{'body'} =~ s/^\s+//g;
        $res{'body'} =~ s/\s+$//g;
        $res{'body'} =~ s/\s*<br>\s*/\n/g;
        $res{'title'} =~ s/^\s+//g;
        $res{'title'} =~ s/\s+$//g;
        if ($date_etc =~ /^(\S+)\s+(\S+)(?:.+?(ID:\S+)(?:\s+(BE:.+))?)?$/) {
            ($res{'date'},$res{'time'},$res{'id'},$res{'be'}) = ($1,$2,$3,$4);
            $res{'number'} = $number;
            $id_count{$res{'id'}}++;
            push @res_list, \%res;
        } elsif ($date_etc =~ /Over 1000 Thread/) {
            my $res_ref = $res_list[999];
            $res{'date'} = $$res_ref{'date'};
            $res{'time'} = $$res_ref{'time'};
            $res{'number'} = $number;
            push @res_list, \%res;
            last;
        } elsif ($date_etc eq Encode::decode('utf8', '停止') ) {
            my $res_ref = $res_list[$#res_list];
            $res{'date'} = $$res_ref{'date'};
            $res{'time'} = $$res_ref{'time'};
            $res{'number'} = $number;
            push @res_list, \%res;
            last;
        } else {
            die "parse error.\ndat: $dat\nnum: $number\ndate_etc: $date_etc\n";
        }
        $number++;
    }
    close DAT;
    #必死度を@res_listに組み込む
    foreach my $res_ref (@res_list) {
        if($$res_ref{'id'} and $id_count{$$res_ref{'id'}}){
            $$res_ref{'hisshido'} = $id_count{$$res_ref{'id'}};
        }
    }
    #print "done.\n";
#}}}
    (\@res_list);
}

# 古いdatは削除
sub unlink_old_dat {
    my ($server, $ita, $dir) = @_; #{{{
    my $thread_list_ref = get_thread_list($server, $ita, $dir);
    # thread list が取れないなら抜ける
    return 1 unless $thread_list_ref;
    my @exists;
    foreach my $thread_ref (@$thread_list_ref) {
        push @exists, $$thread_ref{'id'};
    }
    my @files = glob "$dir/$server/$ita/dat/*.dat";
    my $i = 0;
    foreach my $file (sort @files) {
        my $found = 0;
        # tsushima.2ch.net で生きているスレッド ID と
        # ローカルの dat のスレッド ID を比較
        foreach my $exist (sort @exists) {
            if ($file =~ /dat\/$exist\.dat/) {
                $found = 1;
                last;
            }
        }
        # tsushima.2ch.net 上で消えてたらローカルでも削除
        if (not $found) {
#            print "unlink: $file\n";
            unlink $file;
            $i++;
        }
        # 特定の回数でいったん終了
        last if $i >= 2;
    }
#}}}
    1;
}

1;
