PROCESS BEFORE OUTPUT.
  MODULE status_7001.
  LOOP AT i_outtab_7001 INTO wa_outtab_7001
    WITH CONTROL table_7001
    CURSOR table_7001-current_line.

  ENDLOOP.

PROCESS AFTER INPUT.

  LOOP AT i_outtab_7001.
    CHAIN.
      MODULE validate_7001.
    ENDCHAIN.
  ENDLOOP.
  MODULE user_command_7001.
