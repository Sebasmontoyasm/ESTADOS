USE [DB_Estados]
GO
/****** Object:  StoredProcedure [dbo].[SP_UpdateEstados]    Script Date: 5/06/2023 11:58:48 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,Sebastian Montoya>
-- Create date: <Create Date,23/05/2023>
-- Description:	<Description,Actualiza los nuevos estados de los registros para no realizarlos.>
-- =============================================
ALTER PROCEDURE [dbo].[SP_UpdateEstados]
AS
BEGIN
	-- EXTRACCIÓN DEL DIA DE INSERCIÓN DE DATA.
		SELECT *
		INTO #TransaccionDia
		FROM [dbo].[EST_Comercial]
		WHERE CONVERT(VARCHAR(10),[COM_fecha_insercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101);

	-- ACTUALIZACIÓN DE ESTADOS EN PROCESADOS
		UPDATE EST_Procesados
		SET PRO_Procesado = 1
		WHERE PRO_Documento IN (SELECT COM_numero_documento
								FROM #TransaccionDia T
								WHERE 
									(	
										(COM_estado_acuse_dian = 'a' OR COM_estado_acuse_dian = 'p') AND 
										(COM_estado_recibo_dian = 'a' OR COM_estado_recibo_dian = 'p') AND 
										(COM_estado_aceptacion_dian = 'a' OR COM_estado_aceptacion_dian = 'p')
									) 
									OR 
									(
										(COM_estado_acuse_dian = 'a' OR COM_estado_acuse_dian = 'p') AND
										(COM_estado_recibo_dian = 'a' OR COM_estado_recibo_dian = 'p') AND
										(COM_estado_reclamo_dian = 'a' OR COM_estado_reclamo_dian = 'p')
									)
								);
		
	--	ACEPTACIÓN TACITA
		UPDATE EST_Procesados
		SET PRO_Procesado = 1
		WHERE PRO_daysAceptacion = 3
	
	-- NOTIFICACIÓN RECIBO MAXIMA
		UPDATE EST_Procesados
		SET PRO_Procesado = 1
		WHERE PRO_daysRecibo = 7
END;
