PROCESS BEFORE OUTPUT.
  MODULE status_9013.
  CALL SUBSCREEN dirole INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN dirole.
  CHAIN.
    MODULE p_dirole_validate.
  ENDCHAIN.
  MODULE user_command_9013.
