CLASS zcl_acpf_generic_utils DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      BEGIN OF gty_s_value,
        value TYPE lvc_value,
      END OF gty_s_value .
    TYPES:
      gty_t_values TYPE STANDARD TABLE OF gty_s_value WITH DEFAULT KEY .

    CLASS-METHODS dynamic_convexit
      IMPORTING
        !iv_value       TYPE clike
        !iv_reftab      TYPE clike OPTIONAL
        !iv_reffield    TYPE clike OPTIONAL
        !iv_data_type   TYPE clike OPTIONAL
        !iv_output      TYPE boolean DEFAULT abap_false
      RETURNING
        VALUE(rv_value) TYPE string .
    CLASS-METHODS get_valtab_and_field
      IMPORTING
        !iv_element    TYPE ddobjname
        !iv_entitytab  TYPE boolean DEFAULT abap_false
      RETURNING
        VALUE(rs_info) TYPE help_info .
    CLASS-METHODS get_values_from_valtab
      IMPORTING
        !iv_element      TYPE ddobjname
      RETURNING
        VALUE(rt_values) TYPE gty_t_values .
    CLASS-METHODS get_values_from_domain
      IMPORTING
        !iv_element      TYPE ddobjname
      RETURNING
        VALUE(rt_values) TYPE dd07vtab .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_ACPF_GENERIC_UTILS IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_ACPF_GENERIC_UTILS=>DYNAMIC_CONVEXIT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_VALUE                       TYPE        CLIKE
* | [--->] IV_REFTAB                      TYPE        CLIKE(optional)
* | [--->] IV_REFFIELD                    TYPE        CLIKE(optional)
* | [--->] IV_DATA_TYPE                   TYPE        CLIKE(optional)
* | [--->] IV_OUTPUT                      TYPE        BOOLEAN (default =ABAP_FALSE)
* | [<-()] RV_VALUE                       TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD dynamic_convexit.
    DATA: ls_dd04v TYPE dd04v,
          lv_dtype TYPE ddobjname,
          lt_dfies TYPE STANDARD TABLE OF dfies.

    rv_value = iv_value.

    DO 2 TIMES.

      "Fist, determine via data type (if supplied)
      IF     sy-index = 1
        AND  iv_data_type IS SUPPLIED
        AND  iv_data_type IS NOT INITIAL.
        lv_dtype = iv_data_type.
      ELSEIF iv_reftab   IS SUPPLIED
         AND iv_reffield IS SUPPLIED.
        "Second via ref table and field
        CALL FUNCTION 'DDIF_FIELDINFO_GET'
          EXPORTING
            tabname        = CONV ddobjname( iv_reftab )
            fieldname      = CONV dfies-fieldname( iv_reffield )
          TABLES
            dfies_tab      = lt_dfies
          EXCEPTIONS
            not_found      = 1
            internal_error = 2
            OTHERS         = 3.
        IF sy-subrc <> 0 OR lt_dfies IS INITIAL.
          RETURN.
        ENDIF.
        lv_dtype = lt_dfies[ 1 ]-datatype.
      ENDIF.

      CHECK lv_dtype IS NOT INITIAL.

      "Determine the conv-exit for the data type
      CALL FUNCTION 'DDIF_DTEL_GET'
        EXPORTING
          name          = lv_dtype
        IMPORTING
          dd04v_wa      = ls_dd04v
        EXCEPTIONS
          illegal_input = 1
          OTHERS        = 2.
      IF sy-subrc = 0 AND ls_dd04v-convexit IS NOT INITIAL.
        "Convexit found, no further search
        EXIT.
      ENDIF.
    ENDDO.
    CHECK ls_dd04v-convexit IS NOT INITIAL.
    DATA(lv_fm) = |CONVERSION_EXIT_{ ls_dd04v-convexit }_{ SWITCH #( iv_output WHEN abap_true THEN 'OUTPUT' ELSE 'INPUT' ) }|.

    CALL FUNCTION lv_fm
      EXPORTING
        input            = iv_value
      IMPORTING
        output           = rv_value
      EXCEPTIONS
        unknown_language = 1
        OTHERS           = 2.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.




  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_ACPF_GENERIC_UTILS=>GET_VALTAB_AND_FIELD
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ELEMENT                     TYPE        DDOBJNAME
* | [--->] IV_ENTITYTAB                   TYPE        BOOLEAN (default =ABAP_FALSE)
* | [<-()] RS_INFO                        TYPE        HELP_INFO
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_valtab_and_field.

    DATA:
      ls_dd04v TYPE dd04v,
      lt_dd03p TYPE STANDARD TABLE OF dd03p.


    CALL FUNCTION 'DDIF_DTEL_GET'
      EXPORTING
        name          = iv_element
      IMPORTING
        dd04v_wa      = ls_dd04v
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF iv_entitytab = abap_false.

      CHECK ls_dd04v-entitytab IS NOT INITIAL.


      IF ls_dd04v-entitytab IS NOT INITIAL.
        SELECT SINGLE * INTO @DATA(ls_dd03l) FROM dd03l WHERE as4local = 'A'
                                                   AND tabname NOT LIKE '/%'
                                                   AND checktable = @ls_dd04v-entitytab
                                                   AND rollname =   @iv_element.
        IF sy-subrc NE 0.
          SELECT SINGLE * INTO ls_dd03l FROM dd03l WHERE tabname = ls_dd04v-entitytab
                                                     AND as4local = 'A'
                                                     AND keyflag  = 'X'
                                                     AND rollname = iv_element.
          IF sy-subrc NE 0.
            SELECT SINGLE * INTO ls_dd03l FROM dd03l WHERE tabname = ls_dd04v-entitytab
                                                       AND as4local = 'A'
                                                       AND rollname = iv_element.
            IF sy-subrc NE 0.
              SELECT SINGLE * INTO ls_dd03l FROM dd03l WHERE tabname = ls_dd04v-entitytab
                                                         AND as4local = 'A'
                                                         AND keyflag  = 'X'
                                                         AND domname  = ls_dd04v-domname.
              IF sy-subrc NE 0.
                SELECT SINGLE * INTO ls_dd03l FROM dd03l WHERE tabname = ls_dd04v-entitytab
                                                           AND as4local = 'A'
                                                           AND domname  = ls_dd04v-domname.
                IF sy-subrc NE 0.
                ENDIF.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.

      ELSE.
        SELECT SINGLE * INTO ls_dd03l FROM dd03l WHERE as4local = 'A'
                                                   AND keyflag  = 'X'
                                                   AND rollname = iv_element.
        IF sy-subrc NE 0.
          SELECT SINGLE * INTO ls_dd03l FROM dd03l WHERE as4local = 'A'
                                                     AND rollname = iv_element.
          IF sy-subrc NE 0.
            SELECT SINGLE * INTO ls_dd03l FROM dd03l WHERE as4local = 'A'
                                                       AND keyflag  = 'X'
                                                       AND domname  = ls_dd04v-domname.
            IF sy-subrc NE 0.
              SELECT SINGLE * INTO ls_dd03l FROM dd03l WHERE as4local = 'A'
                                                         AND domname  = ls_dd04v-domname.
              IF sy-subrc NE 0.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      rs_info-tabname   = ls_dd03l-tabname.
      rs_info-fieldname = ls_dd03l-fieldname .

    ELSE.
      "Directly get reference from entitytab
      CALL FUNCTION 'DDIF_TABL_GET'
        EXPORTING
          name          = ls_dd04v-entitytab
        TABLES
          dd03p_tab     = lt_dd03p
        EXCEPTIONS
          illegal_input = 1
          OTHERS        = 2.

      CHECK sy-subrc  = 0.

      rs_info-fieldname = VALUE #( lt_dd03p[ rollname = iv_element ]-fieldname DEFAULT space ).
      CHECK rs_info-fieldname IS NOT INITIAL.
      rs_info-tabname = ls_dd04v-entitytab.

    ENDIF.



  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_ACPF_GENERIC_UTILS=>GET_VALUES_FROM_DOMAIN
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ELEMENT                     TYPE        DDOBJNAME
* | [<-()] RT_VALUES                      TYPE        DD07VTAB
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_values_from_domain.

    SELECT SINGLE domname
      FROM dd04l
      INTO @DATA(lv_domain)
      WHERE rollname = @iv_element.

    CHECK sy-subrc = 0.

    "Try using domain
    CALL FUNCTION 'GET_DOMAIN_VALUES'
      EXPORTING
        domname         = lv_domain
      TABLES
        values_tab      = rt_values
      EXCEPTIONS
        no_values_found = 1
        OTHERS          = 2.

    CHECK sy-subrc = 0.

    SORT rt_values BY domvalue_l ASCENDING.


  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_ACPF_GENERIC_UTILS=>GET_VALUES_FROM_VALTAB
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ELEMENT                     TYPE        DDOBJNAME
* | [<-()] RT_VALUES                      TYPE        GTY_T_VALUES
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_values_from_valtab.

    DO 2 TIMES.
      IF sy-index = 1.
        "First we try to get values from the entitytab
        DATA(lv_entity) = abap_true.
      ELSE.
        "Second we try from the SH reference tab/field
        lv_entity = abap_false.
      ENDIF.

      DATA(ls_info) =  get_valtab_and_field(
                         iv_element   = iv_element
                         iv_entitytab = lv_entity
                       ).
      CHECK ls_info-tabname IS NOT INITIAL AND ls_info-fieldname IS NOT INITIAL.

      TRY.
          SELECT DISTINCT (ls_info-fieldname)
            FROM (ls_info-tabname) "#EC CI_DYNTAB Needed to read data from configured ref. table
            INTO TABLE @rt_values.
          CHECK sy-subrc = 0.
          EXIT.
        CATCH cx_root.
          RETURN.
      ENDTRY.

    ENDDO.


  ENDMETHOD.
ENDCLASS.
