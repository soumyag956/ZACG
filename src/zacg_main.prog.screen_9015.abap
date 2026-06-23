PROCESS BEFORE OUTPUT.
  MODULE status_9015.
  CALL SUBSCREEN rsrole INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN rsrole.
  CHAIN.
    MODULE p_rsrole_validate.
  ENDCHAIN.
  MODULE user_command_9015.
