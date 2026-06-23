PROCESS BEFORE OUTPUT.
  MODULE status_9025.
  CALL SUBSCREEN direct_change INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN direct_change.
  MODULE user_command_9025.
