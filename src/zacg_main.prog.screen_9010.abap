PROCESS BEFORE OUTPUT.
  MODULE status_9010.
  CALL SUBSCREEN usupd INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN usupd.
  CHAIN.
    MODULE p_usupd_validate.
  ENDCHAIN.
  MODULE user_command_9010.
