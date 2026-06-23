PROCESS BEFORE OUTPUT.
  MODULE status_9016.
  CALL SUBSCREEN rmrole INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN rmrole.
  CHAIN.
    MODULE p_rmrole_validate.
  ENDCHAIN.
  MODULE user_command_9016.
