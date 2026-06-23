*&---------------------------------------------------------------------*
*& Include          ZACG_ROLE_ASSIGNMENT_SEL
*&---------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_user    TYPE bapibname-bapibname,
              p_begda   TYPE begda,
              p_endda   TYPE endda.
  SELECT-OPTIONS: so_role FOR g_role.
SELECTION-SCREEN END OF BLOCK b1.
