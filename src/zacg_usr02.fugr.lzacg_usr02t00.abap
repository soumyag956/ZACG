*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZACG_USR02......................................*
DATA:  BEGIN OF STATUS_ZACG_USR02                    .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZACG_USR02                    .
CONTROLS: TCTRL_ZACG_USR02
            TYPE TABLEVIEW USING SCREEN '9001'.
*.........table declarations:.................................*
TABLES: *ZACG_USR02                    .
TABLES: ZACG_USR02                     .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
