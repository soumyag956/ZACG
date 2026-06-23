*&---------------------------------------------------------------------*
*& Include          ZACG_ROLE_ASSIGNMENT_F01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form assign_roles
*&---------------------------------------------------------------------*
*& Assigns the roles entered in select-option SO_ROLE to the user
*& P_USER for the validity period P_BEGDA..P_ENDDA.
*&
*& The user's existing role assignments are first read with
*& BAPI_USER_GET_DETAIL and the new roles are appended to them so that
*& current assignments are preserved. The combined list is then written
*& back with BAPI_USER_ACTGROUPS_ASSIGN and committed.
*&
*& Result messages (BAPIRET2) are returned in the global table
*& GT_ROLE_OUTPUT for display by FORM display_alv.
*&---------------------------------------------------------------------*
FORM assign_roles .
  DATA: ls_act_ad TYPE bapiagr,
        lt_act    TYPE STANDARD TABLE OF bapiagr,
        lt_act_ad TYPE STANDARD TABLE OF bapiagr,
        lt_ret1   TYPE STANDARD TABLE OF bapiret2,
        lt_ret2   TYPE STANDARD TABLE OF bapiret2.

  LOOP AT so_role.
    ls_act_ad-agr_name = so_role-low.
    ls_act_ad-from_dat = p_begda.
    ls_act_ad-to_dat   = p_endda.
    APPEND ls_act_ad TO lt_act_ad.
    CLEAR ls_act_ad.
  ENDLOOP.

  CALL FUNCTION 'BAPI_USER_GET_DETAIL'
    EXPORTING
      username       = p_user
    TABLES
      activitygroups = lt_act
      return         = lt_ret1.
  IF lt_ret1 IS NOT INITIAL AND lt_ret1[ 1 ]-type = 'E'.
    gt_role_output = lt_ret1.
  ELSE.
    APPEND LINES OF lt_act_ad TO lt_act.
    CALL FUNCTION 'BAPI_USER_ACTGROUPS_ASSIGN'
      EXPORTING
        username       = p_user
      TABLES
        activitygroups = lt_act
        return         = lt_ret2.

*   BAPI_USER_ACTGROUPS_ASSIGN does not commit on its own; without this
*   the assignment is not persisted.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.

    gt_role_output = lt_ret2.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& Displays the role-assignment result messages collected in
*& GT_ROLE_OUTPUT as a simple ALV grid (CL_SALV_TABLE). Any SALV
*& exception is caught and its text stored in lv_message.
*&---------------------------------------------------------------------*
FORM display_alv .
  DATA: lo_alv           TYPE REF TO cl_salv_table.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_role_output ).
      IF lo_alv IS BOUND.
        lo_alv->display( ).
      ENDIF.
    CATCH cx_salv_msg cx_salv_not_found cx_salv_data_error INTO DATA(lo_exp).
      DATA(lv_message) = lo_exp->get_text( ).
  ENDTRY.
ENDFORM.
