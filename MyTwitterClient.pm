#!/usr/bin/perl -w
# vim:set foldmethod=marker:

# use {{{
use strict;
use warnings;
use Encode;
use Net::Twitter::Lite;
use WWW::Shorten::Bitly;
use File::Path;
use File::Basename;
use FindBin;
use MyFileUtil;
#}}}

# global vals {{{
package MyTwitterClient;
use base 'Exporter';
our @EXPORT = qw(shorten_message new twit_queue get_net_twitter_lite twit twit_oldest_draft twit_draft save_draft_wrapper save_direct_messages);
my $config_file = "$FindBin::Bin/MyTwitterClient/config.cgi";
my $draft_dir = "$FindBin::Bin/MyTwitterClient/Draft";
my $dm_dir = "$FindBin::Bin/MyTwitterClient/DirectMessage";
my $is_enable_oauth = 0;
#}}}

# コンストラクタ
sub new {
    my ($class, %args) = @_; #{{{
    foreach my $arg (keys %args) {
        if ($arg !~ /^(?:config_file|draft_dir|is_enable_oauth)$/) {
            die "$arg is not implement.";
        }
    }
    $args{'config_file'} = $config_file unless $args{'config_file'};
    $args{'draft_dir'} = $draft_dir unless $args{'draft_dir'};
    $args{'is_enable_oauth'} = $is_enable_oauth unless $args{'is_enable_oauth'};
#}}}
    return bless { %args }, $class;
}

# メッセージ($message)を140($max_len)文字にする
# (引数のリンク($link)は確実に残す)
sub shorten_message {
    my ($self, $message, $link, $max_len) = @_; #{{{
#   $messageはすでにバイト列になっていること
    $max_len = 140 unless $max_len;
    my $config = MyFileUtil::load_config($self->{'config_file'});
    my $bitly = WWW::Shorten::Bitly->new(
        USER => $config->{'bitly_user_id'},
        APIKEY => $config->{'bitly_api_key'},
        jmp => 1,
    );
    $message =~ s/(http:\/\/([^\s<>]+))/$bitly->shorten(URL => $1)/ge;
    if ($link) {
#        print "\n$link\n".$config->{'bitly_user_id'}."\n".$config->{'bitly_api_key'}."\n";
        $link = $bitly->shorten(URL => $link);
#        print "\n$link\n".$config->{'bitly_user_id'}."\n".$config->{'bitly_api_key'}."\n";
        $link or die;
#        print "\n";
#        print "length(\$message): ".length($message)."\n";
#        print "length(\$link): ".length($link)."\n";
        if (length($message) + 1 + length($link) > $max_len) {
            $message = substr($message,0,$max_len-2-length($link)).Encode::decode('utf-8',"…")." $link";
        } else {
            $message = "$message $link";
        }
    } else {
        if (length($message) > $max_len) {
            $message = substr($message,0,$max_len-1).Encode::decode('utf-8',"…");
        }
    }
#    print "\n".Encode::encode('utf-8',$message)."\n";
#}}}
    return $message;
}

# Net::Twitter::Liteを取得
sub get_net_twitter_lite {
    my ($self) = @_; #{{{
    my $nt;
    my $config = MyFileUtil::load_config($self->{'config_file'});
    if ($self->{'is_enable_oauth'}) {
        unless($config->{'consumer_key'} and $config->{'consumer_secret'}){
            die "consumer_key and/or consumer_secret is not found";
        }
        $nt = Net::Twitter::Lite->new(
            consumer_key => $config->{'consumer_key'},
            consumer_secret => $config->{'consumer_secret'},
        );

        my $access_token = $config->{'access_token'};
        my $access_token_secret = $config->{'access_token_secret'};
        if ($access_token and $access_token_secret) {
            $nt->access_token($access_token);
            $nt->access_token_secret($access_token_secret);
        }

        unless ($nt->authorized) {
            print "Authorize this app at\n", $nt->get_authorization_url, "\nand enter the PIN#\n";

            my $pin = <STDIN>; # wait for input
            chomp $pin;

            my ($user_id, $screen_name);
            ($access_token, $access_token_secret, $user_id, $screen_name) =
                $nt->request_access_token(verifier => $pin);
            $config->{'access_token'} = $access_token;
            $config->{'access_token_secret'} = $access_token_secret;
            print "access_token: $access_token\n";
            print "access_token_secret: $access_token_secret\n";
#            print "user_id: $user_id\n";
#            print "screen_name: ".Encode::encode('utf-8',$user_id)."\n";
            MyFileUtil::save_config($config, $self->{'config_file'});
#            print "save_config: $self->{'config_file'}\n";
        }
    } else {
        unless($config->{'username'} and $config->{'password'}){
            die "username and/or password is not found";
        }
        $nt = Net::Twitter::Lite->new(
            'username' => $config->{'username'},
            'password' => $config->{'password'},
        );
    }
#}}}
    \$nt;
}

# つぶやく
sub twit {
    my ($self, $message) = @_; #{{{
    my $nt_ref = $self->get_net_twitter_lite;
    eval { $$nt_ref->update($message) };
    if ($@) {
        print "MyTwitterClient::twit: update failed. because:\n  $@\n";
        if($@ =~ /duplicate/){
            return "duplicate";
        }
        return 0;
    }
    #print "MyTwitterClient::twit: success.\n";
#}}}
    1;
}

# 下書きにある一番古いつぶやきをつぶやく
sub twit_oldest_draft {
    my ($self) = @_; #{{{
    my ($filename, $message) = MyFileUtil::load_draft($self->{'draft_dir'});
    return 0 unless $message;
    chomp $message;
    my $ret = $self->twit($message);
    if ($ret) { # 成功
#        print "unlink $filename\n";
        unlink $filename;
    } else {
        return 0;
    }
#}}}
    1;
}

# 下書きにあるすべてのつぶやきをつぶやく
sub twit_draft {
    my ($self) = @_; #{{{
    while(1){
        my $ret = $self->twit_oldest_draft;
        last unless $ret;
    }
#}}}
    1;
}

# 下書きに保存するだけ
sub save_draft_wrapper {
    my ($self, $message) = @_; #{{{
    if ($message) {
        MyFileUtil::save_draft($message, $self->{'draft_dir'});
    }
#}}}
    1;
}

# 下書きに保存しつつ下書きにある一番古いつぶやきをつぶやく
sub twit_queue {
    my ($self, $message) = @_; #{{{
    if ($message) {
        MyFileUtil::save_draft($message, $self->{'draft_dir'});
    }
    my $ret = $self->twit_oldest_draft;
#}}}
    $ret;
}

# DirectMessageのうち一番古いものを読み込む
sub load_direct_message {
    my ($dir) = @_;
    $dir = $dm_dir unless $dir;
    load_oldest_text($dir);
}

# DirectMessageを保存
sub save_direct_message {
    my ($message, $id, $dir) = @_; # $messageはすでにバイト列になっていること {{{
    $dir = $dm_dir unless $dir;
    make_path $dir or die;
    my $file = sprintf("%s/%d_%d.txt",$dir,time,$id);
    open TXT, ">$file";
    print TXT Encode::encode('utf-8',"$message\n");
    close TXT;
#}}}
    1;
}

# DirectMessageを取得する
sub get_direct_message {
    my ($self) = @_; #{{{
    my $nt_ref = $self->get_net_twitter_lite;
    my $array_ref = $$nt_ref->direct_messages;
    foreach my $hash_ref (@$array_ref) {
        foreach my $key (sort keys %$hash_ref) {
            if(ref($$hash_ref{$key}) eq 'HASH'){
                my $hash_ref2 = $$hash_ref{$key};
                foreach my $key2 (sort keys %$hash_ref2) {
                    print Encode::encode('utf-8',"$key: $key2: ".($$hash_ref2{$key2}?$$hash_ref2{$key2}:"")."\n");
                }
            }else{
                print Encode::encode('utf-8',"$key: ".($$hash_ref{$key}?$$hash_ref{$key}:"")."\n");
            }
        }
    }
#}}}
    1;
}

1;
