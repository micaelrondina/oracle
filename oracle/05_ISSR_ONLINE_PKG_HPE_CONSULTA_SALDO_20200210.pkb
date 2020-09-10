CREATE OR REPLACE PACKAGE BODY ISSR_ONLINE.PKG_HPE_CONSULTA_SALDO
as
   --
   procedure sp_consulta(p_id_usuario     varchar2    ,
                         p_tp_documento   number      ,
                         p_documento      varchar2    ,
                         p_tarjeta        varchar2    ,
                         p_fecha_inicio   number      ,
                         p_fecha_fim      number      ,
                         p_id_externo     varchar2    ,
                         p_erro           out number  ,
                         p_desc_erro      out varchar2,
                         p_rc1            out rc      ,
                         p_rc2            out rc      )
   is
      --
      v_count           number         ;
      v_count_tarjeta   number := 0    ;
      v_conta_duplicada number := 0    ;
      v_tp_chamada      char(1)        ;
      --
      v_emisor          number         ;
      v_sucursal_emisor number         ;
      v_producto        number         ;
      v_produto_sodexo  number         ;
      v_fecha_fim       number         ;
      --
      v_tarjeta         varchar2(16)   ;
      v_documento       char(15)       ;
      --
      v_numero_cuenta   number         ;
      v_tp_cartao       number         ;
      --
      v_dt_in           number         ;
      v_dt_fecha_inicio number         ;
      --
   begin

      --
      -- Obter emisor da tabela de acesso
      --
      begin
         --
         select emisor  , sucursal_emisor
         into   v_emisor, v_sucursal_emisor
         from   TB_WS_USUARIO_EMISOR
         where  ID_USUARIO = p_id_usuario;
         --
      exception
         when others then
            if (v_tarjeta is null) then
               --
               v_tp_chamada := 2;
               --
            else
               --
               v_tp_chamada := 1;
               --
            end if;
            p_erro      := 009;
            p_desc_erro := 'Sistema indisponivel';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  1004                 ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
         return;
      end;


      --
      -- Definir parametros para o LOG
      --
      p_erro := 0;
      --
      v_tarjeta := rtrim(ltrim(p_tarjeta));
      --
      if (v_tarjeta = '') then
         --
         v_tarjeta := null;
         --
      end if;
      --
      v_documento := rpad(p_documento, 15, ' ');
      --
      if (v_tarjeta is null) then
         --
         v_tp_chamada := 2;

         --

         -- 1) Validar CPF (verifica se existe na tabela cuentas.documento)
         --
         v_count := 0;
         --
         select count(1)
         into   v_count
         from   vm_contas
         where  emisor = v_emisor
         and    tipo_de_documento = p_tp_documento
         and    documento = v_documento;
         --
         if v_count = 0 then
            p_erro      := 004;
            p_desc_erro := 'Numero do CPF Invalido';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
         --
      else
         --
         v_tp_chamada := 1;
         --
         -- 1) Validar CPF (verifica se existe na tabela cuentas.documento)
         --
         v_count := 0;
         --
         select count(1)
         into   v_count
         from   vm_contas
         where  emisor = v_emisor
         and    tipo_de_documento = p_tp_documento
         and    documento = v_documento;
         --
         if v_count = 0 then
            p_erro      := 004;
            p_desc_erro := 'Numero do CPF Invalido';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
     --
     -- Ver se existe mais de uma tarjeta mascarada
     --
     select count(*)
     into   v_count_tarjeta
     from   vm_tarjetas  tar,
          vm_contas    cnt,
          VM_REL_CMS_PROD_PRE_PAGO prd
     where  cnt.emisor = v_emisor
     and    cnt.tipo_de_documento = p_tp_documento
     and    cnt.documento = v_documento
     and    tar.emisor = cnt.emisor
     and    tar.sucursal_emisor = cnt.sucursal_emisor
     and    tar.producto = cnt.producto
     and    tar.numero_cuenta = cnt.numero_cuenta
     and    tar.numero_cartao = v_tarjeta
     and    prd.emisor = tar.EMISOR
     and    prd.producto = tar.PRODUCTO
     and    prd.tipo_tarjeta = tar.TIPO_TARJETA;
     --
     if v_count_tarjeta > 1 then
        v_conta_duplicada := 1;
     end if;
         --
         -- 3) Dados para o LOG/ Validacao do cartao
         --
         begin
            --
      select X.producto, X.tipo_tarjeta, X.numero_cuenta, X.PRODUCTO_PREPAGO
      into   v_producto, v_tp_cartao   , v_numero_cuenta, v_produto_sodexo
      FROM (
        select tar.producto, tar.tipo_tarjeta, tar.numero_cuenta, prd.PRODUCTO_PREPAGO

        from   vm_tarjetas  tar,
             vm_contas    cnt,
             VM_REL_CMS_PROD_PRE_PAGO prd
        where  cnt.emisor = v_emisor
        and    cnt.tipo_de_documento = p_tp_documento
        and    cnt.documento = v_documento
        and    tar.emisor = cnt.emisor
        and    tar.sucursal_emisor = cnt.sucursal_emisor
        and    tar.producto = cnt.producto
        and    tar.numero_cuenta = cnt.numero_cuenta
        and    tar.numero_cartao = v_tarjeta
        and    prd.emisor = tar.EMISOR
        and    prd.producto = tar.PRODUCTO
        and    prd.tipo_tarjeta = tar.TIPO_TARJETA
        order  by tar.numero_cuenta desc
      ) X
      WHERE rownum = 1;
            --
         exception
            when others then
               p_erro      := 002;
               p_desc_erro := 'Numero do cartao Invalido';
               sp_log_consulta_saldo(v_tp_chamada         ,
                                     v_emisor             ,
                                     p_tp_documento       ,
                                     p_documento          ,
                                     v_tarjeta            ,
                                     v_produto_sodexo     ,
                                     v_tp_cartao          ,
                                     v_numero_cuenta      ,
                                     p_id_usuario         ,
                                     p_erro               ,
                   p_id_externo          );
            return;
         end;
         --
      end if;
      --

   -- Validacao Cartao Sem CPF

      select
                max(cdh.fecha_proceso)
        into    v_dt_in
        from
                vm_cambio_doc_hist cdh,
                vm_contas cta
       where
                cta.grupo_afinidad     = 2
         and    cta.emisor             = v_emisor
         and    cta.sucursal_emisor    = v_sucursal_emisor
         and    cta.producto           = v_producto
         and    cta.numero_cuenta      = v_numero_cuenta
         and    cta.tipo_de_documento  = p_tp_documento
         and    cta.documento          = v_documento

         and    cdh.emisor             = cta.emisor
         and    cdh.sucursal_emisor    = cta.sucursal_emisor
         and    cdh.producto           = cta.producto
         and    cdh.numero_cuenta      = cta.numero_cuenta
         and    cdh.tipo_documento_act = cta.tipo_de_documento;

         if (v_dt_in is not null and v_dt_in > p_fecha_inicio) then
             v_dt_fecha_inicio := v_dt_in;

         else
            v_dt_fecha_inicio := p_fecha_inicio;

         end if;

         --
      -- Se data final for null, devera ser a data de hoje
      --
      if ((p_fecha_fim is null) or (p_fecha_fim =0)) then
         v_fecha_fim := to_number(to_char(sysdate, 'yyyymmdd'));
      else
         declare
            v_data date;
         begin
            select to_date(p_fecha_fim, 'yyyymmdd') into v_data from dual;
         exception
            when others then
               --
               p_erro      := 005;
               p_desc_erro := 'Data final de pesquisa invalida';
               sp_log_consulta_saldo(v_tp_chamada         ,
                                     v_emisor             ,
                                     p_tp_documento       ,
                                     p_documento          ,
                                     v_tarjeta            ,
                                     v_produto_sodexo     ,
                                     v_tp_cartao          ,
                                     v_numero_cuenta      ,
                                     p_id_usuario         ,
                                     p_erro               ,
                   p_id_externo          );
               return;
         end;
         --
         v_fecha_fim := p_fecha_fim;
         --
      end if;
      --
      -- 4) Validar data inicial, deve ser maior que 90 dias (se nao for informada, retornar saldo)
      --
      if (v_dt_fecha_inicio <> 0) then
         declare
            v_data date;
         begin
            select to_date(v_dt_fecha_inicio, 'yyyymmdd') into v_data from dual;
         exception
            when others then
               --
               p_erro      := 003;
               p_desc_erro := 'Data inicial de pesquisa invalida' ;
               sp_log_consulta_saldo(v_tp_chamada         ,
                                     v_emisor             ,
                                     p_tp_documento       ,
                                     p_documento          ,
                                     v_tarjeta            ,
                                     v_produto_sodexo     ,
                                     v_tp_cartao          ,
                                     v_numero_cuenta      ,
                                     p_id_usuario         ,
                                     p_erro               ,
                   p_id_externo          );
               return;
               --
         end;
         if (to_date(v_dt_fecha_inicio, 'yyyymmdd') < sysdate - 90) then
            p_erro      := 003;
            p_desc_erro := 'Data inicial de pesquisa invalida' ;
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
      end if;
      --
      -- 5) Validar data final, deve ser maior que a data de inicio
      --
      if (v_dt_fecha_inicio <> 0) then
         if (to_date(v_dt_fecha_inicio, 'yyyymmdd') > to_date(v_fecha_fim, 'yyyymmdd')) then
            p_erro      := 005;
            p_desc_erro := 'Data final de pesquisa invalida';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
         if (sysdate < to_date(v_fecha_fim, 'yyyymmdd')) then
            p_erro      := 005;
            p_desc_erro := 'Data final de pesquisa invalida';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
      end if;
      --
      -- 6) Validar data final, deve ser menor que 90 dias da data inicial
      --
      if (v_dt_fecha_inicio <> 0) then
         if (to_date(v_dt_fecha_inicio, 'yyyymmdd') + 90 <= to_date(v_fecha_fim, 'yyyymmdd')) then
            p_erro      := 005;
            p_desc_erro := 'Data final de pesquisa invalida';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
      end if;
      --
      -- 7) Obter os dados do cartao
      --
      begin
         open p_rc1 for
            select distinct car.numero_cartao,
                   abs(spc.VL_SALDO_DISPONIVEL) saldo_disponivel,
                   decode(sign(spc.VL_SALDO_DISPONIVEL), -1, '-', '+') sinal,
                   decode(est.clase_de_estado, 0, '001', 1, '001', 2, '002', 3, '003') status_cartao,
                   rel.motivo_bloqueo motivo_bloqueio,
                   pkg_hpe_consulta_saldo.fc_ind_desbloqueio(car.estado, est.allows_activation, null, car.emisor, car.producto) ind_desbloqueio,
                   car.fecha_estado
            from   vm_contas                                          cnt
                   inner join vm_tarjetas                             car
                   on  car.emisor             = cnt.emisor
                   and car.sucursal_emisor    = cnt.sucursal_emisor
                   and car.producto           = cnt.producto
                   and car.numero_cuenta      = cnt.numero_cuenta
                   inner join vm_estados_ctas_tarj                    est
                   on  est.emisor             = car.emisor
                   and est.producto           = car.producto
                   and est.estado             = car.estado
                   inner join vm_rel_cms_estados                      rel
                   on  rel.emisor             = car.emisor
                   and rel.producto           = car.producto
                   and rel.estado             = car.estado
                   inner join SALDO_POR_CONTA                             spc
                   on  spc.CD_EMISSOR             = cnt.emisor
                   and spc.CD_SUCURSAL_EMISSOR    = cnt.sucursal_emisor
                   and spc.ID_PRODUTO           = cnt.producto
                   and spc.NR_CONTA      = cnt.numero_cuenta
            where  cnt.emisor = v_emisor
            and    cnt.sucursal_emisor = v_sucursal_emisor
            and    ((v_producto is null) or (cnt.producto = v_producto))
            and    cnt.tipo_de_documento    = p_tp_documento
            and    cnt.documento = v_documento
            and    ((v_tarjeta is null) or (car.numero_cartao = v_tarjeta))
      and    ((v_conta_duplicada = 0) or ((v_conta_duplicada = 1) and (cnt.numero_cuenta = v_numero_cuenta)))
            and    (
                      (v_tarjeta is null) and
                      (
                          car.correlativo = (
                                             select max(x.correlativo)
                                             from   vm_tarjetas x
                                             where  x.emisor = car.emisor
                                             and    x.sucursal_emisor = car.sucursal_emisor
                                             and    x.producto = car.producto
                                             and    x.numero_cuenta = car.numero_cuenta
                                            )
                      ) or
                      (car.numero_cartao = v_tarjeta)
                   )
            and    (
                      (v_tarjeta is not null) or
                      (
                         cnt.estado not in (
                                             select dgn.valor
                                             from   vm_datos_x_grupo_num dgn
                                             where  dgn.emisor    = cnt.emisor
                                             and    dgn.producto  = cnt.producto
                                             and    dgn.cod_grupo = 36
                                             and    dgn.valor     > 79
                       and    spc.VL_SALDO_DISPONIVEL = 0
                                            )
                      )
                   )
                   --and est.clase_de_estado in (0, 1)
                   ;
        exception
           when others then
              if p_erro = 0 then
                 p_erro      := 009;
                 p_desc_erro := 'Sistema indisponivel';
              end if;
              sp_log_consulta_saldo(v_tp_chamada         ,
                                    v_emisor             ,
                                    p_tp_documento       ,
                                    p_documento          ,
                                    v_tarjeta            ,
                                    v_produto_sodexo     ,
                                    v_tp_cartao          ,
                                    v_numero_cuenta      ,
                                    p_id_usuario         ,
                                    p_erro               ,
                  p_id_externo          );
              open p_rc1 for
                 select v_tarjeta      numero_cartao,
                        null           saldo_disponivel,
                        null           sinal,
                        null           status_cartao,
                        null           motivo_bloqueio,
                        null           ind_desbloqueio,
                        null           fecha_estado
                       from dual;
              return;
        end;
        --
        if v_dt_fecha_inicio <> 0 then
           begin
              open p_rc2 for
        select tb_aa.numero_cartao  ,
                     tb_aa.dt_transacao   ,
                     tb_aa.hr_transacao   ,
                     tb_aa.cod_aut        ,
                     tb_aa.tp_transacao   ,
                     tb_aa.desc_transacao ,
                     tb_aa.vl_transacao   ,
                     tb_aa.sinal_transacao
        from (
              select distinct
               tb_a.ID_MOVTOS_CUENTAS,
               tb_a.numero_cartao  ,
                     tb_a.dt_transacao   ,
                     tb_a.hr_transacao   ,
                     tb_a.cod_aut        ,
                     tb_a.tp_transacao   ,
                     tb_a.desc_transacao ,
                     tb_a.vl_transacao   ,
                     tb_a.sinal_transacao
              from  (
                      select null,
                             cnt.ID_MOVTOS_CUENTAS,
                             car.numero_cartao                                                                                     numero_cartao  ,
                             cnt.FECHA_MOVIMIENTO                                                                                  dt_transacao   ,
                             null                                                                                                  hr_transacao   ,
                             null                                                                                                  cod_aut        ,
                             --pkg_hpe_consulta_saldo.fc_tp_transacao(rub.rubro, null, cnt.origen_interno, cnt.codigo_operacion)     tp_transacao   ,
                             pkg_hpe_consulta_saldo.fc_tp_transacao(rub.rubro, cnt.origen_interno, cnt.codigo_operacion, null, null)     tp_transacao   ,
                             pkg_hpe_consulta_saldo.fc_descricao_transacao(rub.descripcion,cnt.id_comercio_emi, null)              desc_transacao ,
                             cnt.importe_ml                                                                                        vl_transacao   ,
                             pkg_hpe_consulta_saldo.fc_ind_sinal_transacao(cnt.codigo_operacion, null, null)                       sinal_transacao
                      from   vm_contas                cta
                             inner join vm_tarjetas          car
                             on  car.emisor                = cta.emisor
                             and car.sucursal_emisor       = cta.sucursal_emisor
                             and car.producto              = cta.producto
                             and car.numero_cuenta         = cta.numero_cuenta
                             inner join vm_movtos_conta      cnt
                             on  cnt.emisor                = cta.emisor
                             and cnt.sucursal_emisor       = cta.sucursal_emisor
                             and cnt.producto              = cta.producto
                             and cnt.numero_cuenta         = cta.numero_cuenta
                             inner join vm_rubros            rub
                             on  cnt.rubro                 = rub.rubro
                             inner join vm_estados_ctas_tarj est
                             on  est.emisor                = car.emisor
                             and est.producto              = car.producto
                             and est.estado                = car.estado
                             inner join vm_rel_cms_estados   rel
                             on  rel.emisor                = car.emisor
                             and rel.producto              = car.producto
                             and rel.estado                = car.estado
                              inner join SALDO_POR_CONTA                             spc
                              on  spc.CD_EMISSOR             = cta.emisor
                              and spc.CD_SUCURSAL_EMISSOR    = cta.sucursal_emisor
                              and spc.ID_PRODUTO           = cta.producto
                              and spc.NR_CONTA      = cta.numero_cuenta
                      where  cta.emisor = v_emisor
                      and    cta.sucursal_emisor = v_sucursal_emisor
                      and    ((v_producto is null) or (cta.producto = v_producto))
                      and    cta.tipo_de_documento    = p_tp_documento
                      and    cta.documento = v_documento
                      and    cnt.fecha_movimiento between v_dt_fecha_inicio and v_fecha_fim
            and    ((v_conta_duplicada = 0) or ((v_conta_duplicada = 1) and (cta.numero_cuenta = v_numero_cuenta)))
                      and    (
                                (
                                   (v_tarjeta is null) and
                                   (car.correlativo = (select max(x.correlativo)
                                                       from vm_tarjetas x
                                                       where x.emisor = car.emisor
                                                       and   x.sucursal_emisor = car.sucursal_emisor
                                                       and   x.producto = car.producto
                                                       and   x.numero_cuenta = car.numero_cuenta)
                                   )
                                ) or
                                (cnt.numero_cartao = v_tarjeta)
                             )
                      and    (
                                (v_tarjeta is not null) or
                                (
                                   (cta.estado  not in (
                                                        select dgn.valor
                                                        from   vm_datos_x_grupo_num dgn
                                                        where  dgn.emisor    = cnt.emisor
                                                        and    dgn.producto  = cnt.producto
                                                        and    dgn.cod_grupo = 36
                                                        and    dgn.valor     > 79
                            and    spc.VL_SALDO_DISPONIVEL = 0
                                                       )
                                   )
                                )
                             )
                      union all
                      select null,
                             null,
                             car.numero_cartao                                                                        numero_cartao  ,
                             aut.FECHA_LOCAL                                                                          dt_transacao   ,
                             aut.HHMMSS_LOCAL                                                                         hr_transacao   ,
                             aut.COD_AUT_INT                                                                          cod_aut        ,
                             --pkg_hpe_consulta_saldo.fc_tp_transacao(null, aut.mti, null, null)                        tp_transacao   ,
               pkg_hpe_consulta_saldo.fc_tp_transacao(null, null, null, aut.mti, substr(lpad(proc_code, 6,'0' ), 0, 2))     tp_transacao   ,
                             aut.NOME_EC                                                                              desc_transacao ,
                             aut.IMPORTE_INT_PF_ML                                                                    vl_transacao   ,
                             pkg_hpe_consulta_saldo.fc_ind_sinal_transacao(null, aut.mti, substr(lpad(proc_code, 6,'0' ), 0, 2))              sinal_transacao
                      from   vm_contas                cta
                             inner join vm_tarjetas          car
                             on  car.emisor                = cta.emisor
                             and car.sucursal_emisor       = cta.sucursal_emisor
                             and car.producto              = cta.producto
                             and car.numero_cuenta         = cta.numero_cuenta
                             inner join V_AUTORIZACOES      aut
                             on  aut.producto              = cta.producto
                             and aut.numero_cuenta         = cta.numero_cuenta
                             inner join vm_estados_ctas_tarj est
                             on  est.emisor                = car.emisor
                             and est.producto              = car.producto
                             and est.estado                = car.estado
                             inner join vm_rel_cms_estados   rel
                             on  rel.emisor                = car.emisor
                             and rel.producto              = car.producto
                             and rel.estado                = car.estado
                             inner join SALDO_POR_CONTA        spc
                              on  spc.CD_EMISSOR             = cta.emisor
                              and spc.CD_SUCURSAL_EMISSOR    = cta.sucursal_emisor
                              and spc.ID_PRODUTO           = cta.producto
                              and spc.NR_CONTA      = cta.numero_cuenta
                      where  cta.emisor = v_emisor
                      and    cta.sucursal_emisor = v_sucursal_emisor
                      and    ((v_producto is null) or (cta.producto = v_producto))
                      and    cta.tipo_de_documento    = p_tp_documento
                      and    cta.documento = v_documento
            and    aut.mti not in  (400, 420, 9999)
                      and    aut.FECHA_LOCAL between v_dt_fecha_inicio and v_fecha_fim
            and    ((v_conta_duplicada = 0) or ((v_conta_duplicada = 1) and (cta.numero_cuenta = v_numero_cuenta)))
                      and    (
                                (
                                   (v_tarjeta is null) and
                                   (car.correlativo = (
                                                       select max(x.correlativo)
                                                       from  vm_tarjetas x
                                                       where x.emisor = car.emisor
                                                       and   x.sucursal_emisor = car.sucursal_emisor
                                                       and   x.producto = car.producto
                                                       and   x.numero_cuenta = car.numero_cuenta
                                                      )
                                   )
                                ) or
                                (aut.numero_cartao = v_tarjeta)
                             )
                      and    (
                                (v_tarjeta is not null) or
                                (
                                   (cta.estado not in (
                                                       select dgn.valor
                                                       from   vm_datos_x_grupo_num dgn
                                                       where  dgn.emisor    = cta.emisor
                                                       and    dgn.producto  = cta.producto
                                                       and    dgn.cod_grupo = 36
                                                       and    dgn.valor     > 79
                             and   spc.VL_SALDO_DISPONIVEL = 0
                                                      )
                                   )
                                )
                             )
             union all
             select null,
                    mld.id_lote_detalle                                                                        id_lote_detalle,
                    car.numero_cartao                                                                          numero_cartao  ,
                    mld.F_PREVISTA                                                                             dt_transacao   ,
                    0                                                                                          hr_transacao   ,
                    '0'                                                                                          cod_aut        ,
                    to_char(mld.TIPO)                                                                                   tp_transacao   ,
                       mdt.DESCRIPCION                                                                            desc_transacao ,
                    mld.IMPORTE                                                                                vl_transacao   ,
                    decode(mdt.IND_CREDITO, 0, '-', 1, '+')                                                    sinal_transacao
                      from   vm_contas                       cta
                             inner join vm_tarjetas          car
                             on  car.emisor                = cta.emisor
                             and car.sucursal_emisor       = cta.sucursal_emisor
                             and car.producto              = cta.producto
                             and car.numero_cuenta         = cta.numero_cuenta
                             inner join vm_estados_ctas_tarj est
                             on  est.emisor                = car.emisor
                             and est.producto              = car.producto
                             and est.estado                = car.estado
                             inner join vm_rel_cms_estados   rel
                             on  rel.emisor                = car.emisor
                             and rel.producto              = car.producto
                             and rel.estado                = car.estado
                             inner join VM_MVAG_LOTE_DETALLE mld
                             on  mld.emisor                = cta.emisor
                             and mld.sucursal_emisor       = cta.sucursal_emisor
                             and mld.producto              = cta.producto
                             and mld.numero_cuenta         = cta.numero_cuenta
                             inner join VM_MVAG_LOTE_DETALLE_TIPO   mdt
                             on  mdt.TIPO                  = mld.TIPO
                              inner join SALDO_POR_CONTA        spc
                              on  spc.CD_EMISSOR             = cta.emisor
                              and spc.CD_SUCURSAL_EMISSOR    = cta.sucursal_emisor
                              and spc.ID_PRODUTO           = cta.producto
                              and spc.NR_CONTA      = cta.numero_cuenta
                      where  cta.emisor = v_emisor
                      and    cta.sucursal_emisor = v_sucursal_emisor
                      and    ((v_producto is null) or (cta.producto = v_producto))
                      and    cta.tipo_de_documento    = p_tp_documento
                      and    cta.documento = v_documento
            and    ((v_conta_duplicada = 0) or ((v_conta_duplicada = 1) and (cta.numero_cuenta = v_numero_cuenta)))
                      and    (
                                (
                                   (v_tarjeta is null) and
                                   (car.correlativo = (
                                                       select max(x.correlativo)
                                                       from  vm_tarjetas x
                                                       where x.emisor = car.emisor
                                                       and   x.sucursal_emisor = car.sucursal_emisor
                                                       and   x.producto = car.producto
                                                       and   x.numero_cuenta = car.numero_cuenta
                                                      )
                                   )
                                ) or
                                (car.numero_cartao = v_tarjeta)
                             )
                      and    (
                                (v_tarjeta is not null) or
                                (
                                   (cta.estado not in (
                                                       select dgn.valor
                                                       from   vm_datos_x_grupo_num dgn
                                                       where  dgn.emisor    = cta.emisor
                                                       and    dgn.producto  = cta.producto
                                                       and    dgn.cod_grupo = 36
                                                       and    dgn.valor     > 79
                                                       and    spc.VL_SALDO_DISPONIVEL = 0
                                                      )
                                   )
                                )
                             )
                    ) tb_a ) tb_aa
              order by tb_aa.numero_cartao desc,
                       tb_aa.dt_transacao  desc,
                       tb_aa.hr_transacao  desc;
           --
           exception
              when others then
                 if p_erro = 0 then
                    p_erro      := 009;
                    p_desc_erro := 'Sistema indisponivel';
                 end if;
                 sp_log_consulta_saldo(v_tp_chamada         ,
                                       v_emisor             ,
                                       p_tp_documento       ,
                                       p_documento          ,
                                       v_tarjeta            ,
                                       v_produto_sodexo     ,
                                       v_tp_cartao          ,
                                       v_numero_cuenta      ,
                                       p_id_usuario         ,
                                       p_erro               ,
                     p_id_externo          );
                 open p_rc2 for
                    select null  numero_cartao  ,
                           null  dt_transacao   ,
                           null  hr_transacao   ,
                           null  cod_aut        ,
                           null  tp_transacao   ,
                           null  desc_transacao ,
                           null  vl_transacao   ,
                           null  sinal_transacao
                    from   dual;
                    return;
           end;
        end if;
        --
        p_erro      := 001;
        p_desc_erro := 'Consulta efetuada com sucesso';
        --
        sp_log_consulta_saldo(v_tp_chamada         ,
                              v_emisor             ,
                              p_tp_documento       ,
                              p_documento          ,
                              v_tarjeta            ,
                              v_produto_sodexo     ,
                              v_tp_cartao          ,
                              v_numero_cuenta      ,
                              p_id_usuario         ,
                              p_erro               ,
                p_id_externo          );
        --
   exception
      when others then
         --
         if p_erro = 0 then
            p_erro      := 009;
            p_desc_erro := 'Sistema indisponivel';
         end if;
         sp_log_consulta_saldo(v_tp_chamada         ,
                               v_emisor             ,
                               p_tp_documento       ,
                               p_documento          ,
                               v_tarjeta            ,
                               v_produto_sodexo     ,
                               v_tp_cartao          ,
                               v_numero_cuenta      ,
                               p_id_usuario         ,
                               p_erro               ,
                 p_id_externo          );
         --
         open p_rc1 for
            select v_tarjeta      numero_cartao   ,
                   0              saldo_disponivel,
                   '+'            sinal           ,
                   null           status_cartao   ,
                   null           motivo_bloqueio ,
                   null           ind_desbloqueio ,
                   null           fecha_estado
            from   dual;
            --
         open p_rc2 for
            select v_tarjeta  numero_cartao  ,
                   null       dt_transacao   ,
                   null       hr_transacao   ,
                   null       cod_aut        ,
                   null       tp_transacao   ,
                   null       desc_transacao ,
                   null       vl_transacao   ,
                   null       sinal_transacao
            from   dual;
   end sp_consulta;

  procedure sp_consulta_new(p_id_usuario    varchar2    ,
                         p_tp_documento  number      ,
                         p_documento     varchar2    ,
                         p_tarjeta        varchar2    ,
                         p_fecha_inicio   number      ,
                         p_fecha_fim      number      ,
             p_id_externo      varchar2    ,
             p_versao_chamada  varchar2  ,
                         p_erro           out number  ,
                         p_desc_erro      out varchar2,
                         p_rc1            out rc      ,
                         p_rc2            out rc      ,
             p_rc3        out rc)
   is
      --
      v_count           number         ;
      v_count_tarjeta   number := 0    ;
      v_conta_duplicada number := 0    ;
      v_tp_chamada      char(1)        ;
      --
      v_emisor          number         ;
      v_sucursal_emisor number         ;
      v_producto        number         ;
      v_produto_sodexo  number         ;
      v_fecha_fim       number         ;
      --
      v_tarjeta         varchar2(16)   ;
      v_documento       char(15)       ;
      --
      v_numero_cuenta   number         ;
      v_tp_cartao       number         ;
      --
      v_dt_in           number         ;
      v_dt_fecha_inicio number         ;
      --
   begin
      --
      -- Obter emisor da tabela de acesso
      --
      begin
         --
         select emisor  , sucursal_emisor
         into   v_emisor, v_sucursal_emisor
         from   TB_WS_USUARIO_EMISOR
         where  ID_USUARIO = p_id_usuario;
         --
      exception
         when others then
            if (v_tarjeta is null) then
               --
               v_tp_chamada := 2;
               --
            else
               --
               v_tp_chamada := 1;
               --
            end if;
            p_erro      := 009;
            p_desc_erro := 'Sistema indisponivel';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  1004                 ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
         return;
      end;
    --
    --
    --
    if (p_versao_chamada <> '2.0') then
    p_erro      := 006;
    p_desc_erro := 'Versao invalida';
    return;
    end if;
      --
      -- Definir parametros para o LOG
      --
      p_erro := 0;
      --
      v_tarjeta := rtrim(ltrim(p_tarjeta));
      --
      if (v_tarjeta = '') then
         --
         v_tarjeta := null;
         --
      end if;
      --
      v_documento := rpad(p_documento, 15, ' ');
      --
      if (v_tarjeta is null) then
         --
         v_tp_chamada := 2;

         --

         -- 1) Validar CPF (verifica se existe na tabela cuentas.documento)
         --
         v_count := 0;
         --
         select count(1)
         into   v_count
         from   vm_contas
         where  emisor = v_emisor
         and    tipo_de_documento = p_tp_documento
         and    documento = v_documento;
         --
         if v_count = 0 then
            p_erro      := 004;
            p_desc_erro := 'Numero do CPF Invalido';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
         --
      else
         --
         v_tp_chamada := 1;
         --
         -- 1) Validar CPF (verifica se existe na tabela cuentas.documento)
         --
         v_count := 0;
         --
         select count(1)
         into   v_count
         from   vm_contas
         where  emisor = v_emisor
         and    tipo_de_documento = p_tp_documento
         and    documento = v_documento;
         --
         if v_count = 0 then
            p_erro      := 004;
            p_desc_erro := 'Numero do CPF Invalido';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
     --
     -- Ver se existe mais de uma tarjeta mascarada
     --
     select count(*)
     into   v_count_tarjeta
     from   vm_tarjetas  tar,
          vm_contas    cnt,
          VM_REL_CMS_PROD_PRE_PAGO prd
     where  cnt.emisor = v_emisor
     and    cnt.tipo_de_documento = p_tp_documento
     and    cnt.documento = v_documento
     and    tar.emisor = cnt.emisor
     and    tar.sucursal_emisor = cnt.sucursal_emisor
     and    tar.producto = cnt.producto
     and    tar.numero_cuenta = cnt.numero_cuenta
     and    tar.numero_cartao = v_tarjeta
     and    prd.emisor = tar.EMISOR

     and    prd.producto = tar.PRODUCTO
     and    prd.tipo_tarjeta = tar.TIPO_TARJETA;
     --
     if v_count_tarjeta > 1 then
        v_conta_duplicada := 1;
     end if;
         --
         -- 3) Dados para o LOG/ Validacao do cartao
         --
         begin
            --
      select X.producto, X.tipo_tarjeta, X.numero_cuenta, X.PRODUCTO_PREPAGO
      into   v_producto, v_tp_cartao   , v_numero_cuenta, v_produto_sodexo
      FROM (
        select tar.producto, tar.tipo_tarjeta, tar.numero_cuenta, prd.PRODUCTO_PREPAGO

        from   vm_tarjetas  tar,
             vm_contas    cnt,
             VM_REL_CMS_PROD_PRE_PAGO prd
        where  cnt.emisor = v_emisor
        and    cnt.tipo_de_documento = p_tp_documento
        and    cnt.documento = v_documento
        and    tar.emisor = cnt.emisor
        and    tar.sucursal_emisor = cnt.sucursal_emisor
        and    tar.producto = cnt.producto
        and    tar.numero_cuenta = cnt.numero_cuenta
        and    tar.numero_cartao = v_tarjeta
        and    prd.emisor = tar.EMISOR
        and    prd.producto = tar.PRODUCTO
        and    prd.tipo_tarjeta = tar.TIPO_TARJETA
        order  by tar.numero_cuenta desc
      ) X
      WHERE rownum = 1;
            --
         exception
            when others then
               p_erro      := 002;
               p_desc_erro := 'Numero do cartao Invalido';
               sp_log_consulta_saldo(v_tp_chamada         ,
                                     v_emisor             ,
                                     p_tp_documento       ,
                                     p_documento          ,
                                     v_tarjeta            ,
                                     v_produto_sodexo     ,
                                     v_tp_cartao          ,
                                     v_numero_cuenta      ,
                                     p_id_usuario         ,
                                     p_erro               ,
                   p_id_externo          );
            return;
         end;
         --
      end if;
      --
              -- Validacao Cartao Sem CPF

      select
                max(cdh.fecha_proceso)
        into    v_dt_in
        from
                vm_cambio_doc_hist cdh,
                vm_contas cta
       where
                cta.grupo_afinidad     = 2
         and    cta.emisor             = v_emisor
         and    cta.sucursal_emisor    = v_sucursal_emisor
         and    cta.producto           = v_producto
         and    cta.numero_cuenta      = v_numero_cuenta
         and    cta.tipo_de_documento  = p_tp_documento
         and    cta.documento          = v_documento

         and    cdh.emisor             = cta.emisor
         and    cdh.sucursal_emisor    = cta.sucursal_emisor
         and    cdh.producto           = cta.producto
         and    cdh.numero_cuenta      = cta.numero_cuenta
         and    cdh.tipo_documento_act = cta.tipo_de_documento;

         if (v_dt_in is not null and v_dt_in > p_fecha_inicio) then
             v_dt_fecha_inicio := v_dt_in;

         else
            v_dt_fecha_inicio := p_fecha_inicio;

         end if;

         --
      -- Se data final for null, devera ser a data de hoje
      --
      if ((p_fecha_fim is null) or (p_fecha_fim =0)) then
         v_fecha_fim := to_number(to_char(sysdate, 'yyyymmdd'));
      else
         declare
            v_data date;
         begin
            select to_date(p_fecha_fim, 'yyyymmdd') into v_data from dual;
         exception
            when others then
               --
               p_erro      := 005;
               p_desc_erro := 'Data final de pesquisa invalida';
               sp_log_consulta_saldo(v_tp_chamada         ,
                                     v_emisor             ,
                                     p_tp_documento       ,
                                     p_documento          ,
                                     v_tarjeta            ,
                                     v_produto_sodexo     ,
                                     v_tp_cartao          ,
                                     v_numero_cuenta      ,
                                     p_id_usuario         ,
                                     p_erro               ,
                   p_id_externo          );
               return;
         end;
         --
         v_fecha_fim := p_fecha_fim;
         --
      end if;
      --
      -- 4) Validar data inicial, deve ser maior que 90 dias (se nao for informada, retornar saldo)
      --
      if (v_dt_fecha_inicio <> 0) then
         declare
            v_data date;
         begin
            select to_date(v_dt_fecha_inicio, 'yyyymmdd') into v_data from dual;
         exception
            when others then
               --
               p_erro      := 003;
               p_desc_erro := 'Data inicial de pesquisa invalida' ;
               sp_log_consulta_saldo(v_tp_chamada         ,
                                     v_emisor             ,
                                     p_tp_documento       ,
                                     p_documento          ,
                                     v_tarjeta            ,
                                     v_produto_sodexo     ,
                                     v_tp_cartao          ,
                                     v_numero_cuenta      ,
                                     p_id_usuario         ,
                                     p_erro               ,
                   p_id_externo          );
               return;
               --
         end;
         if (to_date(v_dt_fecha_inicio, 'yyyymmdd') < sysdate - 90) then
            p_erro      := 003;
            p_desc_erro := 'Data inicial de pesquisa invalida' ;
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
      end if;
      --
      -- 5) Validar data final, deve ser maior que a data de inicio
      --
      if (v_dt_fecha_inicio <> 0) then
         if (to_date(v_dt_fecha_inicio, 'yyyymmdd') > to_date(v_fecha_fim, 'yyyymmdd')) then
            p_erro      := 005;
            p_desc_erro := 'Data final de pesquisa invalida';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
         if (sysdate < to_date(v_fecha_fim, 'yyyymmdd')) then
            p_erro      := 005;
            p_desc_erro := 'Data final de pesquisa invalida';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
      end if;
      --
      -- 6) Validar data final, deve ser menor que 90 dias da data inicial
      --
      if (v_dt_fecha_inicio <> 0) then
         if (to_date(v_dt_fecha_inicio, 'yyyymmdd') + 90 <= to_date(v_fecha_fim, 'yyyymmdd')) then
            p_erro      := 005;
            p_desc_erro := 'Data final de pesquisa invalida';
            sp_log_consulta_saldo(v_tp_chamada         ,
                                  v_emisor             ,
                                  p_tp_documento       ,
                                  p_documento          ,
                                  v_tarjeta            ,
                                  v_produto_sodexo     ,
                                  v_tp_cartao          ,
                                  v_numero_cuenta      ,
                                  p_id_usuario         ,
                                  p_erro               ,
                  p_id_externo          );
            return;
         end if;
      end if;
      --
      -- 7) Obter os dados da conta
      --
      begin
         open p_rc1 for
        select distinct
             cnt.emisor,
             cnt.sucursal_emisor,
             cnt.producto,
             cnt.numero_cuenta,
             abs(spc.VL_SALDO_DISPONIVEL) saldo_disponivel,
             decode(sign(spc.VL_SALDO_DISPONIVEL), -1, '-', '+') sinal,
             ppp.producto_prepago codigo_produto,
             cec.nro_cta_empresa
        from   vm_contas                                          cnt
             inner join vm_tarjetas                             car
             on  car.emisor             = cnt.emisor
             and car.sucursal_emisor    = cnt.sucursal_emisor
             and car.producto           = cnt.producto
             and car.numero_cuenta      = cnt.numero_cuenta
             --sdx
             inner join vm_rel_cms_prod_pre_pago          ppp
             on  ppp.tipo_tarjeta     = car.tipo_tarjeta
             and ppp.emisor        = car.emisor
             and ppp.producto        = car.producto
             inner join vm_cuentas_empresas_clientes        cec
             on  cec.emisor        = cnt.emisor
             and cec.sucursal_emisor    = cnt.sucursal_emisor
             and cec.producto        = cnt.producto
             and cec.numero_cuenta    = cnt.numero_cuenta
            inner join SALDO_POR_CONTA                             spc
            on  spc.CD_EMISSOR             = cnt.emisor
            and spc.CD_SUCURSAL_EMISSOR    = cnt.sucursal_emisor
            and spc.ID_PRODUTO           = cnt.producto
            and spc.NR_CONTA      = cnt.numero_cuenta
        where  cnt.emisor = v_emisor
        and    cnt.sucursal_emisor = v_sucursal_emisor
        and    ((v_producto is null) or (cnt.producto = v_producto))
        and    cnt.tipo_de_documento    = p_tp_documento
        and    cnt.documento = v_documento
        and    ((v_tarjeta is null) or (car.numero_cartao = v_tarjeta))
        and    ((v_conta_duplicada = 0) or ((v_conta_duplicada = 1) and (cnt.numero_cuenta = v_numero_cuenta)))
        and    (
              (v_tarjeta is null) and
              (
              car.correlativo in ((select max(x.correlativo)
                           from vm_tarjetas x
                           where x.emisor = car.emisor
                           and   x.sucursal_emisor = car.sucursal_emisor
                           and   x.producto = car.producto
                           and   x.numero_cuenta = car.numero_cuenta),
                           (select max(x.correlativo)
                           from vm_tarjetas x
                           where x.emisor = car.emisor
                           and   x.sucursal_emisor = car.sucursal_emisor
                           and   x.producto = car.producto
                           and   x.numero_cuenta = car.numero_cuenta
                           and   x.estado = 34))
              ) or
              (car.numero_cartao = v_tarjeta)
             )
        and    (
              (v_tarjeta is not null) or
              (
               cnt.estado not in (
                         select dgn.valor
                         from   vm_datos_x_grupo_num dgn
                         where  dgn.emisor    = cnt.emisor
                         and    dgn.producto  = cnt.producto
                         and    dgn.cod_grupo = 36
                         and    dgn.valor     > 79
                         and    spc.VL_SALDO_DISPONIVEL = 0
                        )
              )
             );
        exception
           when others then
              if p_erro = 0 then
                 p_erro      := 009;
                 p_desc_erro := 'Sistema indisponivel';
              end if;
              sp_log_consulta_saldo(v_tp_chamada         ,
                                    v_emisor             ,
                                    p_tp_documento       ,
                                    p_documento          ,
                                    v_tarjeta            ,
                                    v_produto_sodexo     ,
                                    v_tp_cartao          ,
                                    v_numero_cuenta      ,
                                    p_id_usuario         ,
                                    p_erro               ,
                  p_id_externo          );
              open p_rc1 for
                 select  null  emisor,
            null  sucursal_emisor,
            null  producto,
            null  numero_cuenta,
            null  saldo_disponivel,
            null  sinal,
            null  codigo_produto,
            null  nro_cta_empresa
                       from dual;
              return;
        end;
        --
          --
      -- 8) Obter os dados do cartao
      --
      begin
         open p_rc3 for
            select distinct
          cnt.EMISOR,
          cnt.SUCURSAL_EMISOR,
          cnt.PRODUCTO,
          cnt.NUMERO_CUENTA,
          --
          car.numero_cartao,
          --Data de validade do cartao
          car.fecha_vigencia,
          decode(est.clase_de_estado, 0, '001', 1, '001', 2, '002', 3, '003') status_cartao,
          rel.motivo_bloqueo motivo_bloqueio,
          --Descricao do Motivo do Bloqueio
          rel.descripcion,
          fc_ind_desbloqueio(car.estado, est.allows_activation, null, car.emisor, car.producto) ind_desbloqueio,
          car.fecha_estado,
          --Forma de desbloqueio do cartao
          car.forma_desbloqueo
            from   vm_contas                                          cnt
                   inner join vm_tarjetas                             car
                   on  car.emisor             = cnt.emisor
                   and car.sucursal_emisor    = cnt.sucursal_emisor
                   and car.producto           = cnt.producto
                   and car.numero_cuenta      = cnt.numero_cuenta
                   inner join vm_estados_ctas_tarj                    est
                   on  est.emisor             = car.emisor
                   and est.producto           = car.producto
                   and est.estado             = car.estado
                   inner join vm_rel_cms_estados                      rel
                   on  rel.emisor             = car.emisor
                   and rel.producto           = car.producto
                   and rel.estado             = car.estado
                  inner join SALDO_POR_CONTA        spc
                  on  spc.CD_EMISSOR             = cnt.emisor
                  and spc.CD_SUCURSAL_EMISSOR    = cnt.sucursal_emisor
                  and spc.ID_PRODUTO           = cnt.producto
                  and spc.NR_CONTA      = cnt.numero_cuenta
            where  cnt.emisor = v_emisor
            and    cnt.sucursal_emisor = v_sucursal_emisor
            and    ((v_producto is null) or (cnt.producto = v_producto))
            and    cnt.tipo_de_documento    = p_tp_documento
            and    cnt.documento = v_documento
            and    ((v_tarjeta is null) or (car.numero_cartao = v_tarjeta))
      and    ((v_conta_duplicada = 0) or ((v_conta_duplicada = 1) and (cnt.numero_cuenta = v_numero_cuenta)))
            and    (
                      (v_tarjeta is null) and
                      (
                        car.correlativo in ((select max(x.correlativo)
                                               from vm_tarjetas x
                                               where x.emisor = car.emisor
                                               and   x.sucursal_emisor = car.sucursal_emisor
                                               and   x.producto = car.producto
                                               and   x.numero_cuenta = car.numero_cuenta),
                                               (select max(x.correlativo)
                                               from vm_tarjetas x
                                               where x.emisor = car.emisor
                                               and   x.sucursal_emisor = car.sucursal_emisor
                                               and   x.producto = car.producto
                                               and   x.numero_cuenta = car.numero_cuenta
                                               and   x.estado = 34))
                      ) or
                      (car.numero_cartao = v_tarjeta)
                   )
            and    (
                      (v_tarjeta is not null) or
                      (
                         cnt.estado not in (
                                             select dgn.valor
                                             from   vm_datos_x_grupo_num dgn
                                             where  dgn.emisor    = cnt.emisor
                                             and    dgn.producto  = cnt.producto
                                             and    dgn.cod_grupo = 36
                                             and    dgn.valor     > 79
                       and    spc.VL_SALDO_DISPONIVEL = 0
                                            )
                      )
                   )
                   --and est.clase_de_estado in (0, 1)
                   ;
        exception
           when others then
              if p_erro = 0 then
                 p_erro      := 009;
                 p_desc_erro := 'Sistema indisponivel';
              end if;
              sp_log_consulta_saldo(v_tp_chamada         ,
                                    v_emisor             ,
                                    p_tp_documento       ,
                                    p_documento          ,
                                    v_tarjeta            ,
                                    v_produto_sodexo     ,
                                    v_tp_cartao          ,
                                    v_numero_cuenta      ,
                                    p_id_usuario         ,
                                    p_erro               ,
                  p_id_externo          );
              open p_rc3 for
                select  null  EMISOR,
            null  SUCURSAL_EMISOR,
            null  PRODUCTO,
            null  NUMERO_CUENTA,
            null  numero_cartao,
            null  fecha_vigencia,
            null  status_cartao,
            null  motivo_bloqueio,
            null  descripcion,
            null  ind_desbloqueio,
            null  fecha_estado,
            null  forma_desbloqueo
        from dual;
              return;
        end;
    --
        if v_dt_fecha_inicio <> 0 then
           begin
              open p_rc2 for
        select distinct
           tb_aa.emisor,
           tb_aa.sucursal_emisor,
           tb_aa.producto,
           tb_aa.numero_cuenta,
           tb_aa.numero_cartao  ,
           tb_aa.dt_transacao   ,
           tb_aa.hr_transacao   ,
           tb_aa.cod_aut        ,
           tb_aa.tp_transacao   ,
           tb_aa.desc_transacao ,
           tb_aa.vl_transacao   ,
           tb_aa.sinal_transacao,
           --Tipo de documento do EC
           tb_aa.tp_documento_ec,
           --Numero da Documento
           tb_aa.num_doc_ec,
           --Codigo correspondente
           tb_aa.cod_correspondente
        from (
              select distinct
               tb_a.emisor,
               tb_a.sucursal_emisor,
               tb_a.producto,
               tb_a.numero_cuenta,
               tb_a.ID_MOVTOS_CUENTAS,
               tb_a.numero_cartao  ,
               tb_a.id_lote_detalle,
               tb_a.dt_transacao   ,
               tb_a.hr_transacao   ,
               tb_a.cod_aut        ,
               tb_a.tp_transacao   ,
               tb_a.desc_transacao ,
               tb_a.vl_transacao   ,
               tb_a.sinal_transacao,
               --Tipo de documento do EC
               tb_a.tp_documento_ec,
               --Numero da Documento
               tb_a.num_doc_ec,
               --Codigo correspondente
               tb_a.cod_correspondente
              from  (
                      select
                             cta.emisor,
                             cta.sucursal_emisor,
                             cta.producto,
                             cta.numero_cuenta,
                             cnt.ID_MOVTOS_CUENTAS,
                             cnt.numero_cartao                                                                                     numero_cartao  ,
                             NVL(mld.id_lote_detalle,0)                                                                                   id_lote_detalle,
                             cnt.FECHA_MOVIMIENTO                                                                                  dt_transacao   ,
                             null                                                                                                  hr_transacao   ,
                             null                                                                                                  cod_aut        ,
                             --pkg_hpe_consulta_saldo.fc_tp_transacao(rub.rubro, null, cnt.origen_interno, cnt.codigo_operacion)     tp_transacao   ,
                             pkg_hpe_consulta_saldo.fc_tp_transacao(rub.rubro, cnt.origen_interno, cnt.codigo_operacion, null, null)     tp_transacao   ,
                             pkg_hpe_consulta_saldo.fc_descricao_transacao(rub.descripcion,cnt.id_comercio_emi, null)              desc_transacao ,
                             cnt.importe_ml                                                                                        vl_transacao   ,
                             pkg_hpe_consulta_saldo.fc_ind_sinal_transacao(cnt.codigo_operacion, null, null)                       sinal_transacao,
                             null tp_documento_ec,
                             null num_doc_ec,
                             null cod_correspondente
                      from   vm_contas                cta
                             inner join vm_tarjetas          car
                             on  car.emisor                = cta.emisor
                             and car.sucursal_emisor       = cta.sucursal_emisor
                             and car.producto              = cta.producto
                             and car.numero_cuenta         = cta.numero_cuenta
                             inner join vm_movtos_conta      cnt
                             on  cnt.emisor                = cta.emisor
                             and cnt.sucursal_emisor       = cta.sucursal_emisor
                             and cnt.producto              = cta.producto
                             and cnt.numero_cuenta         = cta.numero_cuenta
                             inner join vm_rubros            rub
                             on  cnt.rubro                 = rub.rubro
                             inner join vm_estados_ctas_tarj est
                             on  est.emisor                = car.emisor
                             and est.producto              = car.producto
                             and est.estado                = car.estado
                             inner join vm_rel_cms_estados   rel
                             on  rel.emisor                = car.emisor
                             and rel.producto              = car.producto
                             and rel.estado                = car.estado
                             left join VM_MVAG_LOTE_DETALLE mld
                             on  mld.emisor                = cta.emisor
                             and mld.sucursal_emisor       = cta.sucursal_emisor
                             and mld.producto              = cta.producto
                             and mld.numero_cuenta         = cta.numero_cuenta
                             inner join SALDO_POR_CONTA        spc
                              on  spc.CD_EMISSOR             = cta.emisor
                              and spc.CD_SUCURSAL_EMISSOR    = cta.sucursal_emisor
                              and spc.ID_PRODUTO           = cta.producto
                              and spc.NR_CONTA      = cta.numero_cuenta
                      where  cta.emisor = v_emisor
                      and    cta.sucursal_emisor = v_sucursal_emisor
                      and    ((v_producto is null) or (cta.producto = v_producto))
                      and    cta.tipo_de_documento    = p_tp_documento
                      and    cta.documento = v_documento
                      and    cnt.fecha_movimiento between v_dt_fecha_inicio and v_fecha_fim
                      and    ((v_conta_duplicada = 0) or ((v_conta_duplicada = 1) and (cta.numero_cuenta = v_numero_cuenta)))
                      and    (
                                (
                                   (v_tarjeta is null) and
                                   (car.correlativo in ((select max(x.correlativo)
                                                       from vm_tarjetas x
                                                       where x.emisor = car.emisor
                                                       and   x.sucursal_emisor = car.sucursal_emisor
                                                       and   x.producto = car.producto
                                                       and   x.numero_cuenta = car.numero_cuenta),
                                                       (select max(x.correlativo)
                                                       from vm_tarjetas x
                                                       where x.emisor = car.emisor
                                                       and   x.sucursal_emisor = car.sucursal_emisor
                                                       and   x.producto = car.producto
                                                       and   x.numero_cuenta = car.numero_cuenta
                                                       and   x.estado = 34))
                                   )
                                ) or
                                (cnt.numero_cartao = v_tarjeta)
                             )
                      and    (
                                (v_tarjeta is not null) or
                                (
                                   (cta.estado  not in (
                                                        select dgn.valor
                                                        from   vm_datos_x_grupo_num dgn
                                                        where  dgn.emisor    = cnt.emisor
                                                        and    dgn.producto  = cnt.producto
                                                        and    dgn.cod_grupo = 36
                                                        and    dgn.valor     > 79
                            and    spc.VL_SALDO_DISPONIVEL = 0
                                                       )
                                   )
                                )
                             )
                      union all
                      select
                      cta.emisor,
                      cta.sucursal_emisor,
                      cta.producto,
                      cta.numero_cuenta,
                      null,
                      aut.numero_cartao                                                                        numero_cartao  ,
                      null                                                                                     id_lote_detalle,
                      aut.FECHA_LOCAL                                                                          dt_transacao   ,
                      aut.HHMMSS_LOCAL                                                                         hr_transacao   ,
                      aut.COD_AUT_INT                                                                          cod_aut        ,
                    --pkg_hpe_consulta_saldo.fc_tp_transacao(null, aut.mti, null, null)                        tp_transacao   ,
                      pkg_hpe_consulta_saldo.fc_tp_transacao(null, null, null, aut.mti, substr(lpad(proc_code, 6,'0' ), 0, 2))     tp_transacao   ,
                      aut.NOME_EC                                                                              desc_transacao ,
                      aut.IMPORTE_INT_PF_ML                                                                    vl_transacao   ,
                      pkg_hpe_consulta_saldo.fc_ind_sinal_transacao(null, aut.mti, substr(lpad(proc_code, 6,'0' ), 0, 2))          sinal_transacao,
                      com.TIPO_DE_DOCUMENTO tp_documento_ec,
                      com.DOCUMENTO num_doc_ec,
                      com.NUMERO_CONTRATO cod_correspondente
                      from   vm_contas                cta
                             inner join vm_tarjetas          car
                             on  car.emisor                = cta.emisor
                             and car.sucursal_emisor       = cta.sucursal_emisor
                             and car.producto              = cta.producto
                             and car.numero_cuenta         = cta.numero_cuenta
                             inner join V_AUTORIZACOES      aut
                             on  aut.producto              = cta.producto
                             and aut.numero_cuenta         = cta.numero_cuenta
                             inner join vm_estados_ctas_tarj est
                             on  est.emisor                = car.emisor
                             and est.producto              = car.producto
                             and est.estado                = car.estado
                             inner join vm_rel_cms_estados   rel
                             on  rel.emisor                = car.emisor
                             and rel.producto              = car.producto
                             and rel.estado                = car.estado
                              inner join SALDO_POR_CONTA        spc
                              on  spc.CD_EMISSOR             = cta.emisor
                              and spc.CD_SUCURSAL_EMISSOR    = cta.sucursal_emisor
                              and spc.ID_PRODUTO           = cta.producto
                              and spc.NR_CONTA      = cta.numero_cuenta
               inner join vm_comercios    com
               on  com.acquirer_id       = aut.ID_ACQR
               and com.comercio         = aut.MERCHANT_ID
                      where  cta.emisor = v_emisor
                      and    cta.sucursal_emisor = v_sucursal_emisor
                      and    ((v_producto is null) or (cta.producto = v_producto))
                      and    cta.tipo_de_documento    = p_tp_documento
                      and    cta.documento = v_documento
            and    aut.mti not in  (400, 420, 9999)
                      and    aut.FECHA_LOCAL between v_dt_fecha_inicio and v_fecha_fim
            and    ((v_conta_duplicada = 0) or ((v_conta_duplicada = 1) and (cta.numero_cuenta = v_numero_cuenta)))
                      and    (
                                (
                                   (v_tarjeta is null) and
                                   (car.correlativo in ((select max(x.correlativo)
                                                       from vm_tarjetas x
                                                       where x.emisor = car.emisor
                                                       and   x.sucursal_emisor = car.sucursal_emisor
                                                       and   x.producto = car.producto
                                                       and   x.numero_cuenta = car.numero_cuenta))
                                   )
                                ) or
                                (aut.numero_cartao = v_tarjeta)
                             )
                      and    (
                                (v_tarjeta is not null) or
                                (
                                   (cta.estado not in (
                                                       select dgn.valor
                                                       from   vm_datos_x_grupo_num dgn
                                                       where  dgn.emisor    = cta.emisor
                                                       and    dgn.producto  = cta.producto
                                                       and    dgn.cod_grupo = 36
                                                       and    dgn.valor     > 79
                             and    spc.VL_SALDO_DISPONIVEL = 0
                                                      )
                                   )
                                )
                             )
             union all
             select
                    cta.emisor,
                    cta.sucursal_emisor,
                    cta.producto,
                    cta.numero_cuenta,
                    null,
                    car.numero_cartao                                                                          numero_cartao  ,
                    mld.id_lote_detalle                                                                        id_lote_detalle,
                    mld.F_PREVISTA                                                                             dt_transacao   ,
                    0                                                                                          hr_transacao   ,
                    '0'                                                                                        cod_aut        ,
                    to_char(mld.TIPO)                                                                          tp_transacao   ,
                    mdt.DESCRIPCION                                                                            desc_transacao ,
                    mld.IMPORTE                                                                                vl_transacao   ,
                    decode(mdt.IND_CREDITO, 0, '-', 1, '+')                                                    sinal_transacao,
                    null tp_documento_ec,
                    null num_doc_ec,
                    null cod_correspondente
                      from   vm_contas                       cta
                             inner join vm_tarjetas          car
                             on  car.emisor                = cta.emisor
                             and car.sucursal_emisor       = cta.sucursal_emisor
                             and car.producto              = cta.producto
                             and car.numero_cuenta         = cta.numero_cuenta
                             inner join vm_estados_ctas_tarj est
                             on  est.emisor                = car.emisor
                             and est.producto              = car.producto
                             and est.estado                = car.estado
                             inner join vm_rel_cms_estados   rel
                             on  rel.emisor                = car.emisor
                             and rel.producto              = car.producto
                             and rel.estado                = car.estado
                             inner join VM_MVAG_LOTE_DETALLE mld
                             on  mld.emisor                = cta.emisor
                             and mld.sucursal_emisor       = cta.sucursal_emisor
                             and mld.producto              = cta.producto
                             and mld.numero_cuenta         = cta.numero_cuenta
                             inner join VM_MVAG_LOTE_DETALLE_TIPO   mdt
                             on  mdt.TIPO                  = mld.TIPO
                              inner join SALDO_POR_CONTA        spc
                              on  spc.CD_EMISSOR             = cta.emisor
                              and spc.CD_SUCURSAL_EMISSOR    = cta.sucursal_emisor
                              and spc.ID_PRODUTO           = cta.producto
                              and spc.NR_CONTA      = cta.numero_cuenta
                      where  cta.emisor = v_emisor
                      and    cta.sucursal_emisor = v_sucursal_emisor
                      and    ((v_producto is null) or (cta.producto = v_producto))
                      and    cta.tipo_de_documento    = p_tp_documento
                      and    cta.documento = v_documento
            and    ((v_conta_duplicada = 0) or ((v_conta_duplicada = 1) and (cta.numero_cuenta = v_numero_cuenta)))
                      and    (
                                (
                                   (v_tarjeta is null) and
                                   (car.correlativo in ((select max(x.correlativo)
                                                       from vm_tarjetas x
                                                       where x.emisor = car.emisor
                                                       and   x.sucursal_emisor = car.sucursal_emisor
                                                       and   x.producto = car.producto
                                                       and   x.numero_cuenta = car.numero_cuenta))
                                   )
                                ) or
                                (car.numero_cartao = v_tarjeta)
                             )
                      and    (
                                (v_tarjeta is not null) or
                                (
                                   (cta.estado not in (
                                                       select dgn.valor
                                                       from   vm_datos_x_grupo_num dgn
                                                       where  dgn.emisor    = cta.emisor
                                                       and    dgn.producto  = cta.producto
                                                       and    dgn.cod_grupo = 36
                                                       and    dgn.valor     > 79
                                                       and    spc.VL_SALDO_DISPONIVEL = 0
                                                      )
                                   )
                                )
                             )
                    ) tb_a ) tb_aa
              order by tb_aa.numero_cartao desc,
                       tb_aa.dt_transacao  desc,
                       tb_aa.hr_transacao  desc;
           --
           exception
              when others then
                 if p_erro = 0 then
                    p_erro      := 009;
                    p_desc_erro := 'Sistema indisponivel';
                 end if;
                 sp_log_consulta_saldo(v_tp_chamada         ,
                                       v_emisor             ,
                                       p_tp_documento       ,
                                       p_documento          ,
                                       v_tarjeta            ,
                                       v_produto_sodexo     ,
                                       v_tp_cartao          ,
                                       v_numero_cuenta      ,
                                       p_id_usuario         ,
                                       p_erro               ,
                     p_id_externo          );
                 open p_rc2 for
                    select null  numero_cartao  ,
                           null  dt_transacao   ,
                           null  hr_transacao   ,
                           null  cod_aut        ,
                           null  tp_transacao   ,
                           null  desc_transacao ,
                           null  vl_transacao   ,
                           null  sinal_transacao
                    from   dual;
                    return;
           end;
        end if;
        --
        p_erro      := 001;
        p_desc_erro := 'Consulta efetuada com sucesso';
        --
        sp_log_consulta_saldo(v_tp_chamada         ,
                              v_emisor             ,
                              p_tp_documento       ,
                              p_documento          ,
                              v_tarjeta            ,
                              v_produto_sodexo     ,
                              v_tp_cartao          ,
                              v_numero_cuenta      ,
                              p_id_usuario         ,
                              p_erro               ,
                p_id_externo          );
        --
   exception
      when others then
         --
         if p_erro = 0 then
            p_erro      := 009;
            p_desc_erro := 'Sistema indisponivel';
         end if;
         sp_log_consulta_saldo(v_tp_chamada         ,
                               v_emisor             ,
                               p_tp_documento       ,
                               p_documento          ,
                               v_tarjeta            ,
                               v_produto_sodexo     ,
                               v_tp_cartao          ,
                               v_numero_cuenta      ,
                               p_id_usuario         ,
                               p_erro               ,
                 p_id_externo          );
         --
         open p_rc1 for
            select v_tarjeta      numero_cartao   ,
                   0              saldo_disponivel,
                   '+'            sinal           ,
                   null           status_cartao   ,
                   null           motivo_bloqueio ,
                   null           ind_desbloqueio ,
                   null           fecha_estado
            from   dual;
            --
         open p_rc2 for
            select v_tarjeta  numero_cartao  ,
                   null       dt_transacao   ,
                   null       hr_transacao   ,
                   null       cod_aut        ,
                   null       tp_transacao   ,
                   null       desc_transacao ,
                   null       vl_transacao   ,
                   null       sinal_transacao
            from   dual;
   end sp_consulta_new;
   --
   function fc_ind_desbloqueio(p_estado number, p_allow_activation number, p_tarjeta varchar2, p_emisor number, p_produto number) return char
   is
      --
      v_count             number;
      v_emisor            number(4);
      v_sucursal_emisor   number(5);
      v_producto          number(2);
      v_numero_cuenta     number(9);
      v_fecha_estado      number(8);
      v_parametrizado_25  number;
      v_parametrizado_76  number;
      --
   begin

      select count(1) into v_parametrizado_25 from VM_DATOS_X_GRUPO_NUM where emisor = p_emisor and producto = p_produto and valor = p_estado and cod_grupo = 25;
      select count(1) into v_parametrizado_76 from VM_DATOS_X_GRUPO_NUM where emisor = p_emisor and producto = p_produto and valor = p_estado and cod_grupo = 76;
      --
      -- 1) I . pode ser desbloqueado, Bloqueio Inicial
      --
      --if (p_cod_grupo = 25) then
      if (v_parametrizado_25 = 1) then
         return 'I';
      end if;
      --
      -- 2) S . pode ser desbloqueado
      --
      --if (p_cod_grupo <> 76) and (p_allow_activation = 1) then
      --if (p_cod_grupo = 76 and p_allow_activation = 1 and v_parametrizado_76 = 0) then
      if (p_allow_activation = 1 and v_parametrizado_76 = 0) then
         return 'S';
      end if;
      --
      -- 3) R . pode ser desbloqueado, reutilizar plastico
      --
      if (v_parametrizado_76 = 1) then
         return 'R';
      end if;
      --
      -- 4) N . nao pode ser desbloqueado
      --
      if (p_allow_activation = 0) then
         return 'N';
      end if;
      --
      -- 5) X . Cartao com nova via emitida, nao pode ser desbloqueado
      --
      if (p_tarjeta is not null) then
         if (v_parametrizado_76 = 1) and (p_allow_activation = 1) then
            --
            select emisor  , sucursal_emisor  , producto  , numero_cuenta  , fecha_estado
            into   v_emisor, v_sucursal_emisor, v_producto, v_numero_cuenta, v_fecha_estado
            from   vm_tarjetas
            where  NUMERO_CARTAO = p_tarjeta
      and    rownum = 1
      order  by numero_cuenta;
            --
            v_count := 0;
            --
            select count(1)
            into   v_count
            from   vm_tarjetas
            where  emisor          =  v_emisor
            and    sucursal_emisor =  v_sucursal_emisor
            and    producto        =  v_producto
            and    numero_cuenta   =  v_numero_cuenta
            and    NUMERO_CARTAO   <> p_tarjeta
            and    fecha_estado    >= v_fecha_estado;
            --
            if (v_count <> 0 ) then
               return 'X';
            end if;
            --
         end if ;
      end if;
      --
      return '0';
        --
   end;
   --
   function fc_ind_sinal_transacao(p_cod_operacion number, p_mti number, p_process_code number) return char
   is
   begin
      --
      if (p_cod_operacion =0) then
         return '-';
      elsif (p_cod_operacion =1) then
         return '+';
      elsif ((p_mti in (100, 120, 200, 220)) and (p_process_code in (2, 20))) then
         return '+';
      elsif ((p_mti in (100, 120, 200, 220)) and (p_process_code not in (2, 20))) then
         return '-';
      elsif ((p_mti in (400, 420)) and (p_process_code in (2, 20))) then
         return '-';
      elsif ((p_mti in (400, 420)) and (p_process_code not in (2, 20))) then
         return '+';
      else
         return '+';
      end if;
      --
   end;
   --
   procedure sp_log_consulta_saldo(p_tp_chamada         char    ,
                                   p_emisor             number  ,
                                   p_tipo_de_documento  number  ,
                                   p_documento          char    ,
                                   p_tarjeta            char    ,
                                   p_producto           number  ,
                                   p_tp_cartao          number  ,
                                   p_numero_cuenta      number  ,
                                   p_id_usuario         char    ,
                                   p_id_retorno         number  ,
                                   p_id_externo          varchar2)
   is
      v_cd_http  varchar2(4);
   begin
      --
      -- log
      --
      if p_id_retorno = 1 then
         v_cd_http := '200';
      elsif p_id_retorno = 2 then
         v_cd_http := '404';
      elsif p_id_retorno = 3 then
         v_cd_http := '404';
      elsif p_id_retorno = 4 then
         v_cd_http := '404';
      elsif p_id_retorno = 5 then
         v_cd_http := '404';
      elsif p_id_retorno = 9 then
         v_cd_http := '503';
      end if;
      --
      insert into tb_ws_log_acessos(id_ws_operacao            ,
                                    id_ws_log_acesso          ,
                                    dh_acesso                 ,
                                    id_retorno_ws             ,
                                    tp_chamada                ,
                                    emisor                    ,
                                    tipo_de_documento         ,
                                    documento                 ,
                                    tarjeta                   ,
                                    producto                  ,
                                    tipo_tarjeta              ,
                                    numero_cuenta             ,
                                    id_usuario                ,
                                    id_externo                ,
                  cd_http                   )
      values                       (1                         ,
                                    sq_ws_log_acessos.nextval ,
                                    sysdate                   ,
                                    p_id_retorno              ,
                                    p_tp_chamada              ,
                                    p_emisor                  ,
                                    p_tipo_de_documento       ,
                                    p_documento               ,
                                    p_tarjeta                 ,
                                    p_producto                ,
                                    p_tp_cartao               ,
                                    p_numero_cuenta           ,
                                    p_id_usuario              ,
                                    p_id_externo              ,
                  v_cd_http                 );
      --
   end;
   --
   --function fc_tp_transacao(p_cod_rubro number, p_cod_mti number, p_origem_interno varchar2, p_cod_operacao number) return char
   function fc_tp_transacao(p_cod_rubro number, p_origem_interno varchar2, p_cod_operacao number, p_cod_mti number, p_process_code number) return char
   is
   begin

      --
      if (p_cod_rubro in (2996, 2998, 2995)) then
         return '00020';
      elsif (p_cod_rubro in (2999, 2997)) then
         return '00027';
      elsif (p_cod_rubro in (1000)) then
         return '00040';
      elsif (p_cod_rubro in (1003)) then
         return '00041';
      elsif ((p_origem_interno = 'J') and (p_cod_operacao=1)) then
         return '00017';
      elsif ((p_origem_interno = 'J') and (p_cod_operacao=0)) then
         return '00016';
   -- Regra nova
      elsif ((p_cod_mti in (100, 120, 200, 220)) and (p_process_code in (2, 20))) then
         return '00041'; --return '+';
      elsif ((p_cod_mti in (100, 120, 200, 220)) and (p_process_code not in (2, 20))) then
         return '00040'; --return '-';
      elsif ((p_cod_mti in (400, 420)) and (p_process_code in (2, 20))) then
         return '00040'; --return '-';
      elsif ((p_cod_mti in (400, 420)) and (p_process_code not in (2, 20))) then
         return '00041'; --return '+';
   -- Regra nova 26/02/2019 18:11
      elsif (p_cod_rubro in (2993)) then
         return '00078';
      elsif (p_cod_rubro in (2994)) then
         return '00079';
      elsif (p_cod_rubro in (2991)) then
         return '00080';
      elsif (p_cod_rubro in (2992)) then
         return '00081';
      end if;
      --
      return '0000';
      --
   end;
   --
   function fc_descricao_tp_transacao(p_tp_transacao char) return char
   is
   begin
      --
      if (p_tp_transacao = '00020') then
         return 'Beneficio';
      elsif (p_tp_transacao = '00027') then
         return 'Devolucao de beneficio';
      elsif (p_tp_transacao = '00040') then
         return 'Compras';
      elsif (p_tp_transacao = '00041') then
         return 'Devolucao de compras';

      elsif (p_tp_transacao = '00042') then
         return 'Ajuste a debito de compras';
      elsif (p_tp_transacao = '00043') then
         return 'Ajuste a credito de compras';
      elsif (p_tp_transacao = '00017') then
         return 'Ajuste a credito';
      elsif (p_tp_transacao = '00016') then
         return 'Ajuste a debito';
      elsif (p_tp_transacao = '00060') then
         return 'Ajuste a debito relativo a devolucao';
      elsif (p_tp_transacao = '00061') then
         return 'Ajuste a credito relativo a devolucao';
      end if;
      --
   end;
   --
   function fc_descricao_transacao(p_descripcion char, p_id_comercio_emi char, p_ec_autorizacao char) return char
   is
   begin
      if ((p_id_comercio_emi is null) or (rtrim(ltrim(p_id_comercio_emi)) is null)) then
         return p_descripcion;
      elsif ((p_ec_autorizacao is null) or (rtrim(ltrim(p_ec_autorizacao)) is null)) then
         return p_id_comercio_emi;
      else
         return p_ec_autorizacao;
      end if;
   --
   end;
   --
   procedure sp_consulta_log( p_data varchar2, p_emisor number, p_rc out rc)
   is
   begin
      --
      open p_rc for
      SELECT ID_WS_LOG_ACESSO                 ID_LOG_CONSULTA_SALDO,
             TO_CHAR(DH_ACESSO, 'YYYYMMDD')   DT_CONSULTA          ,
             TO_CHAR(DH_ACESSO, 'HH24MISS')   HR_CONSULTA          ,
             TP_CHAMADA                       METODO               ,
             EMISOR                                                ,
             TARJETA                                               ,
             PRODUCTO                                              ,
             NUMERO_CUENTA                                         ,
             TIPO_TARJETA                     TP_CARTAO            ,
             TIPO_DE_DOCUMENTO                                     ,
             rtrim(ltrim(DOCUMENTO))          DOCUMENTO            ,
             ID_USUARIO                                            ,
             ID_RETORNO_WS                    ID_RETORNO           ,
             nvl(ID_EXTERNO,' ')              ID_EXTERNO           ,
             CD_HTTP
      FROM   V_WS_LOG_ACESSOS
      WHERE  TO_CHAR(DH_ACESSO, 'YYYYMMDD') = p_data
      AND    EMISOR = p_emisor;
      --
   end;
   --
   procedure sp_sequence_arquivo( p_sequencia out number)
   is

   begin
      select sq_log_numero_remessa.nextval
      into   p_sequencia
      from   dual;
   end;
   --
end;
/
