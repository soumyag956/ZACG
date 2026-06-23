*&---------------------------------------------------------------------*
*& Include          ZACG_TLOG_BATCH_F01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form fetch_log_data
*&---------------------------------------------------------------------*
*& Batch helper: reads the Security Audit Log (RSAU_*) for the active
*& firefighter sessions and stores the transactions they executed in the
*& FFID transaction log ZACG_FFID_TLOG for later review.
*&---------------------------------------------------------------------*
FORM fetch_log_data .
  DATA : lv_max_date   TYPE begda,
         lv_dlydy      TYPE dlydy,
         lv_dlymo      TYPE dlymo,
         lv_dlyyr      TYPE dlyyr VALUE '01',
         lr_user       TYPE RANGE OF rslguser,
         lr_session_id TYPE RANGE OF zacg_session_id,

         lo_data       TYPE REF TO data,
         lt_data       TYPE STANDARD TABLE OF rsau_s_result,
         lt_tcode_list TYPE STANDARD TABLE OF rsau_s_result,
         lt_ffid_tlog  TYPE STANDARD TABLE OF zacg_ffid_tlog.


  CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
    EXPORTING
      date      = sy-datum
      days      = lv_dlydy
      months    = lv_dlymo
      signum    = '-'
      years     = lv_dlyyr
    IMPORTING
      calc_date = lv_max_date.

  SELECT session_id
    FROM zacg_ffid_log
    INTO TABLE @DATA(lt_session_id)
    WHERE logindt LT @lv_max_date.
  IF sy-subrc IS INITIAL.
    lr_session_id = VALUE #( FOR ls_session_id IN lt_session_id (
     sign = 'I' option = 'EQ' low = ls_session_id-session_id ) ).
    DELETE FROM zacg_ffid_log WHERE logindt LT lv_max_date.
    IF lr_session_id IS NOT INITIAL.
      DELETE FROM zacg_ffid_tlog WHERE session_id IN lr_session_id.
    ENDIF.
    COMMIT WORK AND WAIT.
  ENDIF.

  "Get the data from the log & tlog tables
  SELECT DISTINCT a~userid, a~session_id, a~ffid,
    a~logindt, a~logintm, a~lgoutdt, a~lgouttm,
    b~session_id AS tlog_id
    FROM zacg_ffid_log AS a
    LEFT OUTER JOIN zacg_ffid_tlog AS b
    ON a~session_id = b~session_id
    WHERE a~session_id IS NOT INITIAL
    AND a~active IS INITIAL
    INTO TABLE @DATA(lt_ffid_log).
  IF sy-subrc = 0.
    SORT lt_ffid_log BY tlog_id.
    "Delete the entries which are already present in TLOG
    "to get the new entries only
    DELETE lt_ffid_log WHERE tlog_id IS NOT INITIAL.
    SORT lt_ffid_log BY session_id.
    "Get the tcodes used
    LOOP AT lt_ffid_log ASSIGNING FIELD-SYMBOL(<lfs_ffid_log>).
      CLEAR : lr_user.
      lr_user = VALUE #( BASE lr_user (
        low     = <lfs_ffid_log>-ffid
        option  = 'EQ'
        sign    = 'I' )
      ).

      cl_salv_bs_runtime_info=>set(
        EXPORTING
          display  = abap_false
          metadata = abap_false
          data     = abap_true
      ).

      "submit sm20 report
      SUBMIT rsau_read_log WITH strtdate EQ <lfs_ffid_log>-logindt
                          WITH strttime EQ <lfs_ffid_log>-logintm
                          WITH enddate EQ <lfs_ffid_log>-lgoutdt
                          WITH endtime EQ <lfs_ffid_log>-lgouttm
                          WITH user IN lr_user
                          WITH logon EQ abap_false
                          WITH rlogon EQ abap_false
                          WITH rfcstart EQ abap_false
                          WITH tastart EQ abap_true
                          WITH repstart EQ abap_false
                          WITH usermgm EQ abap_false
                          WITH misc EQ abap_false
                          WITH system EQ abap_false AND RETURN .

      cl_salv_bs_runtime_info=>get_data_ref(
        IMPORTING
          r_data_descr = DATA(lo_data_desc) ).
      IF lo_data_desc IS NOT INITIAL.
        CREATE DATA lo_data TYPE HANDLE lo_data_desc.
        ASSIGN lo_data->* TO <fs_data>.
      ENDIF.

      IF <fs_data> IS ASSIGNED.
        cl_salv_bs_runtime_info=>get_data(
          IMPORTING
            t_data = <fs_data> ).
      ENDIF.

      IF <fs_data> IS ASSIGNED AND <fs_data> IS NOT INITIAL.
        APPEND LINES OF <fs_data> TO lt_data.
        SORT lt_data BY param2 DESCENDING.
        DELETE lt_data WHERE param2 IS NOT INITIAL.
        SORT lt_data BY param1.
        DELETE lt_data WHERE param1 EQ 'SESSION_MANAGER'.
        LOOP AT lt_data INTO DATA(ls_data) GROUP BY
          ( param1 = ls_data-param1 ) ASSIGNING FIELD-SYMBOL(<lfs_data>).
          lt_tcode_list = VALUE #( FOR ls_group IN GROUP <lfs_data> ( ls_group ) ).
          DATA(lv_tcode_count) = lines( lt_tcode_list ).
          lt_ffid_tlog = VALUE #( BASE lt_ffid_tlog (
               mandt = sy-mandt
               session_id = <lfs_ffid_log>-session_id
               tcode = <lfs_data>-param1
               times = lv_tcode_count ) ).
          CLEAR : lv_tcode_count,lt_tcode_list.
        ENDLOOP.
      ENDIF.
    ENDLOOP.
    "Modify tlog table
    IF lt_ffid_tlog IS NOT INITIAL.
      MODIFY zacg_ffid_tlog FROM TABLE lt_ffid_tlog.
    ENDIF.
  ENDIF.
ENDFORM.
