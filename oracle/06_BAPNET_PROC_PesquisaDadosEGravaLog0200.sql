--USE [FEPHP_H] 
USE [FEPHP] 
GO
/****** Object:  StoredProcedure [dbo].[PROC_PesquisaDadosEGravaLog0200]    Script Date: 02/13/2020 18:02:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[PROC_PesquisaDadosEGravaLog0200]
	/*Procedure que alem de fazer a persistencia da transacao de ida,
	 *pesquisa os dados para que ocorra a validacao na transacao
	 */
	--Parametros da Procedure
			@pNumCartao				CHAR(32),
			@pGrupoBin				INT,
			@pCodEmissor			INT, 
			@pCodMensagem			CHAR(4),
			@pCodProduto			INT,
			@pIdProdutoBackoffice	VARCHAR(10),
			@pCodMoeda				CHAR(3),
			
			
			--Dados de Log Transação
			@pCodProcessamento		CHAR(6),
			@pIdTerminalBackoffice   VARCHAR(15),
			@pValorTransacao		DECIMAL(18,2),
			@pNroIdTrnRedeCaptura	CHAR(6),
			@pHoraTransacao			CHAR(6),
			@pDataTransacao			CHAR(6),
			@pCodRedeCaptura		CHAR(11),
			@pNsuRedeCaptura		CHAR(12),
			@pCodTerminal			CHAR(8),
			@pCodEstabelecimento	CHAR(15),
			@pMensagemISO			VARCHAR(MAX),

			--Dados para PROC_GeraNSUAUTORIZACAO
			@pCNPJ char(14),
			--@pRangeInicial int,
			--@pRangeFinal int
			
			@pSwitchOn					CHAR(5),
			@pTransactionType			INTEGER,
			@pClassetratadorIso			VARCHAR(100),
			@pBit033RedeOrigem			VARCHAR(11),
			@pTokenID                   VARCHAR(19)
			
	AS 


	--Declaração da Variável de Retorno
	DECLARE 
	--VARIAVEIS PARA TRATAMENTO DE SENHAS
			@vNSU				INT,
			@vNSU_GERADO		INT,
			@vStatusTransacao	CHAR(2),
			@vDataContabil		CHAR(8),
			@vNumConta			INT,
			@vStatusMerchant	CHAR(2),
			@vMsgErro			VARCHAR(500),

			@vRangeInicial int,
			@vRangeFinal int,
			
			--VALORES PARA COMPOR O TIF (TLV)
			@pStatusMerchant		CHAR(2),
			@pCardAcceptor			VARCHAR(15),
			@pTechnologyType		VARCHAR(10),
			@pMCC					VARCHAR(07),
			@pParticipantId			INTEGER,
			@pTerminalId			VARCHAR(15),
			@pMerchantId			VARCHAR(9),
			@pValidade				VARCHAR(6),
			@pCnpjCardAcceptor		VARCHAR(14),
			@pCardAcceptorName		VARCHAR(60) --nome fantasia

			SET @vNSU_GERADO = 0

			BEGIN try
				BEGIN tran
				
				
					--4) Gravar o Log da Transação				
					DECLARE @pRetorno	CURSOR

					DECLARE 
					@NSU_Retorno	char(10),
					@TLV			VARCHAR(4096),
					@Retorno		char(2)

					SET @vStatusTransacao='PE'
					SET @vMsgErro=''
					SELECT	@vDataContabil=DATACONTABIL
					FROM	EMISSOR WITH (NOLOCK)
					WHERE	ID_EMISSOR=@pCodEmissor

					SELECT @vNumConta=NUMCONTA,
						@pValidade = VALIDADE
					FROM	CARTAO WITH (NOLOCK)
					where	NUMCARTAO=@pNumCartao

					--alteracao NSU Estabelecimento
					SET @vRangeInicial = (SELECT valor FROM CONFIGURACAO WITH (NOLOCK) where PROPRIEDADE = 'RANGE_NRO_AUT_INICIAL')
					SET @vRangeFinal = (SELECT valor FROM CONFIGURACAO WITH (NOLOCK) where PROPRIEDADE = 'RANGE_NRO_AUT_FINAL')
					
					
					

					--Setamos o status da validação de merchant
					IF @pSwitchOn = 'false'
						BEGIN
							EXEC PROC_TRN_VALIDAMERCHANT 
							@pIdTerminalBackoffice, @pGrupoBin, @pCodMoeda, @pIdProdutoBackoffice, 
							@vStatusMerchant OUTPUT, @pCardAcceptor OUTPUT, @pTechnologyType OUTPUT, @pMCC OUTPUT, @pParticipantId OUTPUT, @pTerminalId OUTPUT,
							@pMerchantId OUTPUT, @pCnpjCardAcceptor OUTPUT, @pCardAcceptorName OUTPUT

							IF @vStatusMerchant IN('00', 'M2','B1')
								BEGIN
							
								SET @pCNPJ = @pCnpjCardAcceptor

								EXEC dbo .PROC_GeraNSUAUTORIZACAO @pCNPJ, @vRangeInicial, @vRangeFinal, @vNSU_GERADO OUTPUT

								SET @TLV =  	  '*CDA' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), LEN(@pCardAcceptor))))   	 + CONVERT (VARCHAR(999),LEN(@pCardAcceptor)) + @pCardAcceptor
								SET @TLV = @TLV + '*TTY' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), LEN(@pTechnologyType)))) 	 + CONVERT (VARCHAR(999),LEN(@pTechnologyType)) + @pTechnologyType
								SET @TLV = @TLV + '*MCC' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), LEN(@pMCC))))  			 	 + CONVERT (VARCHAR(999),LEN(@pMCC)) + @pMCC
								SET @TLV = @TLV + '*PTC' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), LEN(@pParticipantId))))  	 + CONVERT (VARCHAR(999),LEN(@pParticipantId)) + CONVERT (VARCHAR(999),@pParticipantId)
								SET @TLV = @TLV + '*PRD' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), LEN(@pIdProdutoBackoffice))))+ CONVERT (VARCHAR(999),LEN(@pIdProdutoBackoffice)) + @pIdProdutoBackoffice
								SET @TLV = @TLV + '*TID' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), LEN(@pTerminalId))))  		 + CONVERT (VARCHAR(999),LEN(@pTerminalId)) + @pTerminalId
								SET @TLV = @TLV + '*MID' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), LEN(@pMerchantId))))  		 + CONVERT (VARCHAR(999),LEN(@pMerchantId)) + @pMerchantId
								SET @TLV = @TLV + '*DTE' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), LEN(@pValidade))))  		 + CONVERT (VARCHAR(999),LEN(@pValidade)) + @pValidade
								
								DECLARE @vCAN CHAR(25) = cast(@pCardAcceptorName as CHAR(25)),
								@vNSUD CHAR(6) = cast(@vNSU_GERADO as CHAR(6))
								SET @TLV = @TLV + '*CAN' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), DATALENGTH(@vCAN))))   + CONVERT (VARCHAR(999),DATALENGTH(@vCAN)) + @vCAN

								SET @TLV = @TLV + '*AUT' + REPLICATE('0', 3 - LEN( CONVERT (VARCHAR(3), LEN(@vNSUD)))) 	 + CONVERT (VARCHAR(999),LEN(@vNSUD)) + @vNSUD
								END
								ELSE
									BEGIN 
										SET @TLV = ''
									END
						END
						ELSE
							BEGIN
								--Validacao de merchant desativada: entao devemos setar OK na mao
								SET @vStatusMerchant = '00'
								--Se a mensagem vem do postilion, utilizamos o CNPJ que recebemos do postilion para gerar o NSU
								EXEC dbo .PROC_GeraNSUAUTORIZACAO @pCNPJ, @vRangeInicial, @vRangeFinal, @vNSU_GERADO OUTPUT
							END
					
					--Validacao de merchant desativada: entao devemos setar OK na mao
					--SET @vStatusMerchant = '00'

						EXEC dbo .PROC_GravaLogTransacao @vDataContabil, @vStatusTransacao, @pCodEmissor, @pCodProduto, @pCodMensagem, 
														@pCodProcessamento, @pValorTransacao, @pNroIdTrnRedeCaptura, @pHoraTransacao,
														@pDataTransacao, @pCodRedeCaptura, @pNsuRedeCaptura, @pCodTerminal,
														@pCodEstabelecimento, @pMensagemISO, 1, @pNumCartao, @vNumConta, @pCNPJ, @vNSU_GERADO,
														@pClassetratadorIso, @pSwitchOn,@TLV, @pBit033RedeOrigem, @pTokenID,
														@pRetorno OUTPUT
						FETCH NEXT FROM @pRetorno into @vNSU, @vStatusTransacao
					
						CLOSE @pRetorno
						Deallocate @pRetorno
					
						COMMIT
						--110
				--waitfor delay '00:00:03:000'
				END TRY
				BEGIN CATCH
					SET @vMsgErro = ERROR_MESSAGE()
					ROLLBACK
					SET @vStatusTransacao='E4'
				END CATCH

				IF @vStatusMerchant <> '00'
					BEGIN
						SELECT @vNSU						AS NSU,
							   @vStatusTransacao			AS STATUS_TRANSACAO,
							   @vMsgErro					AS MSG_ERRO,
							   @vNSU_GERADO					AS BIT38_AUTORIZATIONCODE,
							   @vStatusMerchant				AS STATUS_MERCHANT
					END

				ELSE
					BEGIN
						IF @vNumConta IS NOT NULL
					 
							BEGIN
								SELECT	@vNSU						  AS NSU,
										@vStatusTransacao			  AS STATUS_TRANSACAO,
										@vStatusMerchant			  AS STATUS_MERCHANT,


										@vNSU_GERADO				  AS BIT38_AUTORIZATIONCODE,
										@vMsgErro					  AS MSG_ERRO,

										C.NOMEEMBOSSING				  AS NOME, 
										C.SENHA						  AS SENHA,
										C.PINHOST					  AS PINHOST,
										C.CONTERROSENHA				  AS CONTADOR,
										C.DATAULTIMOERRO			  AS DT_ULTIMO_ERRO,
										C.HORAULTIMOERRO			  AS HR_ULTIMO_ERRO,
										C.STATUS					  AS STATUS_CARTAO,
										TC.FORMAZERARCONTERROSENHA	  AS FORMA_BLOQUEIO,
										TC.QTDMAXERROSENHA			  AS QTD_MAX_ERRO,
										TC.PIN_BLOCK_FORMAT           AS PIN_BLOCK_FORMAT,
										TC.SCHEME_ID_EMV              AS SCHEME_ID_EMV,
										TC.VECTO_PIN_BLOCK_ALT        AS VENCIMENTO_CARTAO_PIN_BLOCK_ALT,
										TC.SCHEME_PIN_BLOCK_ALT       AS SCHEME_PIN_BLOCK_ALT,
										TC.CVV2                       AS CVV2,
										TC.START_CVV2_VALIDADE        AS INICIO_VALIDADE_CVV2,
										TC.VECTO_CVV2_ALT             AS VENCIMENTO_CARTAO_CVV2_ALT,
										TC.SCHEME_CVV2_ALT            AS SCHEME_CVV2_ALT,
										TC.CVV1                       AS CVV1,
										TC.SCHEME_CVV2_PADRAO		  AS SCHEME_CVV2_PADRAO,
										TC.START_CVV1_VALIDADE        AS INICIO_VALIDADE_CVV1,
										TC.VECTO_CVV1_ALT             AS VENCIMENTO_CARTAO_CVV1_ALT,
										TC.SCHEME_CVV1_ALT            AS SCHEME_CVV1_ALT,
										TC.EMV                        AS EMV,
										TC.FALLBACK                   AS FALLBACK,
										TC.ENABLE                     AS TIPOCARTAO_ENABLE,
										B.ID_BIN                      AS ID_BIN,
										B.MERCHANT_BIN_GRUPO          AS GRUPO_BIN,
										B.POOL_HSM					  AS ID_POOL_HSM,
										C.NUMCONTA					  AS NUMCONTA,
								
										CO.TIPOCONTARH				  AS TIPOCONTARH,
										CO.TRANSACOESAUTORIZADASDIA	  AS TRANSACOESAUTORIZADASDIA,
										P.LIMITETRANSACOESDIA		  AS LIMITETRANSACOESDIA, -- teste com transacoes sem esse retorno da procedure
										CO.CPFCONTA					  AS CPFCONTA,
								
										C.CODPRODUTO				  AS PRODUTO,
										C.NUMCARTAO					  AS NUMCARTAO,
										CO.SALDO					  AS SALDO,
										CO.STATUS					  AS STATUS_CONTA,
										CO.VLRMOVDIA				  AS VALOR_MOVIMENTADO_NO_DIA,
								
										--retorno data do sistema 
										CO.VLRMOVDIASIST			  AS VALOR_MOVIMENTADO_NO_DIA_SIST,
										CO.DATAULTIMOMOVIMENTOSIST	  AS DATA_ULTIMO_MOVIMENTO_SIST,
								
										CO.DATAULTIMOMOVIMENTO		  AS DATA_ULTIMO_MOVIMENTO,
								
										-- dados do limite de autorizacao por empresa
										CO.CODIGOEMPRESA			  AS CODIGO_EMPRESA,
										CO.GRUPORELACIONAMENTO		  AS GRUPO_AFINIDADE,
										LAE.PRODUTO_SODEXO			  AS PRODUTO_SODEXO,
										LAE.QTD_MAX_TRN_DIA			  AS QTD_MAX_TRN_DIA_EMPRESA,
										LAE.VALOR_MAX_TRN_DIA		  AS VALOR_MAX_TRN_DIA_EMPRESA,
								

										C.VALIDADE					  AS VALIDADE_CARTAO,
										P.VALORMINIMOTRANSACAO		  AS VALOR_MIN_TRANSACAO,
										P.VALORMAXIMOTRANSACAO		  AS VALOR_MAX_TRANSACAO,
										P.LIMITEDIARIO				  AS LIMITE_DIARIO,
										P.ECOMMERCE_RH				  AS ECOMMERCE_RH,
										(SELECT	CODIGORESP
										 FROM	DEPARASTATUSCONTACARTAO WITH (NOLOCK)
										 WHERE	EMISSOR=C.CODEMISSOR
										 AND	STATUSEMISSOR=C.STATUS) AS STATUS_CARTAO_PARA,
										(SELECT	CODIGORESP
										 FROM	DEPARASTATUSCONTACARTAO WITH (NOLOCK)
										 WHERE	EMISSOR=C.CODEMISSOR
										 AND	STATUSEMISSOR=CO.STATUS) AS STATUS_CONTA_PARA,
										(SELECT	CODIGORESPTRNCONTACTLESS
										 FROM	DEPARASTATUSCONTACARTAO WITH (NOLOCK)
										 WHERE	EMISSOR=C.CODEMISSOR
										 AND	STATUSEMISSOR=C.STATUS) AS STATUS_CARTAO_TRNCONTACTLESS
						
								FROM CARTAO C WITH (NOLOCK)
									INNER JOIN PRODUTO P WITH (NOLOCK) 
									ON  C.NUMCARTAO	= @pNumCartao
									AND P.PRODUTO_BACKOFFICE = @pIdProdutoBackoffice 

									INNER JOIN CONTA CO WITH (NOLOCK)
									ON  CO.NUMCONTA = C.NUMCONTA
									AND CO.PRODUTO = C.CODPRODUTO
									AND CO.EMISSOR = C.CODEMISSOR

									INNER JOIN TIPOCARTAO TC WITH (NOLOCK)
									ON  TC.TIPOCARTAO = C.TIPOCARTAO 
									AND TC.CODEMISSOR = C.CODEMISSOR
									AND TC.CODPRODUTO = C.CODPRODUTO
								
									INNER JOIN BIN B WITH (NOLOCK) 
									ON B.PRODUTO = P.ID_PRODUTO

									-- DADOS DE LIMITES DE TRANSACOES POR EMPRESA SE EXISTIR
									LEFT JOIN LIMITE_AUTH_EMPRESA LAE WITH (NOLOCK)
									ON (LAE.COD_EMPRESA = CO.CODIGOEMPRESA AND LAE.EMISSOR = CO.EMISSOR AND LAE.PRODUTO_SODEXO = @pIdProdutoBackoffice)
						
							END
						ELSE					
							BEGIN
								SELECT @vNSU						AS NSU,
									   @vStatusTransacao			AS STATUS_TRANSACAO,
									   @vMsgErro					AS MSG_ERRO,
									   @vNSU_GERADO					AS BIT38_AUTORIZATIONCODE,
									   @vStatusMerchant				AS STATUS_MERCHANT
							END
					END
	RETURN
