FUNCTION zacg_users_roles_set.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IT_USERS) TYPE  ZACG_T_USER_SET
*"     VALUE(IT_LEVEL) TYPE  ZACG_T_LEVEL OPTIONAL
*"     VALUE(IT_MODULE) TYPE  ZACG_T_MODULE OPTIONAL
*"     VALUE(IV_SUMMARY) TYPE  FLAG OPTIONAL
*"     VALUE(IV_DETAIL) TYPE  FLAG OPTIONAL
*"     VALUE(IV_LOCAL) TYPE  FLAG OPTIONAL
*"     VALUE(IV_RUNID) TYPE  SYSUUID_X OPTIONAL
*"     VALUE(IV_FULLPATH) TYPE  STRING OPTIONAL
*"     VALUE(IV_FILECOUNT) TYPE  I OPTIONAL
*"     VALUE(IV_JOBNAME) TYPE  BTCJOB OPTIONAL
*"     VALUE(IV_JOBCOUNT) TYPE  BTCJOBCNT OPTIONAL
*"  EXPORTING
*"     VALUE(ET_RISK_SUMMARY) TYPE  ZACG_T_RISK_SUMMARY
*"     VALUE(ET_RISK_DETAIL) TYPE  ZACG_T_RISK_DETAIL
*"     VALUE(EV_FILE) TYPE  FLAG
*"     VALUE(EV_FILECOUNT) TYPE  I
*"     VALUE(EV_JOBNAME) TYPE  BTCJOB
*"     VALUE(EV_JOBCOUNT) TYPE  BTCJOBCNT
*"----------------------------------------------------------------------

  DATA:

    lv_fullpath     TYPE string,
    lv_xml          TYPE string,
    lv_length       TYPE i,

    lw_srole_dtl    TYPE zacg_srole_dtl,

    lr_users        TYPE RANGE OF xubname,

    li_fcat         TYPE lvc_t_fcat,
    li_user         TYPE zacg_t_user_set,
    li_risk_summary TYPE zacg_t_risk_summary,
    li_risk_detail  TYPE zacg_t_risk_detail,
    li_user_detail  TYPE STANDARD TABLE OF zacg_user_detail.


  CLEAR: et_risk_summary, et_risk_detail, ev_file.

  lr_users = VALUE #( FOR lwa_users IN it_users ( low = lwa_users-bname sign = 'I' option = 'EQ' ) ).
  SORT lr_users BY low.
  DELETE ADJACENT DUPLICATES FROM lr_users COMPARING low.

  LOOP AT lr_users INTO DATA(ls_users).

    CLEAR : li_risk_summary, li_risk_detail, li_user.

    SELECT *
      FROM @it_users AS single_user
      WHERE bname EQ @ls_users-low
    INTO TABLE @li_user.

    CALL FUNCTION 'ZACG_USER_ROLES'
      EXPORTING
        it_users        = li_user
        it_level        = it_level
        it_module       = it_module
        iv_summary      = iv_summary
        iv_detail       = iv_detail
      IMPORTING
        et_risk_summary = li_risk_summary
        et_risk_detail  = li_risk_detail.

    IF iv_local IS INITIAL. " When detail data is not asked to save locally in excel

      cl_abap_memory_utilities=>get_total_used_size(
        IMPORTING
          size = DATA(ltp_size)                " Memory Size in Bytes
      ).

      IF iv_jobname IS INITIAL.
        IF ltp_size GE v_max_usr_memory.
          ev_file    = abap_true.
        ENDIF.
      ENDIF.


      IF ev_file IS NOT INITIAL.
        EXIT.
      ELSE.
        APPEND LINES OF li_risk_summary TO et_risk_summary.
        APPEND LINES OF li_risk_detail TO et_risk_detail.
      ENDIF.

    ELSE. " When details are asked to be stored locally in excel

      CLEAR li_risk_summary.
      LOOP AT li_risk_detail INTO DATA(lwa_risk_detail).
        APPEND INITIAL LINE TO li_user_detail ASSIGNING FIELD-SYMBOL(<lfs_user_detail>).
        <lfs_user_detail>-runid       = iv_runid.
        <lfs_user_detail>-bname       = lwa_risk_detail-user.
        <lfs_user_detail>-composite   = lwa_risk_detail-composite.
        <lfs_user_detail>-agr_name    = lwa_risk_detail-agr_name.
        <lfs_user_detail>-risk        = lwa_risk_detail-risk.
        <lfs_user_detail>-riskd       = lwa_risk_detail-riskd.
        <lfs_user_detail>-func        = lwa_risk_detail-func.
        <lfs_user_detail>-funcd       = lwa_risk_detail-funcd.
        <lfs_user_detail>-tcode       = lwa_risk_detail-tcode.
        <lfs_user_detail>-object      = lwa_risk_detail-object.
        <lfs_user_detail>-field       = lwa_risk_detail-field.
        <lfs_user_detail>-low         = lwa_risk_detail-low.
      ENDLOOP.
      CLEAR li_risk_detail.
      MODIFY zacg_user_detail FROM TABLE li_user_detail.
      CLEAR li_user_detail.


    ENDIF.


  ENDLOOP.

  ev_jobname  = iv_jobname.
  ev_jobcount = iv_jobcount.


ENDFUNCTION.
