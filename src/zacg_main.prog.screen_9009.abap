PROCESS BEFORE OUTPUT.
  MODULE status_9009.
  CALL SUBSCREEN set_init_pass INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.

  CALL SUBSCREEN set_init_pass.
  CHAIN.
    MODULE p_initpw_validate.
  ENDCHAIN.
  MODULE user_command_9009.
