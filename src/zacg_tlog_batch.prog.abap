*&---------------------------------------------------------------------*
*& Report ZACG_TLOG_BATCH
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zacg_tlog_batch.

INCLUDE zacg_tlog_batch_top.
INCLUDE zacg_tlog_batch_f01.

START-OF-SELECTION.

  PERFORM fetch_log_data.
