USE [DB_Estados]
GO
/****** Object:  StoredProcedure [dbo].[SP_LimpiarDuplicados]    Script Date: 5/06/2023 11:59:19 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Autho,SebAStian Montoya>
-- Create date: <Create Date,02/05/2023>
-- Description:	<Description,Limpia ejecuciones manuales para almacenar unicamente la ultima ejecución de Jaivana con la mayor cantidad de registros>
-- =============================================
ALTER PROCEDURE [dbo].[SP_LimpiarDuplicados]
AS
BEGIN
	SET NOCOUNT ON;
		DECLARE @FechaMenosUnMes DATETIME;
		SET @FechaMenosUnMes = DATEADD(MONTH, -1, GETDATE());

	-- LIMPIEZA DE EJECUCIONES MANUALES O REPETITIVAS PARA DUPLICIDAD DE DATOS
		DELETE FROM [dbo].[EST_Comercial]
		WHERE CONVERT(VARCHAR(10),[COM_fecha_insercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101);

		DELETE FROM [dbo].[EST_Transaccional]
		WHERE CONVERT(VARCHAR(10),[ESTRAN_FechaInsercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101);

		DELETE FROM [dbo].[EST_TransaccionalAlterna]
		WHERE CONVERT(VARCHAR(10),[ESTRAN_FechaInsercion],101) >= CONVERT(VARCHAR(10),GETDATE(),101);

	--LIMPIEZA PROFUNDA DE REGISTROS PARA EVITAR LLENADO
		DELETE FROM [dbo].[EST_Comercial]
		WHERE CONVERT(VARCHAR(10),[COM_fecha_insercion],101) <= CONVERT(VARCHAR(10),@FechaMenosUnMes,101);
END;