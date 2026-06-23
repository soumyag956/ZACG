*&---------------------------------------------------------------------*
*& Report ZACG_DASHBOARD
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zacg_dashboard.

INCLUDE zacg_dashboard_top.
INCLUDE zacg_dashboard_s01.
INCLUDE zacg_dashboard_f01.


START-OF-SELECTION.

  IF sy-batch IS NOT INITIAL.
    v_date = sy-datum - 5.
    DELETE FROM zacg_dashboard WHERE erdat LE v_date.
  ENDIF.

  IF r_user IS NOT INITIAL.

    PERFORM user_data_prepare.

  ELSEIF r_role IS NOT INITIAL.

    PERFORM role_data_prepare.

  ENDIF.
