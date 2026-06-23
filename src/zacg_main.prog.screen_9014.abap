PROCESS BEFORE OUTPUT.
  MODULE status_9014.
  CALL SUBSCREEN asrole INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN asrole.
  CHAIN.
    MODULE p_asrole_validate.
  ENDCHAIN.
  MODULE user_command_9014.
