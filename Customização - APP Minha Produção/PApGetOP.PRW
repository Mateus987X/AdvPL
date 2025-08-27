#INCLUDE "TOTVS.CH"
   
User Function PApGetOP()
    Local cTipo      := PARAMIXB[1]
    Local cJsRet     := PARAMIXB[2]
    Local cFormCode  := PARAMIXB[3]
    Local cReqSource := PARAMIXB[4] // Fonte da requisição, ler documentação --https://tdn.totvs.com/pages/releaseview.action?pageId=639175873
    //Local cBcodeData := PARAMIXB[5]
    Local oJsRet    := JsonObject():New()
    
    //Converte a string JSON para objeto JSON, para que seja possível manipular os dados.
    oJsRet:FromJson(cJsRet)
   
    Do Case
        Case cTipo == "1" // Apontamento MATA250
            Return cJsRet // Não faz nenhuma alteração, apenas retorna o JSON recebido.

        Case cTipo == "3" // Apontamento MATA681
            
            If cReqSource == "ST" .or. cReqSource == "PA" // se o Botão Stop("ST") ou Pause("PA")
                oJsRet["CustomFieldCharacter02"] := GetSx8Num("SH6", "H6_DOC", xFilial("SH6")) // Preenche o campo "Documento Atual" com o alias do documento de apontamento.
                ConfirmSx8() // Confirma o Sx8 para garantir que o documento foi atualizado corretamente.
                oJsRet["CustomFieldDecimal05"] := SB1 -> B1_QE // Preenche o campo "Peso por Caixa" com o valor do peso por caixa para ser usado no PECusAct.PRW
                oJsRet["CustomFieldCharacter01"] := UltimoDocumento(oJsRet["ProductionOrderNumber"], oJsRet["ActivityCode"]) // Preenche o campo "Último Documento" com o último documento de apontamento encontrado para a OP.

                if aScan({"000009    ", "000010    ", "000011    "}, cFormCode) > 0 // Se o Formulário relacionado as massas (MISTURADEIRAS)
                    oJsRet["LotCode"] := "L" + left(oJsRet["ProductionOrderNumber"],6)
                EndIf

            Endif

        Case cTipo == "4" // Apontamento SFCA314
            Return cJsRet // Não faz nenhuma alteração, apenas retorna o JSON recebido.
    EndCase
    //Converte o objeto Json com as informações manipuladas em uma String Json.
    cJsRet := oJsRet:ToJson()
   
    //Limpa da memória o objeto Json utilizado.
    FreeObj(oJsRet)
Return cJsRet




// Função para obter o último documento de apontamento para a OP e operação especificada.
Static Function UltimoDocumento(cNumOP, cOperacao)
    Local cAlias := GetNextAlias() // Alias para a tabela temporária
    Local cQuery := "SELECT TOP 1 H6_DOC FROM SH6010 WHERE D_E_L_E_T_ = ' ' AND H6_OP =  '" + cNumOP + "'" + " AND H6_OPERAC = '" + cOperacao + "'" + " ORDER BY H6_IDENT DESC"
    
    dbUseArea(.T., "TOPCONN", TcGenQry(,,cQuery), cAlias, .T., .T.)
    (cAlias)->(dbGoTop())

    if !(cAlias)->(Eof()) .and. !Empty((cAlias)->H6_DOC)// Verifica se encontrou algum registro
        Return (cAlias)->H6_DOC // Retorna o último documento encontrado
    else
        Return "SEMDOC" // Se não encontrou, retorna uma string vazia
    EndIf

    (cAlias)->(dbCloseArea())

Return Nil


