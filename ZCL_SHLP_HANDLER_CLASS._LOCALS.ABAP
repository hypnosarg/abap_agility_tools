*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
*"* use this source file for any type of declarations (class
*"* definitions, interfaces or type declarations) you need for
*"* components in the private section

CLASS lcl_f4_handler IMPLEMENTATION.
  METHOD add_value_to_results.
    FIELD-SYMBOLS:
      <lt_results> TYPE lvc_t_modi.

    ASSIGN io_event_data->m_data->* TO <lt_results>.
    CHECK sy-subrc = 0.

    APPEND VALUE #(
      row_id = iv_row
      fieldname = iv_fieldname
      value = iv_value ) TO <lt_results>.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_f4_handler_date IMPLEMENTATION.
  METHOD handle.
    DATA:
      lv_date              TYPE dats,
      lv_value             TYPE dats,
      lo_data_element_type TYPE REF TO cl_abap_elemdescr.

    lo_data_element_type ?= cl_abap_typedescr=>describe_by_name( id_field->data_element ).
    CHECK lo_data_element_type->type_kind = cl_abap_elemdescr=>typekind_date.

    io_event_data->m_event_handled = abap_true.

    lv_value = iv_value.
    CALL FUNCTION 'F4_DATE'
      EXPORTING
        date_for_first_month         = lv_value
        display                      = iv_display
      IMPORTING
        select_date                  = lv_date
      EXCEPTIONS
        calendar_buffer_not_loadable = 1
        date_after_range             = 2
        date_before_range            = 3
        date_invalid                 = 4
        factory_calendar_not_found   = 5
        holiday_calendar_not_found   = 6
        parameter_conflict           = 7
        OTHERS                       = 8.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
        DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    CHECK iv_display = abap_false.
    add_value_to_results(
      iv_row = iv_row
      iv_value = |{ lv_date DATE = USER }|
      iv_fieldname = id_field->field_name
      io_event_data = io_event_data ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_f4_handler_ref_table IMPLEMENTATION.
  METHOD handle.
    DATA:
      lt_values TYPE zcl_acpf_struct_value_list_alv=>gty_t_values.

    CHECK id_field->ref_table IS NOT INITIAL
      AND id_field->ref_field IS NOT INITIAL.
    TRY.
        cl_abap_dyn_prg=>check_column_name(
          val = id_field->ref_field
          strict = abap_true ).
      CATCH cx_abap_invalid_name INTO DATA(lo_column_exception).
        MESSAGE lo_column_exception TYPE 'E'.
        RETURN.
    ENDTRY.

    TRY.
        cl_abap_dyn_prg=>check_table_or_view_name_str(
          val = id_field->ref_table
          packages = '' ).
      CATCH cx_root INTO DATA(lo_table_exception).
        MESSAGE lo_table_exception TYPE 'E'.
        RETURN.
    ENDTRY.

    "Frist try with the search help for the particular tab-field
    show_vh_for_field(
      EXPORTING
        iv_table      = id_field->ref_table
        iv_field      = id_field->ref_field
        iv_row        = iv_row
        iv_display    = iv_display
        iv_value      = iv_value
        id_field      = id_field
        io_event_data = io_event_data ).

    CHECK io_event_data->m_event_handled = abap_false.

    SELECT DISTINCT (id_field->ref_field)
      FROM (id_field->ref_table) "#EC CI_DYNTAB Needed to read data from configured ref. table
      INTO TABLE @lt_values.
    CHECK sy-subrc = 0.

    SORT lt_values BY value.
    show_value_help(
      iv_row        = iv_row
      iv_display    = iv_display
      iv_value      = iv_value
      id_field      = id_field
      it_values     = lt_values
      io_event_data = io_event_data ).
  ENDMETHOD.
  METHOD show_vh_for_field.

    DATA: lt_dynpselect   TYPE STANDARD TABLE OF dselc,
          lt_dynpvaluetab TYPE STANDARD TABLE OF dval,
          lv_sel          TYPE string,
          ls_info         TYPE help_info,
          lv_val          TYPE help_info-fldvalue.

    ls_info-fieldname = iv_field.
    ls_info-tabname   = iv_table.
    ls_info-program   = sy-repid.
    ls_info-dynpro    = sy-dynnr.


    CALL FUNCTION 'DD_SHLP_CALL_FROM_DYNP'
      EXPORTING
        help_infos   = ls_info
      IMPORTING
        selection    = lv_sel
        select_value = lv_val
      TABLES
        dynpselect   = lt_dynpselect
        dynpvaluetab = lt_dynpvaluetab.

    IF lv_sel = abap_on.
      add_value_to_results(
        iv_row = iv_row
        iv_value = lv_val
        iv_fieldname = id_field->field_name
        io_event_data = io_event_data ).
      io_event_data->m_event_handled = abap_true.
    ENDIF.

  ENDMETHOD.
  METHOD show_value_help.
    DATA:
      lv_value   TYPE dynfieldvalue,
      lt_results TYPE TABLE OF ddshretval.

    io_event_data->m_event_handled = abap_true.

    lv_value = iv_value.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        display         = iv_display
        retfield        = 'VALUE'
        value_org       = 'S'
        value           = lv_value
      TABLES
        value_tab       = it_values
        return_tab      = lt_results
      EXCEPTIONS
        parameter_error = 1
        no_values_found = 2
        OTHERS          = 3.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
        DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    CHECK iv_display = abap_false
      AND lt_results[] IS NOT INITIAL.

    add_value_to_results(
      iv_row = iv_row
      iv_value = lt_results[ 1 ]-fieldval
      iv_fieldname = id_field->field_name
      io_event_data = io_event_data ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_f4_handler_domain IMPLEMENTATION.
  METHOD handle.
    TYPES:
      BEGIN OF lty_s_domain_value,
        value TYPE domvalue_l,
        text  TYPE val_text,
      END OF lty_s_domain_value,
      lty_t_domain_values TYPE TABLE OF lty_s_domain_value.

    CONSTANTS:
      lc_lang_english TYPE spras VALUE 'E'.

    DATA:
      ls_data_element  TYPE dd04v,
      lt_domain_values TYPE lty_t_domain_values.

    CHECK id_field->ref_table IS INITIAL
       OR id_field->ref_field IS INITIAL.


    CALL FUNCTION 'DDIF_DTEL_GET'
      EXPORTING
        name          = id_field->data_element
      IMPORTING
        dd04v_wa      = ls_data_element
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
        DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    SELECT a~domvalue_l AS value, b~ddtext AS text, b~ddlanguage AS language
      FROM dd07l AS a
      JOIN dd07t AS b
        ON b~domname = a~domname
        AND b~as4local = a~as4local
        AND b~valpos = a~valpos
        AND b~as4vers = a~as4vers
      WHERE a~domname = @ls_data_element-domname
        AND ( b~ddlanguage = @sy-langu OR b~ddlanguage = @lc_lang_english  )
      INTO TABLE @DATA(lt_domain_values_all).
    CHECK sy-subrc = 0.

    DO 2 TIMES.
      CASE sy-index.
        WHEN 1.
          DATA(lv_language) = sy-langu.
        WHEN 2.
          CHECK sy-langu <> lc_lang_english.
          lv_language = lc_lang_english.
        WHEN OTHERS.
          " not hapenning
      ENDCASE.

      LOOP AT lt_domain_values_all REFERENCE INTO DATA(ld_domain_value)
        WHERE language = lv_language.

        " check if value already in the table
        READ TABLE lt_domain_values TRANSPORTING NO FIELDS
          WITH KEY value = ld_domain_value->value.
        CHECK sy-subrc <> 0.

        APPEND ld_domain_value->* TO lt_domain_values.
      ENDLOOP.
    ENDDO.
    CHECK lt_domain_values[] IS NOT INITIAL.

    SORT lt_domain_values BY value.
    show_value_help(
      iv_row        = iv_row
      iv_display    = iv_display
      iv_value      = iv_value
      id_field      = id_field
      it_values     = lt_domain_values
      io_event_data = io_event_data ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_f4_handler_time IMPLEMENTATION.
  METHOD handle.
    DATA:
      lv_time              TYPE tims,
      lv_value             TYPE tims,
      lo_data_element_type TYPE REF TO cl_abap_elemdescr.

    lo_data_element_type ?= cl_abap_typedescr=>describe_by_name( id_field->data_element ).
    CHECK lo_data_element_type->type_kind = cl_abap_elemdescr=>typekind_time.

    lv_value = iv_value.
    CALL FUNCTION 'F4_CLOCK'
      EXPORTING
        start_time    = lv_value
        display       = iv_display
      IMPORTING
        selected_time = lv_time.

    IF iv_display = abap_false.
      add_value_to_results(
        iv_row = iv_row
        iv_value = |{ lv_time TIME = USER }|
        iv_fieldname = id_field->field_name
        io_event_data = io_event_data ).
    ENDIF.

    io_event_data->m_event_handled = abap_true.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_f4_handler_value_help IMPLEMENTATION.
  METHOD handle.
    DATA:
      lv_field        TYPE fieldname,
      lv_table        TYPE tabname,
      lv_value        TYPE dynfieldvalue,
      ls_data_element TYPE dd04v,
      lt_results      TYPE TABLE OF ddshretval.

    CALL FUNCTION 'DDIF_DTEL_GET'
      EXPORTING
        name          = id_field->data_element
      IMPORTING
        dd04v_wa      = ls_data_element
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
        DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    CHECK ls_data_element-shlpname IS NOT INITIAL
      AND ls_data_element-shlpfield IS NOT INITIAL.

    io_event_data->m_event_handled = abap_true.

    lv_value = iv_value.
    CALL FUNCTION 'F4IF_FIELD_VALUE_REQUEST'
      EXPORTING
        tabname           = lv_table
        fieldname         = lv_field
        searchhelp        = ls_data_element-shlpname
        shlpparam         = ls_data_element-shlpfield
        display           = iv_display
        value             = lv_value
      TABLES
        return_tab        = lt_results
      EXCEPTIONS
        field_not_found   = 1
        no_help_for_field = 2
        inconsistent_help = 3
        no_values_found   = 4
        OTHERS            = 5.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
        DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    CHECK iv_display = abap_false
      AND lt_results[] IS NOT INITIAL.

    add_value_to_results(
      iv_row = iv_row
      iv_value = lt_results[ 1 ]-fieldval
      iv_fieldname = id_field->field_name
      io_event_data = io_event_data ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_f4_handler_valtab IMPLEMENTATION.
  METHOD handle.

    DATA(ls_info) = zcl_acpf_generic_utils=>get_valtab_and_field( id_field->data_element ).
    "Frist try with the search help for the particular tab-field
    show_vh_for_field(
      EXPORTING
        iv_table      = ls_info-tabname
        iv_field      = ls_info-fieldname
        iv_row        = iv_row
        iv_display    = iv_display
        iv_value      = iv_value
        id_field      = id_field
        io_event_data = io_event_data ).

    "Could not be triggered? try getting the data
    CHECK io_event_data->m_event_handled = abap_false.

    DATA(lt_values) = zcl_acpf_generic_utils=>get_values_from_valtab( iv_element = id_field->data_element ).
    CHECK lt_values IS NOT INITIAL.

    SORT lt_values BY value.
    show_value_help(
      iv_row        = iv_row
      iv_display    = iv_display
      iv_value      = iv_value
      id_field      = id_field
      it_values     = lt_values
      io_event_data = io_event_data ).


  ENDMETHOD.
ENDCLASS.
