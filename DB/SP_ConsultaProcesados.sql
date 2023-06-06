USE [DB_Estados]
GO
/****** Object:  StoredProcedure [dbo].[SP_ConsultaProcesados]    Script Date: 5/06/2023 11:54:11 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author: <Author,Sebastian Montoya>
-- Create date: <Create Date,03-03-2023>
-- Description: <Description,Procedimiento para crear Reporte Final>
-- =============================================
ALTER PROCEDURE [dbo].[SP_ConsultaProcesados] 
AS
BEGIN
	SET NOCOUNT ON;
	-- EXTRACCIÓN DEL DIA DE INSERCIÓN DE DATA.
		SELECT *
		INTO #TransaccionDia
		--DROP TABLE #TransaccionDia
		FROM [dbo].[EST_Comercial]
		WHERE CONVERT(VARCHAR(10),[COM_fecha_insercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101) AND COM_forma_pago = 'Credito';
	

	-- PENDIENTE POR PROCESAR EN MEMORIA
		SELECT *
		INTO #Procesados
		-- DROP TABLE #Procesados
		FROM [dbo].[EST_Procesados] 
		WHERE PRO_FechaInsercion >=  CONVERT(VARCHAR(10),GETDATE(),101)

	-- REGLAS DE NEGOCIO ERROR DE ACUSE O RECIBO
		SELECT *
		INTO #TError
		FROM #TransaccionDia
		WHERE (LTRIM(RTRIM(COM_estado_acuse_dian)) = 'e' OR LTRIM(RTRIM(COM_estado_recibo_dian)) = 'e');

	-- REGLA DE NEGOCIO RECIBIDO 7 DIAS
		SELECT *
		INTO #TRecibo
		FROM #TransaccionDia
		WHERE 
		(LTRIM(RTRIM(COM_estado_acuse_dian)) = 'a' OR LTRIM(RTRIM(COM_estado_acuse_dian)) = 'p') AND
		(LTRIM(RTRIM(COM_estado_recibo_dian)) = '.');

	-- REGLA DE NEGOCIO ACEPTACION O RECLAMO 3 DIAS
		SELECT *
		INTO #TAcepRecl
		FROM #TransaccionDia
		WHERE 
		(LTRIM(RTRIM(COM_estado_acuse_dian)) = 'a' OR LTRIM(RTRIM(COM_estado_acuse_dian)) = 'p') AND
		(LTRIM(RTRIM(COM_estado_recibo_dian)) = 'a' OR LTRIM(RTRIM(COM_estado_recibo_dian)) = 'p') AND
		(LTRIM(RTRIM(COM_estado_aceptacion_dian)) = '.') AND (LTRIM(RTRIM(COM_estado_reclamo_dian)) = '.');

		SELECT *
		INTO #Transaccion
		FROM #TError
		UNION ALL
		SELECT *
		FROM #TRecibo
		UNION ALL
		SELECT *
		FROM #TAcepRecl

		-- REGISTROS PROCESADOS POR EL ROBOT.
		SELECT
			LTRIM(RTRIM(COM_numero_documento)) AS Factura,
			LTRIM(RTRIM(COM_pedido)) AS Pedido,
			LTRIM(RTRIM(COM_nit_documento)) AS Empresa,
			COM_nombre AS 'Razón Social',
			COM_fecha_documento+' '+COM_hora_documento AS 'Fecha documento',
			PRO_FechaInsercion AS 'Fecha Insercion',
			PRO_Proceso AS Proceso,
			LTRIM(RTRIM(COM_estado_acuse_dian)) AS Acuse,
			LTRIM(RTRIM(COM_estado_recibo_dian)) AS Recibo,
			LTRIM(RTRIM(COM_estado_aceptacion_dian)) AS Aceptacion,
			LTRIM(RTRIM(COM_estado_reclamo_dian)) AS Reclamo,
			PRO_daysRecibo AS 'Notificación Recibo',
			PRO_daysAceptacion AS 'Notificación Aceptación'
		INTO #ProcesadoDia
		FROM #Transaccion 
		INNER JOIN #Procesados 
		ON COM_numero_documento = PRO_Documento AND COM_pedido = PRO_NumPedido
		WHERE COM_numero_documento IS NOT NULL AND COM_pedido IS NOT NULL;

		-- REGISTROS NO PROCESADOS PRO EL ROBOT
		SELECT
			LTRIM(RTRIM(COM_numero_documento)) AS Factura,
			LTRIM(RTRIM(COM_pedido)) AS Pedido,
			LTRIM(RTRIM(COM_nit_documento)) AS Empresa,
			COM_nombre AS 'Razón Social',
			COM_fecha_documento + ' ' + COM_hora_documento AS 'Fecha documento',
			'No procesado' AS 'Fecha Insercion',
			'6' AS Proceso,
			LTRIM(RTRIM(COM_estado_acuse_dian)) AS Acuse,
			LTRIM(RTRIM(COM_estado_recibo_dian)) AS Recibo,
			LTRIM(RTRIM(COM_estado_aceptacion_dian)) AS Aceptacion,
			LTRIM(RTRIM(COM_estado_reclamo_dian)) AS Reclamo,
			0 AS 'Notificación Recibo',
			0 AS 'Notificación Aceptación'
		INTO #NProcesadoDia
		FROM #Transaccion
		LEFT JOIN #Procesados 
		ON COM_numero_documento = PRO_Documento AND COM_pedido = PRO_NumPedido
		WHERE PRO_Documento IS NULL AND PRO_NumPedido IS NULL;
	
	-- SALIDA DEL PROCEDIMIENTO
		SELECT *
		FROM #ProcesadoDia
		UNION ALL
		SELECT *
		FROM #NProcesadoDia
		ORDER BY Proceso ASC;
END;