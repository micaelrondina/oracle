--USE [FEPHP_H] 
USE [FEPHP]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[PROC_TRN_VALIDAMERCHANT]
		@pIdTerminalBackoffice		VARCHAR(15),
		@pGrupoBin					VARCHAR(6),
		@pCodMoeda					CHAR(3),
		@pIdProdutoBackoffice		VARCHAR(10),
		
		@pStatusMerchant		CHAR(2) 	OUTPUT,
		@pCardAcceptor			VARCHAR(15) OUTPUT,
		@pTechnologyType		VARCHAR(10) OUTPUT,
		@pMCC					VARCHAR(07) OUTPUT,
		@pParticipantId 		INTEGER		OUTPUT,
		@pTerminalId			VARCHAR(15) OUTPUT,
		@pMerchantId			VARCHAR(9)	OUTPUT,
		@pCnpjCardAcceptor		VARCHAR(14) OUTPUT,
		@pCardAcceptorName		VARCHAR(60) OUTPUT
	AS
	--Retornos:
	--00 = ok
	--M1 = Merchant invalido
	--M2 = Acordo comercial(PDV) não encontrado ou acordo comercial nao autorizado
	DECLARE 
	@vRetorno 		CHAR(2),
	@vStatusAcordo	BIT,
	@vCodBloqueio CHAR(2)
	BEGIN
		--Fazemos a consulta dos dados do estabelecimento na tabela sodexo_ec, a partir do terminal alternativo
		SELECT
			@pCardAcceptor 		= card_acceptor,
			@pParticipantId 	= participant_id,
			@pTechnologyType 	= technology_type,
			@pMCC 				= mcc,
			@pTerminalId		= terminal_id,
			@pMerchantId		= merchant_id,
			@pCnpjCardAcceptor  = documento_cnpj,
			@pCardAcceptorName  = nome_fantasia,
			@vCodBloqueio       = COD_BLOQUEIO

		FROM CARDACCEPTOR  WITH (NOLOCK)
		WHERE  terminal_BACKOFFICE  = @pIdTerminalBackoffice

		IF(@@ROWCOUNT > 0)
			BEGIN
				--Encontramos o merchant, então podemos seguir com a validação
				--Vamos encontrar agora o acordo comercial
				IF EXISTS(
						SELECT merchant_fee from  MERCHANT_FEE WITH (NOLOCK) WHERE 
						card_acceptor = @pCardAcceptor AND
						participant_id = @pParticipantId AND
						product = @pIdProdutoBackoffice AND
						technology_type = @pTechnologyType AND
						currency_code = @pCodMoeda AND
						bin_group = @pGrupoBin AND
						enable = 1
				)
					BEGIN
						IF (@vCodBloqueio <> '0')
							SET @pStatusMerchant = 'B1' -- Para estabelecimenntos bloqueados
						ELSE 
							SET @pStatusMerchant = '00'
					END
				ELSE
					SET @pStatusMerchant = 'M2' -- Merchant_fee nao encontrado ou não habilitado
			END
		ELSE
			BEGIN	
				SET @pStatusMerchant = 'M1' --Merchant nao encontrado, retornamos M1
			END
	END

