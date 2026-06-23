FUNCTION zacg_user_roles.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IT_USERS) TYPE  ZACG_T_USER_SET
*"     VALUE(IT_LEVEL) TYPE  ZACG_T_LEVEL OPTIONAL
*"     VALUE(IT_MODULE) TYPE  ZACG_T_MODULE OPTIONAL
*"     VALUE(IV_SUMMARY) TYPE  FLAG OPTIONAL
*"     VALUE(IV_DETAIL) TYPE  FLAG OPTIONAL
*"  EXPORTING
*"     VALUE(ET_RISK_SUMMARY) TYPE  ZACG_T_RISK_SUMMARY
*"     VALUE(ET_RISK_DETAIL) TYPE  ZACG_T_RISK_DETAIL
*"----------------------------------------------------------------------

  TYPES : BEGIN OF lty_pfcg,
            agr_name TYPE agr_name,
            object   TYPE agobject,
            auth     TYPE agauth,
            field	   TYPE agrfield,
            low	     TYPE agval,
            high     TYPE agval,
          END OF lty_pfcg,

          BEGIN OF lty_usobhash,
            name     TYPE xupname,
            type     TYPE usobtype,
            obj_name TYPE char50,
          END OF lty_usobhash,

          BEGIN OF lty_lib_serv,
            tcode TYPE zacg_tcode,
          END OF lty_lib_serv,

          BEGIN OF lty_tcode_func,
            composite TYPE agr_name,
            agr_name  TYPE agr_name,
            risk      TYPE zrisk,
            riskd     TYPE zrisk_descr,
            func      TYPE zfunc,
            funcd     TYPE zfunc_descr,
            tcode     TYPE zacg_tcode,
            auth      TYPE agauth,
          END OF lty_tcode_func,

          BEGIN OF lty_serv_map,
            name     TYPE xupname,
            obj_name TYPE char50,
            tcode    TYPE zacg_tcode,
          END OF lty_serv_map.


  DATA:

    lv_func_not_found              TYPE flag,
    lv_object                      TYPE agobject,
    lv_field                       TYPE agrfield,
    lv_service                     TYPE sobj_name,
    lv_single_role_obj_not_covered TYPE flag,

    lr_pfcg_serv                   TYPE RANGE OF zacg_tcode,
    lr_lib_srvc                    TYPE RANGE OF zacg_tcode,
    lr_lib_tcode                   TYPE RANGE OF zacg_tcode,
    lr_tcode                       TYPE RANGE OF zacg_tcode,
    lr_tcode1                      TYPE RANGE OF zacg_tcode,
    lr_serv                        TYPE RANGE OF zacg_tcode,
    lr_func                        TYPE RANGE OF zfunc,
    lr_role                        TYPE RANGE OF agr_name,
    lr_object                      TYPE RANGE OF agobject,
    lr_auth                        TYPE RANGE OF agauth,
    lr_field                       TYPE RANGE OF agrfield,
    lr_low                         TYPE RANGE OF agval,
    lr_risk                        TYPE RANGE OF zrisk,
    lr_risk_func                   TYPE RANGE OF zrisk,
    lr_agr_name                    TYPE RANGE OF agr_name,

    lit_pfcg_tmp                   TYPE STANDARD TABLE OF lty_pfcg,
    lit_pfcg_tcd                   TYPE STANDARD TABLE OF lty_pfcg,
    lit_agrtcode                   TYPE STANDARD TABLE OF lty_pfcg,
    lit_agr_srv                    TYPE STANDARD TABLE OF lty_pfcg,
    lit_srv_lib_fval               TYPE STANDARD TABLE OF lty_usobhash,
    lit_lib_serv                   TYPE STANDARD TABLE OF lty_lib_serv,
    lit_potential_risk             TYPE zacg_t_potential_risk,
    lit_potential_risk1            TYPE zacg_t_potential_risk,
    lit_potential_risk2            TYPE zacg_t_potential_risk,
    lit_potential_risk3            TYPE zacg_t_potential_risk,
    lit_tcode_func                 TYPE STANDARD TABLE OF lty_tcode_func,
    lit_serv_map                   TYPE STANDARD TABLE OF lty_serv_map.

  CLEAR: et_risk_summary, et_risk_detail.

  " Get Tcodes and Services asscociated for all child roles
  SELECT agr_name, object, auth, field, low, high
    FROM agr_1251
    FOR ALL ENTRIES IN @it_users
    WHERE agr_name  EQ @it_users-child_agr
      AND ( object = 'S_TCODE' OR object = 'S_SERVICE' )
      AND ( field  = 'TCD' OR field = 'SRV_NAME' )
      AND deleted   EQ @space
  INTO TABLE @DATA(lit_agrts).
  IF sy-subrc IS INITIAL.

    DATA(lit_srvice_tcode) = lit_agrts.

    " Get all Risk Library data
    SELECT *
      FROM zacg_risk_lib
      WHERE inact = @space
      INTO TABLE @DATA(lit_risk_lib).
    IF sy-subrc IS INITIAL.
      lr_lib_tcode  = VALUE #( FOR lwa_risk_lib IN lit_risk_lib ( sign = 'I' option = 'EQ' low = lwa_risk_lib-tcode ) ).
      SORT lr_lib_tcode BY low.
      DELETE ADJACENT DUPLICATES FROM lr_lib_tcode COMPARING low.
      DELETE lr_lib_tcode WHERE low IS INITIAL.
    ENDIF.

    lit_agrtcode = VALUE #( FOR ls_pfcg IN lit_agrts WHERE ( object = 'S_TCODE' AND field = 'TCD' )
    ( low = ls_pfcg-low high = ls_pfcg-high ) ).

    lit_agr_srv = VALUE #( FOR ls_pfcg IN lit_agrts WHERE ( object = 'S_SERVICE' AND field = 'SRV_NAME' )
    ( low = ls_pfcg-low ) ).

    IF lit_agr_srv IS NOT INITIAL.
      lr_pfcg_serv = VALUE #( FOR ls_pfcg_serv IN lit_agr_srv ( sign = 'I' option = 'CP' low = ls_pfcg_serv-low ) ).
      SORT lr_pfcg_serv BY low.
      DELETE ADJACENT DUPLICATES FROM lr_pfcg_serv COMPARING low.
      DELETE lr_pfcg_serv WHERE low IS INITIAL.
    ENDIF.
    CLEAR lit_agr_srv.

    IF lr_pfcg_serv IS NOT INITIAL.
      SELECT name, type, obj_name
        FROM usobhash
        WHERE name IN @lr_pfcg_serv
          AND type = 'HT'
      ORDER BY obj_name
      INTO TABLE @lit_srv_lib_fval.

      DELETE lit_srv_lib_fval WHERE obj_name IS INITIAL.

      SELECT DISTINCT tcode
        FROM @lit_risk_lib AS lib_master
        WHERE tcode LIKE '[SVC]%'
          AND inact = @space
      INTO TABLE @lit_lib_serv.

      LOOP AT lit_srv_lib_fval INTO DATA(lwa_srv_lib_fval).
        DATA(lv_obj_name) = lwa_srv_lib_fval-obj_name.
        LOOP AT lit_lib_serv INTO DATA(lwa_lib_serv).
          DATA(lv_srv_tcode) = lwa_lib_serv-tcode.
          SHIFT lv_srv_tcode LEFT BY 5 PLACES.
          lv_srv_tcode = |{ lv_srv_tcode }| & |*|.
          IF lv_obj_name CP lv_srv_tcode.
            APPEND INITIAL LINE TO lr_lib_srvc ASSIGNING FIELD-SYMBOL(<lfs_lib_srvc>).
            <lfs_lib_srvc>-sign   = 'I'.
            <lfs_lib_srvc>-option = 'CP'.
            <lfs_lib_srvc>-low    = lwa_lib_serv-tcode.
            APPEND INITIAL LINE TO lit_serv_map ASSIGNING FIELD-SYMBOL(<lfs_serv_map>).
            <lfs_serv_map>-name     = lwa_srv_lib_fval-name.
            <lfs_serv_map>-obj_name = lwa_srv_lib_fval-obj_name.
            <lfs_serv_map>-tcode    = lwa_lib_serv-tcode.
          ENDIF.
        ENDLOOP.
      ENDLOOP.

      SORT lr_lib_srvc BY low.
      DELETE ADJACENT DUPLICATES FROM lr_lib_srvc COMPARING low.
      DELETE lr_lib_srvc WHERE low IS INITIAL.
    ENDIF.

    " Fill with possible values where range or * given in TCode in PFCG
    LOOP AT lit_agrtcode INTO DATA(lwa_agrtcode).

      CLEAR lr_tcode.

      IF lwa_agrtcode-high IS INITIAL AND lwa_agrtcode-low NA '*'. " Only Low with exact value
        READ TABLE lr_lib_tcode TRANSPORTING NO FIELDS WITH KEY low = lwa_agrtcode-low BINARY SEARCH.
        IF sy-subrc IS INITIAL.
          APPEND INITIAL LINE TO lit_pfcg_tcd ASSIGNING FIELD-SYMBOL(<lfs_pfcg>).
          <lfs_pfcg> = lwa_agrtcode.
          CONTINUE.
        ENDIF.
      ENDIF.

      IF lwa_agrtcode-high IS NOT INITIAL.
        lr_tcode = VALUE #( ( sign = 'I' option = 'BT' low = lwa_agrtcode-low high = lwa_agrtcode-high ) ).
      ELSEIF lwa_agrtcode-low CA '*'.
        lr_tcode = VALUE #( ( sign = 'I' option = 'CP' low = lwa_agrtcode-low ) ).
      ENDIF.

      IF lr_tcode IS NOT INITIAL.
        SELECT DISTINCT tcode
        FROM @lit_risk_lib AS tcode_lib
        WHERE tcode IN @lr_tcode
        INTO TABLE @DATA(lit_tcode_lib).
        IF sy-subrc IS INITIAL.
          lit_pfcg_tmp = VALUE #( FOR lwa_tcode_lib IN lit_tcode_lib (
                         low      = lwa_tcode_lib-tcode ) ).
          APPEND LINES OF lit_pfcg_tmp TO lit_pfcg_tcd.
          CLEAR lit_pfcg_tmp.
        ENDIF.
      ENDIF.

    ENDLOOP.
    CLEAR lit_agrtcode.
    IF lit_pfcg_tcd IS NOT INITIAL.
      lr_tcode  = VALUE #( FOR ls_tcode IN lit_pfcg_tcd ( sign = 'I' option = 'EQ' low = ls_tcode-low ) ).
      CLEAR lit_pfcg_tcd.
      SORT lr_tcode BY low.
      DELETE ADJACENT DUPLICATES FROM lr_tcode COMPARING low.
      DELETE lr_tcode WHERE low IS INITIAL.
    ENDIF.

    APPEND LINES OF lr_lib_srvc TO lr_tcode.

    IF lr_tcode IS NOT INITIAL.

      LOOP AT it_users[] INTO DATA(lwa_users).

        CALL FUNCTION 'ZACG_COMPOSITE_ROLE'
          EXPORTING
            iv_role           = lwa_users-child_agr
            it_tcode          = lr_tcode
          IMPORTING
            et_potential_risk = lit_potential_risk.

        APPEND LINES OF lit_potential_risk TO lit_potential_risk1.
        CLEAR lit_potential_risk.

      ENDLOOP.

      SORT lit_potential_risk1.
      DELETE ADJACENT DUPLICATES FROM lit_potential_risk1 COMPARING ALL FIELDS.

      SORT lit_potential_risk1 BY lib_func lib_tcode.

      lr_tcode = VALUE #( FOR ls_potential_risk IN lit_potential_risk1 ( sign = 'I' option = 'EQ' low = ls_potential_risk-lib_tcode ) ).
      SORT lr_tcode BY low.
      DELETE ADJACENT DUPLICATES FROM lr_tcode COMPARING low.
      DELETE lr_tcode WHERE low IS INITIAL.

      lr_func = VALUE #( FOR ls_potential_risk IN lit_potential_risk1 ( sign = 'I' option = 'EQ' low = ls_potential_risk-lib_func ) ).
      SORT lr_func BY low.
      DELETE ADJACENT DUPLICATES FROM lr_func COMPARING low.
      DELETE lr_func WHERE low IS INITIAL.

      IF lr_func IS NOT INITIAL AND lr_tcode IS NOT INITIAL.
        SELECT *
          FROM @lit_risk_lib AS lib_filter
          WHERE func IN @lr_func
            AND tcode IN @lr_tcode
        INTO TABLE @lit_risk_lib.

        LOOP AT lr_func INTO DATA(lwa_func).

          SELECT *
            FROM @lit_risk_lib AS lib_func
            WHERE func EQ @lwa_func-low
          INTO TABLE @DATA(lit_risk_lib_func).

          lr_tcode = VALUE #( FOR ls_risk_lib_func IN lit_risk_lib_func ( sign = 'I' option = 'EQ' low = ls_risk_lib_func-tcode ) ).
          SORT lr_tcode BY low.
          DELETE ADJACENT DUPLICATES FROM lr_tcode COMPARING low.
          DELETE lr_tcode WHERE low IS INITIAL.


          LOOP AT lr_tcode INTO DATA(lwa_tcode).

            SELECT *
              FROM @lit_risk_lib_func AS lib_tcode
              WHERE tcode EQ @lwa_tcode-low
            INTO TABLE @DATA(lit_risk_lib_func_tcode).

            lr_object = VALUE #( FOR lwa_risk_lib_func_tcode IN lit_risk_lib_func_tcode ( sign = 'I' option = 'EQ' low = lwa_risk_lib_func_tcode-object ) ).
            SORT lr_object BY low.
            DELETE ADJACENT DUPLICATES FROM lr_object COMPARING low.
            DELETE lr_object WHERE low IS INITIAL.

            SELECT *
              FROM @lit_potential_risk1 AS pfcg_filter
              WHERE lib_func  = @lwa_func-low
                AND lib_tcode = @lwa_tcode-low
                AND lib_object IN @lr_object
            INTO TABLE @lit_potential_risk.

            IF sy-subrc IS INITIAL.

*              LOOP AT lr_object INTO DATA(lwa_object).
*
*                READ TABLE lit_potential_risk TRANSPORTING NO FIELDS WITH KEY lib_object = lwa_object-low.
*                IF sy-subrc IS NOT INITIAL.
*                  DELETE lit_potential_risk1 WHERE lib_func = lwa_func-low AND lib_tcode = lwa_tcode-low.
*                  EXIT.
*                ENDIF.
*
*              ENDLOOP.

              lr_agr_name = VALUE #( FOR lwa_potential_risk_role IN lit_potential_risk (
                sign    = 'I'
                option  = 'EQ'
                low     = lwa_potential_risk_role-pfcg_agr_name ) ).
              SORT lr_agr_name BY low.
              DELETE ADJACENT DUPLICATES FROM lr_agr_name COMPARING low.

              IF lines( lr_agr_name ) > 1. " When Multiple Role Involved

                LOOP AT lr_agr_name INTO DATA(lwa_agr_name).

                  DATA(lv_role_tabix) = sy-tabix.

                  CLEAR lv_single_role_obj_not_covered.

                  SELECT *
                  FROM @lit_potential_risk AS pfcg_role_level_filter
                  WHERE pfcg_agr_name = @lwa_agr_name-low
                  INTO TABLE @DATA(lit_potential_risk_role_level).

                  LOOP AT lr_object INTO DATA(lwa_object).

                    READ TABLE lit_potential_risk_role_level INTO DATA(lwa_potential_risk_role_level)
                    WITH KEY lib_object = lwa_object-low.
                    IF sy-subrc IS NOT INITIAL.
                      lv_single_role_obj_not_covered = abap_true.
                      APPEND LINES OF lit_potential_risk_role_level TO lit_potential_risk3.
                      DELETE lit_potential_risk1 WHERE lib_func = lwa_func-low AND lib_tcode = lwa_tcode-low.
                      EXIT.
                    ENDIF.

                  ENDLOOP.

                  IF lv_single_role_obj_not_covered = abap_false.
                    DELETE lit_potential_risk1 WHERE
                    lib_func      = lwa_func-low AND
                    lib_tcode     = lwa_tcode-low AND
                    pfcg_agr_name = lwa_agr_name-low.

                    APPEND LINES OF lit_potential_risk_role_level TO lit_potential_risk2.
                  ENDIF.

                  IF lv_role_tabix EQ lines( lr_agr_name ).
                    APPEND LINES OF lit_potential_risk2 TO lit_potential_risk1.
                    CLEAR lit_potential_risk2.
                    LOOP AT lr_object INTO DATA(lwa_object1).
                      READ TABLE lit_potential_risk3 TRANSPORTING NO FIELDS WITH KEY lib_object = lwa_object1-low.
                      IF sy-subrc IS NOT INITIAL.
                        CLEAR lit_potential_risk3.
                        EXIT.
                      ENDIF.
                    ENDLOOP.
                    APPEND LINES OF lit_potential_risk3 TO lit_potential_risk1.
                    CLEAR lit_potential_risk3.
                  ENDIF.

                ENDLOOP.

              ELSE. " When Single Role is found

                LOOP AT lr_object INTO lwa_object.

                  READ TABLE lit_potential_risk TRANSPORTING NO FIELDS WITH KEY lib_object = lwa_object-low.
                  IF sy-subrc IS NOT INITIAL.
                    lv_single_role_obj_not_covered = abap_true.
                    DELETE lit_potential_risk1 WHERE lib_func = lwa_func-low AND lib_tcode = lwa_tcode-low.
                    EXIT.
                  ENDIF.

                ENDLOOP.

              ENDIF.


            ENDIF.

          ENDLOOP.

        ENDLOOP.

        lr_func = VALUE #( FOR ls_potential_risk IN lit_potential_risk1 ( sign = 'I' option = 'EQ' low = ls_potential_risk-lib_func ) ).
        SORT lr_func BY low.
        DELETE ADJACENT DUPLICATES FROM lr_func COMPARING low.
        DELETE lr_func WHERE low IS INITIAL.

        IF lr_func IS NOT INITIAL.

          CLEAR lit_potential_risk.

          " Get all Risk associated with identified functiona
          SELECT *
            FROM zacg_risk_comb
            WHERE func IN @lr_func
          INTO TABLE @DATA(lit_risk).
          IF sy-subrc IS INITIAL.
            lr_risk = VALUE #( FOR ls_risk IN lit_risk ( sign = 'I' option = 'EQ' low = ls_risk-risk ) ).
            SORT lr_risk BY low.
            DELETE ADJACENT DUPLICATES FROM lr_risk COMPARING low.
            DELETE lr_risk WHERE low IS INITIAL.
          ENDIF.

          CHECK lr_risk IS NOT INITIAL.

          " Get the complete combination of the Risk
          SELECT *
            FROM zacg_risk_comb
            WHERE risk IN @lr_risk
          ORDER BY risk
          INTO TABLE @lit_risk.
          IF sy-subrc IS INITIAL.

            " Get unique Risk IDs
            DATA(lit_risk_sod) = lit_risk.

            " Sepated Critical Authorization Risk
            DATA(lit_risk_crit) = lit_risk.
            DELETE lit_risk_crit WHERE crit EQ abap_false.

            " Sepated Combination Risks
            DELETE lit_risk_sod WHERE crit EQ abap_true.
            lr_risk = VALUE #( FOR ls_risk IN lit_risk_sod ( sign = 'I' option = 'EQ' low = ls_risk-risk ) ).
            SORT lr_risk BY low.
            DELETE ADJACENT DUPLICATES FROM lr_risk COMPARING low.
            DELETE lr_risk WHERE low IS INITIAL.

          ENDIF.

          " Check for Combination Risk
          LOOP AT lr_risk INTO DATA(lwa_unique_risk).

            " Get function ids for speacific Risk
            SELECT *
              FROM @lit_risk_sod AS sod_check
              WHERE risk = @lwa_unique_risk-low
            INTO TABLE @DATA(lit_risk_combo).
            IF sy-subrc IS INITIAL.

              lr_risk_func = VALUE #( FOR ls_risk_combo IN lit_risk_combo ( sign = 'I' option = 'EQ' low = ls_risk_combo-func ) ).
              SORT lr_risk_func BY low.
              DELETE ADJACENT DUPLICATES FROM lr_risk_func COMPARING low.
              DELETE lr_risk_func WHERE low IS INITIAL.

              CLEAR lv_func_not_found.

              LOOP AT lr_risk_func INTO DATA(lwa_risk_func).

                READ TABLE lit_potential_risk1 TRANSPORTING NO FIELDS WITH KEY lib_func = lwa_risk_func-low.
                IF sy-subrc IS NOT INITIAL.
                  lv_func_not_found = abap_true.
                ENDIF.

              ENDLOOP.

              IF lv_func_not_found = abap_false.
                SELECT *
                  FROM @lit_potential_risk1 AS potential_risk
                  WHERE lib_func IN @lr_risk_func
                INTO TABLE @DATA(lit_risk_func).
                LOOP AT lit_risk_func ASSIGNING FIELD-SYMBOL(<lfs_risk_func>).
                  <lfs_risk_func>-risk = lwa_unique_risk-low.
                  APPEND <lfs_risk_func> TO lit_potential_risk.
                ENDLOOP.
              ENDIF.

            ENDIF.

          ENDLOOP.

          " Check for Critical Risk
          SORT lit_potential_risk1 BY lib_func.
          LOOP AT lit_risk_crit INTO DATA(lwa_risk_crit).
            READ TABLE lit_potential_risk1 TRANSPORTING NO FIELDS WITH KEY lib_func = lwa_risk_crit-func BINARY SEARCH.
            IF sy-subrc IS INITIAL.
              DATA(lv_index) =  sy-tabix.
              LOOP AT lit_potential_risk1 ASSIGNING FIELD-SYMBOL(<lfs_potential_risk>) FROM lv_index.
                IF <lfs_potential_risk>-lib_func NE lwa_risk_crit-func.
                  EXIT.
                ELSE.
                  <lfs_potential_risk>-risk = lwa_risk_crit-risk.
                  <lfs_potential_risk>-crit = abap_true.
                  APPEND <lfs_potential_risk> TO lit_potential_risk.
                ENDIF.
              ENDLOOP.
            ENDIF.
          ENDLOOP.

          CLEAR lit_potential_risk1.
          SORT lit_potential_risk.
          DELETE ADJACENT DUPLICATES FROM lit_potential_risk COMPARING ALL FIELDS.

          lr_risk = VALUE #( FOR ls_potential_risk IN lit_potential_risk ( sign = 'I' option = 'EQ' low = ls_potential_risk-risk ) ).
          SORT lr_risk BY low.
          DELETE ADJACENT DUPLICATES FROM lr_risk COMPARING low.
          DELETE lr_risk WHERE low IS INITIAL.
          IF lr_risk IS NOT INITIAL.
            SELECT *
              FROM zacg_risk_mstr
              WHERE risk IN @lr_risk
              AND rlevel IN @it_level
              AND rmodule IN @it_module
            ORDER BY risk
            INTO TABLE @DATA(lit_risk_mstr).

            SELECT *
            FROM dd07t
            INTO TABLE @DATA(lit_dd07t)
            WHERE domname IN ('ZRISK_LEVEL', 'ZRISK_PROC')
            ORDER BY domname, domvalue_l.

          ENDIF.

          SORT lit_potential_risk BY risk.
          READ TABLE it_users[] INTO lwa_users INDEX 1.

          LOOP AT lr_risk INTO DATA(lwa_risk).

            READ TABLE lit_potential_risk TRANSPORTING NO FIELDS WITH KEY risk = lwa_risk-low BINARY SEARCH.
            IF sy-subrc IS INITIAL.

              LOOP AT lit_potential_risk INTO DATA(lwa_potential_risk1) FROM sy-tabix.
                IF lwa_potential_risk1-risk NE lwa_risk-low.
                  EXIT.
                ENDIF.

                READ TABLE lit_risk_mstr INTO DATA(lwa_risk_mstr) WITH KEY risk = lwa_risk-low BINARY SEARCH.
                IF sy-subrc IS INITIAL.

                  APPEND INITIAL LINE TO et_risk_summary ASSIGNING FIELD-SYMBOL(<lfs_risk_summary>).
                  READ TABLE it_users[] INTO lwa_users WITH KEY child_agr = lwa_potential_risk1-pfcg_agr_name.
                  <lfs_risk_summary>-user       = lwa_users-bname.
                  <lfs_risk_summary>-composite  = lwa_users-agr_name.
                  <lfs_risk_summary>-agr_name   = lwa_potential_risk1-pfcg_agr_name.
                  <lfs_risk_summary>-risk       = lwa_risk-low.
                  <lfs_risk_summary>-type       = lwa_potential_risk1-crit.

                  <lfs_risk_summary>-riskd    = lwa_risk_mstr-riskd.
                  <lfs_risk_summary>-level    = lwa_risk_mstr-rlevel.
                  READ TABLE lit_dd07t INTO DATA(lwa_dd07t) WITH KEY domname = 'ZRISK_LEVEL'
                                                                     domvalue_l = <lfs_risk_summary>-level BINARY SEARCH.
                  IF sy-subrc IS INITIAL.
                    <lfs_risk_summary>-leveld = lwa_dd07t-ddtext.
                  ENDIF.

                  <lfs_risk_summary>-module   = lwa_risk_mstr-rmodule.
                  READ TABLE lit_dd07t INTO lwa_dd07t WITH KEY domname = 'ZRISK_PROC'
                                                               domvalue_l = <lfs_risk_summary>-module BINARY SEARCH.
                  IF sy-subrc IS INITIAL.
                    <lfs_risk_summary>-moduled = lwa_dd07t-ddtext.
                  ENDIF.

                  IF <lfs_risk_summary>-type IS NOT INITIAL.
                    <lfs_risk_summary>-typed = 'Critical Authorization'.
                  ELSE.
                    <lfs_risk_summary>-typed = 'Critical Combination'.
                  ENDIF.

                ENDIF.

              ENDLOOP.

            ENDIF.

          ENDLOOP.

          UNASSIGN <lfs_risk_summary>.
          LOOP AT lit_agrts ASSIGNING FIELD-SYMBOL(<lfs_agrts>).

            CLEAR: lv_object, lv_field, lit_potential_risk1.

            READ TABLE et_risk_summary TRANSPORTING NO FIELDS WITH KEY agr_name = <lfs_agrts>-agr_name.
            IF sy-subrc IS NOT INITIAL.

              IF <lfs_agrts>-high IS NOT INITIAL.
                lr_tcode = VALUE #( ( sign = 'I' option = 'BT' low = <lfs_agrts>-low high = <lfs_agrts>-high ) ).
              ELSEIF <lfs_agrts>-low CA '*'.
                lr_tcode = VALUE #( ( sign = 'I' option = 'CP' low = <lfs_agrts>-low ) ).
              ELSE.
                lr_tcode = VALUE #( ( sign = 'I' option = 'EQ' low = <lfs_agrts>-low ) ).
              ENDIF.

              IF <lfs_agrts>-object = 'S_SERVICE'.

                lv_object = 'S_SERVICE'.
                lv_field  = 'SRV_NAME'.


                SELECT *
                  FROM @lit_srv_lib_fval AS service
                  WHERE name IN @lr_tcode
                INTO TABLE @DATA(lit_srv_tcode).

                SELECT DISTINCT lib_tcode
                  FROM @lit_potential_risk AS risk_service
                  WHERE lib_tcode LIKE '[SVC]%'
                INTO TABLE @lit_lib_serv.

                CLEAR lr_tcode.
                LOOP AT lit_lib_serv INTO lwa_lib_serv.
                  SHIFT lwa_lib_serv-tcode BY 5 PLACES.
                  CONCATENATE lwa_lib_serv-tcode '*' INTO lwa_lib_serv-tcode.
                  LOOP AT lit_srv_tcode INTO DATA(lwa_srv_tcode).
                    IF lwa_srv_tcode-obj_name CP lwa_lib_serv-tcode.
                      CONCATENATE '[SVC]' lwa_lib_serv-tcode INTO lwa_lib_serv-tcode.
                      APPEND INITIAL LINE TO lr_tcode ASSIGNING FIELD-SYMBOL(<lfs_tcode>).
                      <lfs_tcode>-sign    = 'I'.
                      <lfs_tcode>-option  = 'CP'.
                      <lfs_tcode>-low     = lwa_lib_serv-tcode.
                    ENDIF.
                  ENDLOOP.
                ENDLOOP.

                IF lr_tcode IS NOT INITIAL.
                  SELECT *
                    FROM @lit_potential_risk AS tcode_risk
                    WHERE lib_tcode IN @lr_tcode
                  INTO TABLE @lit_potential_risk1.

                ENDIF.

              ELSE.

                lv_object = 'S_TCODE'.
                lv_field  = 'TCD'.

                SELECT *
                  FROM @lit_potential_risk AS tcode_risk
                  WHERE lib_tcode IN @lr_tcode
                INTO TABLE @lit_potential_risk1.

              ENDIF.

              CHECK lit_potential_risk1 IS NOT INITIAL.

              READ TABLE lit_potential_risk1 INTO lwa_potential_risk1 INDEX 1.

              READ TABLE lit_potential_risk1 INTO lwa_potential_risk1 WITH KEY risk = lwa_potential_risk1-risk.
              IF sy-subrc IS INITIAL.
                READ TABLE lit_risk_mstr INTO lwa_risk_mstr WITH KEY risk = lwa_potential_risk1-risk BINARY SEARCH.
                IF sy-subrc IS INITIAL.

                  APPEND INITIAL LINE TO et_risk_summary ASSIGNING <lfs_risk_summary>.
                  READ TABLE it_users[] INTO lwa_users WITH KEY child_agr = <lfs_agrts>-agr_name.

                  <lfs_risk_summary>-user       = lwa_users-bname.
                  <lfs_risk_summary>-composite  = lwa_users-agr_name.
                  <lfs_risk_summary>-agr_name   = <lfs_agrts>-agr_name.
                  <lfs_risk_summary>-risk       = lwa_potential_risk1-risk.
                  <lfs_risk_summary>-type       = lwa_potential_risk1-crit.
                  <lfs_risk_summary>-riskd      = lwa_risk_mstr-riskd.
                  <lfs_risk_summary>-level      = lwa_risk_mstr-rlevel.
                  READ TABLE lit_dd07t INTO lwa_dd07t WITH KEY domname = 'ZRISK_LEVEL'
                                                               domvalue_l = <lfs_risk_summary>-level BINARY SEARCH.
                  IF sy-subrc IS INITIAL.
                    <lfs_risk_summary>-leveld = lwa_dd07t-ddtext.
                  ENDIF.
                  <lfs_risk_summary>-module   = lwa_risk_mstr-rmodule.
                  READ TABLE lit_dd07t INTO lwa_dd07t WITH KEY domname = 'ZRISK_PROC'
                                                               domvalue_l = <lfs_risk_summary>-module BINARY SEARCH.
                  IF sy-subrc IS INITIAL.
                    <lfs_risk_summary>-moduled = lwa_dd07t-ddtext.
                  ENDIF.

                  IF <lfs_risk_summary>-type IS NOT INITIAL.
                    <lfs_risk_summary>-typed = 'Critical Authorization'.
                  ELSE.
                    <lfs_risk_summary>-typed = 'Critical Combination'.
                  ENDIF.

                  APPEND INITIAL LINE TO lit_potential_risk2 ASSIGNING FIELD-SYMBOL(<lfs_potential_risk2>).
                  <lfs_potential_risk2>-pfcg_agr_name = <lfs_agrts>-agr_name.
                  <lfs_potential_risk2>-lib_object    = lv_object.
                  <lfs_potential_risk2>-lib_field     = lv_field.
                  <lfs_potential_risk2>-risk          = lwa_potential_risk1-risk.
                  <lfs_potential_risk2>-lib_func      = lwa_potential_risk1-lib_func.
                  <lfs_potential_risk2>-lib_low       = lwa_potential_risk1-lib_tcode.
                  <lfs_potential_risk2>-lib_tcode     = lwa_potential_risk1-lib_tcode.

                ENDIF.

              ELSE.

                CLEAR <lfs_agrts>-agr_name.  " Role does not contain risk

              ENDIF.
            ELSE.

              CLEAR <lfs_agrts>-agr_name. " Role already taken care

            ENDIF.

          ENDLOOP.

          DELETE lit_agrts WHERE agr_name IS INITIAL.

          IF iv_detail = abap_true.

            SORT et_risk_summary.
            DELETE ADJACENT DUPLICATES FROM et_risk_summary COMPARING ALL FIELDS.

            lr_role   = VALUE #( FOR ls_potential_risk IN lit_potential_risk ( sign = 'I' option = 'EQ'
                               low = ls_potential_risk-pfcg_agr_name ) ).
            SORT lr_role BY low.
            DELETE ADJACENT DUPLICATES FROM lr_role COMPARING low.
            DELETE lr_role WHERE low IS INITIAL.

            lr_object = VALUE #( FOR ls_potential_risk IN lit_potential_risk ( sign = 'I' option = 'EQ'
                               low = ls_potential_risk-pfcg_object ) ).
            SORT lr_object BY low.
            DELETE ADJACENT DUPLICATES FROM lr_object COMPARING low.
            DELETE lr_object WHERE low IS INITIAL.

            lr_auth   = VALUE #( FOR ls_potential_risk IN lit_potential_risk ( sign = 'I' option = 'EQ'
                               low = ls_potential_risk-pfcg_auth ) ).
            SORT lr_auth BY low.
            DELETE ADJACENT DUPLICATES FROM lr_auth COMPARING low.
            DELETE lr_auth WHERE low IS INITIAL.

            lr_field  = VALUE #( FOR ls_potential_risk IN lit_potential_risk ( sign = 'I' option = 'EQ'
                               low = ls_potential_risk-pfcg_field ) ).
            SORT lr_field BY low.
            DELETE ADJACENT DUPLICATES FROM lr_field COMPARING low.
            DELETE lr_field WHERE low IS INITIAL.

            LOOP AT lit_agrts ASSIGNING <lfs_agrts>.
              APPEND INITIAL LINE TO lr_role ASSIGNING FIELD-SYMBOL(<lfs_role>).
              <lfs_role>-sign = 'I'.
              <lfs_role>-option = 'EQ'.
              <lfs_role>-low = <lfs_agrts>-agr_name.
              APPEND INITIAL LINE TO lr_object ASSIGNING FIELD-SYMBOL(<lfs_object>).
              <lfs_object>-sign = 'I'.
              <lfs_object>-option = 'EQ'.
              <lfs_object>-low = <lfs_agrts>-object.
              APPEND INITIAL LINE TO lr_auth ASSIGNING FIELD-SYMBOL(<lfs_auth>).
              <lfs_auth>-sign = 'I'.
              <lfs_auth>-option = 'EQ'.
              <lfs_auth>-low = <lfs_agrts>-auth.
              APPEND INITIAL LINE TO lr_field ASSIGNING FIELD-SYMBOL(<lfs_field>).
              <lfs_field>-sign = 'I'.
              <lfs_field>-option = 'EQ'.
              <lfs_field>-low = <lfs_agrts>-field.
            ENDLOOP.

            lr_func  = VALUE #( FOR ls_potential_risk IN lit_potential_risk ( sign = 'I' option = 'EQ'
                               low = ls_potential_risk-lib_func ) ).
            SORT lr_func BY low.
            DELETE ADJACENT DUPLICATES FROM lr_func COMPARING low.
            DELETE lr_func WHERE low IS INITIAL.

            IF lr_func IS NOT INITIAL.
              SELECT *
                FROM zacg_funct
                WHERE func IN @lr_func
              ORDER BY func
              INTO TABLE @DATA(li_funct).
            ENDIF.

*            IF lr_role IS NOT INITIAL AND lr_object IS NOT INITIAL AND lr_auth IS NOT INITIAL AND lr_field IS NOT INITIAL.
            SELECT agr_name, object, auth, field, low, high
              FROM agr_1251
              WHERE agr_name  IN @lr_role
                AND object    IN ('S_TCODE','S_SERVICE')
                AND deleted   EQ @space
             ORDER BY agr_name, object
             INTO TABLE @DATA(lit_agr1251_detail).

            APPEND LINES OF lit_potential_risk2 TO lit_potential_risk.
            CLEAR lit_potential_risk2.

            SORT lit_potential_risk.
            DELETE ADJACENT DUPLICATES FROM lit_potential_risk COMPARING ALL FIELDS.

            SORT et_risk_summary  BY agr_name.
            SORT lit_potential_risk BY pfcg_agr_name.

            LOOP AT et_risk_summary INTO DATA(lwa_risk_summary).

              READ TABLE lit_potential_risk TRANSPORTING NO FIELDS WITH KEY pfcg_agr_name = lwa_risk_summary-agr_name.
              IF sy-subrc IS INITIAL.
                DATA(lv_tabix1) = sy-tabix.

                LOOP AT lit_potential_risk INTO DATA(lwa_potential_risk) FROM lv_tabix1.

                  IF lwa_potential_risk-pfcg_agr_name NE lwa_risk_summary-agr_name.
                    EXIT.
                  ELSE.

                    CHECK lwa_risk_summary-risk EQ lwa_potential_risk-risk.

                    APPEND INITIAL LINE TO et_risk_detail ASSIGNING FIELD-SYMBOL(<lfs_risk_detail>).

                    READ TABLE it_users[] INTO lwa_users WITH KEY child_agr = lwa_risk_summary-agr_name.
                    <lfs_risk_detail>-user      = lwa_users-bname.
                    <lfs_risk_detail>-composite = lwa_users-agr_name.
                    <lfs_risk_detail>-agr_name  = lwa_risk_summary-agr_name.
                    <lfs_risk_detail>-risk      = lwa_risk_summary-risk.
                    READ TABLE lit_risk_mstr INTO lwa_risk_mstr WITH KEY risk = lwa_risk_summary-risk BINARY SEARCH.
                    IF sy-subrc IS INITIAL.
                      <lfs_risk_detail>-riskd     = lwa_risk_mstr-riskd.
                    ENDIF.
                    <lfs_risk_detail>-func      = lwa_potential_risk-lib_func.
                    READ TABLE li_funct INTO DATA(lwa_funct) WITH KEY func = lwa_potential_risk-lib_func BINARY SEARCH.
                    IF sy-subrc IS INITIAL.
                      <lfs_risk_detail>-funcd   = lwa_funct-funcd.
                    ENDIF.
                    <lfs_risk_detail>-object    = lwa_potential_risk-lib_object.
                    <lfs_risk_detail>-field     = lwa_potential_risk-lib_field.
                    <lfs_risk_detail>-low       = lwa_potential_risk-lib_low.

                    IF lwa_potential_risk-lib_tcode(1) = '['.
                      SELECT *
                        FROM @lit_agr1251_detail AS service
                        WHERE agr_name EQ @lwa_risk_summary-agr_name
                          AND object = 'S_SERVICE'
                          AND field  = 'SRV_NAME'
                        INTO TABLE @DATA(lit_agr1251_service).
                      LOOP AT lit_agr1251_service INTO DATA(lwa_agr1251_service).
                        lv_service = lwa_potential_risk-lib_tcode.
                        REPLACE '[SVC]' WITH space INTO lv_service.
                        CONCATENATE lv_service '%' INTO lv_service.
                        SHIFT lv_service LEFT DELETING LEADING space.

                        SELECT SINGLE *
                          FROM @lit_srv_lib_fval AS single_service
                            WHERE obj_name LIKE @lv_service
                          INTO @DATA(lwa_service_tcode).
                        IF sy-subrc IS INITIAL.
                          <lfs_risk_detail>-tcode     = lwa_service_tcode-name.
                          EXIT.
                        ENDIF.

                      ENDLOOP.
                    ELSE.
                      CLEAR lr_low.
                      SELECT *
                        FROM @lit_agr1251_detail AS tcode
                        WHERE agr_name EQ @lwa_risk_summary-agr_name
                          AND object = 'S_TCODE'
                        INTO TABLE @DATA(lit_agr1251_tcode).
                      LOOP AT lit_agr1251_tcode INTO DATA(lwa_agr1251_tcode).
                        IF lwa_agr1251_tcode-high IS NOT INITIAL.
                          lr_low  = VALUE #( ( sign = 'I' option = 'BT' low = lwa_agr1251_tcode-low high = lwa_agr1251_tcode-high ) ).
                        ELSEIF lwa_agr1251_tcode-low CA '*'.
                          lr_low = VALUE #( ( sign = 'I' option = 'CP' low = lwa_agr1251_tcode-low ) ).
                        ELSE.
                          lr_low = VALUE #( ( sign = 'I' option = 'EQ' low = lwa_agr1251_tcode-low ) ).
                        ENDIF.

                        IF lwa_potential_risk-lib_tcode IN lr_low.
                          <lfs_risk_detail>-tcode     = lwa_potential_risk-lib_tcode.
                          EXIT.
                        ENDIF.

                      ENDLOOP.

                    ENDIF.

                  ENDIF.

                ENDLOOP.

              ENDIF.

              IF lines( et_risk_detail ) GE 100000.
                SORT et_risk_detail.
                DELETE ADJACENT DUPLICATES FROM et_risk_detail COMPARING ALL FIELDS.
              ENDIF.

            ENDLOOP.

          ENDIF.

        ENDIF.

      ENDIF.

    ENDIF.

  ENDIF.

  IF iv_detail IS NOT INITIAL.
    CLEAR et_risk_summary.
  ENDIF.
  SORT et_risk_summary  BY user composite agr_name risk.
  DELETE ADJACENT DUPLICATES FROM et_risk_summary COMPARING user composite agr_name risk.

  SORT et_risk_detail   BY user composite agr_name risk func tcode object field low high.
  DELETE ADJACENT DUPLICATES FROM et_risk_detail COMPARING user composite agr_name risk func tcode object field low high.


ENDFUNCTION.
