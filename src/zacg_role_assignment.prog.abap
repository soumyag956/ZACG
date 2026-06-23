*&---------------------------------------------------------------------*
*& Report ZACG_ROLE_ASSIGNMENT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zacg_role_assignment.

INCLUDE zacg_role_assignment_top.
INCLUDE zacg_role_assignment_sel.
INCLUDE zacg_role_assignment_f01.

START-OF-SELECTION.
  PERFORM assign_roles.
  IF gt_role_output IS NOT INITIAL.
    PERFORM display_alv.
  ENDIF.
