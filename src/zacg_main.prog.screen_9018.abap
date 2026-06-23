PROCESS BEFORE OUTPUT.
  MODULE status_9018.
  CALL SUBSCREEN ccrole INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN ccrole.
  CHAIN.
    MODULE p_ccrole_validate.
  ENDCHAIN.
  MODULE user_command_9018.
