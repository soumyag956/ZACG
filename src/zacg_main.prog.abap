*&---------------------------------------------------------------------*
*& Report ZACG_MAIN
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zacg_main.

CLASS lcl_acg DEFINITION DEFERRED.

INCLUDE zacg_maintop.
INCLUDE zacg_mains01.
INCLUDE zacg_maindef.
INCLUDE zacg_mainimp.
INCLUDE zacg_maino01.
INCLUDE zacg_maini01.
INCLUDE zacg_mainf01.
INCLUDE zacg_mainh01.

INITIALIZATION.

  rsimfrmt = 'Download Format'.
  rexecute = 'Execute'.
  usimfrmt = 'Download Format'.
  uexecute = 'Execute'.

AT SELECTION-SCREEN OUTPUT.
  PERFORM screen_modification.

AT SELECTION-SCREEN.
  g_ucomm = sy-ucomm.

START-OF-SELECTION.
  CREATE OBJECT o_acg.
  SET SCREEN 1000.
