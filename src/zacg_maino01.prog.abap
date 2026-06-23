*&---------------------------------------------------------------------*
*& Include          ZACG_MAINO01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module STATUS_1000 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_1000 OUTPUT.

  CLEAR: sy-ucomm.

  SET PF-STATUS 'PF_1000'.

  g_title = 'Access Control Guard'.
  SET TITLEBAR 'TL_1000' WITH g_title.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9000 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9000 OUTPUT.

  TYPES pict_line(256) TYPE c.

  DATA:
    lv_url   TYPE cndp_url.

  IF o_conttainer_9000 IS NOT BOUND.
    CREATE OBJECT o_conttainer_9000
      EXPORTING
        container_name = 'CC_9000'.
  ENDIF.

  IF o_picture_control IS NOT BOUND.
    CREATE OBJECT o_picture_control
      EXPORTING
        parent = o_conttainer_9000.
  ENDIF.

  IF g_logo_url IS INITIAL.
    g_stxbmaps-tdobject = 'GRAPHICS'.
    g_stxbmaps-tdname = 'ACG_LOGO'.
    g_stxbmaps-tdid = 'BMAP'.
    g_stxbmaps-tdbtype = 'BCOL'.



    CALL FUNCTION 'SAPSCRIPT_GET_GRAPHIC_BDS'
      EXPORTING
        i_object       = g_stxbmaps-tdobject
        i_name         = g_stxbmaps-tdname
        i_id           = g_stxbmaps-tdid
        i_btype        = g_stxbmaps-tdbtype
      IMPORTING
        e_bytecount    = g_bytecnt
      TABLES
        content        = gt_content
      EXCEPTIONS
        not_found      = 1
        bds_get_failed = 2
        bds_no_content = 3
        OTHERS         = 4.

    CALL FUNCTION 'SAPSCRIPT_CONVERT_BITMAP'
      EXPORTING
        old_format               = 'BDS'
        new_format               = 'BMP'
        bitmap_file_bytecount_in = g_bytecnt
      IMPORTING
        bitmap_file_bytecount    = g_logo_size
      TABLES
        bds_bitmap_file          = gt_content
        bitmap_file              = gt_logo_table
      EXCEPTIONS
        OTHERS                   = 1.

    CALL FUNCTION 'DP_CREATE_URL'
      EXPORTING
        type     = 'image'
        subtype  = cndp_sap_tab_unknown
        size     = g_logo_size
        lifetime = cndp_lifetime_transaction
      TABLES
        data     = gt_logo_table
      CHANGING
        url      = g_logo_url
      EXCEPTIONS
        OTHERS   = 4.
    IF sy-subrc IS INITIAL.
    ENDIF.
  ENDIF.


* load image
  IF g_logo_url IS NOT INITIAL.
    CALL METHOD o_picture_control->load_picture_from_url_async
      EXPORTING
        url = g_logo_url.

    CALL METHOD o_picture_control->set_display_mode
      EXPORTING
        display_mode = cl_gui_picture=>display_mode_fit_center
      EXCEPTIONS
        error        = 1.
    IF sy-subrc IS INITIAL.
    ENDIF.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9001 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9001 OUTPUT.

  g_subscr_nn = 0001.
*  CLEAR sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9002 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9002 OUTPUT.

  g_subscr_nn = 0002.
*  CLEAR sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9006 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9006 OUTPUT.

  g_subscr_nn = 0006.
  CLEAR sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9007 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9007 OUTPUT.

  g_subscr_nn = 0007.
  CLEAR sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9008 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9008 OUTPUT.


  LOOP AT SCREEN .
    IF screen-group1 = 'GR1' AND gt_lock_data IS INITIAL.    "Modi ground assigned by double click the push button on the layout at
      screen-active = 0.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

  g_subscr_nn = 0008.
  CLEAR sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_8001 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_8001 OUTPUT.

  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_8001 IS NOT BOUND.
    PERFORM show_8001.
  ELSE.
    CALL METHOD o_grid_8001->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_8001->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.
    o_grid_8001->refresh_table_display( ).
    CALL METHOD o_docu_8001->initialize_document
      EXPORTING
        background_color = cl_dd_area=>col_textarea.

    CALL METHOD o_grid_8001->list_processing_events
      EXPORTING
        i_event_name = 'TOP_OF_PAGE'
        i_dyndoc_id  = o_docu_8001.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_8002 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_8002 OUTPUT.
  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_8002 IS NOT BOUND.
    PERFORM show_8002.
  ELSE.

    CALL METHOD o_grid_8002->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_8002->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.

    o_grid_8002->refresh_table_display( ).

    CALL METHOD o_docu_8002->initialize_document
      EXPORTING
        background_color = cl_dd_area=>col_textarea.

    CALL METHOD o_grid_8002->list_processing_events
      EXPORTING
        i_event_name = 'TOP_OF_PAGE'
        i_dyndoc_id  = o_docu_8002.
  ENDIF.

ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_8003 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_8003 OUTPUT.
  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_8003 IS NOT BOUND.
    PERFORM show_8003.
  ELSE.
    CALL METHOD o_grid_8003->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_8003->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.
    o_grid_8003->refresh_table_display( ).
    CALL METHOD o_docu_8003->initialize_document
      EXPORTING
        background_color = cl_dd_area=>col_textarea.

    CALL METHOD o_grid_8003->list_processing_events
      EXPORTING
        i_event_name = 'TOP_OF_PAGE'
        i_dyndoc_id  = o_docu_8003.
  ENDIF.

ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_8004 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_8004 OUTPUT.
  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_8004 IS NOT BOUND.
    PERFORM show_8004.
  ELSE.
    CALL METHOD o_grid_8004->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_8004->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.
    o_grid_8004->refresh_table_display( ).
    CALL METHOD o_docu_8004->initialize_document
      EXPORTING
        background_color = cl_dd_area=>col_textarea.

    CALL METHOD o_grid_8004->list_processing_events
      EXPORTING
        i_event_name = 'TOP_OF_PAGE'
        i_dyndoc_id  = o_docu_8004.
  ENDIF.

ENDMODULE.

MODULE status_8005 OUTPUT.

  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_8005 IS NOT BOUND.
    PERFORM show_8005.
  ELSE.
    PERFORM adjust_fieldcatalog.

    CALL METHOD o_grid_8005->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_8005->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.
    o_grid_8005->refresh_table_display( ).
    CALL METHOD o_docu_8005->initialize_document
      EXPORTING
        background_color = cl_dd_area=>col_textarea.

    CALL METHOD o_grid_8005->list_processing_events
      EXPORTING
        i_event_name = 'TOP_OF_PAGE'
        i_dyndoc_id  = o_docu_8005.
  ENDIF.

ENDMODULE.

MODULE status_8006 OUTPUT.
  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_8006 IS NOT BOUND.
    PERFORM show_8006.
  ELSE.
    PERFORM adjust_fieldcatalog.

    CALL METHOD o_grid_8006->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_8006->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.
    o_grid_8006->refresh_table_display( ).
    CALL METHOD o_docu_8006->initialize_document
      EXPORTING
        background_color = cl_dd_area=>col_textarea.

    CALL METHOD o_grid_8006->list_processing_events
      EXPORTING
        i_event_name = 'TOP_OF_PAGE'
        i_dyndoc_id  = o_docu_8006.
  ENDIF.

ENDMODULE.

*&---------------------------------------------------------------------*
*& Module STATUS_9009 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9009 OUTPUT.

  g_subscr_nn = 0009.
  CLEAR sy-ucomm.
  PERFORM show_result_9009.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9010 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9010 OUTPUT.

  g_subscr_nn = 0010.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9011 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9011 OUTPUT.

  g_subscr_nn = 0011.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9012 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9012 OUTPUT.

  g_subscr_nn = 0012.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9013 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9013 OUTPUT.

  g_subscr_nn = 0013.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9014 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9014 OUTPUT.

  g_subscr_nn = 0014.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9015 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9015 OUTPUT.

  g_subscr_nn = 0015.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9016 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9016 OUTPUT.

  g_subscr_nn = 0016.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9017 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9017 OUTPUT.

  g_subscr_nn = 0017.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9018 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9018 OUTPUT.

  g_subscr_nn = 0018.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9019 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9019 OUTPUT.

  g_subscr_nn = 0019.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9020 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9020 OUTPUT.

  g_subscr_nn = 0020.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_7001 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_7001 OUTPUT.

  SET PF-STATUS 'PF_7001'.
  SET TITLEBAR 'TL_7001'.

  PERFORM populate_data_7001.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9021 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9021 OUTPUT.

  PERFORM monitor_standard_users.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9022 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9022 OUTPUT.

  g_subscr_nn = 0022.
  CLEAR sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9023 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9023 OUTPUT.

  PERFORM display_user_list.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_2024 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_2024 OUTPUT.

  g_subscr_nn = 0023.
  CLEAR : sy-ucomm.
  PERFORM show_result_9024.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9025 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9025 OUTPUT.

  g_subscr_nn = 0024.
  CLEAR : sy-ucomm.
  PERFORM show_result_9025.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9026 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9026 OUTPUT.

  g_subscr_nn = 0025.
  CLEAR : sy-ucomm.
  PERFORM show_result_9026.

ENDMODULE.

MODULE status_9027 OUTPUT.

  g_subscr_nn = 0026.
  CLEAR : sy-ucomm.
  PERFORM show_result_9027.

ENDMODULE.

MODULE status_9028 OUTPUT.

  CLEAR : sy-ucomm.
  IF hrs IS INITIAL.
    hrs = 24.
  ENDIF.
  IF date1 IS INITIAL.
    date1 = sy-datum.
  ENDIF.
  IF date2 IS INITIAL.
    date2 = sy-datum.
  ENDIF.
  PERFORM show_result_9028.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9029 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9029 OUTPUT.
  g_subscr_nn = 0029.
  CLEAR : sy-ucomm.

  PERFORM get_data_9029.

  PERFORM show_result_9029.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9029 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9030 OUTPUT.
  g_subscr_nn = 0030.
  CLEAR : sy-ucomm.

  PERFORM show_result_9030.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9029 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9031 OUTPUT.
  g_subscr_nn = 0031.
  CLEAR : sy-ucomm.

  PERFORM get_data_9031.

  PERFORM show_result_9031.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_8007 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_8007 OUTPUT.
  CLEAR g_mitigated.
  SET PF-STATUS 'PF_8007'.

  IF o_conttainer_8007 IS NOT BOUND.
    PERFORM show_8007.
  ELSE.
    CALL METHOD o_grid_8007->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_8007->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.

    o_grid_8007->refresh_table_display( ).

  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_7002 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_7002 OUTPUT.
  SET PF-STATUS 'PF_7002'.
  SET TITLEBAR 'TL_7002'.

  table_7002-lines = lines( i_outtab_7002 ).
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_7003 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_7003 OUTPUT.
  SET PF-STATUS 'PF_7001'.
  SET TITLEBAR 'TL_7003'.

  table_7003-lines = lines( i_outtab_7003 ).
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_7004 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_7004 OUTPUT.

  SET PF-STATUS 'PF_7001'.
  SET TITLEBAR 'TL_7004'.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9033 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9033 OUTPUT.
  CLEAR : sy-ucomm.

  PERFORM populate_data_9033.

  table_9033-lines = lines( i_outtab_9033 ).
  table_9033-fixed_cols = 6.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module HIDE_ROW_9033 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE hide_row_9033 OUTPUT.
  PERFORM hide_row_9033.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_7005 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_7005 OUTPUT.
  SET PF-STATUS 'PF_7001'.
  SET TITLEBAR 'TL_7005'.

  PERFORM status_7005.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9034 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9034 OUTPUT.

  CLEAR : sy-ucomm.

  PERFORM get_data_9034.

  PERFORM show_result_9034.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_7006 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_7006 OUTPUT.
  SET PF-STATUS 'PF_7006'.
  SET TITLEBAR 'TL_7006'.

  table_7006-lines = lines( i_outtab_7006 ).
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9035 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9035 OUTPUT.

  g_subscr_nn = 0035.

*  PERFORM get_data_9035.

  CLEAR : sy-ucomm.

  PERFORM show_result_9035.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9036 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9036 OUTPUT.

  g_subscr_nn = 0036.

  CLEAR : sy-ucomm.

  PERFORM get_data_9036.

  PERFORM show_result_9036.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9037 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9037 OUTPUT.

  g_subscr_nn = 0037.

  PERFORM show_result_9037.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_7007 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_7007 OUTPUT.

*  PERFORM status_7007.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9041 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9041 OUTPUT.

  g_subscr_nn = 0041.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_9042 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_9042 OUTPUT.

  g_subscr_nn = 0042.
  CLEAR : sy-ucomm.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_8008 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_8008 OUTPUT.

  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_8008 IS NOT BOUND.
    PERFORM show_8008.
  ELSE.
    CALL METHOD o_grid_8008->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_8008->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.

    o_grid_8008->refresh_table_display( ).
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_6001 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_6001 OUTPUT.

  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_6001 IS NOT BOUND.
    PERFORM show_6001.
  ELSE.
    CALL METHOD o_grid_6001->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_6001->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.

    o_grid_6001->refresh_table_display( ).
  ENDIF.


ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_8009 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_8009 OUTPUT.

  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_8009 IS NOT BOUND.
    PERFORM show_8009.
  ELSE.
    CALL METHOD o_grid_8009->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_8009->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.

    o_grid_8008->refresh_table_display( ).
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_6002 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_6002 OUTPUT.

  SET PF-STATUS 'PF_8001'.

  IF o_conttainer_6002 IS NOT BOUND.
    PERFORM show_6001.
  ELSE.
    CALL METHOD o_grid_6002->get_frontend_layout
      IMPORTING
        es_layout = wa_layout.
    wa_layout-cwidth_opt = abap_true.
    CALL METHOD o_grid_6002->set_frontend_layout
      EXPORTING
        is_layout = wa_layout.

    o_grid_6002->refresh_table_display( ).
  ENDIF.


ENDMODULE.
