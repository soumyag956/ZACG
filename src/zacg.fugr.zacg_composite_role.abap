FUNCTION zacg_composite_role.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_ROLE) TYPE  AGR_NAME
*"     VALUE(IT_TCODE) TYPE  ZACG_T_TCODE
*"     VALUE(IV_DETAIL) TYPE  FLAG OPTIONAL
*"     VALUE(IV_SUMMARY) TYPE  FLAG OPTIONAL
*"  EXPORTING
*"     VALUE(ET_POTENTIAL_RISK) TYPE  ZACG_T_POTENTIAL_RISK
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

          BEGIN OF lty_join,
            pfcg_agr_name TYPE agr_name,
            pfcg_object   TYPE agobject,
            pfcg_auth     TYPE agauth,
            pfcg_field    TYPE agrfield,
            pfcg_low      TYPE agval,
            pfcg_high     TYPE agval,
            lib_func      TYPE zfunc,
            lib_tcode     TYPE zacg_tcode,
            lib_object    TYPE agobject,
            lib_field     TYPE agrfield,
            lib_low       TYPE agval,
            lib_high      TYPE agval,
            risk          TYPE zrisk,
            crit          TYPE flag,
          END OF lty_join.

  DATA:
    lv_tcode_rc         TYPE sy-subrc,
    lv_servc_rc         TYPE sy-subrc,
    lv_actvt_not_found  TYPE flag,
    lv_object_not_found TYPE flag,
    lv_func_not_found   TYPE flag,

    lr_tcode            TYPE RANGE OF zacg_tcode,
    lr_lib_tcode        TYPE RANGE OF zacg_tcode,
    lr_object_lib       TYPE RANGE OF agobject,
    lr_fval             TYPE RANGE OF agval,
    lr_pfcg_serv        TYPE RANGE OF zacg_tcode,
    lr_lib_srvc         TYPE RANGE OF zacg_tcode,
    lr_func             TYPE RANGE OF zfunc,
    lr_lib_obj          TYPE RANGE OF agobject,
    lr_instance         TYPE RANGE OF agauth,
    lr_risk             TYPE RANGE OF zrisk,
    lr_risk_no_sod      TYPE RANGE OF zrisk,
    lr_field            TYPE RANGE OF agrfield,
    lr_risk_func        TYPE RANGE OF zrisk,
    lr_low              TYPE RANGE OF agval,
    lr_pfcg_obj         TYPE RANGE OF agobject,
    lr_pfcg_field       TYPE RANGE OF agrfield,

    lit_pfcg_tmp        TYPE STANDARD TABLE OF lty_pfcg,
    lit_pfcg_tcd        TYPE STANDARD TABLE OF lty_pfcg,
    lit_pfcg            TYPE STANDARD TABLE OF lty_pfcg,
    lit_srv_lib_fval    TYPE STANDARD TABLE OF lty_usobhash,
    lit_join            TYPE STANDARD TABLE OF lty_join,
    lit_potential_obj   TYPE STANDARD TABLE OF lty_join,
    lit_potential_tcd   TYPE STANDARD TABLE OF lty_join,
    lit_potential_risk  TYPE STANDARD TABLE OF lty_join,
    lit_lib_serv        TYPE STANDARD TABLE OF lty_lib_serv.


  DATA:lit_agrtcode TYPE STANDARD TABLE OF lty_pfcg,
       lit_agr_srv  TYPE STANDARD TABLE OF lty_pfcg,
       lit_agr1251  TYPE STANDARD TABLE OF lty_pfcg.


  CLEAR et_potential_risk[].

  " Get Tcodes asscociated for the role
  SELECT agr_name, object, auth, field, low, high
    FROM agr_1251
    WHERE agr_name  EQ @iv_role
      AND ( object <> 'S_TCODE' AND object <> 'S_SERVICE' )
      AND deleted   EQ @space
  INTO TABLE @lit_agr1251.
  IF sy-subrc IS INITIAL.

    SELECT *
      FROM zacg_risk_lib
      WHERE tcode IN @it_tcode[]
        AND inact = @space
    INTO TABLE @DATA(lit_risk_lib).

    IF sy-subrc IS INITIAL.

      " Get details of exact field values for KOART
      READ TABLE lit_agr1251 TRANSPORTING NO FIELDS WITH KEY low = '$KOART'.
      IF sy-subrc IS INITIAL.

        " Get Actual values maintained for KOART
        SELECT agr_name,
               low,
               high
        FROM agr_1252
        WHERE agr_name EQ @iv_role
        AND varbl EQ '$KOART'
        ORDER BY agr_name
        INTO TABLE @DATA(lit_agr1252).
        IF sy-subrc IS INITIAL.
          lit_pfcg_tmp = lit_agr1251.
          DELETE lit_pfcg_tmp WHERE low NE '$KOART'.
          SORT lit_agr1252 BY agr_name.
          LOOP AT lit_pfcg_tmp INTO DATA(lwa_pfcg_tmp).
            LOOP AT lit_agr1252 INTO DATA(lwa_agr1252) WHERE agr_name = lwa_pfcg_tmp-agr_name.
              lwa_pfcg_tmp-low  = lwa_agr1252-low.
              lwa_pfcg_tmp-high = lwa_agr1252-high.
              APPEND lwa_pfcg_tmp TO lit_agr1251.
            ENDLOOP.
          ENDLOOP.
          CLEAR lit_pfcg_tmp.
          DELETE lit_agr1251 WHERE low EQ '$KOART'.
        ENDIF.
      ENDIF.

      " Get all possible values
      SELECT object, field, low
        FROM zacg_obj_fval
      INTO TABLE @DATA(lit_obj_fval).

      lr_object_lib = VALUE #( FOR lwa_risk_lib IN lit_risk_lib ( sign = 'I' option = 'EQ' low = lwa_risk_lib-object ) ).
      SORT lr_object_lib BY low.
      DELETE ADJACENT DUPLICATES FROM lr_object_lib COMPARING low.
      DELETE lr_object_lib WHERE low IS INITIAL.

      IF lr_object_lib IS NOT INITIAL.
        " Add posible values for ACTVT field
        SELECT brobj AS object,
               'ACTVT' AS field,
               actvt AS per_val
          FROM tactz
          APPENDING TABLE @lit_obj_fval
          WHERE brobj IN @lr_object_lib.
      ENDIF.

      " Replace wild card values of values with range
      LOOP AT lit_agr1251 INTO DATA(lwa_agr1251).

        CLEAR lr_fval.

        IF lwa_agr1251-high IS NOT INITIAL.
          lr_fval = VALUE #( ( sign = 'I' option = 'BT' low = lwa_agr1251-low high = lwa_agr1251-high ) ).
        ELSEIF lwa_agr1251-low CA '*'.
          lr_fval = VALUE #( ( sign = 'I' option = 'CP' low = lwa_agr1251-low ) ).
        ENDIF.

        IF lr_fval IS NOT INITIAL.

          SELECT *
            FROM @lit_obj_fval AS premisible_value
          WHERE object    = @lwa_agr1251-object
                AND field = @lwa_agr1251-field
                AND low   IN @lr_fval
          INTO TABLE @DATA(lit_values).
          IF sy-subrc IS INITIAL.
            lit_pfcg_tmp = VALUE #( FOR lwa_values IN lit_values (
                                agr_name = lwa_agr1251-agr_name
                                object   = lwa_agr1251-object
                                auth     = lwa_agr1251-auth
                                field    = lwa_agr1251-field
                                low      = lwa_values-low ) ).

          ENDIF.
          APPEND LINES OF lit_pfcg_tmp TO lit_pfcg.
          CLEAR lit_pfcg_tmp.
        ELSE.
          IF lwa_agr1251-low(1) NE '$'.
            APPEND lwa_agr1251 TO lit_pfcg.
          ENDIF.

        ENDIF.

      ENDLOOP.
      lit_agr1251 = lit_pfcg.
      CLEAR: lit_pfcg, lit_obj_fval.

      APPEND LINES OF lr_lib_srvc TO lr_tcode.

      IF it_tcode[] IS NOT INITIAL.
        SELECT pfcg~agr_name,
               pfcg~object,
               pfcg~auth,
               pfcg~field,
               pfcg~low,
               pfcg~high,
               lib~func,
               lib~tcode,
               lib~object,
               lib~field,
               lib~low,
               lib~high
          FROM @lit_agr1251 AS pfcg
          INNER JOIN zacg_risk_lib AS lib
          ON pfcg~object EQ lib~object
          AND pfcg~field EQ lib~field
          AND pfcg~low EQ lib~low
         WHERE lib~tcode IN @it_tcode[]
          AND lib~inact = @space
         ORDER BY lib~func, lib~tcode, lib~object
         INTO TABLE @lit_join.
      ENDIF.
      CLEAR lit_agr1251.

      lr_tcode = VALUE #( FOR ls_join IN lit_join ( sign = 'I' option = 'EQ' low = ls_join-lib_tcode ) ).
      SORT lr_tcode BY low.
      DELETE ADJACENT DUPLICATES FROM lr_tcode COMPARING low.
      DELETE lr_tcode WHERE low IS INITIAL.

      lr_func = VALUE #( FOR ls_func IN lit_join ( sign = 'I' option = 'EQ' low = ls_func-lib_func ) ).
      SORT lr_func BY low.
      DELETE ADJACENT DUPLICATES FROM lr_func COMPARING low.
      DELETE lr_func WHERE low IS INITIAL.


      IF lr_func IS NOT INITIAL AND lr_tcode IS NOT INITIAL.
        SELECT *
          FROM @lit_risk_lib AS risl_lib
          WHERE func  IN @lr_func
            AND tcode IN @lr_tcode
            AND inact EQ @space
         INTO TABLE @lit_risk_lib.
      ENDIF.

      LOOP AT lr_func INTO DATA(lwa_func). " Check for each function id

        CLEAR: lv_actvt_not_found.

        SELECT *
          FROM @lit_risk_lib AS lib_func_tcode
          WHERE func  EQ @lwa_func-low
        INTO TABLE @DATA(lit_lib_func).
        IF sy-subrc IS INITIAL.

          lr_tcode = VALUE #( FOR ls_lib_func IN lit_lib_func ( sign = 'I' option = 'EQ' low = ls_lib_func-tcode ) ).
          SORT lr_tcode BY low.
          DELETE ADJACENT DUPLICATES FROM lr_tcode COMPARING low.
          DELETE lr_tcode WHERE low IS INITIAL.

          LOOP AT lr_tcode INTO DATA(lwa_tcode). " Check for each tcode within function

            SELECT *
              FROM @lit_lib_func AS lib_func_tcode
              WHERE tcode EQ @lwa_tcode-low
            INTO TABLE @DATA(lit_lib_func_tcode).
            IF sy-subrc IS INITIAL.

              lr_lib_obj = VALUE #( FOR ls_lib_obj IN lit_lib_func_tcode ( sign = 'I' option = 'EQ' low = ls_lib_obj-object ) ).
              SORT lr_lib_obj BY low.
              DELETE ADJACENT DUPLICATES FROM lr_lib_obj COMPARING low .
              DELETE lr_lib_obj WHERE low IS INITIAL.

              LOOP AT lr_lib_obj INTO DATA(lwa_lib_obj). " For each Object within the tcode

                SELECT *
                  FROM @lit_join AS pfcg_func_tcode_obj
                  WHERE lib_func   = @lwa_func-low
                    AND lib_tcode  = @lwa_tcode-low
                    AND lib_object = @lwa_lib_obj-low
                 INTO TABLE @DATA(lit_pfcg_func_tcode_obj).
                IF sy-subrc IS INITIAL.

                  lr_instance = VALUE #( FOR ls_pfcg_func_tcode_obj IN lit_pfcg_func_tcode_obj ( sign = 'I' option = 'EQ' low = ls_pfcg_func_tcode_obj-pfcg_auth ) ).
                  SORT lr_instance BY low.
                  DELETE ADJACENT DUPLICATES FROM lr_instance COMPARING low.
                  DELETE lr_instance WHERE low IS INITIAL.

                  LOOP AT lr_instance INTO DATA(lwa_instance). " For each Instance of the object

                    CLEAR lv_actvt_not_found.

                    SELECT *
                      FROM @lit_pfcg_func_tcode_obj AS pfcg_func_tcode_obj_ins
                      WHERE pfcg_auth = @lwa_instance-low
                    INTO TABLE @DATA(lit_pfcg_func_tcode_obj_ins).
                    IF sy-subrc IS INITIAL.

                      SELECT *
                        FROM @lit_lib_func_tcode AS lib_field
                        WHERE object = @lwa_lib_obj-low
                      INTO TABLE @DATA(lit_lib_func_tcode_obj).
                      IF sy-subrc IS INITIAL.

                        lr_field = VALUE #( FOR ls_lib_func_tcode_obj IN lit_lib_func_tcode_obj ( sign = 'I' option = 'EQ' low = ls_lib_func_tcode_obj-field ) ).
                        SORT lr_field BY low.
                        DELETE ADJACENT DUPLICATES FROM lr_field COMPARING low.
                        DELETE lr_field WHERE low IS INITIAL.

                        LOOP AT lr_field INTO DATA(lwa_field).
                          READ TABLE lit_pfcg_func_tcode_obj_ins INTO DATA(lwa_pfcg_func_tcode_obj_ins)
                          WITH KEY lib_field = lwa_field-low.
                          IF sy-subrc IS NOT INITIAL.
                            lv_actvt_not_found = abap_true.
                          ENDIF.
                        ENDLOOP.

                        IF lv_actvt_not_found EQ abap_false.
                          " Take the set for consideration.
                          APPEND LINES OF lit_pfcg_func_tcode_obj_ins TO lit_potential_obj.
                        ENDIF.

                      ENDIF.

                    ENDIF.

                  ENDLOOP. " end of instance

                ENDIF.

              ENDLOOP. " end of each object

            ENDIF.

          ENDLOOP. " end of each tcode check

        ENDIF.

      ENDLOOP. " end of each function check

    ENDIF.

  ENDIF.

  SORT lit_potential_obj.
  DELETE ADJACENT DUPLICATES FROM lit_potential_obj COMPARING ALL FIELDS.
  et_potential_risk = lit_potential_obj.

ENDFUNCTION.
