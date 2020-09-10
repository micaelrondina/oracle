USE [FEPHP] 
GO

CREATE PROCEDURE [dbo].[PROC_CONFIG_EC](@CNPJ VARCHAR(14), @PARTICIPANT_ID INT, @COD_BLOQUEIO INT, @SAIDA INT OUTPUT)
AS
BEGIN
      UPDATE CARDACCEPTOR SET COD_BLOQUEIO = @COD_BLOQUEIO
      WHERE documento_cnpj = @CNPJ
      AND participant_id = @PARTICIPANT_ID;
		
	  SET @SAIDA = @@ROWCOUNT;
      
      if @@ERROR <> 0
      BEGIN
        SET @SAIDA = -1;
      END;    
END;

