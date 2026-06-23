PROCESS BEFORE OUTPUT.
  MODULE status_9029.
  CALL SUBSCREEN new_request INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN new_request.
    CHAIN.
    MODULE validate_9029.
  ENDCHAIN.
  MODULE user_command_9029.
