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

use Kernel::System::ConfigurationWizard;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (
        qw(
        GroupObject   ParamObject  DBObject   ModuleReg  LayoutObject
        LogObject     ConfigObject UserObject MainObject TimeObject
        SessionObject UserID       AccessRo   SessionID
        EncodeObject
        )
        )
    {
        if ( !$Param{$Needed} ) {
            $Param{LayoutObject}->FatalError( Message => "Got no $Needed!" );
        }
        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{ConfigurationWizardObject} = Kernel::System::ConfigurationWizard->new( %{$Self} );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %Modules = $Self->{ConfigurationWizardObject}->WizardModuleListGet(
        UserID => $Self->{UserID},
    );

    my $Config = $Self->{ConfigObject}->Get('ConfigurationWizard');

    for my $Module ( sort keys %Modules ) {

        # read name from configuration
        my $Name = $Config->{$Module}->{Name} // $Module;
        $Self->{LayoutObject}->Block(
            Name => 'AvailableModule',
            Data => {
                ModuleName => $Name,
                Module     => $Module,
            },
        );
    }

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
