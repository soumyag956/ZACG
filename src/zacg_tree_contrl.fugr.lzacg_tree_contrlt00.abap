*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZACG_TREE_CONTRL................................*
DATA:  BEGIN OF STATUS_ZACG_TREE_CONTRL              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZACG_TREE_CONTRL              .
CONTROLS: TCTRL_ZACG_TREE_CONTRL
            TYPE TABLEVIEW USING SCREEN '9001'.
*.........table declarations:.................................*
TABLES: *ZACG_TREE_CONTRL              .
TABLES: ZACG_TREE_CONTRL               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
