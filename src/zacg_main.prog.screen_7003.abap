PROCESS BEFORE OUTPUT.
  MODULE status_7003.
  LOOP AT i_outtab_7003 INTO wa_outtab_7003
    WITH CONTROL table_7003 CURSOR table_7003-current_line.

  ENDLOOP.

PROCESS AFTER INPUT.
  LOOP AT i_outtab_7003.
    CHAIN.
      MODULE validate_7003.
    ENDCHAIN.

  ENDLOOP.

  MODULE user_command_7003.
