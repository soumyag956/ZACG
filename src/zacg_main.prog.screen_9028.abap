PROCESS BEFORE OUTPUT.
  MODULE status_9028.


PROCESS AFTER INPUT.
  CHAIN.
    FIELD: date1, date2, hrs.
    MODULE validate_9028.
  ENDCHAIN.
  MODULE user_command_9028.
