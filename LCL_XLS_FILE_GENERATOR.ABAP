CLASS lcl_xls_file_generator DEFINITION .
  PUBLIC SECTION.
    TYPES: BEGIN OF gty_s_column_labels,
             column TYPE string,
             label  TYPE string,
           END OF gty_s_column_labels,
           gty_t_column_labels TYPE STANDARD TABLE OF gty_s_column_labels WITH DEFAULT KEY.
    CLASS-METHODS:
      flat_table_to_xsls IMPORTING  it_columns    TYPE gty_t_column_labels OPTIONAL
                         CHANGING   ct_data       TYPE STANDARD TABLE
                         RETURNING  VALUE(rv_xls) TYPE xstring
                         EXCEPTIONS generation_error.

ENDCLASS.
CLASS lcl_xls_file_generator IMPLEMENTATION.
  METHOD  flat_table_to_xsls .
    DATA: lo_salv      TYPE REF TO cl_salv_table.
    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table   = lo_salv
          CHANGING
            t_table        = ct_data
        ).

        LOOP AT lo_salv->get_columns( )->get( ) ASSIGNING FIELD-SYMBOL(<ls_col>).
          READ TABLE  it_columns ASSIGNING FIELD-SYMBOL(<ls_inc>)  WITH KEY column = <ls_col>-columnname.
          CHECK sy-subrc = 0.
          <ls_col>-r_column->set_fixed_header_text( 'L' ).
          <ls_col>-r_column->set_long_text( CONV scrtext_l( <ls_inc>-label ) ).
        ENDLOOP.

        CALL METHOD lo_salv->to_xml
          EXPORTING
            xml_type = if_salv_bs_xml=>c_type_xlsx
          RECEIVING
            xml      = rv_xls.

      CATCH cx_root. " ALV: General Error Class with Message
        RAISE generation_error.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.