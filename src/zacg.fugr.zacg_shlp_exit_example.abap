FUNCTION zacg_shlp_exit_example.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  TABLES
*"      SHLP_TAB TYPE  SHLP_DESCT
*"      RECORD_TAB STRUCTURE  SEAHLPRES
*"  CHANGING
*"     VALUE(SHLP) TYPE  SHLP_DESCR
*"     VALUE(CALLCONTROL) LIKE  DDSHF4CTRL STRUCTURE  DDSHF4CTRL
*"----------------------------------------------------------------------

* EXIT immediately, if you do not want to handle this step
  IF callcontrol-step <> 'SELONE' AND
     callcontrol-step <> 'SELECT' AND
     " AND SO ON
     callcontrol-step <> 'DISP'.
    EXIT.
  ENDIF.

*"----------------------------------------------------------------------
* STEP SELONE  (Select one of the elementary searchhelps)
*"----------------------------------------------------------------------
* This step is only called for collective searchhelps. It may be used
* to reduce the amount of elementary searchhelps given in SHLP_TAB.
* The compound searchhelp is given in SHLP.
* If you do not change CALLCONTROL-STEP, the next step is the
* dialog, to select one of the elementary searchhelps.
* If you want to skip this dialog, you have to return the selected
* elementary searchhelp in SHLP and to change CALLCONTROL-STEP to
* either to 'PRESEL' or to 'SELECT'.
  IF callcontrol-step = 'SELONE'.
*   PERFORM SELONE .........
    EXIT.
  ENDIF.

*"----------------------------------------------------------------------
* STEP PRESEL  (Enter selection conditions)
*"----------------------------------------------------------------------
* This step allows you, to influence the selection conditions either
* before they are displayed or in order to skip the dialog completely.
* If you want to skip the dialog, you should change CALLCONTROL-STEP
* to 'SELECT'.
* Normaly only SHLP-SELOPT should be changed in this step.
  IF callcontrol-step = 'PRESEL'.
*   PERFORM PRESEL ..........
    EXIT.
  ENDIF.
*"----------------------------------------------------------------------
* STEP SELECT    (Select values)
*"----------------------------------------------------------------------
* This step may be used to overtake the data selection completely.
* To skip the standard seletion, you should return 'DISP' as following
* step in CALLCONTROL-STEP.
* Normally RECORD_TAB should be filled after this step.
* Standard function module F4UT_RESULTS_MAP may be very helpfull in this
* step.
  IF callcontrol-step = 'SELECT'.
*   PERFORM STEP_SELECT TABLES RECORD_TAB SHLP_TAB
*                       CHANGING SHLP CALLCONTROL RC.
*   IF RC = 0.
*     CALLCONTROL-STEP = 'DISP'.
*   ELSE.
*     CALLCONTROL-STEP = 'EXIT'.
*   ENDIF.
    EXIT. "Don't process STEP DISP additionally in this call.
  ENDIF.
*"----------------------------------------------------------------------
* STEP DISP     (Display values)
*"----------------------------------------------------------------------
* This step is called, before the selected data is displayed.
* You can e.g. modify or reduce the data in RECORD_TAB
* according to the users authority.
* If you want to get the standard display dialog afterwards, you
* should not change CALLCONTROL-STEP.
* If you want to overtake the dialog on you own, you must return
* the following values in CALLCONTROL-STEP:
* - "RETURN" if one line was selected. The selected line must be
*   the only record left in RECORD_TAB. The corresponding fields of
*   this line are entered into the screen.
* - "EXIT" if the values request should be aborted
* - "PRESEL" if you want to return to the selection dialog
* Standard function modules F4UT_PARAMETER_VALUE_GET and
* F4UT_PARAMETER_RESULTS_PUT may be very helpfull in this step.
  IF callcontrol-step = 'DISP'.
    SORT record_tab[].
    DELETE ADJACENT DUPLICATES FROM record_tab[].
*** Start of Change Rounak
    DATA : lt_req_aprover  TYPE TABLE OF zacg_req_aprover,
           lwa_req_aprover TYPE zacg_req_aprover.

*    lt_req_aprover = VALUE #( FOR lwa_record IN record_tab
*                              ( req_no = lwa_record-string ) ).

    LOOP AT record_tab INTO DATA(lwa_record).
      CONDENSE lwa_record-string NO-GAPS.
      lwa_req_aprover-req_no = lwa_record-string.
      APPEND lwa_req_aprover TO lt_req_aprover.
      CLEAR : lwa_req_aprover.
    ENDLOOP.

    SELECT req_no,
           child_req_no
    FROM zacg_req_blk_map
    INTO TABLE @DATA(li_req_blk_map)
    FOR ALL ENTRIES IN @lt_req_aprover
    WHERE child_req_no = @lt_req_aprover-req_no.
    IF sy-subrc IS INITIAL.
      SORT li_req_blk_map BY child_req_no.
      LOOP AT record_tab ASSIGNING FIELD-SYMBOL(<lfs_record_tab>).
        DATA(lv_child_req) = <lfs_record_tab>-string.
        CONDENSE lv_child_req NO-GAPS.
        READ TABLE li_req_blk_map INTO DATA(lwa_req_blk_map)
             WITH KEY child_req_no = lv_child_req BINARY SEARCH.
        IF sy-subrc IS INITIAL.
*** Add 3 spaces
          <lfs_record_tab>-string = |   { lwa_req_blk_map-req_no }| .
        ENDIF.
      ENDLOOP.
    ENDIF.

    SORT record_tab[].
    DELETE ADJACENT DUPLICATES FROM record_tab[].
*** End of Change Rounak
*   PERFORM AUTHORITY_CHECK TABLES RECORD_TAB SHLP_TAB
*                           CHANGING SHLP CALLCONTROL.
    EXIT.
  ENDIF.
ENDFUNCTION.
