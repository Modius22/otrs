# --
# Kernel/Modules/AgentWizard.pm - HTML reference pages
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentWizard;

use strict;
use warnings;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $NeededData (
        qw(
        GroupObject   ParamObject  DBObject   ModuleReg  LayoutObject
        LogObject     ConfigObject UserObject MainObject TimeObject
        SessionObject UserID       AccessRo   SessionID
        EncodeObject
        )
        )
    {
        if ( !$Param{$NeededData} ) {
            $Param{LayoutObject}->FatalError( Message => "Got no $NeededData!" );
        }
        $Self->{$NeededData} = $Param{$NeededData};
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # show dashboard
    $Self->{LayoutObject}->Block(
        Name => 'Content',
        Data => {
            Con => 'fooooo',
        },
    );

    # build output
    my $Output .= $Self->{LayoutObject}->Header(
        Title => 'Agent Wizard',
    );
    $Output .= $Self->{LayoutObject}->NavigationBar();
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentWizard',
    );
    $Output .= $Self->{LayoutObject}->Footer();

    return $Output;
}

1;
