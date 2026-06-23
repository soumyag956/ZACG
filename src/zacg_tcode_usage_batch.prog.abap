*&---------------------------------------------------------------------*
*& Report ZACG_TCODE_USAGE_BATCH
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zacg_tcode_usage_batch.

TYPES: BEGIN OF lty_user_tcode,
         mandt    TYPE mandt,
         slguser  TYPE xubname,
         sal_date TYPE datum,
         tcode    TYPE tcode,
         times    TYPE i,
       END OF lty_user_tcode.


DATA: lv_start_date TYPE datum,
      lv_end_date   TYPE datum,
      lv_start_time TYPE uzeit,
      lv_end_time   TYPE uzeit,
      lv_max_date   TYPE begda,
      lv_dlydy      TYPE dlydy,
      lv_dlymo      TYPE dlymo,
      lv_dlyyr      TYPE dlyyr VALUE '01',

      lt_data       TYPE STANDARD TABLE OF rsau_s_result,
      lt_user_tcode TYPE STANDARD TABLE OF lty_user_tcode,
      lt_tusg_dlog  TYPE STANDARD TABLE OF zacg_tusg_dlog,

      lr_user       TYPE RANGE OF rslguser,
      lr_slguser    TYPE RANGE OF xubname,
      lr_tcode      TYPE RANGE OF tcode,

      lo_data       TYPE REF TO data.

FIELD-SYMBOLS : <lfs_data> TYPE ANY TABLE.

PARAMETERS: p_date TYPE datum.

IF p_date IS INITIAL.
  p_date = sy-datum.
ENDIF.

lv_start_date = lv_end_date = p_date - 1.
lv_end_time   = '235959'.

CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
  EXPORTING
    date      = sy-datum
    days      = lv_dlydy
    months    = lv_dlymo
    signum    = '-'
    years     = lv_dlyyr
  IMPORTING
    calc_date = lv_max_date.

DELETE FROM zacg_tusg_dlog WHERE sal_date LT lv_max_date.
COMMIT WORK AND WAIT.

cl_salv_bs_runtime_info=>set(
  EXPORTING
    display  = abap_false
    metadata = abap_false
    data     = abap_true ).

SUBMIT rsau_read_log
  WITH strtdate EQ lv_start_date
  WITH strttime EQ lv_start_time
  WITH enddate  EQ lv_end_date
  WITH endtime  EQ lv_end_time
  WITH user     IN lr_user
  WITH logon    EQ abap_false
  WITH rlogon   EQ abap_false
  WITH rfcstart EQ abap_false
  WITH tastart  EQ abap_true
  WITH repstart EQ abap_false
  WITH usermgm  EQ abap_false
  WITH misc     EQ abap_false
  WITH system   EQ abap_false
  AND RETURN.

cl_salv_bs_runtime_info=>get_data_ref(
  IMPORTING
    r_data_descr = DATA(lo_data_desc) ).
IF lo_data_desc IS NOT INITIAL.
  CREATE DATA lo_data TYPE HANDLE lo_data_desc.
  ASSIGN lo_data->* TO <lfs_data>.
ENDIF.

IF <lfs_data> IS ASSIGNED.
  cl_salv_bs_runtime_info=>get_data(
    IMPORTING
      t_data = <lfs_data> ).

  APPEND LINES OF <lfs_data> TO lt_data.
  SORT lt_data BY param2 DESCENDING.
  DELETE lt_data WHERE param2 IS NOT INITIAL.
  SORT lt_data BY param1.
  DELETE lt_data WHERE param1 EQ 'SESSION_MANAGER'.

  lr_slguser = VALUE #( FOR ls_user IN lt_data (
                        sign    = 'I'
                        option  = 'EQ'
                        low     = ls_user-slguser )
                       ).
  SORT lr_slguser BY low.
  DELETE ADJACENT DUPLICATES FROM lr_slguser COMPARING low.

  LOOP AT lt_data INTO DATA(ls_data).
    APPEND INITIAL LINE TO lt_user_tcode ASSIGNING FIELD-SYMBOL(<lfs_user_tcode>).
    <lfs_user_tcode>-mandt      = sy-mandt.
    <lfs_user_tcode>-sal_date   = lv_start_date.
    <lfs_user_tcode>-slguser    = ls_data-slguser.
    <lfs_user_tcode>-tcode      = ls_data-param1.
  ENDLOOP.


  SELECT mandt AS mandt, slguser, sal_date, tcode,
    COUNT( tcode ) AS times
    FROM @lt_user_tcode AS lt_data1
    GROUP BY mandt, slguser, sal_date, tcode
  INTO TABLE @lt_tusg_dlog.

  IF lt_tusg_dlog IS NOT INITIAL.
    MODIFY zacg_tusg_dlog FROM TABLE lt_tusg_dlog.
    COMMIT WORK AND WAIT.
  ENDIF.

ENDIF.
