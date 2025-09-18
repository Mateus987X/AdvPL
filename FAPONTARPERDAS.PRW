#include 'protheus.ch'
#include 'parmtype.ch'

// Rotina para apontar perdas automaticamente de acordo com a quantidade produzida em cada etapa da OP

User Function FAPONTARPERDAS()
    Local cAlias := GetNextAlias() // Alias para a tabela temporária
    Local cNumOP := SH6->H6_OP // Número da OP corrente
    Local aVetor := {}
    Local nOpc := 3
    Local lOk := .T.
    Local lPerda := .F. // Flag para indicar se há perdas a serem apontadas
    Local cQuery := ''
    Local nQuatidadeProduzidaAnterior := 0 // Quantidade produzida da etapa anterior decorrente da QUERY
    Local nQtdPerda := 0

    Private lApontarPerdas := .T. // variável responsável para conversar com o ponto de entada MT681INC para que não execute o apontamento automático da operação 15.

    cQuery := " SELECT  H6_OP, C2_QUANT QtdOriginalOP, SUM(H6_QTDPROD) QtdProduzidaTotal, SUM(H6_QTDPERD) QtdPerdaTotal , H6_OPERAC Operacao, H6_LOCAL Armazem "
    cQuery += " FROM SH6010 SH6"
    cQuery += " INNER JOIN SC2010 SC2 ON C2_FILIAL = H6_FILIAL AND C2_NUM+C2_ITEM+C2_SEQUEN = H6_OP AND C2_PRODUTO = H6_PRODUTO AND SC2.D_E_L_E_T_ = '' " 
    cQuery += " WHERE H6_OP = '" + cNumOP + "'" + " AND SH6.D_E_L_E_T_ = ''"
    cQuery += " GROUP BY H6_OP, C2_QUANT, H6_OPERAC, H6_LOCAL"
    cQuery += " ORDER BY H6_OP, H6_OPERAC ASC"
    cQuery := ChangeQuery(cQuery)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),cAlias,.T.,.T.)
    (cAlias) -> (dbGoTop())

    While !(cAlias)->(Eof())
        if IIF(Empty(nQuatidadeProduzidaAnterior), QtdOriginalOP, nQuatidadeProduzidaAnterior) - (QtdProduzidaTotal + QtdPerdaTotal) > 0 // Verifica se há perda a ser apontada
            nQtdPerda := IIF(Empty(nQuatidadeProduzidaAnterior), QtdOriginalOP, nQuatidadeProduzidaAnterior) - (QtdProduzidaTotal + QtdPerdaTotal) // Calcula a quantidade de perda
            aVetor := {}
            // 1) Definindo rotina
            SetFunName("MATA681")
            // 2) Adicionando os parâmetros no vetor
            aAdd(aVetor, {"H6_FILIAL"      , SH6->H6_FILIAL, NIL})
            aAdd(aVetor, {"H6_OP"      , SH6->H6_OP, NIL})
            aAdd(aVetor, {"H6_PRODUTO" , SH6->H6_PRODUTO, NIL})
            aAdd(aVetor, {"H6_OPERAC"  , Operacao   , NIL})
            aAdd(aVetor, {"H6_RECURSO" , SH6->H6_RECURSO , NIL})
            aAdd(aVetor, {"H6_DATAINI" , Date()  , NIL})
            aAdd(aVetor, {"H6_HORAINI" , "00:00" , NIL})
            aAdd(aVetor, {"H6_DATAFIN" , Date()  , NIL})
            aAdd(aVetor, {"H6_HORAFIN" , "00:01" , NIL})
            aAdd(aVetor, {"H6_QTDPERD" , nQtdPerda, NIL})
            aAdd(aVetor, {"H6_PT"      , "T"  , NIL})
            aAdd(aVetor, {"H6_DTAPONT" , Date()  , NIL})
            aAdd(aVetor, {"H6_LOCAL"   , Armazem , NIL}) 

            nQuatidadeProduzidaAnterior := QtdProduzidaTotal // Atualiza a quantidade produzida anterior

            // 3) Executando a rotina

            lMsErroAuto := .F.
            MSExecAuto ({|x| MATA681(x)}, aVetor, nOpc)

            If lMsErroAuto
                MostraErro()
                lOk := .F.
                Exit
            EndIf
            (cAlias) -> (dbSkip())
            
        Else
            nQuatidadeProduzidaAnterior := QtdProduzidaTotal
            (cAlias) -> (dbSkip())
        EndIf

    EndDo
    (cAlias)->(dbCloseArea())
    if lOk
        RecLock("SC2",.F.)
        Replace SC2->C2_DATRF With Date() // Atualiza a data de referência da OP
        MsUnlock()
        // Se tudo ocorreu bem, exibe a mensagem de sucesso
        MsgInfo("Todas as perdas apontadas, OP finalizada.", "Info")
    else
        if !lPerda
            MsgInfo("Nenhuma perda a ser apontada.", "Info")
        Endif
    Endif
Return Nil
