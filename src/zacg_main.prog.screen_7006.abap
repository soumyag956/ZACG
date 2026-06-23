PROCESS BEFORE OUTPUT.
  LOOP AT   i_outtab_7006
       INTO wa_outtab_7006
       WITH CONTROL table_7006
       CURSOR table_7006-current_line.
  ENDLOOP.

  MODULE status_7006.
*
PROCESS AFTER INPUT.
  LOOP AT i_outtab_7006.
    CHAIN.
*      FIELD wa_outtab_7006-session_id.
*      FIELD wa_outtab_7006-ffid.
*      FIELD wa_outtab_7006-owner.
*      FIELD wa_outtab_7006-userid.
*      FIELD wa_outtab_7006-tcode.
*      FIELD wa_outtab_7006-times.
*      FIELD wa_outtab_7006-reason.
      MODULE validate_7006.
    ENDCHAIN.
  ENDLOOP.

  MODULE user_command_7006.
