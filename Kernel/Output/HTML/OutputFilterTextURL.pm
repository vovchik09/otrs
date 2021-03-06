# --
# Kernel/Output/HTML/OutputFilterTextURL.pm - auto URL detection filter
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilterTextURL;

use strict;
use warnings;

use vars qw(@ISA);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for (qw(DBObject ConfigObject LogObject TimeObject MainObject LayoutObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    return $Self;
}

sub Pre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{Data} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'Need Data!' );
        $Self->{LayoutObject}->FatalDie();
    }

    $Self->{LinkHash} = undef;
    my $Counter = 0;
    ${ $Param{Data} } =~ s{
        ( > | < | &gt; | &lt; | )  # $1 greater-than and less-than sign

        (                                              #2
            (?:                                      # http or only www
                (?: (?: http s? | ftp ) :\/\/) |        # http://,https:// and ftp://
                (?: (?: \w*www | ftp ) \. \w+ )                 # www.something and ftp.something
            )
            .*?               # this part should be better defined!
        )
        (                               # $3
            [\?,;!\.\)\]] (?: \s | $ )    # \)\s this construct is because of bug#2450 and bug#7288
            | \s
            | \"
            | &quot;
            | &nbsp;
            | '
            | >                           # greater-than and less-than sign
            | <                           # "
            | &gt;                        # "
            | &lt;                        # "
            | $                           # bug# 2715
        )        }
    {
        my $Start = $1;
        my $Link  = $2;
        my $End   = $3;
        $Counter++;
        if ( $Link !~ m{^ ( http | https | ftp ) : \/ \/ }xi ) {
            if ($Link =~ m{^ ftp }smx ) {
                $Link = 'ftp://' . $Link;
            }
            else {
                $Link = 'http://' . $Link;
            }
        }
        my $Length = length $Link ;
        $Length = $Length < 75 ? $Length : 75;
        my $String = '#' x $Length;
        $Self->{LinkHash}->{"[$String$Counter]"} = $Link;
        $Start . "[$String$Counter]" . $End;
    }egxism;

    return $Param{Data};
}

sub Post {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{Data} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'Need Data!' );
        $Self->{LayoutObject}->FatalDie();
    }

    if ( $Self->{LinkHash} ) {
        for my $Key ( sort keys %{ $Self->{LinkHash} } ) {
            my $LinkSmall = $Self->{LinkHash}->{$Key};
            $LinkSmall =~ s/^(.{75}).*$/$1\[\.\.\]/gs;
            $Self->{LinkHash}->{$Key} =~ s/ //g;
            ${ $Param{Data} }
                =~ s/\Q$Key\E/<a href=\"$Self->{LinkHash}->{$Key}\" target=\"_blank\" title=\"$Self->{LinkHash}->{$Key}\">$LinkSmall<\/a>/;
        }
    }

    return $Param{Data};
}

1;
