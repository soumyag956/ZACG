*&---------------------------------------------------------------------*
*& Include          ZACG_DASHBOARD_S01
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK blk1 WITH FRAME TITLE TEXT-b01.

  PARAMETERS r_user RADIOBUTTON GROUP gr1 DEFAULT 'X'.
  PARAMETERS r_role RADIOBUTTON GROUP gr1.
  SELECT-OPTIONS s_role  FOR v_role.
  SELECT-OPTIONS s_user  FOR v_user.

SELECTION-SCREEN END OF BLOCK blk1.
