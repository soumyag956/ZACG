FUNCTION zacg_composite_roles.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IT_COMP_SET) TYPE  ZACG_T_COMP_SET
*"     VALUE(IT_LEVEL) TYPE  ZACG_T_LEVEL OPTIONAL
*"     VALUE(IT_MODULE) TYPE  ZACG_T_MODULE OPTIONAL
*"     VALUE(IV_SUMMARY) TYPE  FLAG OPTIONAL
*"     VALUE(IV_DETAIL) TYPE  FLAG OPTIONAL
*"     VALUE(IV_JOBNAME) TYPE  BTCJOB OPTIONAL
*"     VALUE(IV_JOBCOUNT) TYPE  BTCJOBCNT OPTIONAL
*"  EXPORTING
*"     VALUE(ET_RISK_SUMMARY) TYPE  ZACG_T_RISK_SUMMARY
*"     VALUE(ET_RISK_DETAIL) TYPE  ZACG_T_RISK_DETAIL
*"     VALUE(EV_FILE) TYPE  FLAG
*"----------------------------------------------------------------------

  DATA:
    lr_set           TYPE RANGE OF i,
    lr_comp          TYPE RANGE OF agr_name,
    lr_role          TYPE RANGE OF agr_name,
    lit_role_set     TYPE zacg_t_comp_set,
    lit_risk_summary TYPE zacg_t_risk_summary,
    lit_risk_detail  TYPE zacg_t_risk_detail.

  CLEAR: et_risk_summary[], et_risk_detail[].

  lr_set = VALUE #( FOR ls_set IN it_comp_set ( sign = 'I' option = 'EQ' low = ls_set-setno ) ).
  SORT lr_set BY low.
  DELETE ADJACENT DUPLICATES FROM lr_set COMPARING low.

  LOOP AT lr_set INTO DATA(lwa_set).

    SELECT *
      FROM @it_comp_set AS comp_set
      WHERE setno = @lwa_set-low
    INTO TABLE @DATA(lit_comp_set).

    lr_comp = VALUE #( FOR ls_comp IN lit_comp_set ( sign = 'I' option = 'EQ' low = ls_comp-agr_name ) ).
    SORT lr_comp BY low.
    DELETE ADJACENT DUPLICATES FROM lr_comp COMPARING low.

    LOOP AT lr_comp INTO DATA(lwa_comp).

      SELECT *
        FROM @lit_comp_set AS comp_set
        WHERE agr_name = @lwa_comp-low
        INTO TABLE @lit_role_set.

      lr_role = VALUE #( FOR ls_role IN lit_role_set ( sign = 'I' option = 'EQ' low = ls_role-child_agr ) ).
      SORT lr_role BY low.
      DELETE ADJACENT DUPLICATES FROM lr_role COMPARING low.

      CALL FUNCTION 'ZACG_COMPOSITE_ROLES_SET'
        EXPORTING
          it_comp         = lit_role_set
          it_level        = it_level
          it_module       = it_module
          iv_summary      = iv_summary
          iv_detail       = iv_detail
        IMPORTING
          et_risk_summary = lit_risk_summary
          et_risk_detail  = lit_risk_detail.
      APPEND LINES OF lit_risk_summary TO et_risk_summary[].
      APPEND LINES OF lit_risk_detail  TO et_risk_detail[].
      CLEAR: lit_risk_summary, lit_risk_detail.

    ENDLOOP.

  ENDLOOP.


ENDFUNCTION.
