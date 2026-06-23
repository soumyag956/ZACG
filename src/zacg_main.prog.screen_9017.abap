PROCESS BEFORE OUTPUT.
  MODULE status_9017.
  CALL SUBSCREEN pmrole INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN pmrole.
  CHAIN.
    MODULE p_pmrole_validate.
  ENDCHAIN.
  MODULE user_command_9017.
