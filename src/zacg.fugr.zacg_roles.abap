FUNCTION zacg_roles.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IT_ROLE) TYPE  ZACG_T_ROLE
*"     VALUE(IV_SUMMARY) TYPE  FLAG OPTIONAL
*"     VALUE(IV_DETAIL) TYPE  FLAG OPTIONAL
*"     VALUE(IT_LEVEL) TYPE  ZACG_T_LEVEL OPTIONAL
*"     VALUE(IT_MODULE) TYPE  ZACG_T_MODULE OPTIONAL
*"  EXPORTING
*"     VALUE(ET_RISK_SUMMARY) TYPE  ZACG_T_RISK_SUMMARY
*"     VALUE(ET_RISK_DETAIL) TYPE  ZACG_T_RISK_DETAIL
*"----------------------------------------------------------------------


  DATA :
    li_summary TYPE zacg_t_risk_summary,
    li_detail  TYPE zacg_t_risk_detail.

  CLEAR: et_risk_summary, et_risk_detail.

  LOOP AT it_role INTO DATA(lwa_role).

    CLEAR: li_summary, li_detail.

    DATA(lv_text) = |Processing{ lwa_role-low }|.

    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING
        text = lv_text.

    CALL FUNCTION 'ZACG_ROLE'
      EXPORTING
        iv_role         = lwa_role-low
        iv_summary      = iv_summary
        iv_detail       = iv_detail
        it_level        = it_level
        it_module       = it_module
      IMPORTING
        et_risk_summary = li_summary
        et_risk_detail  = li_detail.

    APPEND LINES OF li_summary  TO et_risk_summary.
    APPEND LINES OF li_detail   TO et_risk_detail.


  ENDLOOP.


ENDFUNCTION.
