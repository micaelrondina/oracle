/*==============================================================*/
/* Table: CTRL_LIMITADOR_EC                                     */
/*==============================================================*/
CREATE TABLE ISSR_ONLINE.ctrl_limitador_ec (
    id_acqr          NUMBER(4)     NOT NULL,
    nr_doc           NUMBER(14)    NOT NULL,
    id_produto       NUMBER(2)     NOT NULL,
    qt_max_transac   NUMBER(5)     NULL,
    vl_max_transac   NUMBER(18,4)  NULL,
    qt_acum_transac  NUMBER(5)     NULL,
    vl_acum_transac  NUMBER(18,4)  NULL,
    dt_contagem      DATE          NOT NULL,
	enviado_payware  CHAR           NULL,
    CONSTRAINT pk_ctrl_limitador_ec PRIMARY KEY (id_acqr, nr_doc, id_produto)
);
COMMENT ON TABLE  ISSR_ONLINE.ctrl_limitador_ec                 IS 'Transacoes por EC : quantidade e valor permitidos no dia e contagem do dia';
COMMENT ON COLUMN ISSR_ONLINE.ctrl_limitador_ec.id_acqr         IS 'Identificacao do adquirente';
COMMENT ON COLUMN ISSR_ONLINE.ctrl_limitador_ec.nr_doc          IS 'Numero do documento (CNPJ do comercio)';
COMMENT ON COLUMN ISSR_ONLINE.ctrl_limitador_ec.id_produto      IS 'Produto';
COMMENT ON COLUMN ISSR_ONLINE.ctrl_limitador_ec.qt_max_transac  IS 'Quantidade maxima permitida por dia';
COMMENT ON COLUMN ISSR_ONLINE.ctrl_limitador_ec.vl_max_transac  IS 'Valor maximo permitido por dia';
COMMENT ON COLUMN ISSR_ONLINE.ctrl_limitador_ec.qt_acum_transac IS 'Quantidade acumulada de transacoes no dia';
COMMENT ON COLUMN ISSR_ONLINE.ctrl_limitador_ec.vl_acum_transac IS 'Valor acumulado das transacoes no dia';
COMMENT ON COLUMN ISSR_ONLINE.ctrl_limitador_ec.dt_contagem     IS 'Data da contagem';
COMMENT ON COLUMN ISSR_ONLINE.ctrl_limitador_ec.enviado_payware IS 'Indica se foi enviado ao payware (S)';

