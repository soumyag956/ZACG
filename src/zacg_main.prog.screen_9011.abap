PROCESS BEFORE OUTPUT.
  MODULE status_9011.
  CALL SUBSCREEN cdrole INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN cdrole.
  CHAIN.
    MODULE p_cdrole_validate.
  ENDCHAIN.
  MODULE user_command_9011.
