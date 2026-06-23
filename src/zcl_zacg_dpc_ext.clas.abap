class ZCL_ZACG_DPC_EXT definition
  public
  inheriting from ZCL_ZACG_DPC
  create public .

public section.
protected section.

  methods CRITICALROLELE01_GET_ENTITYSET
    redefinition .
  methods CRITICALROLELEVE_GET_ENTITYSET
    redefinition .
  methods CRITICALROLEPR01_GET_ENTITYSET
    redefinition .
  methods CRITICALROLEPROC_GET_ENTITYSET
    redefinition .
  methods CRITICALUSERLE01_GET_ENTITYSET
    redefinition .
  methods CRITICALUSERLEVE_GET_ENTITYSET
    redefinition .
  methods SODROLELEVELDATA_GET_ENTITYSET
    redefinition .
  methods SODROLELEVELGRAP_GET_ENTITYSET
    redefinition .
  methods SODROLEPROCESS01_GET_ENTITYSET
    redefinition .
  methods SODROLEPROCESSLE_GET_ENTITYSET
    redefinition .
  methods SODUSERLEVELGRAP_GET_ENTITYSET
    redefinition .
  methods SODUSERLEVELDATA_GET_ENTITYSET
    redefinition .
private section.
ENDCLASS.



CLASS ZCL_ZACG_DPC_EXT IMPLEMENTATION.


  METHOD criticalroleleve_get_entityset.

    DATA:
      li_data       TYPE STANDARD TABLE OF zacg_dashboard.

    SELECT _data~jobname, _data~jobcount
      FROM zacg_dashboard AS _data
      INNER JOIN tbtco AS _job
      ON _data~jobname = _job~jobname
      AND _data~jobcount = _job~jobcount
      AND _job~status = 'F'
      AND _data~bname IS INITIAL
      ORDER BY erdat DESCENDING, ertim DESCENDING
      INTO @DATA(lwa_latest_job)
      UP TO 1 ROWS.
    ENDSELECT.

    SELECT *
      FROM zacg_dashboard
      WHERE jobname   = @lwa_latest_job-jobname
        AND jobcount  = @lwa_latest_job-jobcount
        AND rtype     = @abap_true
        AND bname     = @space
    INTO TABLE @li_data.
    IF sy-subrc IS INITIAL.
      SORT li_data BY agr_name rlevel DESCENDING.
      DELETE ADJACENT DUPLICATES FROM li_data COMPARING agr_name.
    ENDIF.

    SELECT DISTINCT COUNT( agr_name )
       FROM zacg_agr_define
       WHERE agr_name LIKE 'Z%'
          OR agr_name LIKE 'Y%'
       INTO @DATA(lv_total_role).
    IF lv_total_role IS INITIAL.
      SELECT DISTINCT COUNT( agr_name )
        FROM agr_define
        WHERE agr_name LIKE 'Z%'
           OR agr_name LIKE 'Y%'
        INTO @lv_total_role.
    ENDIF.

    SELECT rlevel AS levelid, leveld AS level, COUNT( leveld ) AS count
      FROM @li_data AS data
      GROUP BY rlevel, leveld
      INTO TABLE @DATA(li_level_count).

    SELECT SUM( count )
      FROM @li_level_count AS sum_count
      INTO @DATA(lv_sum_count).

    SELECT ddtext, domvalue_l
      FROM dd07t
      WHERE domname = 'ZRISK_LEVEL'
        AND ddlanguage = @sy-langu
    INTO TABLE @DATA(li_levels).

    LOOP AT li_level_count INTO DATA(lwa_level_count).
      APPEND INITIAL LINE TO et_entityset[] ASSIGNING FIELD-SYMBOL(<lfs_entityset>).
      <lfs_entityset>-jobname   = lwa_latest_job-jobname.
      <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
      <lfs_entityset>-levelid   = lwa_level_count-levelid.
      <lfs_entityset>-level     = lwa_level_count-level.
      <lfs_entityset>-count     = lwa_level_count-count.
    ENDLOOP.

    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '0'.
    <lfs_entityset>-level     = 'No Risk'.
    <lfs_entityset>-count     = lv_total_role - lv_sum_count.

    LOOP AT li_levels INTO DATA(lwa_levels).
      READ TABLE et_entityset[] TRANSPORTING NO FIELDS WITH KEY levelid = lwa_levels-domvalue_l.
      IF sy-subrc IS NOT INITIAL.
        APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
        <lfs_entityset>-jobname   = lwa_latest_job-jobname.
        <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
        <lfs_entityset>-levelid   = lwa_levels-domvalue_l.
        <lfs_entityset>-level     = lwa_levels-ddtext.
        <lfs_entityset>-count     = 0.
      ENDIF.
    ENDLOOP.

    SORT et_entityset[] BY levelid DESCENDING.

  ENDMETHOD.


  METHOD sodrolelevelgrap_get_entityset.

    DATA:
      li_data       TYPE STANDARD TABLE OF zacg_dashboard.

    SELECT _data~jobname, _data~jobcount
      FROM zacg_dashboard AS _data
      INNER JOIN tbtco AS _job
      ON _data~jobname = _job~jobname
      AND _data~jobcount = _job~jobcount
      AND _job~status = 'F'
      AND _data~bname IS INITIAL
      ORDER BY erdat DESCENDING, ertim DESCENDING
      INTO @DATA(lwa_latest_job)
      UP TO 1 ROWS.
    ENDSELECT.

    SELECT *
      FROM zacg_dashboard
      WHERE jobname   = @lwa_latest_job-jobname
        AND jobcount  = @lwa_latest_job-jobcount
        AND rtype     = @abap_false
        AND bname     = @space
    INTO TABLE @li_data.
    IF sy-subrc IS INITIAL.
      SORT li_data BY agr_name rlevel DESCENDING.
      DELETE ADJACENT DUPLICATES FROM li_data COMPARING agr_name.
    ENDIF.

    SELECT DISTINCT COUNT( agr_name )
       FROM zacg_agr_define
       WHERE agr_name LIKE 'Z%'
          OR agr_name LIKE 'Y%'
       INTO @DATA(lv_total_role).
    IF lv_total_role IS INITIAL.
      SELECT DISTINCT COUNT( agr_name )
        FROM agr_define
        WHERE agr_name LIKE 'Z%'
           OR agr_name LIKE 'Y%'
        INTO @lv_total_role.
    ENDIF.

    SELECT rlevel AS levelid, leveld AS level, COUNT( leveld ) AS count
      FROM @li_data AS data
      GROUP BY rlevel, leveld
      INTO TABLE @DATA(li_level_count).

    SELECT SUM( count )
      FROM @li_level_count AS sum_count
      INTO @DATA(lv_sum_count).

    SELECT ddtext, domvalue_l
      FROM dd07t
      WHERE domname = 'ZRISK_LEVEL'
        AND ddlanguage = @sy-langu
    INTO TABLE @DATA(li_levels).

    LOOP AT li_level_count INTO DATA(lwa_level_count).
      APPEND INITIAL LINE TO et_entityset[] ASSIGNING FIELD-SYMBOL(<lfs_entityset>).
      <lfs_entityset>-jobname   = lwa_latest_job-jobname.
      <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
      <lfs_entityset>-levelid   = lwa_level_count-levelid.
      <lfs_entityset>-level     = lwa_level_count-level.
      <lfs_entityset>-count     = lwa_level_count-count.
    ENDLOOP.

    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '0'.
    <lfs_entityset>-level     = 'No Risk'.
    <lfs_entityset>-count     = lv_total_role - lv_sum_count.

    LOOP AT li_levels INTO DATA(lwa_levels).
      READ TABLE et_entityset[] TRANSPORTING NO FIELDS WITH KEY levelid = lwa_levels-domvalue_l.
      IF sy-subrc IS NOT INITIAL.
        APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
        <lfs_entityset>-jobname   = lwa_latest_job-jobname.
        <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
        <lfs_entityset>-levelid   = lwa_levels-domvalue_l.
        <lfs_entityset>-level     = lwa_levels-ddtext.
        <lfs_entityset>-count     = 0.
      ENDIF.
    ENDLOOP.

    SORT et_entityset[] BY levelid DESCENDING.

  ENDMETHOD.


  METHOD criticalrolele01_get_entityset.

    DATA:
      lv_jobname  TYPE btcjob,
      lv_jobcount TYPE btcjobcnt.

    READ TABLE it_filter_select_options ASSIGNING FIELD-SYMBOL(<fs_filter>)
    WITH KEY property = 'Jobname'.
    IF sy-subrc IS INITIAL.

      READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobname>) INDEX 1.
      IF sy-subrc IS INITIAL.

        lv_jobname = <lfs_jobname>-low.

        READ TABLE it_filter_select_options ASSIGNING <fs_filter>
        WITH KEY property = 'Jobcount'.
        IF sy-subrc IS INITIAL.

          READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobcount>) INDEX 1.
          IF sy-subrc IS INITIAL.

            lv_jobcount = <lfs_jobcount>-low.

            SELECT jobname,
                   jobcount,
                   agr_name,
                   risk,
                   riskd,
                   leveld,
                   moduled
              FROM zacg_dashboard
              INTO TABLE @et_entityset[]
              WHERE jobname   = @lv_jobname
                AND jobcount  = @lv_jobcount
                AND bname     = @space
                AND rtype     = @abap_true.

            SORT et_entityset[] BY role level.
            DELETE ADJACENT DUPLICATES FROM et_entityset[] COMPARING role level.


*            READ TABLE it_filter_select_options ASSIGNING <fs_filter>
*            WITH KEY property = 'Level'.
*            IF sy-subrc IS INITIAL.
*
*              READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_level>) INDEX 1.
*              IF sy-subrc IS INITIAL.
*
*                IF <lfs_level>-low IS INITIAL.
*
*                  SELECT jobname,
*                         jobcount,
*                         agr_name,
*                         risk,
*                         riskd,
*                         leveld,
*                         moduled
*                    FROM zacg_dashboard
*                    INTO TABLE @et_entityset[]
*                    WHERE jobname   = @lv_jobname
*                      AND jobcount  = @lv_jobcount
*                      AND bname     = @space
*                      AND rtype     = @abap_true.
*                  IF sy-subrc IS INITIAL.
*
*                    SORT et_entityset[] BY role level.
*                    DELETE ADJACENT DUPLICATES FROM et_entityset[] COMPARING role.
*
*                  ENDIF.
*
*                ELSE.
*
*                  SELECT jobname,
*                         jobcount,
*                         agr_name,
*                         risk,
*                         riskd,
*                         leveld,
*                         moduled
*                    FROM zacg_dashboard
*                    INTO TABLE @et_entityset[]
*                    WHERE jobname   = @lv_jobname
*                      AND jobcount  = @lv_jobcount
*                      AND bname     = @space
*                      AND leveld    = @<lfs_level>-low
*                      AND rtype     = @abap_true.
*                  IF sy-subrc IS INITIAL.
*
*                    SORT et_entityset[] BY role level.
*                    DELETE ADJACENT DUPLICATES FROM et_entityset[] COMPARING role.
*
*                  ELSE.
*
*                    " Invalid Filter values
*
*                  ENDIF.
*
*                ENDIF.
*
*              ELSE.
*
*                " No filter value for Level
*
*              ENDIF.
*
*            ELSE.
*
*              " No filter value for Level
*
*            ENDIF.

          ELSE.

            " No filter value for Jobcount

          ENDIF.

        ELSE.

          " No filter value for Jobcount

        ENDIF.

      ELSE.

        " No filter value for Jobname

      ENDIF.

    ELSE.

      " No filter value for jobname

    ENDIF.



  ENDMETHOD.


  METHOD criticalroleproc_get_entityset.

    DATA:
      lv_count      TYPE i,
      lv_percentage TYPE p DECIMALS 2,
      li_data       TYPE STANDARD TABLE OF zacg_dashboard,
      li_process    TYPE STANDARD TABLE OF val_text.


    SELECT _data~jobname, _data~jobcount
      FROM zacg_dashboard AS _data
      INNER JOIN tbtco AS _job
      ON _data~jobname = _job~jobname
      AND _data~jobcount = _job~jobcount
      AND _job~status = 'F'
      AND _data~bname IS INITIAL
      ORDER BY erdat DESCENDING, ertim DESCENDING
      INTO @DATA(lwa_latest_job)
      UP TO 1 ROWS.
    ENDSELECT.

    SELECT *
      FROM zacg_dashboard
      WHERE jobname   = @lwa_latest_job-jobname
        AND jobcount  = @lwa_latest_job-jobcount
        AND rtype     = @abap_true
        AND bname     = @space
    INTO TABLE @li_data.
    IF sy-subrc IS INITIAL.
      SORT li_data BY agr_name rlevel DESCENDING rmodule.
      DELETE ADJACENT DUPLICATES FROM li_data COMPARING agr_name rmodule.
    ENDIF.

    SELECT DISTINCT COUNT( agr_name )
       FROM zacg_agr_define
       WHERE agr_name LIKE 'Z%'
          OR agr_name LIKE 'Y%'
       INTO @DATA(lv_total_role).
    IF lv_total_role IS INITIAL.
      SELECT DISTINCT COUNT( agr_name )
        FROM agr_define
        WHERE agr_name LIKE 'Z%'
           OR agr_name LIKE 'Y%'
        INTO @lv_total_role.
    ENDIF.

    SELECT leveld AS level, moduled AS process, COUNT( leveld ) AS count
      FROM @li_data AS data
      GROUP BY leveld, moduled
      ORDER BY level
      INTO TABLE @DATA(li_level_count).

    SELECT ddtext
      FROM dd07t
      WHERE domname = 'ZRISK_PROC'
        AND ddlanguage = @sy-langu
      ORDER BY ddtext
      INTO TABLE @li_process.

    LOOP AT li_process INTO DATA(lwa_process).

      APPEND INITIAL LINE TO et_entityset[] ASSIGNING FIELD-SYMBOL(<lfs_entityset>).

      <lfs_entityset>-jobname   = lwa_latest_job-jobname.
      <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
      <lfs_entityset>-process   = lwa_process.

      LOOP AT li_level_count INTO DATA(lwa_level_count).

        ASSIGN COMPONENT lwa_level_count-level OF STRUCTURE <lfs_entityset> TO FIELD-SYMBOL(<lfs_level>).
        IF <lfs_level> IS ASSIGNED.
          IF lwa_level_count-process = lwa_process.
            lv_count      = lwa_level_count-count.
            <lfs_level>   = lv_count.
*            lv_percentage = ( lwa_level_count-count / lv_total_role ) * 100.
*            <lfs_level>   = |{ lv_count } ({ lv_percentage }%)|.
          ENDIF.
        ENDIF.
        UNASSIGN <lfs_level>.
      ENDLOOP.

      UNASSIGN <lfs_entityset>.

    ENDLOOP.



  ENDMETHOD.


  METHOD sodroleleveldata_get_entityset.

    DATA:
      lv_jobname  TYPE btcjob,
      lv_jobcount TYPE btcjobcnt.

    READ TABLE it_filter_select_options ASSIGNING FIELD-SYMBOL(<fs_filter>)
    WITH KEY property = 'Jobname'.
    IF sy-subrc IS INITIAL.

      READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobname>) INDEX 1.
      IF sy-subrc IS INITIAL.

        lv_jobname = <lfs_jobname>-low.

        READ TABLE it_filter_select_options ASSIGNING <fs_filter>
        WITH KEY property = 'Jobcount'.
        IF sy-subrc IS INITIAL.

          READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobcount>) INDEX 1.
          IF sy-subrc IS INITIAL.

            lv_jobcount = <lfs_jobcount>-low.


            SELECT jobname,
                   jobcount,
                   agr_name,
                   risk,
                   riskd,
                   leveld,
                   moduled
              FROM zacg_dashboard
              INTO TABLE @et_entityset[]
              WHERE jobname   = @lv_jobname
                AND jobcount  = @lv_jobcount
                AND bname     = @space
                AND rtype     = @space.

            SORT et_entityset[] BY role level.
            DELETE ADJACENT DUPLICATES FROM et_entityset[] COMPARING role level.

*            READ TABLE it_filter_select_options ASSIGNING <fs_filter>
*            WITH KEY property = 'Level'.
*            IF sy-subrc IS INITIAL.
*
*              READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_level>) INDEX 1.
*              IF sy-subrc IS INITIAL.
*
*                IF <lfs_level>-low IS INITIAL.
*
*                  SELECT jobname,
*                         jobcount,
*                         agr_name,
*                         risk,
*                         riskd,
*                         leveld,
*                         moduled
*                    FROM zacg_dashboard
*                    INTO TABLE @et_entityset[]
*                    WHERE jobname   = @lv_jobname
*                      AND jobcount  = @lv_jobcount
*                      AND bname     = @space
*                      AND rtype     = @space.
*                  IF sy-subrc IS INITIAL.
*
*                    SORT et_entityset[] BY role level.
*                    DELETE ADJACENT DUPLICATES FROM et_entityset[] COMPARING role.
*
*                  ENDIF.
*
*                ELSE.
*
*                  SELECT jobname,
*                         jobcount,
*                         agr_name,
*                         risk,
*                         riskd,
*                         leveld,
*                         moduled
*                    FROM zacg_dashboard
*                    INTO TABLE @et_entityset[]
*                    WHERE jobname   = @lv_jobname
*                      AND jobcount  = @lv_jobcount
*                      AND bname     = @space
*                      AND leveld    = @<lfs_level>-low
*                      AND rtype     = @space.
*                  IF sy-subrc IS INITIAL.
*
*                    SORT et_entityset[] BY role level.
*                    DELETE ADJACENT DUPLICATES FROM et_entityset[] COMPARING role.
*
*                  ELSE.
*
*                    " Invalid Filter values
*
*                  ENDIF.
*
*                ENDIF.
*              ELSE.
*
*                " No filter value for Level
*
*              ENDIF.
*
*            ELSE.
*
*              " No filter value for Level
*
*            ENDIF.

          ELSE.

            " No filter value for Jobcount

          ENDIF.

        ELSE.

          " No filter value for Jobcount

        ENDIF.

      ELSE.

        " No filter value for Jobname

      ENDIF.

    ELSE.

      " No filter value for jobname

    ENDIF.


  ENDMETHOD.


  METHOD sodroleprocessle_get_entityset.

    DATA:
      lv_count      TYPE i,
      lv_percentage TYPE p DECIMALS 2,
      li_data       TYPE STANDARD TABLE OF zacg_dashboard,
      li_process    TYPE STANDARD TABLE OF val_text.


    SELECT _data~jobname, _data~jobcount
      FROM zacg_dashboard AS _data
      INNER JOIN tbtco AS _job
      ON _data~jobname = _job~jobname
      AND _data~jobcount = _job~jobcount
      AND _job~status = 'F'
      AND _data~bname IS INITIAL
      ORDER BY erdat DESCENDING, ertim DESCENDING
      INTO @DATA(lwa_latest_job)
      UP TO 1 ROWS.
    ENDSELECT.

    SELECT *
      FROM zacg_dashboard
      WHERE jobname   = @lwa_latest_job-jobname
        AND jobcount  = @lwa_latest_job-jobcount
        AND rtype     = @space
        AND bname     = @space
    INTO TABLE @li_data.
    IF sy-subrc IS INITIAL.
      SORT li_data BY agr_name rlevel DESCENDING rmodule.
      DELETE ADJACENT DUPLICATES FROM li_data COMPARING agr_name rlevel rmodule.
    ENDIF.

    SELECT DISTINCT COUNT( agr_name )
       FROM zacg_agr_define
       WHERE agr_name LIKE 'Z%'
          OR agr_name LIKE 'Y%'
       INTO @DATA(lv_total_role).
    IF lv_total_role IS INITIAL.
      SELECT DISTINCT COUNT( agr_name )
        FROM agr_define
        WHERE agr_name LIKE 'Z%'
           OR agr_name LIKE 'Y%'
        INTO @lv_total_role.
    ENDIF.

    SELECT leveld AS level, moduled AS process, COUNT( leveld ) AS count
      FROM @li_data AS data
      GROUP BY leveld, moduled
      ORDER BY level
      INTO TABLE @DATA(li_level_count).

    SELECT ddtext
      FROM dd07t
      WHERE domname = 'ZRISK_PROC'
        AND ddlanguage = @sy-langu
      ORDER BY ddtext
      INTO TABLE @li_process.

    LOOP AT li_process INTO DATA(lwa_process).

      APPEND INITIAL LINE TO et_entityset[] ASSIGNING FIELD-SYMBOL(<lfs_entityset>).

      <lfs_entityset>-jobname   = lwa_latest_job-jobname.
      <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
      <lfs_entityset>-process   = lwa_process.

      LOOP AT li_level_count INTO DATA(lwa_level_count).

        ASSIGN COMPONENT lwa_level_count-level OF STRUCTURE <lfs_entityset> TO FIELD-SYMBOL(<lfs_level>).
        IF <lfs_level> IS ASSIGNED.
          IF lwa_level_count-process = lwa_process.
            lv_count      = lwa_level_count-count.
            <lfs_level>   = lv_count.
*            lv_percentage = ( lwa_level_count-count / lv_total_role ) * 100.
*            <lfs_level>   = |{ lv_count } ({ lv_percentage }%)|.
          ENDIF.
        ENDIF.
        UNASSIGN <lfs_level>.
      ENDLOOP.

      UNASSIGN <lfs_entityset>.

    ENDLOOP.


  ENDMETHOD.


  METHOD criticalrolepr01_get_entityset.

    DATA:
      lv_jobname  TYPE btcjob,
      lv_jobcount TYPE btcjobcnt,
      lv_level    TYPE val_text,
      lv_module   TYPE val_text.

    READ TABLE it_filter_select_options ASSIGNING FIELD-SYMBOL(<fs_filter>)
    WITH KEY property = 'Jobname'.
    IF sy-subrc IS INITIAL.

      READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobname>) INDEX 1.
      IF sy-subrc IS INITIAL.

        lv_jobname = <lfs_jobname>-low.

        READ TABLE it_filter_select_options ASSIGNING <fs_filter>
        WITH KEY property = 'Jobcount'.
        IF sy-subrc IS INITIAL.

          READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobcount>) INDEX 1.
          IF sy-subrc IS INITIAL.

            lv_jobcount = <lfs_jobcount>-low.

            SELECT *
              FROM zacg_dashboard
              INTO TABLE @DATA(li_data)
              WHERE jobname   = @lv_jobname
                AND jobcount  = @lv_jobcount
                AND bname     = @space
                AND rtype     = @abap_true.
            IF sy-subrc IS INITIAL.

              SORT li_data BY agr_name rlevel DESCENDING.
              DELETE ADJACENT DUPLICATES FROM li_data COMPARING agr_name rlevel.

              SELECT jobname,
                     jobcount,
                     agr_name,
                     risk,
                     riskd,
                     leveld,
                     moduled
               FROM @li_data AS core_data
               ORDER BY agr_name
               INTO TABLE @et_entityset[].

            ELSE.

              " Invalid Filter values

            ENDIF.

          ELSE.

          ENDIF.


*          READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobcount>) INDEX 1.
*          IF sy-subrc IS INITIAL.
*
*            lv_jobcount = <lfs_jobcount>-low.
*
*            READ TABLE it_filter_select_options ASSIGNING <fs_filter>
*            WITH KEY property = 'Level'.
*            IF sy-subrc IS INITIAL.
*
*              READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_level>) INDEX 1.
*              IF sy-subrc IS INITIAL.
*
*                lv_level = <lfs_level>-low.
*
*                READ TABLE it_filter_select_options ASSIGNING <fs_filter>
*                WITH KEY property = 'Process'.
*                IF sy-subrc IS INITIAL.
*
*                  READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_process>) INDEX 1.
*                  IF sy-subrc IS INITIAL.
*
*                    lv_module = <lfs_process>-low.
*
*                    SELECT *
*                      FROM zacg_dashboard
*                      INTO TABLE @DATA(li_data)
*                      WHERE jobname   = @lv_jobname
*                        AND jobcount  = @lv_jobcount
*                        AND bname     = @space
*                        AND moduled   = @lv_module
*                        AND rtype     = @abap_true.
*                    IF sy-subrc IS INITIAL.
*                      SORT li_data BY agr_name rlevel DESCENDING.
*                      DELETE ADJACENT DUPLICATES FROM li_data COMPARING agr_name.
*
*                      SELECT jobname,
*                             jobcount,
*                             agr_name,
*                             risk,
*                             riskd,
*                             leveld,
*                             moduled
*                       FROM @li_data AS core_data
*                       WHERE leveld    = @lv_level
*                       ORDER BY agr_name
*                       INTO TABLE @et_entityset[].
*
*                    ELSE.
*
*                      " Invalid Filter values
*
*                    ENDIF.
*
*
*                  ELSE.
*
*                    " No filter value for Process
*
*                  ENDIF.
*
*                ELSE.
*
*                  " No filter value for Process
*
*                ENDIF.
*
*
*              ELSE.
*
*                " No filter value for Level
*
*              ENDIF.
*
*            ELSE.
*
*              " No filter value for Level
*
*            ENDIF.
*
*          ELSE.
*
*            " No filter value for Jobcount
*
*          ENDIF.

        ELSE.

          " No filter value for Jobcount

        ENDIF.

      ELSE.

        " No filter value for Jobname

      ENDIF.

    ELSE.

      " No filter value for jobname

    ENDIF.

  ENDMETHOD.


  METHOD criticaluserle01_get_entityset.

    DATA:
      lv_jobname  TYPE btcjob,
      lv_jobcount TYPE btcjobcnt.

    READ TABLE it_filter_select_options ASSIGNING FIELD-SYMBOL(<fs_filter>)
    WITH KEY property = 'Jobname'.
    IF sy-subrc IS INITIAL.

      READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobname>) INDEX 1.
      IF sy-subrc IS INITIAL.

        lv_jobname = <lfs_jobname>-low.

        READ TABLE it_filter_select_options ASSIGNING <fs_filter>
        WITH KEY property = 'Jobcount'.
        IF sy-subrc IS INITIAL.

          READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobcount>) INDEX 1.
          IF sy-subrc IS INITIAL.

            lv_jobcount = <lfs_jobcount>-low.

            SELECT *
              FROM zacg_dashboard
              INTO TABLE @DATA(li_data)
              WHERE jobname   = @lv_jobname
                AND jobcount  = @lv_jobcount
                AND bname     <> @space
                AND rtype     = @abap_true.

            SORT li_data BY bname rlevel DESCENDING.
            DELETE ADJACENT DUPLICATES FROM li_data COMPARING bname rlevel.

            SELECT jobname,
                   jobcount,
                   bname,
                   risk,
                   riskd,
                   leveld,
                   moduled
              FROM @li_data AS core_data
              ORDER BY bname
              INTO TABLE @et_entityset[].


*            READ TABLE it_filter_select_options ASSIGNING <fs_filter>
*            WITH KEY property = 'Level'.
*            IF sy-subrc IS INITIAL.
*
*              READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_level>) INDEX 1.
*              IF sy-subrc IS INITIAL.
*
*                SELECT *
*                  FROM zacg_dashboard
*                  INTO TABLE @DATA(li_data)
*                  WHERE jobname   = @lv_jobname
*                    AND jobcount  = @lv_jobcount
*                    AND bname     <> @space
*                    AND rtype     = @abap_true.
*                IF sy-subrc IS INITIAL.
*
*                  SORT li_data BY bname rlevel DESCENDING.
*                  DELETE ADJACENT DUPLICATES FROM li_data COMPARING bname.
*
*                  IF <lfs_level>-low IS INITIAL.
*
*                    SELECT jobname,
*                           jobcount,
*                           bname,
*                           risk,
*                           riskd,
*                           leveld,
*                           moduled
*                      FROM @li_data AS core_data
*                      ORDER BY bname
*                      INTO TABLE @et_entityset[].
*
*                  ELSE.
*
*                    SELECT jobname,
*                           jobcount,
*                           bname,
*                           risk,
*                           riskd,
*                           leveld,
*                           moduled
*                      FROM @li_data AS core_data
*                      WHERE leveld = @<lfs_level>-low
*                      ORDER BY bname
*                      INTO TABLE @et_entityset[].
*
*                  ENDIF.
*
*                ELSE.
*
*                  " Invalid Filter values
*
*                ENDIF.
*
*              ELSE.
*
*                " No filter value for Level
*
*              ENDIF.
*
*            ELSE.
*
*              " No filter value for Level
*
*            ENDIF.

          ELSE.

            " No filter value for Jobcount

          ENDIF.

        ELSE.

          " No filter value for Jobcount

        ENDIF.

      ELSE.

        " No filter value for Jobname

      ENDIF.

    ELSE.

      " No filter value for jobname

    ENDIF.

  ENDMETHOD.


  METHOD criticaluserleve_get_entityset.

    DATA:
      lv_usercount TYPE i,
      lv_no_riskp  TYPE p DECIMALS 5,
      lv_criticalp TYPE p DECIMALS 5,
      lv_highp     TYPE p DECIMALS 5,
      lv_mediump   TYPE p DECIMALS 5,
      lv_lowp      TYPE p DECIMALS 5,
      li_data      TYPE STANDARD TABLE OF zacg_dashboard.

    SELECT _data~jobname, _data~jobcount
      FROM zacg_dashboard AS _data
      INNER JOIN tbtco AS _job
      ON _data~jobname = _job~jobname
      AND _data~jobcount = _job~jobcount
      AND _job~status = 'F'
      AND _data~bname IS NOT INITIAL
      ORDER BY erdat DESCENDING, ertim DESCENDING
      INTO @DATA(lwa_latest_job)
      UP TO 1 ROWS.
    ENDSELECT.

    SELECT *
      FROM zacg_dashboard
      WHERE jobname   = @lwa_latest_job-jobname
        AND jobcount  = @lwa_latest_job-jobcount
        AND rtype     = @abap_true
        AND bname     IS NOT INITIAL
    INTO TABLE @li_data.
    IF sy-subrc IS INITIAL.
      SORT li_data BY bname rlevel DESCENDING.
    ENDIF.

    SELECT DISTINCT COUNT( bname )
      FROM zacg_usr02
    INTO @DATA(lv_total_user).
    IF lv_total_user IS INITIAL.
      SELECT DISTINCT COUNT( bname )
        FROM usr02
        WHERE gltgv <= @sy-datum
          AND ( gltgb >= @sy-datum OR gltgb IS INITIAL )
          AND ustyp IN ('A','S')
          AND uflag IN (0,128)
        INTO @lv_total_user.
    ENDIF.


    DATA(li_data_unique_user) = li_data.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING FIELD-SYMBOL(<lfs_entityset>).
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '0'.
    <lfs_entityset>-level     = 'No Risk'.
    lv_usercount =  lv_total_user - lines( li_data_unique_user ).
    lv_no_riskp = lv_usercount / lv_total_user.
    lv_no_riskp = lv_no_riskp * 100.
    <lfs_entityset>-count     = lv_no_riskp.

    li_data_unique_user = li_data.
    DELETE li_data_unique_user WHERE rlevel NE 4.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '4'.
    <lfs_entityset>-level     = 'Critical'.
    lv_usercount =  lines( li_data_unique_user ).
    lv_criticalp =  lv_usercount / lv_total_user.
    lv_criticalp =  lv_criticalp * 100.
    <lfs_entityset>-count     = lv_criticalp.

    li_data_unique_user = li_data.
    DELETE li_data_unique_user WHERE rlevel NE 3.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '3'.
    <lfs_entityset>-level     = 'High'.
    lv_usercount =  lines( li_data_unique_user ).
    lv_highp =  lv_usercount / lv_total_user.
    lv_highp =  lv_highp * 100.
    <lfs_entityset>-count     = lv_highp.

    li_data_unique_user = li_data.
    DELETE li_data_unique_user WHERE rlevel NE 2.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '2'.
    <lfs_entityset>-level     = 'Medium'.
    lv_usercount =  lines( li_data_unique_user ).
    lv_mediump =  lv_usercount / lv_total_user.
    lv_mediump =  lv_mediump * 100.
    <lfs_entityset>-count     = lv_mediump.

    li_data_unique_user = li_data.
    DELETE li_data_unique_user WHERE rlevel NE 1.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '1'.
    <lfs_entityset>-level     = 'Low'.
    lv_usercount =  lines( li_data_unique_user ).
    lv_lowp =  lv_usercount / lv_total_user.
    lv_lowp =  lv_lowp * 100.
    <lfs_entityset>-count     = lv_lowp.

    SORT et_entityset[] BY levelid DESCENDING.


*    SELECT rlevel AS levelid, leveld AS level, COUNT( leveld ) AS count
*      FROM @li_data AS data
*      GROUP BY rlevel, leveld
*      INTO TABLE @DATA(li_level_count).
*
*    SELECT SUM( count )
*      FROM @li_level_count AS sum_count
*      INTO @DATA(lv_sum_count).
*
*    SELECT ddtext, domvalue_l
*      FROM dd07t
*      WHERE domname = 'ZRISK_LEVEL'
*        AND ddlanguage = @sy-langu
*    INTO TABLE @DATA(li_levels).
*
*    LOOP AT li_level_count INTO DATA(lwa_level_count).
*      APPEND INITIAL LINE TO et_entityset[] ASSIGNING FIELD-SYMBOL(<lfs_entityset>).
*      <lfs_entityset>-jobname   = lwa_latest_job-jobname.
*      <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
*      <lfs_entityset>-levelid   = lwa_level_count-levelid.
*      <lfs_entityset>-level     = lwa_level_count-level.
*      <lfs_entityset>-count     = lwa_level_count-count.
*    ENDLOOP.
*
*    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
*    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
*    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
*    <lfs_entityset>-levelid   = '0'.
*    <lfs_entityset>-level     = 'No Risk'.
*    <lfs_entityset>-count     = lv_total_user - lv_sum_count.
*
*    LOOP AT li_levels INTO DATA(lwa_levels).
*      READ TABLE et_entityset[] TRANSPORTING NO FIELDS WITH KEY levelid = lwa_levels-domvalue_l.
*      IF sy-subrc IS NOT INITIAL.
*        APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
*        <lfs_entityset>-jobname   = lwa_latest_job-jobname.
*        <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
*        <lfs_entityset>-levelid   = lwa_levels-domvalue_l.
*        <lfs_entityset>-level     = lwa_levels-ddtext.
*        <lfs_entityset>-count     = 0.
*      ENDIF.
*    ENDLOOP.
*
*    SORT et_entityset[] BY levelid DESCENDING.

  ENDMETHOD.


  METHOD sodroleprocess01_get_entityset.

    DATA:
      lv_jobname  TYPE btcjob,
      lv_jobcount TYPE btcjobcnt,
      lv_level    TYPE val_text,
      lv_module   TYPE val_text.

    READ TABLE it_filter_select_options ASSIGNING FIELD-SYMBOL(<fs_filter>)
    WITH KEY property = 'Jobname'.
    IF sy-subrc IS INITIAL.

      READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobname>) INDEX 1.
      IF sy-subrc IS INITIAL.

        lv_jobname = <lfs_jobname>-low.

        READ TABLE it_filter_select_options ASSIGNING <fs_filter>
        WITH KEY property = 'Jobcount'.
        IF sy-subrc IS INITIAL.

          READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobcount>) INDEX 1.
          IF sy-subrc IS INITIAL.

            lv_jobcount = <lfs_jobcount>-low.


            SELECT *
              FROM zacg_dashboard
              INTO TABLE @DATA(li_data)
              WHERE jobname   = @lv_jobname
                AND jobcount  = @lv_jobcount
                AND bname     = @space
                AND rtype     = @abap_false.

            SELECT jobname,
                   jobcount,
                   agr_name,
                   risk,
                   riskd,
                   leveld,
                   moduled
             FROM @li_data AS core_data
             ORDER BY agr_name
             INTO TABLE @et_entityset[].

            SORT et_entityset[] BY role risk.


*            READ TABLE it_filter_select_options ASSIGNING <fs_filter>
*            WITH KEY property = 'Level'.
*            IF sy-subrc IS INITIAL.
*
*              READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_level>) INDEX 1.
*              IF sy-subrc IS INITIAL.
*
*                lv_level = <lfs_level>-low.
*
*                READ TABLE it_filter_select_options ASSIGNING <fs_filter>
*                WITH KEY property = 'Process'.
*                IF sy-subrc IS INITIAL.
*
*                  READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_process>) INDEX 1.
*                  IF sy-subrc IS INITIAL.
*
*                    lv_module = <lfs_process>-low.
*
*                    SELECT *
*                      FROM zacg_dashboard
*                      INTO TABLE @DATA(li_data)
*                      WHERE jobname   = @lv_jobname
*                        AND jobcount  = @lv_jobcount
*                        AND bname     = @space
*                        AND moduled   = @lv_module
*                        AND rtype     = @abap_false.
*                    IF sy-subrc IS INITIAL.
*                      SORT li_data BY agr_name rlevel DESCENDING.
*                      DELETE ADJACENT DUPLICATES FROM li_data COMPARING agr_name.
*
*                      SELECT jobname,
*                             jobcount,
*                             agr_name,
*                             risk,
*                             riskd,
*                             leveld,
*                             moduled
*                       FROM @li_data AS core_data
*                       WHERE leveld = @lv_level
*                       ORDER BY agr_name
*                       INTO TABLE @et_entityset[].
*
*                      SORT et_entityset[] BY role risk.
*
*                    ELSE.
*
*                      " Invalid Filter values
*
*                    ENDIF.
*
*                  ELSE.
*
*                    " No filter value for Process
*
*                  ENDIF.
*
*                ELSE.
*
*                  " No filter value for Process
*
*                ENDIF.
*
*
*              ELSE.
*
*                " No filter value for Level
*
*              ENDIF.
*
*            ELSE.
*
*              " No filter value for Level
*
*            ENDIF.

          ELSE.

            " No filter value for Jobcount

          ENDIF.

        ELSE.

          " No filter value for Jobcount

        ENDIF.

      ELSE.

        " No filter value for Jobname

      ENDIF.

    ELSE.

      " No filter value for jobname

    ENDIF.


  ENDMETHOD.


  METHOD soduserleveldata_get_entityset.

    DATA:
      lv_jobname  TYPE btcjob,
      lv_jobcount TYPE btcjobcnt.

    READ TABLE it_filter_select_options ASSIGNING FIELD-SYMBOL(<fs_filter>)
    WITH KEY property = 'Jobname'.
    IF sy-subrc IS INITIAL.

      READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobname>) INDEX 1.
      IF sy-subrc IS INITIAL.

        lv_jobname = <lfs_jobname>-low.

        READ TABLE it_filter_select_options ASSIGNING <fs_filter>
        WITH KEY property = 'Jobcount'.
        IF sy-subrc IS INITIAL.

          READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_jobcount>) INDEX 1.
          IF sy-subrc IS INITIAL.

            lv_jobcount = <lfs_jobcount>-low.

            SELECT *
              FROM zacg_dashboard
              INTO TABLE @DATA(li_data)
              WHERE jobname   = @lv_jobname
                AND jobcount  = @lv_jobcount
                AND bname     <> @space
                AND rtype     = @space.

            SORT li_data BY bname rlevel DESCENDING.
            DELETE ADJACENT DUPLICATES FROM li_data COMPARING bname rlevel.


            SELECT jobname,
                   jobcount,
                   bname,
                   risk,
                   riskd,
                   leveld,
                   moduled
              FROM @li_data AS core_data
              ORDER BY bname
              INTO TABLE @et_entityset[].



*            READ TABLE it_filter_select_options ASSIGNING <fs_filter>
*            WITH KEY property = 'Level'.
*            IF sy-subrc IS INITIAL.
*
*              READ TABLE <fs_filter>-select_options ASSIGNING FIELD-SYMBOL(<lfs_level>) INDEX 1.
*              IF sy-subrc IS INITIAL.
*
*                SELECT *
*                  FROM zacg_dashboard
*                  INTO TABLE @DATA(li_data)
*                  WHERE jobname   = @lv_jobname
*                    AND jobcount  = @lv_jobcount
*                    AND bname     <> @space
**                    AND leveld    = @<lfs_level>-low
*                    AND rtype     = @space.
*                IF sy-subrc IS INITIAL.
*
*                  SORT li_data BY bname rlevel DESCENDING.
*                  DELETE ADJACENT DUPLICATES FROM li_data COMPARING bname.
*
*                  IF <lfs_level>-low IS INITIAL.
*                    SELECT jobname,
*                           jobcount,
*                           bname,
*                           risk,
*                           riskd,
*                           leveld,
*                           moduled
*                      FROM @li_data AS core_data
**                    WHERE leveld = @<lfs_level>-low
*                      ORDER BY bname
*                      INTO TABLE @et_entityset[].
*                  ELSE.
*                    SELECT jobname,
*                           jobcount,
*                           bname,
*                           risk,
*                           riskd,
*                           leveld,
*                           moduled
*                      FROM @li_data AS core_data
*                      WHERE leveld = @<lfs_level>-low
*                      ORDER BY bname
*                      INTO TABLE @et_entityset[].
*                  ENDIF.
*
*
*                ELSE.
*
*                  " Invalid Filter values
*
*                ENDIF.
*
*              ELSE.
*
*                " No filter value for Level
*
*              ENDIF.
*
*            ELSE.
*
*              " No filter value for Level
*
*            ENDIF.

          ELSE.

            " No filter value for Jobcount

          ENDIF.

        ELSE.

          " No filter value for Jobcount

        ENDIF.

      ELSE.

        " No filter value for Jobname

      ENDIF.

    ELSE.

      " No filter value for jobname

    ENDIF.

  ENDMETHOD.


  METHOD soduserlevelgrap_get_entityset.

    DATA:
      lv_usercount TYPE i,
      lv_no_riskp  TYPE p DECIMALS 5,
      lv_criticalp TYPE p DECIMALS 5,
      lv_highp     TYPE p DECIMALS 5,
      lv_mediump   TYPE p DECIMALS 5,
      lv_lowp      TYPE p DECIMALS 5,
      li_data      TYPE STANDARD TABLE OF zacg_dashboard.

    SELECT _data~jobname, _data~jobcount
      FROM zacg_dashboard AS _data
      INNER JOIN tbtco AS _job
      ON _data~jobname = _job~jobname
      AND _data~jobcount = _job~jobcount
      AND _job~status = 'F'
      AND _data~bname IS NOT INITIAL
      ORDER BY erdat DESCENDING, ertim DESCENDING
      INTO @DATA(lwa_latest_job)
      UP TO 1 ROWS.
    ENDSELECT.

    SELECT *
      FROM zacg_dashboard
      WHERE jobname   = @lwa_latest_job-jobname
        AND jobcount  = @lwa_latest_job-jobcount
        AND rtype     = @abap_false
        AND bname     IS NOT INITIAL
    INTO TABLE @li_data.
    IF sy-subrc IS INITIAL.
      SORT li_data BY bname rlevel DESCENDING.
    ENDIF.

    SELECT DISTINCT COUNT( bname )
      FROM zacg_usr02
    INTO @DATA(lv_total_user).
    IF lv_total_user IS INITIAL.
      SELECT DISTINCT COUNT( bname )
        FROM usr02
        WHERE gltgv <= @sy-datum
          AND ( gltgb >= @sy-datum OR gltgb IS INITIAL )
          AND ustyp IN ('A','S')
          AND uflag IN (0,128)
        INTO @lv_total_user.
    ENDIF.

    DATA(li_data_unique_user) = li_data.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING FIELD-SYMBOL(<lfs_entityset>).
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '0'.
    <lfs_entityset>-level     = 'No Risk'.
    lv_usercount =  lv_total_user - lines( li_data_unique_user ).
    lv_no_riskp = lv_usercount / lv_total_user.
    lv_no_riskp = lv_no_riskp * 100.
    <lfs_entityset>-count     = lv_no_riskp.

    li_data_unique_user = li_data.
    DELETE li_data_unique_user WHERE rlevel NE 4.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '4'.
    <lfs_entityset>-level     = 'Critical'.
    lv_usercount =  lines( li_data_unique_user ).
    lv_criticalp =  lv_usercount / lv_total_user.
    lv_criticalp =  lv_criticalp * 100.
    <lfs_entityset>-count     = lv_criticalp.

    li_data_unique_user = li_data.
    DELETE li_data_unique_user WHERE rlevel NE 3.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '3'.
    <lfs_entityset>-level     = 'High'.
    lv_usercount =  lines( li_data_unique_user ).
    lv_highp =  lv_usercount / lv_total_user.
    lv_highp =  lv_highp * 100.
    <lfs_entityset>-count     = lv_highp.

    li_data_unique_user = li_data.
    DELETE li_data_unique_user WHERE rlevel NE 2.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '2'.
    <lfs_entityset>-level     = 'Medium'.
    lv_usercount =  lines( li_data_unique_user ).
    lv_mediump =  lv_usercount / lv_total_user.
    lv_mediump =  lv_mediump * 100.
    <lfs_entityset>-count     = lv_mediump.

    li_data_unique_user = li_data.
    DELETE li_data_unique_user WHERE rlevel NE 1.
    SORT li_data_unique_user BY bname.
    DELETE ADJACENT DUPLICATES FROM li_data_unique_user COMPARING bname.
    APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
    <lfs_entityset>-jobname   = lwa_latest_job-jobname.
    <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
    <lfs_entityset>-levelid   = '1'.
    <lfs_entityset>-level     = 'Low'.
    lv_usercount =  lines( li_data_unique_user ).
    lv_lowp =  lv_usercount / lv_total_user.
    lv_lowp =  lv_lowp * 100.
    <lfs_entityset>-count     = lv_lowp.



*    SELECT rlevel AS levelid, leveld AS level, COUNT( leveld ) AS count
*      FROM @li_data AS data
*      GROUP BY rlevel, leveld
*      INTO TABLE @DATA(li_level_count).
*
*    SELECT SUM( count )
*      FROM @li_level_count AS sum_count
*      INTO @DATA(lv_sum_count).
*
*    SELECT ddtext, domvalue_l
*      FROM dd07t
*      WHERE domname = 'ZRISK_LEVEL'
*        AND ddlanguage = @sy-langu
*    INTO TABLE @DATA(li_levels).
*
*    LOOP AT li_level_count INTO DATA(lwa_level_count).
*      APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
*      <lfs_entityset>-jobname   = lwa_latest_job-jobname.
*      <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
*      <lfs_entityset>-levelid   = lwa_level_count-levelid.
*      <lfs_entityset>-level     = lwa_level_count-level.
*      <lfs_entityset>-count     = lwa_level_count-count.
*    ENDLOOP.
*
*
*
*    LOOP AT li_levels INTO DATA(lwa_levels).
*      READ TABLE et_entityset[] TRANSPORTING NO FIELDS WITH KEY levelid = lwa_levels-domvalue_l.
*      IF sy-subrc IS NOT INITIAL.
*        APPEND INITIAL LINE TO et_entityset[] ASSIGNING <lfs_entityset>.
*        <lfs_entityset>-jobname   = lwa_latest_job-jobname.
*        <lfs_entityset>-jobcount  = lwa_latest_job-jobcount.
*        <lfs_entityset>-levelid   = lwa_levels-domvalue_l.
*        <lfs_entityset>-level     = lwa_levels-ddtext.
*        <lfs_entityset>-count     = 0.
*      ENDIF.
*    ENDLOOP.

    SORT et_entityset[] BY levelid DESCENDING.

  ENDMETHOD.
ENDCLASS.
