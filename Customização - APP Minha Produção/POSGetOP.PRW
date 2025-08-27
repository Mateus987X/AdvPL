User Function POSGetOP()
    Local aItemsOP  := PARAMIXB[1] // Array de itens da OP voltadas na pesquisa
    //Local cForm     := PARAMIXB[2] // Formulário que está chamando a função
    Local nIndItem  := 1 // Índice do item no array
    Local nLenArr   := Len(aItemsOP) // Tamanho do array de itens
    Local cNumOP := ""  // Variável para armazenar o número da OP
    Local cProduto := "" // Variável para armazenar o código do produto
    Local cOperacao := "" // Variável para armazenar o código da operação
    Local nApontAnterior := 0 // Variável para armazenar a quantidade do apontamento anterior

 
    dbSelectArea("SH6")
    dbSetOrder(1)

    For nIndItem := 1 to nLenArr // Percorre o array de itens

        // Pega o número da OP, código do produto e código da operação do item atual
        cNumOP := aItemsOP[nIndItem]["ProductionOrderNumber"]
        cProduto := aItemsOP[nIndItem]["ItemCode"]
        cOperacao := aItemsOP[nIndItem]["ActivityCode"]

        If SH6->(MsSeek(xFilial("SH6")+cNumOP+cProduto)) // H6_OP H6_PRODUTO
            nApontAnterior := ApontamentoAnterior(cOperacao, cNumOP) // Chama a função para pegar a quantidade do apontamento anterior
            If nApontAnterior > 0 // Verifica se existe apontamento anterior
                aItemsOP[nIndItem]["ActivityQuantity"] := nApontAnterior // Grava a quantidade do apontamento anterior na "QUANTIDADE PREVISTA" do card
            EndIf
        EndIf
    Next nIndItem
    
Return FiltrarOpsEncerradas(aItemsOP)





// Função para obter a quantidade do apontamento anterior
// Recebe a operação corrente e o número da OP como parâmetros
Static Function ApontamentoAnterior(cOperacCorrente, cNumOP)
    Local cQuery   		:= "" // Query para pegar a operação anterior
    Local nQtd  := 0 // Variável para armazenar a quantidade do apontamento anterior
    Local cNumOperacao := "" // Variável para armazenar o número da operação anterior
    Local cAlias := GetNextAlias() // Alias para a tabela temporária

    Local cOper := cOperacCorrente // Operação corrente
    Local cOP   := cNumOP // Número da OP corrente


    cQuery := " SELECT TOP 1 H6_OP, H6_PRODUTO, H6_OPERAC, SUM(H6_QTDPROD)  QTDAPON  "
    cQuery += " FROM SH6010"
    cQuery += " WHERE H6_OPERAC < '" + cOper + "' " + "AND H6_OP = '" + cOP + "'" + " AND D_E_L_E_T_= ' ' " 
    cQuery += " GROUP BY H6_OP, H6_PRODUTO, H6_OPERAC"
    cQuery += " ORDER BY H6_OPERAC DESC"
    cQuery := ChangeQuery(cQuery)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),cAlias,.T.,.T.)
    (cAlias) -> (dbGoTop())

    if !(cAlias)->(Eof()) // Verifica se encontrou algum registro
        // Se encontrou, pega a quantidade e o número da operação
        cNumOperacao := (cAlias)->H6_OPERAC
        nQtd := (cAlias)->QTDAPON
    else // Se não encontrou, não faz nada
        Return 0
    EndIf

    (cAlias)->(dbCloseArea())

Return Round(nQtd,2)


// Função para filtrar as ordens de produção encerradas
// Retorna um array com os itens que não estão encerrados (status diferente de 5
Static Function FiltrarOpsEncerradas(aItemsOP)
    Local aItemsFiltrados := {} // Array para armazenar os itens filtrados
    Local nIndItem := 1 // Índice do item no array
    Local nLenArr := Len(aItemsOP) // Tamanho do array de itens
    Local cStatus := "" // Variável para armazenar o status da ordem

    For nIndItem := 1 to nLenArr // Percorre o array de itens

        // Verifica se o status da ordem não é 5 ou 6
        cStatus := aItemsOP[nIndItem]["StatusOrderType"]
        if !(cStatus == "5" .or. cStatus == "6") // Verifica se o status da ordem não é 5 ou 6 (Encerrados parcialmente/ Totalmente encerrado)
            AADD(aItemsFiltrados, aItemsOP[nIndItem]) // Adiciona o item ao array filtrado
        EndIf

    Next nIndItem

Return aItemsFiltrados


