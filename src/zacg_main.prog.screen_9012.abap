PROCESS BEFORE OUTPUT.
  MODULE status_9012.
  CALL SUBSCREEN drrole INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.

  CALL SUBSCREEN drrole.
  CHAIN.
    MODULE p_drrole_validate.
  ENDCHAIN.
  MODULE user_command_9012.
