USE [DB_Estados]
GO
/****** Object:  StoredProcedure [dbo].[SP_InsertEstado]    Script Date: 5/06/2023 11:57:52 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,28/05/2023>
-- Description:	<Description,Procedimiento para insetar los dias de notificación necesarios>
-- =============================================
ALTER PROCEDURE [dbo].[SP_InsertEstado]
	@in_documento VARCHAR(MAX),
	@in_pedido VARCHAR(MAX),
    @in_email VARCHAR(MAX),
	@in_acuse VARCHAR(MAX),
	@in_recibo VARCHAR(MAX),
	@in_aceptacion VARCHAR(MAX),
	@in_reclamo VARCHAR(MAX),
	@in_proceso INT,
	@in_noti INT
AS
BEGIN
	-- Variable para verificar si el cursor tiene registros
	DECLARE @ExisteRegistro BIT;
	DECLARE @FechaInsercion DATETIME;

	DECLARE Memoria CURSOR FOR
    SELECT PRO_FechaInsercion AS Fecha
    FROM EST_Procesados
    WHERE LTRIM(RTRIM(@in_documento)) = LTRIM(RTRIM(PRO_Documento));

	OPEN Memoria;

	-- Verificar si el cursor tiene registros
	FETCH NEXT FROM Memoria INTO @FechaInsercion;
	SET @ExisteRegistro = CASE WHEN @@FETCH_STATUS = 0 THEN 1 ELSE 0 END;

	IF @in_noti = 0
    BEGIN
		IF @ExisteRegistro = 1 AND @FechaInsercion >= GETDATE()
		BEGIN
			UPDATE EST_Procesados 
			SET PRO_Email = @in_email,
			    PRO_EstadoAcuse = @in_acuse,
			    PRO_EstadoRecibo = @in_recibo,
			    PRO_EstadoAceptacion = @in_aceptacion,
			    PRO_EstadoReclamo = @in_reclamo,
			    PRO_FechaInsercion = FORMAT(GETDATE(), 'MM/dd/yyyy HH:mm:ss'),
			    PRO_daysRecibo = PRO_daysRecibo + 1,
				PRO_Proceso = @in_proceso
			WHERE PRO_Documento = @in_documento
		END
		ELSE
		BEGIN
			INSERT INTO EST_Procesados (
				PRO_Documento,
				PRO_NumPedido,
				PRO_Email,
				PRO_EstadoAcuse,
				PRO_EstadoRecibo,
				PRO_EstadoAceptacion,
				PRO_EstadoReclamo,
				PRO_Proceso,
				PRO_FechaInsercion,
				PRO_Procesado,
				PRO_daysRecibo,
				PRO_daysAceptacion
			) VALUES(
				LTRIM(RTRIM(@in_documento)),
				LTRIM(RTRIM(@in_pedido)),
				@in_Email,
				@in_acuse,
				@in_recibo,
				@in_aceptacion,
				@in_reclamo,
				@in_proceso,
				FORMAT(GETDATE(), 'MM/dd/yyyy HH:mm:ss'),
				0,
				1,
				0
			);
		END
    END
    ELSE IF @in_noti = 1
    BEGIN
		IF @ExisteRegistro = 1 AND @FechaInsercion >= GETDATE()
		BEGIN
		UPDATE EST_Procesados 
		SET PRO_Email = @in_email,
			PRO_EstadoAcuse = @in_acuse,
			PRO_EstadoRecibo = @in_recibo,
			PRO_EstadoAceptacion = @in_aceptacion,
			PRO_EstadoReclamo = @in_reclamo,
			PRO_FechaInsercion = FORMAT(GETDATE(), 'MM/dd/yyyy HH:mm:ss'),
			PRO_daysAceptacion = PRO_daysAceptacion + 1,
			PRO_Proceso = @in_proceso
		WHERE PRO_Documento = @in_documento
		END
		ELSE
		BEGIN
			INSERT INTO EST_Procesados (
				PRO_Documento,
				PRO_NumPedido,
				PRO_Email,
				PRO_EstadoAcuse,
				PRO_EstadoRecibo,
				PRO_EstadoAceptacion,
				PRO_EstadoReclamo,
				PRO_Proceso,
				PRO_FechaInsercion,
				PRO_Procesado,
				PRO_daysRecibo,
				PRO_daysAceptacion
			) VALUES(
				LTRIM(RTRIM(@in_documento)),
				LTRIM(RTRIM(@in_pedido)),
				@in_Email,
				@in_acuse,
				@in_recibo,
				@in_aceptacion,
				@in_reclamo,
				@in_proceso,
				FORMAT(GETDATE(), 'MM/dd/yyyy HH:mm:ss'),
				0,
				0,
				1
			);
		END
    END
	-- Cerrar el cursor
	CLOSE Memoria;
	DEALLOCATE Memoria;
END;

