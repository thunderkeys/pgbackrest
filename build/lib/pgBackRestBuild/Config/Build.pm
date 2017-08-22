####################################################################################################################################
# Build Makefile and Auto-Generate Files Required for Build
####################################################################################################################################
package pgBackRestBuild::Config::Build;

use strict;
use warnings FATAL => qw(all);
use Carp qw(confess);
use English '-no_match_vars';

use Cwd qw(abs_path);
use Exporter qw(import);
    our @EXPORT = qw();
use File::Basename qw(dirname);
use Storable qw(dclone);

use pgBackRest::Common::Log;
use pgBackRest::Common::String;
use pgBackRest::Config::Data;
use pgBackRest::Version;

use pgBackRestBuild::Build::Common;
use pgBackRestBuild::CodeGen::Common;
use pgBackRestBuild::CodeGen::Lookup;
use pgBackRestBuild::CodeGen::Switch;

####################################################################################################################################
# Constants
####################################################################################################################################
use constant BLDLCL_FILE_CONFIG                                     => 'config';
use constant BLDLCL_FILE_CONFIG_RULE                                => BLDLCL_FILE_CONFIG . 'Rule';

use constant BLDLCL_PARAM_OPTIONID                                  => 'uiOptionId';
use constant BLDLCL_PARAM_COMMANDID                                 => 'uiCommandId';
    push @EXPORT, qw(BLDLCL_PARAM_COMMANDID);
use constant BLDLCL_PARAM_VALUEID                                   => 'uiValueId';

use constant BLDLCL_CONSTANT_COMMAND                                => 'CFGCMDDEF';
use constant BLDLCL_CONSTANT_COMMAND_TOTAL                          => BLDLCL_CONSTANT_COMMAND . '_TOTAL';

use constant BLDLCL_CONSTANT_OPTION                                 => 'CFGOPTDEF';
use constant BLDLCL_CONSTANT_OPTION_TOTAL                           => BLDLCL_CONSTANT_OPTION . '_TOTAL';
use constant BLDLCL_CONSTANT_OPTION_TYPE                            => BLDLCL_CONSTANT_OPTION . '_TYPE';

use constant BLDLCL_PREFIX_COMMAND                                  => 'cfgCommand';

use constant BLDLCL_FUNCTION_COMMAND_NAME                           => BLDLCL_PREFIX_COMMAND . 'Name';
use constant BLDLCL_FUNCTION_COMMAND_ID                             => BLDLCL_PREFIX_COMMAND . 'Id';

use constant BLDLCL_PREFIX_OPTION                                   => 'cfgOption';

use constant BLDLCL_FUNCTION_INDEX_TOTAL                            => BLDLCL_PREFIX_OPTION . 'IndexTotal';
use constant BLDLCL_FUNCTION_OPTION_NAME                            => BLDLCL_PREFIX_OPTION . 'Name';
use constant BLDLCL_FUNCTION_OPTION_ID                              => BLDLCL_PREFIX_OPTION . 'Id';

use constant BLDLCL_PREFIX_RULE_OPTION                              => 'cfgRuleOption';

use constant BLDLCL_FUNCTION_ALLOW_LIST                             => BLDLCL_PREFIX_RULE_OPTION . 'AllowList';
use constant BLDLCL_FUNCTION_ALLOW_LIST_VALUE                       => BLDLCL_FUNCTION_ALLOW_LIST . 'Value';
use constant BLDLCL_FUNCTION_ALLOW_LIST_VALUE_TOTAL                 => BLDLCL_FUNCTION_ALLOW_LIST_VALUE . 'Total';

use constant BLDLCL_FUNCTION_ALLOW_RANGE                            => BLDLCL_PREFIX_RULE_OPTION . 'AllowRange';
use constant BLDLCL_FUNCTION_ALLOW_RANGE_MAX                        => BLDLCL_FUNCTION_ALLOW_RANGE . 'Max';
use constant BLDLCL_FUNCTION_ALLOW_RANGE_MIN                        => BLDLCL_FUNCTION_ALLOW_RANGE . 'Min';

use constant BLDLCL_FUNCTION_DEFAULT                                => BLDLCL_PREFIX_RULE_OPTION . "Default";

use constant BLDLCL_FUNCTION_DEPEND                                 => BLDLCL_PREFIX_RULE_OPTION . 'Depend';
use constant BLDLCL_FUNCTION_DEPEND_OPTION                          => BLDLCL_FUNCTION_DEPEND . 'Option';
use constant BLDLCL_FUNCTION_DEPEND_VALUE                           => BLDLCL_FUNCTION_DEPEND . 'Value';
use constant BLDLCL_FUNCTION_DEPEND_VALUE_TOTAL                     => BLDLCL_FUNCTION_DEPEND_VALUE . 'Total';

use constant BLDLCL_FUNCTION_HINT                                   => BLDLCL_PREFIX_RULE_OPTION . 'Hint';
use constant BLDLCL_FUNCTION_NAME_ALT                               => BLDLCL_PREFIX_RULE_OPTION . 'NameAlt';
use constant BLDLCL_FUNCTION_NEGATE                                 => BLDLCL_PREFIX_RULE_OPTION . 'Negate';
use constant BLDLCL_FUNCTION_PREFIX                                 => BLDLCL_PREFIX_RULE_OPTION . 'Prefix';
use constant BLDLCL_FUNCTION_REQUIRED                               => BLDLCL_PREFIX_RULE_OPTION . 'Required';
use constant BLDLCL_FUNCTION_SECTION                                => BLDLCL_PREFIX_RULE_OPTION . 'Section';
use constant BLDLCL_FUNCTION_SECURE                                 => BLDLCL_PREFIX_RULE_OPTION . 'Secure';
use constant BLDLCL_FUNCTION_TYPE                                   => BLDLCL_PREFIX_RULE_OPTION . 'Type';
use constant BLDLCL_FUNCTION_VALID                                  => BLDLCL_PREFIX_RULE_OPTION . 'Valid';
use constant BLDLCL_FUNCTION_VALUE_HASH                             => BLDLCL_PREFIX_RULE_OPTION . 'ValueHash';

####################################################################################################################################
# Build command constant maps
####################################################################################################################################
my $rhCommandIdConstantMap;
my $rhCommandNameConstantMap;
my $rhCommandNameIdMap;
my $iCommandTotal = 0;

foreach my $strCommand (sort(keys(%{cfgbldCommandGet()})))
{
    my $strCommandConstant = "CFGCMD_" . uc($strCommand);
    $strCommandConstant =~ s/\-/\_/g;

    $rhCommandIdConstantMap->{$iCommandTotal} = $strCommandConstant;
    $rhCommandNameConstantMap->{$strCommand} = $strCommandConstant;
    $rhCommandNameIdMap->{$strCommand} = $iCommandTotal;

    $iCommandTotal++;
};

####################################################################################################################################
# Build option constant maps
####################################################################################################################################
my $rhOptionIdConstantMap;
my $rhOptionNameConstantMap;
my $rhOptionNameIdMap;
my $iOptionTotal = 0;
my $rhOptionRule = cfgdefRuleIndex();
my @stryOptionAlt;

foreach my $strOption (sort(keys(%{$rhOptionRule})))
{
    my $rhOption = $rhOptionRule->{$strOption};
    my $strOptionConstant = "CFGOPT_" . uc($strOption);
    $strOptionConstant =~ s/\-/\_/g;

    $rhOptionIdConstantMap->{$iOptionTotal} = $strOptionConstant;
    $rhOptionNameConstantMap->{$strOption} = $strOptionConstant;
    $rhOptionNameIdMap->{$strOption} = $iOptionTotal;

    # Create constants for the db- alt names
    my $strOptionAlt = $rhOption->{&CFGBLDDEF_RULE_ALT_NAME};

    if (defined($strOptionAlt) && $strOptionAlt =~ /^db-/)
    {
        $strOptionConstant = "CFGOPT_" . uc($strOptionAlt);
        $strOptionConstant =~ s/\-/\_/g;

        $rhOptionNameConstantMap->{$strOptionAlt} = $strOptionConstant;
        $rhOptionNameIdMap->{$strOptionAlt} = $iOptionTotal;

        push(@stryOptionAlt, $strOptionAlt);
    }

    $iOptionTotal++;
};

####################################################################################################################################
# Build option type constant maps
####################################################################################################################################
my $rhOptionTypeIdConstantMap;
my $rhOptionTypeNameConstantMap;
my $rhOptionTypeNameIdMap;
my $iOptionTypeTotal = 0;

foreach my $strOption (sort(keys(%{$rhOptionRule})))
{
    my $strOptionType = $rhOptionRule->{$strOption}{&CFGBLDDEF_RULE_TYPE};

    if (!defined($rhOptionTypeNameConstantMap->{$strOptionType}))
    {
        my $strOptionTypeConstant = BLDLCL_CONSTANT_OPTION_TYPE . '_' . uc($strOptionType);
        $strOptionTypeConstant =~ s/\-/\_/g;

        $rhOptionTypeIdConstantMap->{$iOptionTypeTotal} = $strOptionTypeConstant;
        $rhOptionTypeNameConstantMap->{$strOptionType} = $strOptionTypeConstant;
        $rhOptionTypeNameIdMap->{$strOptionType} = $iOptionTypeTotal;

        $iOptionTypeTotal++;
    }
};

####################################################################################################################################
# Definitions for functions to build
####################################################################################################################################
my $rhBuild =
{
    &BLD_PARAM_LABEL =>
    {
        &BLDLCL_PARAM_OPTIONID => $rhOptionIdConstantMap,
        &BLDLCL_PARAM_COMMANDID => $rhCommandIdConstantMap,
    },

    &BLD_FILE =>
    {
        #---------------------------------------------------------------------------------------------------------------------------
        &BLDLCL_FILE_CONFIG =>
        {
            &BLD_SUMMARY => 'Query Configuration Settings',

            &BLD_CONSTANT_GROUP =>
            {
                &BLDLCL_CONSTANT_COMMAND =>
                {
                    &BLD_SUMMARY => 'Command',

                    &BLD_CONSTANT =>
                    {
                        &BLDLCL_CONSTANT_COMMAND_TOTAL =>
                        {
                            &BLD_CONSTANT_VALUE => $iCommandTotal,
                        },
                    },
                },

                &BLDLCL_CONSTANT_OPTION =>
                {
                    &BLD_SUMMARY => 'Option',

                    &BLD_CONSTANT =>
                    {
                        &BLDLCL_CONSTANT_OPTION_TOTAL =>
                        {
                            &BLD_CONSTANT_VALUE => $iOptionTotal,
                        },
                    },
                },

                &BLDLCL_CONSTANT_OPTION_TYPE =>
                {
                    &BLD_SUMMARY => 'Option type',
                    &BLD_CONSTANT => {},
                },
            },

            &BLD_FUNCTION =>
            {
                &BLDLCL_FUNCTION_COMMAND_NAME =>
                {
                    &BLD_SUMMARY => 'lookup command name using command id',
                },

                &BLDLCL_FUNCTION_INDEX_TOTAL =>
                {
                    &BLD_SUMMARY => 'total index values allowed',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_INT32,
                    &BLD_PARAM => [BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => 1,
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_VALID,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_OPTION_NAME =>
                {
                    &BLD_SUMMARY => 'lookup option name using option id',
                },
            },
        },

        #---------------------------------------------------------------------------------------------------------------------------
        &BLDLCL_FILE_CONFIG_RULE =>
        {
            &BLD_SUMMARY => 'Parse Configuration Settings',

            &BLD_FUNCTION =>
            {
                &BLDLCL_FUNCTION_COMMAND_ID =>
                {
                    &BLD_SUMMARY => 'lookup command id using command name',
                },

                &BLDLCL_FUNCTION_ALLOW_LIST =>
                {
                    &BLD_SUMMARY => 'is there an allow list for this option?',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_BOOL,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => false,
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_VALID,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_ALLOW_LIST_VALUE =>
                {
                    &BLD_SUMMARY => 'get value from allowed list',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_CONSTCHAR,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID, BLDLCL_PARAM_VALUEID],
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_ALLOW_LIST,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_ALLOW_LIST_VALUE_TOTAL =>
                {
                    &BLD_SUMMARY => 'total number of values allowed',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_INT32,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_ALLOW_LIST,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_ALLOW_RANGE =>
                {
                    &BLD_SUMMARY => 'is the option constrained to a range?',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_BOOL,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => false,
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_VALID,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_ALLOW_RANGE_MIN =>
                {
                    &BLD_SUMMARY => 'minimum value allowed (if the option is constrained to a range)',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_DOUBLE,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_ALLOW_RANGE,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_ALLOW_RANGE_MAX =>
                {
                    &BLD_SUMMARY => 'maximum value allowed (if the option is constrained to a range)',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_DOUBLE,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_ALLOW_RANGE,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_DEFAULT =>
                {
                    &BLD_SUMMARY => 'default value',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_CONSTCHAR,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => undef,
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_VALID,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_DEPEND =>
                {
                    &BLD_SUMMARY => 'does the option have a dependency on another option?',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_BOOL,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => false,
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_VALID,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_DEPEND_OPTION =>
                {
                    &BLD_SUMMARY => 'name of the option that this option depends in order to be set',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_INT32,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_RETURN_VALUE_MAP => $rhOptionIdConstantMap,
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_DEPEND,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_DEPEND_VALUE =>
                {
                    &BLD_SUMMARY => 'the depend option must have one of these values before this option is set',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_CONSTCHAR,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID, BLDLCL_PARAM_VALUEID],
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_DEPEND,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_DEPEND_VALUE_TOTAL =>
                {
                    &BLD_SUMMARY => 'total depend values for this option',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_INT32,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_DEPEND,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_HINT =>
                {
                    &BLD_SUMMARY => 'some clue as to what value the user should provide when the option is missing but required',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_CONSTCHAR,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => undef,
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_VALID,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_OPTION_ID =>
                {
                    &BLD_SUMMARY => 'lookup option id using option name',
                },

                &BLDLCL_FUNCTION_NAME_ALT =>
                {
                    &BLD_SUMMARY => 'alternate name for the option primarily used for deprecated names',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_CONSTCHAR,
                    &BLD_PARAM => [BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => undef,
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_VALID,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_NEGATE =>
                {
                    &BLD_SUMMARY => 'can the boolean option be negated?',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_BOOL,
                    &BLD_PARAM => [BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => false,
                },

                &BLDLCL_FUNCTION_PREFIX =>
                {
                    &BLD_SUMMARY => 'prefix when the option has an index > 1 (e.g. "db")',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_CONSTCHAR,
                    &BLD_PARAM => [BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => undef,
                },

                &BLDLCL_FUNCTION_REQUIRED =>
                {
                    &BLD_SUMMARY => 'is the option required?',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_BOOL,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => false,
                    &BLD_FUNCTION_DEPEND => BLDLCL_FUNCTION_VALID,
                    &BLD_FUNCTION_DEPEND_RESULT => true,
                },

                &BLDLCL_FUNCTION_SECTION =>
                {
                    &BLD_SUMMARY => 'section that the option belongs in, NULL means command-line only',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_CONSTCHAR,
                    &BLD_PARAM => [BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => undef,
                },

                &BLDLCL_FUNCTION_SECURE =>
                {
                    &BLD_SUMMARY => 'secure options can never be passed on the commmand-line',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_BOOL,
                    &BLD_PARAM => [BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => false,
                },

                &BLDLCL_FUNCTION_TYPE =>
                {
                    &BLD_SUMMARY => 'secure options can never be passed on the commmand-line',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_INT32,
                    &BLD_PARAM => [BLDLCL_PARAM_OPTIONID],
                    &BLD_RETURN_VALUE_MAP => $rhOptionTypeIdConstantMap,
                },

                &BLDLCL_FUNCTION_VALID =>
                {
                    &BLD_SUMMARY => 'is the option valid for this command?',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_BOOL,
                    &BLD_PARAM => [BLDLCL_PARAM_COMMANDID, BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => false,
                },

                &BLDLCL_FUNCTION_VALUE_HASH =>
                {
                    &BLD_SUMMARY => 'is the option a true hash or just a list of keys?',
                    &BLD_RETURN_TYPE => CGEN_DATATYPE_BOOL,
                    &BLD_PARAM => [BLDLCL_PARAM_OPTIONID],
                    &BLD_TRUTH_DEFAULT => false,
                },
            },
        },
    },
};

####################################################################################################################################
# Option rule helper functions
####################################################################################################################################
sub optionRule
{
    my $strRule = shift;
    my $strValue = shift;
    my $iCommandId = shift;
    my $iOptionId = shift;

    push(
        @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{$strRule}{&BLD_MATRIX}},
        [$iCommandId, $iOptionId, $strValue]);
}

sub optionRuleDepend
{
    my $rhDepend = shift;
    my $iCommandId = shift;
    my $iOptionId = shift;

    my $strDependOption = $rhDepend->{&CFGBLDDEF_RULE_DEPEND_OPTION};

    optionRule(BLDLCL_FUNCTION_DEPEND, defined($strDependOption) ? true : false, $iCommandId, $iOptionId);

    if (defined($strDependOption))
    {
        optionRule(BLDLCL_FUNCTION_DEPEND_OPTION, $rhOptionNameIdMap->{$strDependOption}, $iCommandId, $iOptionId);

        my $iValueTotal = 0;

        if (defined($rhDepend->{&CFGBLDDEF_RULE_DEPEND_LIST}))
        {
            foreach my $strValue (@{$rhDepend->{&CFGBLDDEF_RULE_DEPEND_LIST}})
            {
                push(
                    @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_DEPEND_VALUE}{&BLD_MATRIX}},
                    [$iCommandId, $iOptionId, $iValueTotal, $strValue]);

                $iValueTotal++;
            }
        }

        optionRule(BLDLCL_FUNCTION_DEPEND_VALUE_TOTAL, $iValueTotal, $iCommandId, $iOptionId);
    }
}

sub optionRuleRange
{
    my $riyRange = shift;
    my $iCommandId = shift;
    my $iOptionId = shift;

    optionRule(
        BLDLCL_FUNCTION_ALLOW_RANGE, defined($riyRange) ? true : false, $iCommandId, $iOptionId);

    if (defined($riyRange))
    {
        optionRule(BLDLCL_FUNCTION_ALLOW_RANGE_MIN, $riyRange->[0], $iCommandId, $iOptionId);
        optionRule(BLDLCL_FUNCTION_ALLOW_RANGE_MAX, $riyRange->[1], $iCommandId, $iOptionId);
    }
}

sub optionRuleAllowList
{
    my $rhAllowList = shift;
    my $iCommandId = shift;
    my $iOptionId = shift;

    optionRule(
        BLDLCL_FUNCTION_ALLOW_LIST, defined($rhAllowList) ? true : false, $iCommandId, $iOptionId);

    if (defined($rhAllowList))
    {
        my $iValueTotal = 0;

        foreach my $strValue (@{$rhAllowList})
        {
            push(
                @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_ALLOW_LIST_VALUE}{&BLD_MATRIX}},
                [$iCommandId, $iOptionId, $iValueTotal, $strValue]);

            $iValueTotal++;
        }

        optionRule(BLDLCL_FUNCTION_ALLOW_LIST_VALUE_TOTAL, $iValueTotal, $iCommandId, $iOptionId);
    }
}

####################################################################################################################################
# Build configuration functions and constants
####################################################################################################################################
sub buildConfig
{
    # Build constants
    #-------------------------------------------------------------------------------------------------------------------------------
    # Add command constants
    my $rhConstant = $rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG}{&BLD_CONSTANT_GROUP}{&BLDLCL_CONSTANT_COMMAND}{&BLD_CONSTANT};

    foreach my $strCommand (sort(keys(%{$rhCommandNameConstantMap})))
    {
        my $strConstant = $rhCommandNameConstantMap->{$strCommand};
        my $strConstantValue = $rhCommandNameIdMap->{$strCommand};

        $rhConstant->{$strConstant}{&BLD_CONSTANT_VALUE} = $strConstantValue;
        $rhConstant->{$strConstant}{&BLD_CONSTANT_EXPORT} = true;
    }

    # Add option type constants
    $rhConstant = $rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG}{&BLD_CONSTANT_GROUP}{&BLDLCL_CONSTANT_OPTION_TYPE}{&BLD_CONSTANT};

    foreach my $strOptionType (sort(keys(%{$rhOptionTypeNameConstantMap})))
    {
        my $strConstant = $rhOptionTypeNameConstantMap->{$strOptionType};
        my $strConstantValue = $rhOptionTypeNameIdMap->{$strOptionType};

        $rhConstant->{$strConstant}{&BLD_CONSTANT_VALUE} = $strConstantValue;
        $rhConstant->{$strConstant}{&BLD_CONSTANT_EXPORT} = true;
    }

    # Add option constants
    $rhConstant = $rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG}{&BLD_CONSTANT_GROUP}{&BLDLCL_CONSTANT_OPTION}{&BLD_CONSTANT};

    foreach my $strOption (sort(keys(%{$rhOptionNameConstantMap})))
    {
        my $strConstant = $rhOptionNameConstantMap->{$strOption};
        my $strConstantValue = $rhOptionNameIdMap->{$strOption};

        $rhConstant->{$strConstant}{&BLD_CONSTANT_VALUE} = $strConstantValue;
        $rhConstant->{$strConstant}{&BLD_CONSTANT_EXPORT} = true;
    }

    # Build config rule maps used to create functions
    #-------------------------------------------------------------------------------------------------------------------------------
    foreach my $strOption (sort(keys(%{$rhOptionRule})))
    {
        my $rhOption = $rhOptionRule->{$strOption};
        my $iOptionId = $rhOptionNameIdMap->{$strOption};

        foreach my $strCommand (sort(keys(%{cfgbldCommandGet()})))
        {
            my $rhCommand = $rhOption->{&CFGBLDDEF_RULE_COMMAND}{$strCommand};
            my $iCommandId = $rhCommandNameIdMap->{$strCommand};

            optionRule(BLDLCL_FUNCTION_VALID, cfgOptionValid($strCommand, $strOption), $iCommandId, $iOptionId);

            if (defined($rhCommand))
            {
                optionRule(BLDLCL_FUNCTION_REQUIRED, cfgOptionRequired($strCommand, $strOption), $iCommandId, $iOptionId);

                optionRule(
                    BLDLCL_FUNCTION_DEFAULT,
                    defined($rhCommand->{&CFGBLDDEF_RULE_DEFAULT}) ?
                        $rhCommand->{&CFGBLDDEF_RULE_DEFAULT} : $rhOption->{&CFGBLDDEF_RULE_DEFAULT},
                    $iCommandId, $iOptionId);
                optionRule(
                    BLDLCL_FUNCTION_HINT,
                        defined($rhCommand->{&CFGBLDDEF_RULE_HINT}) ?
                            $rhCommand->{&CFGBLDDEF_RULE_HINT} : $rhOption->{&CFGBLDDEF_RULE_HINT},
                    $iCommandId, $iOptionId);
                optionRuleDepend(
                    defined($rhCommand->{&CFGBLDDEF_RULE_DEPEND}) ?
                        $rhCommand->{&CFGBLDDEF_RULE_DEPEND} : $rhOption->{&CFGBLDDEF_RULE_DEPEND},
                    $iCommandId, $iOptionId);
                optionRuleRange(
                    defined($rhCommand->{&CFGBLDDEF_RULE_ALLOW_RANGE}) ?
                        $rhCommand->{&CFGBLDDEF_RULE_ALLOW_RANGE} : $rhOption->{&CFGBLDDEF_RULE_ALLOW_RANGE},
                    $iCommandId, $iOptionId);
                optionRuleAllowList(
                    defined($rhCommand->{&CFGBLDDEF_RULE_ALLOW_LIST}) ?
                        $rhCommand->{&CFGBLDDEF_RULE_ALLOW_LIST} : $rhOption->{&CFGBLDDEF_RULE_ALLOW_LIST},
                    $iCommandId, $iOptionId);
            }
        }

        push(
            @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_INDEX_TOTAL}{&BLD_MATRIX}},
            [$iOptionId, $rhOption->{&CFGBLDDEF_RULE_INDEX}]);

        push(
            @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_NEGATE}{&BLD_MATRIX}},
            [$iOptionId, coalesce($rhOption->{&CFGBLDDEF_RULE_NEGATE}, false)]);

        push(
            @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_NAME_ALT}{&BLD_MATRIX}},
            [$iOptionId, $rhOption->{&CFGBLDDEF_RULE_ALT_NAME}]);

        push(
            @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_PREFIX}{&BLD_MATRIX}},
            [$iOptionId, $rhOption->{&CFGBLDDEF_RULE_PREFIX}]);

        push(
            @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_SECTION}{&BLD_MATRIX}},
            [$iOptionId, $rhOption->{&CFGBLDDEF_RULE_SECTION}]);

        push(
            @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_SECURE}{&BLD_MATRIX}},
            [$iOptionId, $rhOption->{&CFGBLDDEF_RULE_SECURE}]);

        push(
            @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_TYPE}{&BLD_MATRIX}},
            [$iOptionId, $rhOptionTypeNameIdMap->{$rhOption->{&CFGBLDDEF_RULE_TYPE}}]);

        push(
            @{$rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_VALUE_HASH}{&BLD_MATRIX}},
            [$iOptionId, $rhOption->{&CFGBLDDEF_RULE_HASH_VALUE}]);
    }

    # Build lookup functions that are not implemented with switch statements
    #-------------------------------------------------------------------------------------------------------------------------------
    $rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_COMMAND_NAME}{&BLD_SOURCE} = cgenLookupString(
        'Command', BLDLCL_CONSTANT_COMMAND_TOTAL, $rhCommandNameConstantMap);
    $rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_OPTION_NAME}{&BLD_SOURCE} = cgenLookupString(
        'Option', BLDLCL_CONSTANT_OPTION_TOTAL, $rhOptionNameConstantMap, '^(' . join('|', @stryOptionAlt) . ')$');

    $rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_COMMAND_ID}{&BLD_SOURCE} = cgenLookupId(
        'Command', BLDLCL_CONSTANT_COMMAND_TOTAL);
    $rhBuild->{&BLD_FILE}{&BLDLCL_FILE_CONFIG_RULE}{&BLD_FUNCTION}{&BLDLCL_FUNCTION_OPTION_ID}{&BLD_SOURCE} = cgenLookupId(
        'Option', BLDLCL_CONSTANT_OPTION_TOTAL);

    # Build switch functions for all files
    #-------------------------------------------------------------------------------------------------------------------------------
    foreach my $strFile (sort(keys(%{$rhBuild->{&BLD_FILE}})))
    {
        my $rhFileFunction = $rhBuild->{&BLD_FILE}{$strFile}{&BLD_FUNCTION};

        foreach my $strFunction (sort(keys(%{$rhFileFunction})))
        {
            my $rhFunction = $rhFileFunction->{$strFunction};

            next if !defined($rhFunction->{&BLD_MATRIX});

            $rhFunction->{&BLD_SOURCE} = cgenSwitchBuild(
                $strFunction, $rhFunction->{&BLD_RETURN_TYPE}, $rhFunction->{&BLD_MATRIX}, $rhFunction->{&BLD_PARAM},
                $rhBuild->{&BLD_PARAM_LABEL}, $rhFunction->{&BLD_RETURN_VALUE_MAP});
        }
    }

    return $rhBuild;
}

push @EXPORT, qw(buildConfig);

1;
