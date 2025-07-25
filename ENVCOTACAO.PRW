#include "protheus.ch"
#include "parmtype.ch"
#Include "RestFul.ch"
#include "totvs.ch"
#Include "TopConn.ch"
#INCLUDE "TBICONN.CH"
#Include "Rwmake.ch"  
#Include "Colors.ch" 
#Include "FWBrowse.ch"




User Function ENVCOTACAO() //Monta Tela para o usuário digitar a cotação *********************** 

//Local cNomeC  := Posicione("SA1",1,xFilial("SA1")+cCliSe1+cLojSe1,"A1_NOME") 
    Local cTitulo := "Enviar cotação"   
    Local cNumCotacao := Space(6)
    Local lConfirmed := .F. //FLAG ARA SABER SE O USUÁRIO CONFIRMOU
    Local oDlgCotacao // Objeto do MSDIALOG
 
    // Define o diálogo
    DEFINE MSDIALOG oDlgCotacao TITLE cTitulo FROM 0,0 TO 150,450 OF oMainWnd PIXEL FONT oMainWnd:oFont

    //Campo de entrada para o número da cotação
    @ 30, 20 SAY "Número da Cotação:"
    @ 30, 75 GET cNumCotacao PICTURE "@!" SIZE 80, 15 F3 "GSPC83"
    
    // Botão de Confirmar
    // Type 01 geralmente é um botão de OK/Confirmar
    @ 50, 100 BMPBUTTON TYPE 01 ACTION Eval({|| lConfirmed := .T., oDlgCotacao:End() })

    // Botão de Cancelar
    // Type 02 geralmente é um botão de Cancelar
    @ 50, 130 BMPBUTTON TYPE 02 ACTION  Eval({|| lConfirmed := .F., oDlgCotacao:End() })

    ACTIVATE MSDIALOG oDlgCotacao CENTER

    If lConfirmed
        cNumCotacao := Alltrim(cNumCotacao)
        ConOut("Número da Cotação Digitado: " + cNumCotacao)
        // Chama a função que envia o webhook
        If !Empty(cNumCotacao)
            ConOut("Número da Cotação Digitado: " + cNumCotacao)
            If EnviarCotacao(cNumCotacao)
                // Mensagem de sucesso já é tratada dentro de SendQuoteWebhookData
            Else
                // Mensagem de erro já é trada dentro do EnviarCotacao()
            EndIf
        Else
            MsgInfo("Nenhum número de cotação foi digitado.", "Aviso")
        EndIf
    EndIf
Return Nil


static function EnviarCotacao(cCotacao)
    Local cJsonString := "["
    Local cWebhookUrl := "WEBHOOK"
    Local cRetornoWebhook := ""
    Local nStatusCode := ""
    Local oRest := Nil
    Local aHeader := {}
    
    

    dbSelectArea("SC8")
    dbSetOrder(12) // C8_FILIAL + C8_NUM
    dbGoTop()

    if DbSeek(xFilial("SC8") + cCotacao)
        cCot := cCotacao // Recebe o número da cotação digitado pelo usuário
        nCount := 0 //
        While SC8->C8_NUM == cCot
            //Adiciona vÃ­rgula antes de cada objeto, exceto o primeiro
            if nCount > 0
                cJsonString += ","
            EndIf
            cJsonString += '{'
            cJsonString += '"Filial":"' + SC8->C8_FILIAL + '",'
            cJsonString += '"Cotacao":"' + cCot + '",'
            cJsonString += '"Produto":"' + SC8->C8_PRODUTO + '",'
            cJsonString += '"Fornecedor":"' + SC8->C8_FORNECE + '",'
            cJsonString += '"ForLoja":"' + SC8->C8_LOJA + '"'
            cJsonString += '}'

            nCount++
            DbSkip()
        Enddo
    EndIf

    cJsonString += "]" // Fecha o array JSON
    

    // --- 1. Gerar a string JSON (cJsonString) da SC8 aqui ---
    
    if !empty(cJsonString)
        oRest := FWRest():New(cWebhookUrl)
        oRest:SetPostParams(cJsonString)

        aAdd(aHeader, "Content-Type: application/json") // Define o cabeÃ§alho Content-Type como JSON
        
        oRest:setPath("/")  


        If oRest:Post(aHeader) // Envia a requisiÃ§Ã£o

            nStatusCode := oRest:GetLastError()
            cRetornoWebhook := oRest:GetResult()

            if nStatusCode == "200 OK" // CÃ³digos 2xx indicam sucesso 
                ConOut("JSON da SC8 enviado via webhook som sucesso! Status: " + alltrim(nStatusCode))
                ConOut("Resposta do Webhook: " + cRetornoWebhook)
                msgInfo("Cotações enviadas,  Status: " + alltrim(nStatusCode) + Chr(13) + "Resposta do Webhook: " + cRetornoWebhook, "Cotações Enviadas com Sucesso")
            EndIf
        Else    
            nStatusCode := oRest:GetLastError()
            cRetornoWebhook := oRest:GetResult()
            ConOut("Erro ao enviar JSON. Status: " + alltrim(nStatusCode))
            ConOut("Resposta do Webhook: " + cRetornoWebhook)
            msgInfo("Erro ao enviar JSON, Status: " + alltrim(nStatusCode) + Chr(13) + "Resposta do Webhook: " + cRetornoWebhook, "Erro no envio do JSON")
        EndIf
    Else
        ConOut("Nenhum dado encontrado na SC8 para enviar.")
    EndIf
Return

// -------------------------------------------------------------------
//  Função de Validação para o GET que implementa o F3
//    (Esta função é chamada pelo VALID do GET)
// -------------------------------------------------------------------

static Function ValidaCotacaoGET(cValorCampo) // Recebe o valor atual do campo GET
    Local lRet := .T. // Por padrão, a validação é verdadeira
 
    If Empty(cValorCampo)
        MsgStop("O número da cotação não pode ser vazio.", "Validação")
        lRet := .F. // Não permite a saída do campo
    elseif Len(alltrim(cValorCampo)) != 6
        MsgStop("O número da cotação deve ter exatamente 6 dígitos.", "Validação")
        lRet := .F. // Não permite a saída do campo
    elseif !empty(cValorCampo)
        lRet := .T. // Permite a saída do campo se o valor for válido      
    Endif

Return lRet // Retorna o resultado da validação



