//Rotina responsável por encerrar o pedido de compra, zerando a quantidade de itens do pedido//
#include "TOTVS.CH"
User Function XELIMPED()

	Local cAltElim := SuperGetMV("MV_ELIMPED", ," ")

	IF !(__cUserID $ cAltElim) // códigos dos UserId permitidos na rotina
		APMSGALERT( "Você não tem permissão para usar essa rotina !!!","ATENÇÃO")
		RETURN
	ENDIF

    
	If MsgYesNo("Encerrar pedido " + C7_NUM + " ?" ,"ATENÇÃO","YESNO")

		cNumCorrente:= SC7->C7_NUM
		cQuery := " UPDATE " + RetSqlName("SC7")
		cQuery += " SET C7_QUJE = C7_QUANT
		cQuery += " WHERE C7_FILIAL = '" + xFilial('SC7') + "'" 
		cQuery += " AND C7_NUM = '" + cNumCorrente + "' " 
		cQuery += " AND D_E_L_E_T_ = ' ' "
		TCSqlExec( cQuery )
		msgInfo("Pedido encerrado com sucesso!!!")

	Else
        MSGSTOP("Operação cancelada pelo usuário!")
	EndIf
	
Return
