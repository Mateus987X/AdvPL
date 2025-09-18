// UTILIZANDO O PONTO DE ENTRADA MVC DO NOVO FLUXO DE COMPRAS para:
// • Adicionar Saldo: Reabrir a cotação, adicionando saldo novamente a cotação para possibilitar novos pedidos baseado na mesma cotação.
// • Editar Cotação: Editando a quantidade original da cotação para contextos em que o fornecedor possui uma quantidade maior e faz um preço melhor baseado no lote.

#include "protheus.ch"
#include "parmtype.ch"
#Include "RestFul.ch"
#include "totvs.ch"
#Include "TopConn.ch"
#Include "tbiconn.ch"
#Include "Rwmake.ch"  
#Include "Colors.ch" 
#Include "FWBrowse.ch"

User Function NFCA020()
Local aParam := PARAMIXB
Local xRet   := .T.
Local cIDPonto := ''
Private lEditarCotacao := .F. // Variável responsável para controlar o fluxo da função "SelecionaProdutos"

If aParam <> NIL
        oObj        := aParam[1]
        cIDPonto    := aParam[2]
        cIDModel    := aParam[3]
        lIsGrid     := (Len(aParam) > 3)
        nOperation  := oObj:GetOperation()

        if cIDPonto == "BUTTONBAR"
            if nOPCNFC = 1 // Visualizar
                xRet    := {{'Adicionar saldo na Cotação','Adicionar saldo na Cotação',{|| AdicionarSaldo()},'Adicionar saldo na Cotação'}}
            elseif nOPCNFC = 4 // Alterar
                xRet := {{'Editar Saldo da Cotação', 'Editar Saldo da Cotação', {||Editarcotacao() }, 'Editar saldo.'}}
            EndIf   
        EndIf
EndIf

Return xRet

Static Function  Editarcotacao()
    Local cNumCot := DHU -> DHU_NUM // número da cotação
    Local aProdutos := CarregaProdutosCotacao(cNumCot) // {{Cod, Desc, Saldo}}
    Local aSelIdx := {} //índices selecionados no listbox
    Local nI

    lEditarCotacao := .T. // 

    if Empty(aProdutos)
        MsgInfo("Nenhum produto encontrado para a cotação " + cNumCot, "Atenção")
        return
    Endif

    //1) Tela para escolher 1..N produtos
    aSelIdx := SelecionaProdutos(aProdutos)
    if Empty(aSelIdx)
        MsgInfo("Nenhum produto selecionado.", "Atenção")
        Return
    Endif

    //2) para cada produto selecionador, perguntar a quantidade e atualizar saldo
    for nI := 1 to Len(aSelIdx)
        hProd := aSelIdx[nI][1]
        nQtd := aSelIdx[nI][3]

        if nQtd > 0
            if AtualizarQuantidadeCotacao(cNumcot, hProd, nQtd)
                MsgInfo("Saldos atualizados com sucesso!", "Informação")
            else
                MsgStop("Erro ao atualizar saldo para o produto " + hProd[1] + " - " + hProd[2], "Erro")
            EndIf
        Else
            //
        Endif
    Next

Static Function AdicionarSaldo()
    Local cNumCot := DHU -> DHU_NUM // número da cotação
    Local aProdutos := CarregaProdutosCotacao(cNumCot) // {{Cod, Desc, Saldo}}
    Local aSelIdx := {} //índices selecionados no listbox
    Local nI, hProd, nQtd

    if Empty(aProdutos)
        MsgInfo("Nenhum produto encontrado para a cotação " + cNumCot, "Atenção")
        return
    Endif

    //1) Tela para escolher 1..N produtos
    aSelIdx := SelecionaProdutos(aProdutos)
    if Empty(aSelIdx)
        MsgInfo("Nenhum produto selecionado.", "Atenção")
        Return
    Endif

    //2) para cada produto selecionador, perguntar a quantidade e atualizar saldo
    for nI := 1 to Len(aSelIdx)
        hProd := aSelIdx[nI][1]
        nQtd := aSelIdx[nI][3]

        if nQtd > 0
            if AtualizasaldoProduto(cNumcot, hProd, nQtd)
                MsgInfo("Saldos atualizados com sucesso!", "Informação")
            else
                MsgStop("Erro ao atualizar saldo para o produto " + hProd[1] + " - " + hProd[2], "Erro")
            EndIf
        Else
            //
        Endif
    Next
Return

// -----------------------------------------------------------------------

Static Function CarregaProdutosCotacao(cNumCot)
    Local aRet := {}
    Local cQuery := "" 
    Local cAlias := GetNextAlias()

    cQuery := "SELECT DHV_CODPRO, B1_DESC, DHV_SALDO"
    cQuery += " FROM DHV010 DHV"
    cQuery += " INNER JOIN SB1010 SB1 ON B1_COD = DHV_CODPRO AND B1_FILIAL = '01' AND SB1.D_E_L_E_T_ = ''"
    cQuery += " WHERE DHV_NUM = '" + cNumCot + "' AND DHV.D_E_L_E_T_ = ''"
    cQuery := ChangeQuery(cQuery)
    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),cAlias,.T.,.T.)

    While !((cAlias)->(Eof()))
        AAdd(aRet, { (cAlias)->DHV_CODPRO, (cAlias)->B1_DESC, (cAlias)->DHV_SALDO })
        (cAlias)->(DbSkip())
    EndDo
Return aRet

// -------------------------------------------------------------------------

Static Function SelecionaProdutos(aProdutos)
    Local oOk      := LoadBitmap( GetResources(), "LBOK" )
    Local oNo      := LoadBitmap( GetResources(), "LBNO" )
    Local oDlg, oLbx
    Local aVetor    := {}           // { lSel, cCod, cDesc, nSaldo }
    Local aResult   := {}           // retorno: { {cCod,cDesc,nQtd}, ... }
    Local lOk       := .F.
    Local cVar      := ""           // VAR do listbox (não usado, mas requerido)
    Local cCod, cDesc, nQtd, n

    
    // 1) Monta a "tabela" que o LISTBOX vai renderizar
    If Len(aProdutos) == 0
        APMsgAlert("Não existem produtos para selecionar!")
        Return {}
    EndIf

    // Monta vetor com ccoluna de seleção (booleana) na primeira posição
    AEval(aProdutos, {|p| Aadd(aVetor, {.F., p[1], p[2], p[3]})})

    // Janela 640x360 px, centralizada
    DEFINE MSDIALOG oDlg TITLE "Seleção de Produtos" FROM 0,0 TO 400,600 PIXEL

    @ 0,0 LISTBOX oLbx VAR cVar FIELDS HEADER ;
    " ", "Código", "Descrição", "Saldo";
    SIZE 600,400 OF oDlg PIXEL ;
    ON dblClick( aVetor[oLbx:nAt,1] := !aVetor[oLbx:nAt,1], oLbx:Refresh() )
    
    oLbx:SetArray( aVetor )
    oLbx:bLine := {|| { ;
    Iif(aVetor[oLbx:nAt,1], oOk, oNo), ;
    aVetor[oLbx:nAt,2], ;
    aVetor[oLbx:nAt,3], ;
    Transform( IIf(ValType(aVetor[oLbx:nAt,4])=="N", aVetor[oLbx:nAt,4], 0), "@E 999,999,999.99") } }

    DEFINE SBUTTON FROM 188,270 TYPE 1 ACTION ( lOk := .T., oDlg:End() ) ENABLE OF oDlg PIXEL
    DEFINE SBUTTON FROM 188,240 TYPE 2 ACTION ( lOk := .F., oDlg:End() ) ENABLE OF oDlg PIXEL

    ACTIVATE MSDIALOG oDlg CENTERED ON INIT ( oLbx:Refresh(), oLbx:SetFocus() ) 

    // 3) Se confirmou, para cada item marcado pergunta a quantidade
    If lOk
        For n := 1 To Len(aVetor)
            If aVetor[n,1]
                cCod  := aVetor[n,2]
                cDesc := aVetor[n,3]
                nQtd  := PerguntaQuantidade(cCod, cDesc )
                If nQtd > 0
                    AAdd(aResult, { cCod, cDesc, nQtd } )
                EndIf
            EndIf
        Next
    Else
        //
    EndIf

Return aResult

// -------------------------------------------------------------------------

Static Function PerguntaQuantidade(cCod, cDesc)
    Local oDlg
    Local nQtd := 0
    Local lOk := .F.

    if lEditarCotacao 
        DEFINE MSDIALOG oDlg TITLE "Editar Quantidade da Solicitação Cotação" + cDesc FROM 0,0 TO 130, 440 PIXEL
        @ 10, 10 SAY "Produto:" SIZE 40, 10 PIXEL
        @ 10, 42 SAY cCod + " - " + cDesc SIZE 280, 10 PIXEL
    Else
        DEFINE MSDIALOG oDlg TITLE "Adicionar Saldo à Cotação " + cDesc FROM 0,0 TO 130, 440 PIXEL 
        @ 10, 10 SAY "Produto:" SIZE 40, 10 PIXEL
        @ 10, 42 SAY cCod + " - " + cDesc SIZE 280, 10 PIXEL
    EndIf

    @ 28, 10 SAY "Quantidade a adicionar:" SIZE 90, 10 PIXEL
    @ 28, 100 GET nQtd PICTURE "@E 999,999,999.99" SIZE 80, 12 PIXEL VALID (nQtd >= 0)

    @ 52, 120 BUTTON "Confirmar" SIZE 40, 12 PIXEL ACTION {|| lOk := .T., oDlg:End()}
    @ 52, 180 BUTTON "Cancelar" SIZE 40, 12 PIXEL ACTION {|| lOk := .F., oDlg:End()}

    ACTIVATE MSDIALOG oDlg CENTERED
Return IIf(lOk, nQtd, 0)


// -------------------------------------------------------------------------

Static Function AtualizaSaldoProduto(cNumCot, cCod, nQtd)
    Local cFor := SA2 -> A2_COD
    Local cForLoja := SA2 -> A2_LOJA
    Local nitemProd 

    // Posicionando na SC8 para pegar o C8_ITEM que será usada para posicionar na DHV
    dbSelectArea("SC8")
    dbSetOrder(3)

    if MsSeek(xFilial("DHU")+cNumCot+cCod+cFor+cForLoja)
        nitemProd := SC8 -> C8_ITEM
    else 
        MsgStop("Erro no índice da SC8","Erro")
        return .F.
    EndIf

    // Atualizando saldo do produto da cotação corrente
    DbSelectArea("DHV")
    dbSetOrder(1)
    if DbSeek(xFilial("DHU")+cNumCot+nitemProd)
        if RecLock("DHV", .F.)
            Replace DHV -> DHV_SALDO with DHV -> DHV_SALDO + nQtd
            MsUnLock()
        else
            MsgStop("Erro no RecLock na tabela DHV","Erro")
            return .F.
        EndIf
    else 
        MsgStop("Erro no MsSeek do DHV","Erro")
        return .F.
    EndIf

    // Atualizando status da cotação para "Atendido parcialmente"
    RecLock("DHU",.F.)
    Replace DHU -> DHU_STATUS with "6" // Status: Atendido parcialmente
    MsUnLock()
Return .T.

Static Function AtualizarQuantidadeCotacao(cNumCot, cCod, nQtd)
    Local cFor := SA2 -> A2_COD
    Local cForLoja := SA2 -> A2_LOJA
    Local nitemProd 

    // Posicionando na SC8 para pegar o C8_ITEM que será usada para posicionar na DHV
    dbSelectArea("SC8")
    dbSetOrder(3)

    if MsSeek(xFilial("DHU")+cNumCot+cCod+cFor+cForLoja)
        nitemProd := SC8 -> C8_ITEM
        RecLock("SC8", .F.)
        Replace SC8 -> C8_QUANT with nQtd + SC8 -> C8_QUANT
        MsUnLock()
    else 
        MsgStop("Erro no índice da SC8","Erro")
        return .F.
    EndIf

    // Atualizando saldo do produto da cotação corrente
    DbSelectArea("DHV")
    dbSetOrder(1)
    if DbSeek(xFilial("DHU")+cNumCot+nitemProd)
        if RecLock("DHV", .F.)
            Replace DHV -> DHV_SALDO with DHV -> DHV_SALDO + nQtd
            MsUnLock()
        else
            MsgStop("Erro no RecLock na tabela DHV","Erro")
            return .F.
        EndIf
    else 
        MsgStop("Erro no MsSeek do DHV","Erro")
        return .F.
    EndIf
Return .T.




