*&---------------------------------------------------------------------*
*& Report ZACG_FFID_LOGOUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zacg_ffid_logout.

DATA:
      lv_message TYPE string.

DATA(lo_server_info) = NEW cl_server_info( ).
DATA(li_session_list) = lo_server_info->get_session_list(
  tenant                = sy-mandt
  with_application_info = 1 ).

SELECT *
  FROM zacg_ffid_log
  INTO TABLE @DATA(li_log)
  WHERE active = @abap_true.
LOOP AT li_log ASSIGNING FIELD-SYMBOL(<lfs_log>).
  CLEAR lv_message.
  READ TABLE li_session_list TRANSPORTING NO FIELDS
  WITH KEY user_name = <lfs_log>-ffid.
  IF sy-subrc IS NOT INITIAL.
    UPDATE zacg_ffid_log
    SET active = abap_false
        lgoutdt = sy-datum
        lgouttm = sy-uzeit
    WHERE session_id   = <lfs_log>-session_id.
    COMMIT WORK AND WAIT.
    lv_message = |User { <lfs_log>-ffid } loged out by system on { sy-datum }{ sy-uzeit }|.
    MESSAGE lv_message TYPE 'S'.
  ENDIF.
ENDLOOP.
