PROCESS BEFORE OUTPUT.
  MODULE status_9030.
  CALL SUBSCREEN bulk_request INCLUDING sy-repid g_subscr_nn.


PROCESS AFTER INPUT.
  CALL SUBSCREEN bulk_request.
  CHAIN.
    MODULE validate_9030.
  ENDCHAIN.
  MODULE user_command_9030.
