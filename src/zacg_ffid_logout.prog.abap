*&---------------------------------------------------------------------*
*& Report ZACG_FFID_LOGOUT
*&---------------------------------------------------------------------*
*& Reconciles the Firefighter (FFID) session log.
*&
*& For every FFID session still flagged active in ZACG_FFID_LOG, the
*& report checks whether a matching live application-server session
*& still exists. If the session has ended, the log entry is closed
*& (ACTIVE = '', logout date / time stamped).
*&
*& Intended to run as a periodic background job.
*&
*& LIMITATION: cl_server_info=>get_session_list returns the sessions
*& known to the application-server instance the job runs on. In a
*& multi-instance system, FFID sessions held on *other* instances are
*& not reported here and would be closed incorrectly. A robust version
*& should aggregate sessions across all instances (e.g. via
*& TH_GET_SESSIONLIST / a system-wide session source) before closing
*& log entries.
*&---------------------------------------------------------------------*
REPORT zacg_ffid_logout.

DATA:
      lv_message TYPE string.

DATA(lo_server_info) = NEW cl_server_info( ).
DATA(li_session_list) = lo_server_info->get_session_list(
  tenant                = sy-mandt
  with_application_info = 1 ).

" Only the fields required below are read instead of SELECT *.
SELECT ffid, session_id
  FROM zacg_ffid_log
  INTO TABLE @DATA(li_log)
  WHERE active = @abap_true.
LOOP AT li_log ASSIGNING FIELD-SYMBOL(<lfs_log>).
  CLEAR lv_message.
  READ TABLE li_session_list TRANSPORTING NO FIELDS
  WITH KEY user_name = <lfs_log>-ffid.
  IF sy-subrc IS NOT INITIAL.
    UPDATE zacg_ffid_log
    SET active = @abap_false
        lgoutdt = @sy-datum
        lgouttm = @sy-uzeit
    WHERE session_id = @<lfs_log>-session_id.
    IF sy-subrc = 0.
      COMMIT WORK AND WAIT.
      lv_message = |User { <lfs_log>-ffid } logged out by system on { sy-datum } { sy-uzeit }|.
      MESSAGE lv_message TYPE 'S'.
    ELSE.
      " Nothing was updated (entry already closed / changed) - undo any
      " pending work so the next iteration starts clean.
      ROLLBACK WORK.
    ENDIF.
  ENDIF.
ENDLOOP.
