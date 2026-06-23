PROCESS BEFORE OUTPUT.
  MODULE status_7002.
  LOOP AT i_outtab_7002 INTO wa_outtab_7002
    WITH CONTROL table_7002 CURSOR table_7002-current_line.

  ENDLOOP.

PROCESS AFTER INPUT.
  LOOP AT i_outtab_7002.
    CHAIN.
      MODULE validate_7002.
    ENDCHAIN.
  ENDLOOP.
  MODULE user_command_7002.
