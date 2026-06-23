*&---------------------------------------------------------------------*
*& Include          ZACG_MAINDEF
*&---------------------------------------------------------------------*

CLASS lcl_acg_tree DEFINITION.

  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING
          parent TYPE REF TO cl_gui_container,

      build_tree,

      handle_node_double_click
        FOR EVENT node_double_click
        OF cl_gui_simple_tree
        IMPORTING node_key.

  PRIVATE SECTION.
    DATA:
      o_tree        TYPE REF TO cl_gui_simple_tree,
      li_node_table TYPE STANDARD TABLE OF sapwltreen,
      lw_tree_type  TYPE sapwltrtyp,
      lv_active     TYPE c.

ENDCLASS.

CLASS lcl_acg DEFINITION.

  PUBLIC SECTION.

    METHODS:
      constructor.

  PRIVATE SECTION.

    DATA:
      v_repid            TYPE sy-repid,
      v_dynnr            TYPE sy-dynnr,
      o_splitter         TYPE REF TO cl_gui_splitter_container,
      o_docking          TYPE REF TO cl_gui_docking_container,
      o_toolbarmode_cont TYPE REF TO cl_gui_container,
      o_treecontent_cont TYPE REF TO cl_gui_container,
      o_treeprofile_cont TYPE REF TO cl_gui_container,
      o_tree_content     TYPE REF TO lcl_acg_tree.

    CONSTANTS:

      c_height_small    TYPE i                   VALUE 40.

ENDCLASS.

CLASS lcl_event_receiver DEFINITION.

  PUBLIC SECTION.

    METHODS: on_double_click FOR EVENT double_click
      OF cl_salv_events_table
      IMPORTING row column,

      handle_top_of_page_8001
        FOR EVENT top_of_page OF cl_gui_alv_grid IMPORTING e_dyndoc_id table_index,

      handle_top_of_page_8002
        FOR EVENT top_of_page OF cl_gui_alv_grid IMPORTING e_dyndoc_id table_index,

      handle_top_of_page_8003
        FOR EVENT top_of_page OF cl_gui_alv_grid IMPORTING e_dyndoc_id table_index,

      handle_top_of_page_8004
        FOR EVENT top_of_page OF cl_gui_alv_grid IMPORTING e_dyndoc_id table_index,

      handle_top_of_page_8005
        FOR EVENT top_of_page OF cl_gui_alv_grid IMPORTING e_dyndoc_id table_index,

      handle_top_of_page_8006
        FOR EVENT top_of_page OF cl_gui_alv_grid IMPORTING e_dyndoc_id table_index,

      handle_toolbar
        FOR EVENT toolbar OF cl_gui_alv_grid IMPORTING e_object e_interactive,

      handle_user_command
        FOR EVENT user_command OF cl_gui_alv_grid IMPORTING e_ucomm,

      handle_hot_spot
        FOR EVENT hotspot_click OF cl_gui_alv_grid IMPORTING e_row_id e_column_id,

      handle_hot_spot_8008
        FOR EVENT hotspot_click OF cl_gui_alv_grid IMPORTING e_row_id e_column_id,

      handle_hot_spot_8009
        FOR EVENT hotspot_click OF cl_gui_alv_grid IMPORTING e_row_id e_column_id.


ENDCLASS.
