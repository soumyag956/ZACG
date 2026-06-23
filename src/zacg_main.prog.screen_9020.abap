PROCESS BEFORE OUTPUT.
  MODULE status_9020.
  CALL SUBSCREEN role_assign INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN role_assign.
  CHAIN.
    MODULE p_role_assign_validate.
  ENDCHAIN.
  MODULE user_command_9020.
