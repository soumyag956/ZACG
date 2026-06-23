PROCESS BEFORE OUTPUT.
  MODULE status_9031.
  CALL SUBSCREEN search_request INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN search_request.
    CHAIN.
    MODULE validate_9031.
  ENDCHAIN.
  MODULE user_command_9031.
