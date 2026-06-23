PROCESS BEFORE OUTPUT.
  MODULE status_9007.
  CALL SUBSCREEN pwr INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN pwr.
  CHAIN.
    MODULE p_pwfile_validate.
  ENDCHAIN.
  MODULE user_command_9007.
