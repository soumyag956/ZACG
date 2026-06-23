PROCESS BEFORE OUTPUT.
  MODULE status_9019.
  CALL SUBSCREEN csrole_copy INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN csrole_copy.
  CHAIN.
    MODULE p_copy_role_validate.
  ENDCHAIN.
  MODULE user_command_9019.
