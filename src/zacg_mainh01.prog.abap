*&---------------------------------------------------------------------*
*& Include          ZACG_MAINH01
*&---------------------------------------------------------------------*



AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM select_file CHANGING p_file.


AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file2.
  PERFORM select_file CHANGING p_file2.


AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_rfile.
  PERFORM select_file CHANGING p_rfile.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_ufile.
  PERFORM select_file CHANGING p_ufile.
