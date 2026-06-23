PROCESS BEFORE OUTPUT.
  MODULE status_9026.
  CALL SUBSCREEN org_fields INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN org_fields.
  MODULE user_command_9026.
