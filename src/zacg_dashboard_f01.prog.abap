*&---------------------------------------------------------------------*
*& Include          ZACG_DASHBOARD_F01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form user_critical_authorization
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM user_data_prepare.

  DATA:
    lv_jobname   TYPE  btcjob,
    lv_jobcount  TYPE  btcjobcnt,

    lr_module    TYPE RANGE OF zrisk_proc,

    li_user_role TYPE zacg_t_user_role,
    li_level     TYPE zacg_t_level,
    li_summary   TYPE zacg_t_risk_summary,
    li_dashboard TYPE STANDARD TABLE OF zacg_dashboard.


  CALL FUNCTION 'GET_JOB_RUNTIME_INFO'
    IMPORTING
      jobcount        = lv_jobcount
      jobname         = lv_jobname
    EXCEPTIONS
      no_runtime_info = 1
      OTHERS          = 2.
  IF sy-subrc = 0.

    SELECT a~bname, b~agr_name
      FROM usr02 AS a
      INNER JOIN agr_users AS b
      ON a~bname EQ b~uname
      WHERE a~bname IN @s_user[]
        AND a~gltgv <= @sy-datum
        AND ( a~gltgb >= @sy-datum OR a~gltgb IS INITIAL )
        AND a~ustyp IN ('A','S')
        AND a~uflag IN (0,128)
        AND b~to_dat >= @sy-datum
      INTO TABLE @li_user_role.
    IF li_user_role IS NOT INITIAL.

      CALL FUNCTION 'ZACG_RISK_USERS' DESTINATION 'NONE'
        EXPORTING
          it_user_role    = li_user_role
          iv_summary      = abap_true
          it_level        = li_level
          it_module       = lr_module
          iv_jobname      = lv_jobname
          iv_jobcount     = lv_jobcount
        IMPORTING
          et_risk_summary = li_summary.


      LOOP AT li_summary INTO DATA(lwa_summary).
        APPEND INITIAL LINE TO li_dashboard ASSIGNING FIELD-SYMBOL(<lfs_dashboard>).
        <lfs_dashboard>-jobname   = lv_jobname.
        <lfs_dashboard>-jobcount  = lv_jobcount.
        <lfs_dashboard>-bname     = lwa_summary-user.
        <lfs_dashboard>-risk      = lwa_summary-risk.
        <lfs_dashboard>-riskd     = lwa_summary-riskd.
        <lfs_dashboard>-rlevel    = lwa_summary-level.
        <lfs_dashboard>-leveld    = lwa_summary-leveld.
        <lfs_dashboard>-rtype     = lwa_summary-type.
        <lfs_dashboard>-typed     = lwa_summary-typed.
        <lfs_dashboard>-rmodule   = lwa_summary-module.
        <lfs_dashboard>-moduled   = lwa_summary-moduled.
        <lfs_dashboard>-ernam     = sy-uname.
        <lfs_dashboard>-erdat     = sy-datum.
        <lfs_dashboard>-ertim     = sy-uzeit.
      ENDLOOP.

      IF sy-batch IS NOT INITIAL.
        MODIFY zacg_dashboard FROM TABLE li_dashboard.
      ENDIF.

    ELSE.

      MESSAGE 'No valid user found' TYPE 'S'.

    ENDIF.

  ELSE.

    MESSAGE 'This program is only to be run in background. Kindly user ZACG transaction otherwise' TYPE 'S'.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form role_critical_authorization
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM role_data_prepare.

  DATA:
    lv_jobname   TYPE btcjob,
    lv_jobcount  TYPE btcjobcnt,
    lr_module    TYPE RANGE OF zrisk_proc,
    li_roles     TYPE zt_role,
    li_zroles    TYPE zt_role,
    li_yroles    TYPE zt_role,
    li_agr_agrs  TYPE zt_role,
    li_zagr_agrs TYPE zt_role,
    li_yagr_agrs TYPE zt_role,
    li_level     TYPE zacg_t_level,
    li_summary   TYPE zacg_t_risk_summary,
    li_dashboard TYPE STANDARD TABLE OF zacg_dashboard.

  CALL FUNCTION 'GET_JOB_RUNTIME_INFO'
    IMPORTING
      jobcount        = lv_jobcount
      jobname         = lv_jobname
    EXCEPTIONS
      no_runtime_info = 1
      OTHERS          = 2.
  IF sy-subrc = 0.

    SELECT DISTINCT agr_name
      FROM agr_define
      WHERE agr_name IN @s_role[]
      INTO TABLE @li_roles.
    IF sy-subrc IS INITIAL.

      li_zroles = li_yroles = li_roles.
      DELETE li_zroles WHERE agr_name(1) NE 'Z'.
      DELETE li_yroles WHERE agr_name(1) NE 'Y'.
      CLEAR li_roles.
      APPEND LINES OF li_zroles TO li_roles.
      APPEND LINES OF li_yroles TO li_roles.

      IF li_roles IS NOT INITIAL.
        CLEAR li_summary.
        CALL FUNCTION 'ZACG_RISK_ROLES' DESTINATION 'NONE'
          EXPORTING
            it_role         = li_roles
            iv_summary      = abap_true
            it_level        = li_level
            it_module       = lr_module
          IMPORTING
            et_risk_summary = li_summary.
        LOOP AT li_summary INTO DATA(lwa_summary).
          APPEND INITIAL LINE TO li_dashboard ASSIGNING FIELD-SYMBOL(<lfs_dashboard>).
          <lfs_dashboard>-jobname   = lv_jobname.
          <lfs_dashboard>-jobcount  = lv_jobcount.
          <lfs_dashboard>-agr_name  = lwa_summary-agr_name.
          <lfs_dashboard>-risk      = lwa_summary-risk.
          <lfs_dashboard>-riskd     = lwa_summary-riskd.
          <lfs_dashboard>-rlevel    = lwa_summary-level.
          <lfs_dashboard>-leveld    = lwa_summary-leveld.
          <lfs_dashboard>-rtype     = lwa_summary-type.
          <lfs_dashboard>-typed     = lwa_summary-typed.
          <lfs_dashboard>-rmodule   = lwa_summary-module.
          <lfs_dashboard>-moduled   = lwa_summary-moduled.
          <lfs_dashboard>-ernam     = sy-uname.
          <lfs_dashboard>-erdat     = sy-datum.
          <lfs_dashboard>-ertim     = sy-uzeit.
        ENDLOOP.

      ELSE.
        MESSAGE 'No Single Roles found with Z or Y' TYPE 'S'.
      ENDIF.
    ELSE.
      MESSAGE 'No Single Roles found' TYPE 'S'.
    ENDIF.


    SELECT DISTINCT agr_name
      FROM agr_agrs
      WHERE agr_name IN @s_role[]
        AND attributes = @space
    ORDER BY agr_name
    INTO TABLE @li_agr_agrs.
    IF sy-subrc IS INITIAL.

      li_zagr_agrs = li_yagr_agrs = li_agr_agrs.
      DELETE li_zagr_agrs WHERE agr_name(1) NE 'Z'.
      DELETE li_yagr_agrs WHERE agr_name(1) NE 'Y'.
      CLEAR li_agr_agrs.
      APPEND LINES OF li_zagr_agrs TO li_agr_agrs.
      APPEND LINES OF li_yagr_agrs TO li_agr_agrs.

      IF li_agr_agrs IS NOT INITIAL.

        CLEAR li_summary.
        CALL FUNCTION 'ZACG_RISK_COMPOSITE_ROLES' DESTINATION 'NONE'
          EXPORTING
            it_role         = li_agr_agrs
            iv_summary      = abap_true
            it_level        = li_level
            it_module       = lr_module
          IMPORTING
            et_risk_summary = li_summary.

        LOOP AT li_summary INTO lwa_summary.
          APPEND INITIAL LINE TO li_dashboard ASSIGNING <lfs_dashboard>.
          <lfs_dashboard>-jobname   = lv_jobname.
          <lfs_dashboard>-jobcount  = lv_jobcount.
          <lfs_dashboard>-agr_name  = lwa_summary-composite.
          <lfs_dashboard>-risk      = lwa_summary-risk.
          <lfs_dashboard>-riskd     = lwa_summary-riskd.
          <lfs_dashboard>-rlevel    = lwa_summary-level.
          <lfs_dashboard>-leveld    = lwa_summary-leveld.
          <lfs_dashboard>-rtype     = lwa_summary-type.
          <lfs_dashboard>-typed     = lwa_summary-typed.
          <lfs_dashboard>-rmodule   = lwa_summary-module.
          <lfs_dashboard>-moduled   = lwa_summary-moduled.
          <lfs_dashboard>-ernam     = sy-uname.
          <lfs_dashboard>-erdat     = sy-datum.
          <lfs_dashboard>-ertim     = sy-uzeit.
        ENDLOOP.

      ELSE.

        MESSAGE 'No Composite Roles found with Z or Y' TYPE 'S'.

      ENDIF.

    ELSE.

      MESSAGE 'No Composite Roles' TYPE 'S'.

    ENDIF.

    IF li_dashboard IS NOT INITIAL.
      IF sy-batch IS NOT INITIAL.
        MODIFY zacg_dashboard FROM TABLE li_dashboard.
      ENDIF.
    ENDIF.

  ELSE.

    MESSAGE 'This program is only to be run in background. Kindly user ZACG transaction otherwise' TYPE 'S'.

  ENDIF.



ENDFORM.
