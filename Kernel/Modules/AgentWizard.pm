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

    # add all params to %GetParam so we can pass them to wizard modules
    my %GetParam;
    my @ParamNames = $Self->{ParamObject}->GetParamNames();
    for my $ParamName (@ParamNames) {
        $GetParam{$ParamName} = $Self->{ParamObject}->GetParam( Param => $ParamName );
    }

    my %Modules = $Self->{ConfigurationWizardObject}->WizardModuleListGet(
        UserID => $Self->{UserID},
    );

    my $Config = $Self->{ConfigObject}->Get('ConfigurationWizard');

    # read name from configuration
    for my $Module ( sort keys %Modules ) {

        $Modules{$Module} = $Config->{$Module}->{Name} // $Module;
    }

    my $WizardList = $Self->{LayoutObject}->BuildSelection(
        Class => 'Validate_Required W25pc' . ( $Param{Errors}->{WizardIDInvalid} || ' ' ),
        Data  => \%Modules,
        Name  => 'WizardID',
        SelectedID   => $GetParam{WizardID},
        PossibleNone => 1,
        Sort         => 'AlphanumericValue',
        Translation  => 1,
    );

    # show wizard list
    $Self->{LayoutObject}->Block(
        Name => 'WizardList',
        Data => {
            WizardList => $WizardList,
        },
    );

    # run wizard module
    if ( $GetParam{WizardID} ) {

        $Self->{LayoutObject}->ChallengeTokenCheck();

        my $Module = $Config->{ $GetParam{WizardID} }->{FrontendModule};

        # check if FrontendModule exists in configuration
        if ( !$Module ) {

            $Self->{LayoutObject}->FatalError(
                Message => "No FrontendModule registered for $GetParam{WizardID}!",
            );
        }

        my $ModuleLoaded = $Self->{MainObject}->Require($Module);

        if ( !$ModuleLoaded ) {

            $Self->{LayoutObject}->FatalError(
                Message => "Can't load '$Module'!",
            );
        }

        my $Object = $ModuleLoaded->new(
            %{$Self},
            %GetParam,
        );

    }

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
