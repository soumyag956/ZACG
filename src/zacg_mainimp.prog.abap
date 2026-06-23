*&---------------------------------------------------------------------*
*& Include          ZACG_MAINIMP
*&---------------------------------------------------------------------*

CLASS lcl_acg IMPLEMENTATION.


  METHOD constructor.

*   Initialize
    v_repid = sy-repid.
    v_dynnr = sy-dynnr.


*   Create the containers
    "docking container on the left for splitter
    CREATE OBJECT o_docking
      EXPORTING
        repid                       = v_repid
        dynnr                       = v_dynnr
        side                        = cl_gui_docking_container=>dock_at_left
        extension                   = 300
        ratio                       = 25
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 99.
    IF sy-subrc <> 0.
    ENDIF.

    "splitter control for toolbar, tree(s) and picture
    CREATE OBJECT o_splitter
      EXPORTING
        parent            = o_docking
        rows              = 1
        columns           = 1
        width             = 100
      EXCEPTIONS
        cntl_error        = 1
        cntl_system_error = 2
        OTHERS            = 99.
    IF sy-subrc <> 0.
    ENDIF.

    CALL METHOD o_splitter->get_container
      EXPORTING
        row       = 1
        column    = 1
      RECEIVING
        container = o_treecontent_cont
      EXCEPTIONS
        OTHERS    = 99.
    IF sy-subrc <> 0.
    ENDIF.


    "first container of splitter (for toolbar) not resizeable
    CALL METHOD o_splitter->set_row_sash
      EXPORTING
        id                = 1
        type              = o_splitter->type_movable
        value             = o_splitter->false
      EXCEPTIONS
        cntl_error        = 1
        cntl_system_error = 2
        OTHERS            = 99.
    IF sy-subrc <> 0.
    ENDIF.

    "size of upper part shall be set in absolute values (toolbar)
    CALL METHOD o_splitter->set_row_mode
      EXPORTING
        mode              = 0
      EXCEPTIONS
        cntl_error        = 1
        cntl_system_error = 2
        OTHERS            = 99.
    IF sy-subrc <> 0.
    ENDIF.

    CALL METHOD o_splitter->set_row_height
      EXPORTING
        id                = 1
        height            = 30
      EXCEPTIONS
        cntl_error        = 1
        cntl_system_error = 2
        OTHERS            = 99.
    IF sy-subrc <> 0.
    ENDIF.

    o_splitter->set_alignment( alignment = o_splitter->align_at_bottom ).

    "no borders (splitter)
    CALL METHOD o_splitter->set_border
      EXPORTING
        border            = cl_gui_cfw=>false
      EXCEPTIONS
        cntl_error        = 1
        cntl_system_error = 2
        OTHERS            = 99.
    IF sy-subrc <> 0.
    ENDIF.

*   create tree(s)
    CREATE OBJECT o_tree_content
      EXPORTING
        parent = o_treecontent_cont.
    IF sy-subrc <> 0.
    ENDIF.

    "initial size of last splitter container: small (no contents?)
    CALL METHOD o_splitter->set_row_height
      EXPORTING
        id                = 3
        height            = 100
      EXCEPTIONS
        cntl_error        = 1
        cntl_system_error = 2
        OTHERS            = 99.
    IF sy-subrc <> 0.
    ENDIF.


  ENDMETHOD.

ENDCLASS.

CLASS lcl_acg_tree IMPLEMENTATION.

  METHOD constructor.

    DATA: li_event TYPE cntl_simple_events,
          lw_event TYPE cntl_simple_event.


    CREATE OBJECT o_tree
      EXPORTING
        parent                      = parent
        node_selection_mode         = cl_gui_simple_tree=>node_sel_mode_single
      EXCEPTIONS
        lifetime_error              = 1
        cntl_system_error           = 2
        create_error                = 3
        failed                      = 4
        illegal_node_selection_mode = 5
        OTHERS                      = 99.
    IF sy-subrc <> 0.
    ENDIF.



    me->build_tree( ).

    lw_event-eventid    = cl_gui_simple_tree=>eventid_node_double_click.
    lw_event-appl_event = abap_true.
    APPEND lw_event TO li_event.

    CALL METHOD o_tree->set_registered_events
      EXPORTING
        events                    = li_event
      EXCEPTIONS
        cntl_error                = 1
        cntl_system_error         = 2
        illegal_event_combination = 3
        OTHERS                    = 99.
    IF sy-subrc <> 0.
    ENDIF.

    SET HANDLER handle_node_double_click FOR o_tree.

    o_tree->expand_root_nodes( ).

  ENDMETHOD.

  METHOD build_tree.

    PERFORM fill_node CHANGING li_node_table.

    CALL METHOD o_tree->add_nodes
      EXPORTING
        table_structure_name           = 'SAPWLTREEN'
        node_table                     = li_node_table
      EXCEPTIONS
        failed                         = 1
        error_in_node_table            = 2
        dp_error                       = 3
        table_structure_name_not_found = 4
        OTHERS                         = 5.
    IF sy-subrc <> 0.
    ENDIF.


  ENDMETHOD.

  METHOD handle_node_double_click.

    DATA:
      lv_dynnr       TYPE sy-dynnr,
      lv_fiori_url   TYPE string,
      lv_host        TYPE string,
      lv_protocol    TYPE string,
      lv_port        TYPE string,
      lv_app_name    TYPE string VALUE 'zsecdashboard',
      lv_full_url    TYPE string,
      lo_http_server TYPE REF TO if_http_server.

    lv_dynnr = g_subscr_nr.

    CASE node_key.
      WHEN 'RLRA'. " Role Level Risk Analysis
        lv_dynnr = 9001.
      WHEN 'ULRA'. " User Level Risk Analysis
        lv_dynnr = 9002.
      WHEN 'DASH'.

        CALL FUNCTION 'CALL_BROWSER'
          EXPORTING
            url                    = 'http://s4hananewgrc.pwcglb.com:8000/sap/bc/ui5_ui5/sap/zacgdashboard/index.html?sap-client=010'
            new_window             = abap_true
          EXCEPTIONS
            frontend_not_supported = 1
            frontend_error         = 2
            prog_not_found         = 3
            no_batch               = 4
            unspecified_error      = 5
            OTHERS                 = 6.
        IF sy-subrc <> 0.
* Implement suitable error handling here
        ENDIF.

      WHEN 'MUCR'. " User Creation (Mass)
        lv_dynnr = 9006.
      WHEN 'RPWD'. " Password Set/Reset
        lv_dynnr = 9007.
      WHEN 'LUSR'. " Lock User
        lv_dynnr = 9008.
      WHEN 'PPWD'. " Set Productive Password
        lv_dynnr = 9009.
      WHEN 'USPD'. " Update user details
        lv_dynnr = 9010.
      WHEN 'UROL'. " Role Assignment/Removal
        lv_dynnr = 9020.
      WHEN 'DROL'. " Role Description Change
        lv_dynnr = 9011.
      WHEN 'DRLC'. " Derive Role Creation
        lv_dynnr = 9012.
      WHEN 'DINR'. " Delete Inheritance
        lv_dynnr = 9013.
      WHEN 'ADDR'. " Add Single Role to Composite Role
        lv_dynnr = 9014.
      WHEN 'RMVR'. " Remove Single from Composite
        lv_dynnr = 9015.
      WHEN 'DELR'. " Delete Roles
        lv_dynnr = 9016.
      WHEN 'PSHR'. " Master Role Pushing
        lv_dynnr = 9017.
      WHEN 'CCRL'. " Create Composite Role( Blank )
        lv_dynnr = 9018.
      WHEN 'CROL'. " Create Single Role (by Copying)
        lv_dynnr = 9019.
      WHEN 'AVAL'. " Mass Maintenance of Authorization Values
        lv_dynnr = 9024.
      WHEN 'MUSR'. " Monitor Standard Users
        lv_dynnr = 9021.
      WHEN 'UMBS'. " User Modification by Self
        lv_dynnr = 9022.
      WHEN 'PUSR'.  " List of Users for Standard Profile
        lv_dynnr = 9023.
      WHEN 'DCDR'. " Direct Change in Derive Role
        lv_dynnr = 9025.
      WHEN 'ORGL'. " Direct Change in Org Level Fields
        lv_dynnr = 9026.
      WHEN 'CUFR'. " Create User(s) from Reference
        lv_dynnr = 9027.
      WHEN 'CDFU'. " Change Document for User
        lv_dynnr = 9028.
      WHEN 'NREQ'. " Role Request
        lv_dynnr = 9029.
      WHEN 'BREQ'. " Role Request in Bulk
        lv_dynnr = 9030.
      WHEN 'SREQ'. " Search Request
        lv_dynnr = 9031.
      WHEN 'FFID'. " Emergency Login
        lv_dynnr = 9033.
      WHEN 'FLOG'. " Emergency Login Report
        lv_dynnr = 9034.
      WHEN 'RFDM'. " Emergency Report for admin
        lv_dynnr = 9035.
      WHEN 'TUSG'. " Transactional Usage
        lv_dynnr = 9036.
      WHEN 'ADRQ'. " Admin Role Request
        lv_dynnr = 9037.
      WHEN 'FUEU'. " FUE for User
        lv_dynnr = 9041.
      WHEN 'FUER'. " FUE for Role
        lv_dynnr = 9042.

    ENDCASE.

    g_subscr_nr = lv_dynnr.

  ENDMETHOD.


ENDCLASS.

CLASS lcl_event_receiver IMPLEMENTATION.

  METHOD on_double_click.

  ENDMETHOD.

  METHOD handle_top_of_page_8001.
    PERFORM handle_top_of_page_8001.
  ENDMETHOD.

  METHOD handle_top_of_page_8002.
    PERFORM handle_top_of_page_8002.
  ENDMETHOD.

  METHOD handle_top_of_page_8003.
    PERFORM handle_top_of_page_8003.
  ENDMETHOD.

  METHOD handle_top_of_page_8004.
    PERFORM handle_top_of_page_8004.
  ENDMETHOD.

  METHOD handle_top_of_page_8005.
    PERFORM handle_top_of_page_8005.
  ENDMETHOD.

  METHOD handle_top_of_page_8006.
    PERFORM handle_top_of_page_8006.
  ENDMETHOD.

  METHOD handle_toolbar.
    PERFORM handle_toolbar USING e_object e_interactive.
  ENDMETHOD .

  METHOD handle_user_command.
    CASE e_ucomm.
      WHEN 'LDWD'.
        IF sy-dynnr = 8001.
          PERFORM download_8001.
        ELSEIF sy-dynnr = 8002.
          PERFORM download_8002.
        ELSEIF sy-dynnr = 8003.
          PERFORM download_8003.
        ELSEIF sy-dynnr = 8004.
          PERFORM download_8004.
        ENDIF.
      WHEN 'ALLR'.
        i_outtab_6001 = i_outtab_9042_s3.
        CALL SCREEN 6001.
    ENDCASE.

  ENDMETHOD.

  METHOD handle_hot_spot.
    CASE g_subscr_nr.
      WHEN 9035.
        IF e_column_id-fieldname = 'FRSN'.
          PERFORM display_ffid_login_reason USING e_row_id.
        ELSEIF e_column_id-fieldname = 'ASSMNTDTL'.
          PERFORM display_ffid_assessment USING e_row_id.
        ENDIF.
      WHEN 9042.
        IF e_row_id-index = 1.
          i_outtab_8008 = i_outtab_9042_s2.

          CASE e_column_id-fieldname.
            WHEN 'GB_ADVANCE'.
              DELETE i_outtab_8008 WHERE priority NE 1.
            WHEN 'GC_CORE'.
              DELETE i_outtab_8008 WHERE priority NE 2.
            WHEN 'GD_SELF'.
              DELETE i_outtab_8008 WHERE priority NE 3.
            WHEN 'NOT_CLASS'.
              DELETE i_outtab_8008 WHERE priority NE 4.
            WHEN 'TOT_CLASS'.
              DELETE i_outtab_8008 WHERE priority EQ 0.
            WHEN 'TOTAL'.
            WHEN OTHERS.
          ENDCASE.

          CALL SCREEN 8008.
        ELSE.
          MESSAGE 'Please select proper row' TYPE 'I'.
        ENDIF.
      WHEN 9041.
        IF e_row_id-index = 1.
          i_outtab_8009 = i_outtab_9041_s2.

          CASE e_column_id-fieldname.
            WHEN 'GB_ADVANCE'.
              DELETE i_outtab_8009 WHERE priority NE 1.
            WHEN 'GC_CORE'.
              DELETE i_outtab_8009 WHERE priority NE 2.
            WHEN 'GD_SELF'.
              DELETE i_outtab_8009 WHERE priority NE 3.
            WHEN 'NOT_CLASS'.
              DELETE i_outtab_8009 WHERE priority NE 4.
            WHEN 'TOT_CLASS'.
              DELETE i_outtab_8009 WHERE priority EQ 0.
            WHEN 'TOTAL'.
            WHEN OTHERS.
          ENDCASE.

          CALL SCREEN 8009.
        ELSE.
          MESSAGE 'Please select proper row' TYPE 'I'.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD handle_hot_spot_8008.
    i_outtab_6001 = i_outtab_9042_s3.
    READ TABLE i_outtab_8008 INTO DATA(ls_outtab_8008) INDEX e_row_id-index.
    IF sy-subrc IS INITIAL.
      DELETE i_outtab_6001 WHERE agr_name NE ls_outtab_8008-agr_name OR priority NE ls_outtab_8008-priority.
    ENDIF.
    CALL SCREEN 6001.
  ENDMETHOD.

  METHOD handle_hot_spot_8009.
    i_outtab_6002 = i_outtab_9041_s3.
    READ TABLE i_outtab_8009 INTO DATA(ls_outtab_8009) INDEX e_row_id-index.
    IF sy-subrc IS INITIAL.
*      DELETE i_outtab_6002 WHERE agr_name NE ls_outtab_8009-agr_name OR priority NE ls_outtab_8009-priority.
    ENDIF.
    CALL SCREEN 6002.
  ENDMETHOD.
ENDCLASS.
