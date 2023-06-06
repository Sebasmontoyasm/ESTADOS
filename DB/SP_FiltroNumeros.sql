USE [DB_Estados]
GO
/****** Object:  StoredProcedure [dbo].[SP_FiltroNumeros]    Script Date: 5/06/2023 11:55:45 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,Sebastian Montoya>
-- Create date: <Create Date,26/04/2023>
-- Description:	<Description,Filtrado de la información para la obtención de las bodegas en Javaina segun el proceso normal, alterno, excepciones>
-- =============================================
ALTER PROCEDURE [dbo].[SP_FiltroNumeros]
AS
BEGIN
	SET NOCOUNT ON;

	-- LIMPIEZA DE EJECUCIONES MANUALES O REPETITIVAS PARA DUPLICIDAD DE DATOS
		DELETE FROM [dbo].[EST_TransaccionalExcepciones]
		WHERE CONVERT(VARCHAR(10),[ESTEXC_FechaInsercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101);

	-- EXTRACCIÓN DEL DIA DE INSERCIÓN DE DATA.
		SELECT *
		INTO #TransaccionDia
		--DROP TABLE #TransaccionDia
		FROM [dbo].[EST_Comercial]
		WHERE CONVERT(VARCHAR(10),[COM_fecha_insercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101) AND COM_forma_pago = 'Credito';
	
	-- PENDIENTE POR PROCESAR EN MEMORIA
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

	-- LIMPIAR TABLA DE ERRORES.
		DELETE FROM EST_TransaccionalERROR
		WHERE CONVERT(VARCHAR(10),[ESTERR_FechaInsercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101);

	-- ESTADO ACUSE DIAN ERROR QUITAR TOP 2
		INSERT INTO EST_TransaccionalERROR(ESTERR_NumPedido,ESTERR_Email,ESTERR_FechaInsercion, ESTERR_Documento,ESTERR_Proceso,ESTERR_Nit,ESTERR_EstadoDian)
		SELECT TOP 2 
			COM_pedido,'notificaciones.fac@sumatec.co',GETDATE(),COM_numero_documento,'4',COM_nit_documento,'acuse'
		FROM #TranNProcesadas
		WHERE COM_estado_acuse_dian = 'e';

	-- ESTADO RECIBIDO DIAN ERROR QUITAR TOP 2
		INSERT INTO EST_TransaccionalERROR(ESTERR_NumPedido,ESTERR_Email,ESTERR_FechaInsercion, ESTERR_Documento,ESTERR_Proceso,ESTERR_Nit,ESTERR_EstadoDian)
		SELECT TOP 2
			COM_pedido,'notificaciones.fac@sumatec.co',GETDATE(),COM_numero_documento,'4',COM_nit_documento,'recibo'
		FROM #TranNProcesadas
		WHERE COM_estado_recibo_dian = 'e';

	-- FILTRO FLUJO NORMAL
		SELECT COM_pedido,LTRIM(RTRIM(COM_numero_documento)) AS COM_numero_documento,COM_nit_documento,'1' AS COM_Proceso
		INTO #tblFNormal
		--DROP TABLE #tblFNormal
		FROM #TranPendientes
		WHERE ISNUMERIC(COM_pedido) = 1 and LEN(COM_pedido) = 6;

	-- FILTRO FLUJO ALTERNO
		SELECT COM_pedido,LTRIM(RTRIM(COM_numero_documento)) AS COM_numero_documento,COM_nit_documento,'3' AS COM_Proceso 
		INTO #tblFAlterno
		-- DROP TABLE #tblFAlterno
		FROM #TranPendientes
		WHERE ISNUMERIC(COM_pedido) <> 1 OR LEN(COM_pedido) <> 6 OR COM_pedido = '';

	-- FILTRO PARA ENCONTRAR LOS QUE SI TIENEN 6 DIGITOS CON CARACTERES Y RETIRAR LOS CARACTERES 
		SELECT *, REPLACE(SUBSTRING(COM_pedido, PATINDEX('%[0-9][0-9][0-9][0-9][0-9][0-9]%', COM_pedido), 6), '[^0-9]', '') AS pedido 
		INTO #tblFiltro6dig
		FROM #tblFAlterno
		WHERE COM_pedido <> '' 
		AND PATINDEX('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9]%',COM_pedido) = 0;

	-- FILTRO PARA RESCATAR LOS QUE TENGAN CARACTERES ESPECIALES Y MENORES A 6 DIGITOS
		SELECT * 
		INTO #tblCEspeciales
		FROM #tblFiltro6dig
		WHERE COM_pedido NOT LIKE '%[!@#$%^&*()_+-=[]{}|;:",.<>?/\\~ `]%' AND LEN(pedido) = 6;

	-- FILAS RESCADATAS PARA NO HACER EL FLUJO ALTERNO
		INSERT INTO #tblFNormal (COM_pedido,COM_numero_documento,COM_nit_documento,COM_Proceso)
		SELECT pedido,COM_numero_documento,COM_nit_documento,'1'
		FROM #tblCEspeciales

	-- RETIRO DEL FLUJO ALTERNO LOS CARACTERES ESPECIALES
		DELETE FROM #tblFAlterno
		WHERE COM_numero_documento IN (SELECT COM_numero_documento FROM #tblCEspeciales);

	-- FLUJO DE EXCEPCIONES
		SELECT *
		INTO #tblExcepciones
		FROM #tblFAlterno F
		WHERE COM_nit_documento IN (SELECT EXC_Nit FROM EST_Excepciones);

	-- RETIRO DEL FLUJO ALTERNO LAS EXCEPCIONES
		DELETE FROM #tblFAlterno
		WHERE COM_numero_documento IN (SELECT COM_numero_documento FROM #tblExcepciones);

	-- INSERSION DE FLUJO EXCEPCIONES
		INSERT INTO EST_TransaccionalExcepciones (ESTEXC_NumPedido,ESTEXC_Email,ESTEXC_FechaInsercion, ESTEXC_Documento,ESTEXC_Proceso,ESTEXC_Nit)
		SELECT TOP 2 tblEXC.COM_pedido,EXC.EXC_Email,GETDATE() as FechaInsercion,tblEXC.COM_numero_documento,'2' as Proceso,EXC.EXC_Nit 
		FROM #tblExcepciones tblEXC
		INNER JOIN EST_Excepciones EXC 
		ON tblEXC.COM_nit_documento = EXC.EXC_Nit;

	--SALIDA DEL PROCEDIMIENTO QUITAR TOP 2
		SELECT TOP 2
			COM_pedido AS Pedido,
			LTRIM(RTRIM(COM_numero_documento)) AS Documento,
			COM_nit_documento AS NIT,
			COM_Proceso AS Proceso
		FROM #tblFNormal
		UNION ALL
		SELECT TOP 2 *
		FROM #tblFAlterno;
END;


