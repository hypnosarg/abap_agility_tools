

********************************************************************
*ZCL_AUT_DYNPRO_TOOLS: General utilities to work with Dynpros
********************************************************************
CLASS ZCL_AUT_DYNPRO_TOOLS DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS: update_dynpro_fields IMPORTING iv_dynnr  TYPE dynnr
                                                  iv_prefix TYPE clike OPTIONAL
                                        CHANGING  co_data   TYPE REF TO data.
ENDCLASS.

CLASS ZCL_AUT_DYNPRO_TOOLS IMPLEMENTATION.
  METHOD update_dynpro_fields.
    "Updates fields of a structure taking current values set in the UI
    "even if they have not been commited by executing a user command
    "The prefix means for example if all fields of the dynpro are in structure GS_0100
    "like GS_0100-MATNR, etc. then iv prefix should be provided with value 'GS_0100-'
    DATA: lt_fields     TYPE STANDARD TABLE OF dynpread,
          lt_all_fields TYPE STANDARD TABLE OF rsdcf,
          lt_lines      TYPE STANDARD TABLE OF tline.
    FIELD-SYMBOLS: <ls_out> TYPE any.

    CHECK co_data IS BOUND.
    ASSIGN co_data->* TO <ls_out>.
    CHECK sy-subrc = 0.

    CALL FUNCTION 'DYNPRO_FIELD_GET'
      EXPORTING
        dynpro           = CONV dynpronr( iv_dynnr )
        program          = sy-cprog
      TABLES
        dynp_fields      = lt_all_fields
        lines            = lt_lines
      EXCEPTIONS
        dynpro_not_found = 1
        OTHERS           = 2.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    "Read values for all I/O fields that have a corresponding in the selected output
    DELETE lt_all_fields WHERE flg11 <> '80'.
    LOOP AT lt_all_fields ASSIGNING FIELD-SYMBOL(<ls_fld>).
      ASSIGN COMPONENT <ls_fld>-dynpro_fld OF STRUCTURE <ls_out> TO FIELD-SYMBOL(<lv_out>).
      IF sy-subrc <> 0 AND <ls_fld>-dynpro_fld CA '-'.
        "Try again with just the fieldname
        SPLIT <ls_fld>-dynpro_fld AT '-' INTO DATA(lv_structure)  ##NEEDED
                                              DATA(lv_field).
        ASSIGN COMPONENT lv_field OF STRUCTURE <ls_out> TO <lv_out>.
      ENDIF.
      CHECK <lv_out> IS ASSIGNED.
      APPEND VALUE  dynpread( fieldname = <ls_fld>-dynpro_fld ) TO lt_fields.
      UNASSIGN <lv_out>.
    ENDLOOP.

    CALL FUNCTION 'DYNP_VALUES_READ'
      EXPORTING
        dyname               = sy-cprog
        dynumb               = iv_dynnr
      TABLES
        dynpfields           = lt_fields
      EXCEPTIONS
        invalid_abapworkarea = 1
        invalid_dynprofield  = 2
        invalid_dynproname   = 3
        invalid_dynpronummer = 4
        invalid_request      = 5
        no_fielddescription  = 6
        invalid_parameter    = 7
        undefind_error       = 8
        double_conversion    = 9
        stepl_not_found      = 10
        OTHERS               = 11.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    "Finally put the values from the UI back to the data structure
    lcl_dynamic_utils=>transpose_tab_to_str(
      EXPORTING
        iv_remove_name = iv_prefix
        it_data        = lt_fields
        iv_name_field  = 'FIELDNAME'
        iv_value_field = 'FIELDVALUE'
      CHANGING
        cs_out         = <ls_out>
    ).


  ENDMETHOD.
ENDCLASS.
