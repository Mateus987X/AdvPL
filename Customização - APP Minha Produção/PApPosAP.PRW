#INCLUDE "TOTVS.CH"
 
User Function PApPosAp()
    Local cTipoApon := PARAMIXB[1] //Tipo do apontamento em execução
    Local aDados    := PARAMIXB[2] //Array de dados que será utilizado pelo MATA250 ou MATA681
 
    Do Case
        Case cTipoApon == "3" // Apontamento MATA681
            custom681(@aDados)
    EndCase
     
Return aDados

 
Static Function custom681(aDados)
    Local nQtdProd := aDados[aScan(aDados,{|x| x[1] == "H6_QTDPROD"})][2]// //Quantidade produzida apontada
    Local nQtdPerda := aDados[aScan(aDados,{|x| x[1] == "H6_QTDPERD"})][2] //Quantidade de perda apontada
    Local nQtdTotalApontando := nQtdProd + nQtdPerda //Quantidade total que está sendo apontada
    Local cProdutoOP := aDados[aScan(aDados,{|x| x[1] == "H6_PRODUTO"})][2] + Space(1) //Produto da OP
    Local cNumOP := aDados[aScan(aDados,{|x| x[1] == "H6_OP"})][2] + Space(3) //Número da OP
    Local nQtdTotalApontada := 0
    Local nQtdOriOP := QuantidadeOpOriginal(cNumOP) //Quantidade original da OP
    Local cOperacao := aDados[aScan(aDados,{|x| x[1] == "H6_OPERAC"})][2] //Operação da OP
    
    dbSelectArea("SH6")
    dbSetOrder(2) // H6_FILIAL, H6_PRODUTO, H6_OP
    if dbSeek(xFilial() + cProdutoOP + cNumOP) //Busca a OP na tabela SH6, se tiver.
        While !(SH6 -> (Eof())) .and. SH6 -> H6_PRODUTO == cProdutoOP .and. SH6 -> H6_OP == cNumOP
            if SH6 -> H6_OPERAC == cOperacao //Se a operação for igual àquela que está sendo apontada
                nQtdTotalApontada += SH6 -> H6_QTDPROD + SH6 -> H6_QTDPERD //Soma as quantidades apontadas
            Endif
            SH6 -> (dbSkip()) //Avança para o próximo registro
        EndDo
    Endif
    if nQtdOriOP <= Round(nQtdTotalApontada + nQtdTotalApontando,2) //Se a quantidade original da OP for menor ou igual a quantidade total que está sendo apontada, coloca o status da OP como "TOTAL" e não "PARCIAL".
        aDados[aScan(aDados,{|x| x[1] == "H6_PT"})][2] := "TOTAL"
    EndIf

Return aDados

Static Function QuantidadeOpOriginal(cNumOP)
    dbSelectArea("SC2")
    dbSetOrder(12) // C2_FILIAL, C2_NUMOP
    MsSeek(xFilial() + cNumOP)
return SC2 -> C2_QUANT




