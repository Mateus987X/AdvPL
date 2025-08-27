User Function PECusAct()
    Local cBodyParam := PARAMIXB
    Local cJsRet     := ""
    Local oJsRet     := JsonObject():New()
    Local nKGporCaixa := 0
    Local nQtdApontada := 0
    

    //Converte a string JSON para objeto JSON, para que seja possível manipular os dados.
    oJsRet:FromJson(cBodyParam)

    if oJsRet["formSource"]["appointmentType"] == "3" // Apontamento MATA681

        if oJsRet["formSource"]["fieldCode"] == "H6_CALCCX" // Botão de calcular KG por Caixa
            nQtdApontada := oJsRet["CustomFieldDecimal01"] // Quantidade de Caixa apontada
            nKGporCaixa := oJsRet["CustomFieldDecimal05"] // Peso por Caixa
            oJsRet["H6_QTDPROD"] := nQtdApontada * nKGporCaixa
        Endif
                   
    Endif

    cJsRet := oJsRet:ToJson()

    FreeObj(oJsRet)
Return cJsRet  


Static Function QuantidadeJaApontadaDaOperacao()
    Local cQuery   		:= "" // Query para pegar a operação anterior
    Local cNumOperacao := "" // Variável para armazenar o número da operação anterior
    Local cAlias := GetNextAlias() // Alias para a tabela temporária
    Local cNumOP   := cNumOP // Número da OP corrente


    cQuery := " SELECT H6_OP, H6_OPERAC, SUM(H6_QTDPROD) QNTAPONTADA  "
    cQuery += " FROM SH6010"
    cQuery += " WHERE H6_OP = '" + cNumOP + "' AND H6_OPERAC = '" + cNumOperacao + "'  AND D_E_L_E_T_ = '' " 
    cQuery += " GROUP BY H6_OP, H6_OPERAC"
    cQuery := ChangeQuery(cQuery)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),cAlias,.T.,.T.)

    (cAlias) -> (dbGoTop())
    (cAlias)->(dbCloseArea())

Return Round((cAlias) -> QNTAPONTADA,2)




