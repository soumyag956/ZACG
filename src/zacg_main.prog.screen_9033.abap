PROCESS BEFORE OUTPUT.
  MODULE status_9033.

  LOOP AT i_outtab_9033 INTO wa_outtab_9033
    WITH CONTROL table_9033 CURSOR table_9033-current_line.

    MODULE hide_row_9033.

  ENDLOOP.

PROCESS AFTER INPUT.
  LOOP AT i_outtab_9033.
    CHAIN.
      MODULE validate_9033.
    ENDCHAIN.
  ENDLOOP.
  MODULE user_command_9033.
