*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZACG_AGR_DEFINE.................................*
DATA:  BEGIN OF STATUS_ZACG_AGR_DEFINE               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZACG_AGR_DEFINE               .
CONTROLS: TCTRL_ZACG_AGR_DEFINE
            TYPE TABLEVIEW USING SCREEN '9002'.
*.........table declarations:.................................*
TABLES: *ZACG_AGR_DEFINE               .
TABLES: ZACG_AGR_DEFINE                .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
