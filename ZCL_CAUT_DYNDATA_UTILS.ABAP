class ZCL_CAUT_DYNDATA_UTILS definition
  public
  final
  create public .

public section.

  types:
    gty_t_fields TYPE STANDARD TABLE OF fieldname WITH DEFAULT KEY .
  types:
    BEGIN OF gty_s_field_list,
             source_field TYPE string,
             target_field TYPE string,
           END OF gty_s_field_list .
  types:
    gty_t_field_list TYPE STANDARD TABLE OF gty_s_field_list WITH DEFAULT KEY .

  class-methods ADD_FIELDS_TO_TYPE
    importing
      !IT_DATA type STANDARD TABLE
      !IT_NEWFIELDS type CL_ABAP_STRUCTDESCR=>COMPONENT_TABLE
    returning
      value(RO_NEWTYPE) type ref to DATA .
  class-methods GET_DATADESCR_FOR_TYPE
    importing
      !IV_TYPENAME type CLIKE
    returning
      value(RO_DATADESCR) type ref to CL_ABAP_DATADESCR .
  class-methods CREATE_SUBTYPE
    importing
      !IS_SOURCE_STR type ANY
      !IT_FIELD_LIST type GTY_T_FIELD_LIST
      !IV_TABLE_TYPE type BOOLEAN default ABAP_FALSE
    returning
      value(RO_DATA) type ref to DATA .
  class-methods MOVE_TO_CORRESPONDING
    importing
      !IT_FIELDS type GTY_T_FIELDS
      !IS_SOURCE type ANY
    changing
      !CS_TARGET type ANY .
  class-methods SOURCE_TO_TARGET
    importing
      !IV_FIELD type CLIKE
      !IS_SOURCE type ANY
    changing
      !CS_TARGET type ANY .
  class-methods TRANSPOSE_TAB_TO_STR
    importing
      !IT_DATA type ANY TABLE
      !IV_NAME_FIELD type CLIKE
      !IV_VALUE_FIELD type CLIKE
      !IV_REMOVE_NAME type BOOLEAN default ABAP_FALSE
    changing
      !CS_OUT type ANY .
protected section.
private section.

  class-methods ASSIGN_WITH_CONVERSION
    importing
      !IV_VALUE type ANY
    changing
      !CV_OUT type ANY .
ENDCLASS.



CLASS ZCL_CAUT_DYNDATA_UTILS IMPLEMENTATION.


  METHOD add_fields_to_type.
    "Receives a structure type and returns a subtype with some of its components
    "renaming of fields is possible
    DATA: lo_str     TYPE REF TO cl_abap_structdescr,
          lo_str_new TYPE REF TO cl_abap_structdescr,
          lo_tab     TYPE REF TO cl_abap_tabledescr,
          lo_tab_new TYPE REF TO cl_abap_tabledescr,
          lt_fields  TYPE cl_abap_structdescr=>component_table.


    lo_tab ?= cl_abap_tabledescr=>describe_by_data( p_data = it_data  ).
    lo_str ?= lo_tab->get_table_line_type( ).
    APPEND LINES OF lo_str->get_components( ) TO lt_fields.
    LOOP AT it_newfields ASSIGNING FIELD-SYMBOL(<ls_comp>).
      READ TABLE lt_fields WITH KEY name = <ls_comp>-name TRANSPORTING NO FIELDS.
      CHECK sy-subrc <> 0.
      APPEND <ls_comp> TO lt_fields.
    ENDLOOP.
*
    lo_str_new = cl_abap_structdescr=>create( lt_fields ).
    lo_tab_new  = cl_abap_tabledescr=>create(
                     p_line_type  = lo_str_new
                     p_table_kind = cl_abap_tabledescr=>tablekind_std
                     p_unique     = abap_false ).

    CREATE DATA ro_newtype TYPE HANDLE lo_tab_new.

  ENDMETHOD.


  method ASSIGN_WITH_CONVERSION.
      DATA: lo_descr TYPE REF TO cl_abap_datadescr.
    "Sets the source value to the output applying conversions where needed
    lo_descr ?= cl_abap_datadescr=>describe_by_data( cv_out ).
    CHECK lo_descr IS BOUND.

    TRY.
        CASE lo_descr->type_kind.
          WHEN 'D'.
            "Apply date conversion exit
            CALL METHOD cl_abap_datfm=>conv_date_ext_to_int
              EXPORTING
                im_datext = iv_value
              IMPORTING
                ex_datint = cv_out.
          WHEN 'P'.
            "Apply decimal conversion
            CALL FUNCTION 'MOVE_CHAR_TO_NUM'
              EXPORTING
                chr             = iv_value
              IMPORTING
                num             = cv_out
              EXCEPTIONS
                convt_no_number = 1
                convt_overflow  = 2
                OTHERS          = 3.
            IF sy-subrc <> 0.
              RETURN.
            ENDIF.

          WHEN OTHERS.
            "Assign directly
            cv_out = iv_value.
        ENDCASE.
      CATCH cx_root.
        RETURN.
    ENDTRY.

  endmethod.


  METHOD create_subtype.


    "Receives a structure type and returns a subtype with some of its components
    "renaming of fields is possible
    DATA: lo_descr  TYPE REF TO cl_abap_structdescr,
          lo_str    TYPE REF TO cl_abap_structdescr,
          lo_tab    TYPE REF TO cl_abap_tabledescr,
          lt_fields TYPE cl_abap_structdescr=>component_table.


    lo_descr ?= cl_abap_structdescr=>describe_by_data( p_data = is_source_str  ).
    CHECK lo_descr IS BOUND.
    LOOP AT lo_descr->get_components( ) ASSIGNING FIELD-SYMBOL(<ls_comp>).
      READ TABLE it_field_list WITH KEY source_field = <ls_comp>-name
                               ASSIGNING FIELD-SYMBOL(<ls_mapping>).
      CHECK sy-subrc = 0.
      APPEND <ls_comp> TO lt_fields ASSIGNING FIELD-SYMBOL(<ls_out>).
      <ls_out>-name = SWITCH string( <ls_mapping>-target_field WHEN space THEN <ls_mapping>-source_field ELSE <ls_mapping>-target_field ).
    ENDLOOP.

    lo_str = cl_abap_structdescr=>create( lt_fields ).
    IF iv_table_type = abap_true.
      lo_tab = cl_abap_tabledescr=>create(
                       p_line_type  = lo_str
                       p_table_kind = cl_abap_tabledescr=>tablekind_std
                       p_unique     = abap_false ).
      CREATE DATA ro_data TYPE HANDLE lo_tab.
    ELSE.
      CREATE DATA ro_data TYPE HANDLE lo_str.
    ENDIF.



  ENDMETHOD.


  METHOD get_datadescr_for_type.
    TRY.
        ro_datadescr ?= cl_abap_datadescr=>describe_by_name(
          EXPORTING
            p_name         =  iv_typename
        ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.


  METHOD move_to_corresponding.
    LOOP AT it_fields ASSIGNING FIELD-SYMBOL(<lv_field>).
      source_to_target(
        EXPORTING
          iv_field  = <lv_field>
          is_source = is_source
        CHANGING
          cs_target = cs_target
      ).
    ENDLOOP.

  ENDMETHOD.


  METHOD source_to_target.
    ASSIGN COMPONENT iv_field OF STRUCTURE is_source TO FIELD-SYMBOL(<lv_source>).
    CHECK sy-subrc = 0.
    ASSIGN COMPONENT iv_field OF STRUCTURE cs_target TO FIELD-SYMBOL(<lv_target>).
    CHECK sy-subrc = 0.
    <lv_target> = <lv_source>.
  ENDMETHOD.


  METHOD transpose_tab_to_str.
    DATA: lv_name TYPE string.
    "Transpose values from a table  containing field names and values in a charlike
    "to a structure of same fields in internal format or not
    "Example
    "Input FIELD = 'MATNR' VALUE = '012358' / FIELD = 'LIFNR' VALUE = '123123'
    "Output structure with MATNR and LIFNR = 012358 | 123123
    LOOP AT it_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      ASSIGN COMPONENT iv_value_field OF STRUCTURE <ls_data> TO FIELD-SYMBOL(<lv_src>).
      CHECK sy-subrc = 0.
      ASSIGN COMPONENT iv_name_field OF STRUCTURE <ls_data> TO FIELD-SYMBOL(<lv_fld_name>).
      CHECK sy-subrc = 0.
      lv_name = <lv_fld_name>.
      IF iv_remove_name IS NOT INITIAL.
        "Remove prefix from fieldname
        REPLACE ALL OCCURRENCES OF iv_remove_name IN lv_name WITH ''.
      ENDIF.
      ASSIGN COMPONENT lv_name OF STRUCTURE cs_out TO FIELD-SYMBOL(<lv_out>).
      CHECK sy-subrc = 0.
      assign_with_conversion(
        EXPORTING
          iv_value = <lv_src>
        CHANGING
          cv_out   = <lv_out>      ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
