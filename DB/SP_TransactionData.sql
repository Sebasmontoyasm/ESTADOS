USE [DB_Estados]
GO
/****** Object:  StoredProcedure [dbo].[SP_TransactionData]    Script Date: 5/06/2023 11:56:40 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,Juan Sebastian Montoya Acevedo>
-- Create date: <Create Date,09/05/2023>
-- Description:	<Description,Procedimiento para identificar cuales son los que debe notificar>
-- =============================================
ALTER PROCEDURE [dbo].[SP_TransactionData]
	-- Add the parameters for the stored procedure here
AS
BEGIN
	SET NOCOUNT ON;

	
	-- SELECCION DE FLUJO NORMAL PARA TRATAMIENTO
		SELECT * 
		INTO #tblFNormal
		-- DROP TABLE #tblFNormal
		FROM [dbo].[EST_Transaccional]
		WHERE CONVERT(VARCHAR(10),[ESTRAN_FechaInsercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101);

	-- ASIGNACION DE LOS CORREOS EN EL FLUJO NORMAL
		SELECT NOR.*,BOD.BOD_Email
		INTO #tblFNormalEmail
		-- DROP TABLE #tblFNormalEmail
		FROM #tblFNormal NOR
		LEFT JOIN [dbo].[EST_Bodegas] BOD
		ON NOR.ESTRAN_Bodega = BOD.BOD_Bodega;

	-- SELECCION DE FLUJO ALTERNO PARA TRATAMIENTO
		SELECT *
		INTO #tblFAlterno
		-- DROP TABLE #tblFAlterno
		FROM [dbo].[EST_TransaccionalAlterna]
		WHERE CONVERT(VARCHAR(10),[ESTRAN_FechaInsercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101);

	-- ASIGNACION DE LOS CORREOS FLUJO ALTERNO
		SELECT ALT.*,BOD.BOD_Email
		INTO #tblFAlternoEmail
		-- DROP TABLE #tblFAlternoEmail
		FROM #tblFAlterno ALT
		LEFT JOIN [dbo].[EST_Bodegas] BOD
		ON ALT.ESTRAN_Bodega = BOD.BOD_Bodega;
		
	-- CURSOR ENCARGADO DE ENCONTRAR BODEGAS REPEDITAS Y LIMPIA PARA LA AGREGACION DEL FLUJO ALTERNO.
		DECLARE @documento VARCHAR(50), @bodega VARCHAR(MAX) , @repeticiones INT, @contador INT = 0;
		
		DECLARE REP_BODEGAS CURSOR FOR
		SELECT ESTRAN_Documento,ESTRAN_Bodega,COUNT(ESTRAN_Bodega) as Repeticiones
		FROM #tblFAlternoEmail
		GROUP BY ESTRAN_Documento,ESTRAN_Bodega
		HAVING COUNT(ESTRAN_Bodega) > 1
		ORDER BY ESTRAN_Documento ASC;
		
		OPEN REP_BODEGAS;

		FETCH NEXT FROM REP_BODEGAS INTO @documento, @bodega, @repeticiones;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @contador = @repeticiones - 1;
			DELETE TOP(@contador) FROM #tblFAlternoEmail
			WHERE ESTRAN_Documento = @documento AND ESTRAN_Bodega = @bodega;
			FETCH NEXT FROM REP_BODEGAS INTO @documento, @bodega, @repeticiones;
		END;

		CLOSE REP_BODEGAS;
		DEALLOCATE REP_BODEGAS;

	-- AGRUPAMIENTO DE BODEGAS Y EMAILS EN 1 SOLA FILA.
		SELECT ESTRAN_Documento AS documento,STRING_AGG(BOD_Email,'') AS email,ESTRAN_NumPedido AS pedido,3 AS proceso,STRING_AGG(ESTRAN_Bodega, ',') AS Bodega 
		INTO #tblFAlternoAGG
		FROM #tblFAlternoEmail 
		GROUP BY ESTRAN_Documento, ESTRAN_NumPedido;
	
	--  TRANSACCIONES DE EXCEPCIONES POR PROCESAR.
		SELECT 
		ESTEXC_Documento AS documento,
		ESTEXC_Email AS email,
		ESTEXC_NumPedido AS pedido,
		ESTEXC_Proceso AS proceso,
		'' AS Bodega
		INTO #tblExcepciones
		FROM [dbo].[EST_TransaccionalExcepciones]
		WHERE CONVERT(VARCHAR(10),[ESTEXC_FechaInsercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101);

	-- TRANSACCIONES DE ERROR POR PROCESAR
		SELECT TOP 2
			ESTERR_Documento AS documento,
			ESTERR_Email AS email,
						ESTERR_NumPedido AS pedido,
			ESTERR_Proceso AS proceso,
			'' AS Bodega
		INTO #tblFError
		FROM EST_TransaccionalERROR
		WHERE  CONVERT(VARCHAR(10),ESTERR_FechaInsercion,101) >= CONVERT(VARCHAR(10),GETDATE(),101);

	-- TRANSACCIONES POR PROCESAR
		SELECT 
			LTRIM(RTRIM(ESTRAN_Documento)) AS documento,
			BOD_Email AS email,
			ESTRAN_NumPedido AS pedido,
			ESTRAN_Proceso AS proceso,
			ESTRAN_Bodega AS Bodega
		INTO #TransacionesPro
		FROM #tblFNormalEmail
		UNION ALL
		SELECT *
		FROM #tblExcepciones
		UNION ALL
		SELECT *
		FROM #tblFAlternoAGG
		UNION ALL
		SELECT *
		FROM #tblFError
		
	-- EXTRACCIÓN DEL DIA PARA ASIGNAR LOS ESTADOS
		SELECT *
		INTO #TransaccionDia
		--DROP TABLE #TransaccionDia
		FROM [dbo].[EST_Comercial]
		WHERE CONVERT(VARCHAR(10),[COM_fecha_insercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101) AND COM_forma_pago = 'Credito';

	-- ASIGNACION DE ESTADOS
		SELECT TP.*,
			   T.COM_estado_acuse_dian AS acuse,
			   T.COM_estado_recibo_dian AS recibo,
			   T.COM_estado_aceptacion_dian AS aceptacion,
			   T.COM_estado_reclamo_dian as reclamo
		INTO #TransacionesProcesadas
		-- DROP TABLE #TransacionesProcesadas
		FROM #TransacionesPro TP
		INNER JOIN #TransaccionDia T
		ON T.COM_numero_documento = TP.documento AND T.COM_pedido = TP.pedido
		WHERE TP.documento IS NOT NULL;
	
	-- PENDIENTE POR PROCESAR EN MEMORIA PARA INDENTIFICAR NO PROCESADOS
		SELECT *
		INTO #ProcesoMemoria
		-- DROP TABLE #ProcesoMemoria
		FROM [dbo].[EST_Procesados] 
		WHERE PRO_Procesado = 1;

	-- MEMORIA DEL ROBOT PARA PROCESADOS
		SELECT T.*
		INTO #TranNProcesadas
		--DROP TABLE #TranNProcesadas
		FROM #TransaccionDia T
		LEFT JOIN #ProcesoMemoria P
		ON T.COM_numero_documento = P.PRO_Documento 
		WHERE P.PRO_Documento IS NULL;

	-- REGISTROS QUE REQUIEREN PROCESO EN JAIVANA
		SELECT T.COM_numero_documento, T.COM_pedido, T.COM_nit_documento, T.COM_estado_acuse_dian, T.COM_estado_recibo_dian, T.COM_estado_aceptacion_dian, T.COM_estado_reclamo_dian, COM_fecha_insercion
		INTO #TranPendientes
		-- DROP TABLE #TranPendientes
		FROM #TranNProcesadas T
		WHERE 
		((COM_estado_acuse_dian = 'a' OR COM_estado_acuse_dian = 'p') AND COM_estado_recibo_dian = '.') OR 
		((COM_estado_acuse_dian = 'a' OR COM_estado_acuse_dian = 'p') AND (COM_estado_recibo_dian = 'a' OR COM_estado_recibo_dian = 'p') AND COM_estado_aceptacion_dian = '.' AND COM_estado_reclamo_dian = '.');

	-- TRANSACCIONES QUE NO SE VAN A PROCESAR
		SELECT TOP 2 T.*
		INTO #TranNProcesadasEstados
		FROM #TranPendientes T
		WHERE COM_numero_documento NOT IN (SELECT documento
										   FROM #TransacionesProcesadas);

	-- ARREGLAR FORMATO NO SE VAN A PROCESAR
		SELECT TOP 2
			LTRIM(RTRIM(COM_numero_documento)) AS documento,
			'notificaciones.fac@sumatec.co' AS email,
			COM_pedido AS pedido,
			'5' AS proceso,
			'' AS Bodega,
			COM_estado_acuse_dian AS acuse,
			COM_estado_recibo_dian AS recibo,
			COM_estado_aceptacion_dian as aceptacion,
			COM_estado_reclamo_dian AS reclamo
		INTO #TransacionesNProcesadas
		-- DROP TABLE #TransacionesNProcesadas
		FROM #TranNProcesadasEstados

	-- SALIDA DEL PROCEDIMIENTO
		SELECT *
		FROM #TransacionesProcesadas
		UNION ALL
		SELECT *
		FROM #TransacionesNProcesadas
		ORDER BY proceso ASC;
END
