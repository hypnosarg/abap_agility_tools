********************************************************************
*ZCL_CAUT_ALV_UTILS: General utilities to work with ALVs
********************************************************************
CLASS zcl_caut_alv_utils
   DEFINITION
   PUBLIC
   FINAL
   CREATE PUBLIC
   INHERITING  FROM cl_gui_alv_grid..
  PUBLIC SECTION.
    CLASS-METHODS: get_grid  IMPORTING io_parent      TYPE REF TO cl_gui_container
                             CHANGING  ct_data        TYPE ANY TABLE
                             RETURNING VALUE(ro_grid) TYPE REF TO cl_gui_alv_grid,
      force_raise_data_changed IMPORTING io_grid  TYPE REF TO cl_gui_alv_grid,
      get_displayed_data IMPORTING io_grid        TYPE REF TO cl_gui_alv_grid
                         RETURNING VALUE(ro_data) TYPE REF TO data,
      set_dropdown_for_field IMPORTING iv_fieldname TYPE clike
                                       iv_length    TYPE numeric OPTIONAL
                                       it_values    TYPE ANY TABLE
                                       iv_value_fld TYPE clike
                                       iv_descr_fld TYPE clike OPTIONAL
                             CHANGING  co_grid      TYPE REF TO cl_gui_alv_grid,
      set_field_editable IMPORTING iv_fieldname TYPE clike
                                   iv_length    TYPE numeric OPTIONAL
                         CHANGING  co_grid      TYPE REF TO cl_gui_alv_grid.



ENDCLASS.



CLASS ZCL_CAUT_ALV_UTILS IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_CAUT_ALV_UTILS=>FORCE_RAISE_DATA_CHANGED
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_GRID                        TYPE REF TO CL_GUI_ALV_GRID
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD force_raise_data_changed ##NEEDED. "Part of the utilities framework

    FIELD-SYMBOLS: <lt_outdata> TYPE STANDARD TABLE.
    DATA: lo_descr  TYPE REF TO cl_abap_structdescr,
          lo_descr2 TYPE REF TO cl_abap_structdescr.

    CHECK io_grid IS BOUND.

    "Just assign a dumy delta record with the value of the first cell first row of the output
    DATA(lo_data) = get_displayed_data( io_grid ).
    CHECK lo_data IS BOUND.

    ASSIGN lo_data->* TO <lt_outdata>.
    CHECK <lt_outdata> IS NOT INITIAL.
    READ TABLE <lt_outdata> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_first>).
    CHECK sy-subrc = 0.


    lo_descr ?= cl_abap_structdescr=>describe_by_data( p_data = <ls_first> ).
    CHECK lo_descr IS BOUND.
    READ TABLE lo_descr->get_components( ) INDEX 1 INTO DATA(ls_comp).
    CHECK sy-subrc = 0.
    lo_descr2 ?= ls_comp-type.
    READ TABLE lo_descr2->get_components( ) INDEX 1 INTO ls_comp.
    CHECK sy-subrc = 0.

    ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_first> TO FIELD-SYMBOL(<lv_value>).

    DATA(lt_delta) = VALUE lvc_t_modi( ( row_id    = 1
                                         fieldname =  ls_comp-name
                                         value     =  <lv_value>
                                          ) ).
    io_grid->set_delta_cells(
      EXPORTING
        it_delta_cells  = lt_delta
        i_modified      = abap_true
        i_frontend_only = abap_true
    ).
    io_grid->check_changed_data( ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_CAUT_ALV_UTILS=>GET_DISPLAYED_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_GRID                        TYPE REF TO CL_GUI_ALV_GRID
* | [<-()] RO_DATA                        TYPE REF TO DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_displayed_data ##NEEDED. "Part of the utilities framework
    ro_data = io_grid->mt_outtab.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_CAUT_ALV_UTILS=>GET_GRID
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_PARENT                      TYPE REF TO CL_GUI_CONTAINER
* | [<-->] CT_DATA                        TYPE        ANY TABLE
* | [<-()] RO_GRID                        TYPE REF TO CL_GUI_ALV_GRID
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_grid ##NEEDED. "Part of the utilities framework
    DATA: lo_salv   TYPE REF TO cl_salv_table,
          ls_layout TYPE lvc_s_layo.
    TRY.
        "We use a SALV to do all the heavy work for us
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table   = lo_salv
          CHANGING
            t_table        = ct_data
        ).

        ro_grid = NEW cl_gui_alv_grid( i_parent         =  io_parent ).
        cl_salv_controller_metadata=>get_lvc_layout(
           EXPORTING
             r_functional_settings = lo_salv->get_functional_settings( )
             r_display_settings    = lo_salv->get_display_settings( )
             r_columns             = lo_salv->get_columns( )
             r_aggregations        = lo_salv->get_aggregations( )
             r_selections          = lo_salv->get_selections( )
           CHANGING
             s_layout              = ls_layout ).

        DATA(lt_fcat) = cl_salv_controller_metadata=>get_lvc_fieldcatalog(
                                                        r_columns      = lo_salv->get_columns( )
                                                        r_aggregations = lo_salv->get_aggregations( )    ).
        ro_grid->set_frontend_layout( ls_layout  ).
        ro_grid->set_frontend_fieldcatalog( lt_fcat ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_CAUT_ALV_UTILS=>SET_DROPDOWN_FOR_FIELD
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_FIELDNAME                   TYPE        CLIKE
* | [--->] IV_LENGTH                      TYPE        NUMERIC(optional)
* | [--->] IT_VALUES                      TYPE        ANY TABLE
* | [--->] IV_VALUE_FLD                   TYPE        CLIKE
* | [--->] IV_DESCR_FLD                   TYPE        CLIKE(optional)
* | [<-->] CO_GRID                        TYPE REF TO CL_GUI_ALV_GRID
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD set_dropdown_for_field ##NEEDED. "Part of the utilities framework
    DATA: lv_descr TYPE string,
          lt_ddali TYPE lvc_t_dral.
    "Also set the values for the Dropdown on Tax Type and Condition type
    co_grid->get_frontend_fieldcatalog(
      IMPORTING
        et_fieldcatalog = DATA(lt_fcat)
    ).
    "Determine a handle
    DATA lv_handle TYPE numc4.
    LOOP AT lt_fcat ASSIGNING FIELD-SYMBOL(<ls_field>).
      CHECK <ls_field>-drdn_hndl IS NOT INITIAL AND <ls_field>-drdn_hndl > lv_handle.
      lv_handle = <ls_field>-drdn_hndl.
    ENDLOOP.
    lv_handle = lv_handle + 1.

    READ TABLE lt_fcat WITH KEY fieldname = iv_fieldname
                                ASSIGNING <ls_field>.
    CHECK sy-subrc = 0.
    <ls_field>-drdn_hndl = lv_handle.
    IF iv_descr_fld IS SUPPLIED.
      <ls_field>-drdn_alias = abap_true.
    ENDIF.
    LOOP AT it_values ASSIGNING FIELD-SYMBOL(<ls_value>).
      ASSIGN COMPONENT iv_value_fld OF STRUCTURE <ls_value> TO FIELD-SYMBOL(<lv_value>).
      CHECK sy-subrc = 0.
      lv_descr = <lv_value>.
      IF iv_descr_fld IS SUPPLIED.
        ASSIGN COMPONENT iv_descr_fld OF STRUCTURE <ls_value> TO FIELD-SYMBOL(<lv_descr>).
        CHECK sy-subrc = 0.
        "Only used when supplied, else we just show the keys
        lv_descr = |{ <lv_value> } { <lv_descr> }|.
      ENDIF.
      APPEND VALUE lvc_s_dral(
       handle     = <ls_field>-drdn_hndl
       int_value  = <lv_value>
       value      = lv_descr      ) TO lt_ddali.
    ENDLOOP.

    co_grid->set_drop_down_table(
      EXPORTING
        it_drop_down_alias = lt_ddali

    ).

    IF iv_length IS SUPPLIED.
      <ls_field>-outputlen = iv_length.
    ENDIF.

    co_grid->set_frontend_fieldcatalog( it_fieldcatalog = lt_fcat ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_CAUT_ALV_UTILS=>SET_FIELD_EDITABLE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_FIELDNAME                   TYPE        CLIKE
* | [--->] IV_LENGTH                      TYPE        NUMERIC(optional)
* | [<-->] CO_GRID                        TYPE REF TO CL_GUI_ALV_GRID
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD set_field_editable ##NEEDED. "Part of the utilities framework

    DATA: lt_fcat  TYPE  lvc_t_fcat.

    co_grid->get_frontend_fieldcatalog(
     IMPORTING
       et_fieldcatalog = lt_fcat
   ).


    READ TABLE lt_fcat WITH KEY fieldname = iv_fieldname
                       ASSIGNING FIELD-SYMBOL(<ls_field>).
    CHECK sy-subrc = 0.
    <ls_field>-edit = abap_on.
    <ls_field>-checktable = '!'.
    IF iv_length IS SUPPLIED.
      <ls_field>-outputlen = iv_length.
    ENDIF.
    co_grid->set_frontend_fieldcatalog( it_fieldcatalog = lt_fcat ).


  ENDMETHOD.
ENDCLASS.
