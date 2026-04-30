/* 
API REST (ADVPL/Protheus) para cadastro de vagas (SQS).
- Recebe payload JSON via POST
- Valida dados obrigatórios
- Prepara ambiente dinamicamente (empresa/filial)
- Gera código da vaga via SX8
- Executa inclusão com MSExecAuto (RSP100Inc)
- Controle transacional (commit/rollback)
- Tratamento de erros e logs
- Retorno estruturado em JSON (sucesso/erro)
*/

#include 'totvs.ch'
#include 'protheus.ch'
#include 'restful.ch'
#include 'rwmake.ch'
#include 'parmtype.ch'
#include 'tbiconn.ch'
#include 'topconn.ch'

WsRestful VAGAS Description "CADASTRAR VAGAS" Format APPLICATION_JSON

    WsMethod POST Description "CADASTRAR VAGA" WsSyntax "/Post/{method}"

End WsRestful


WsMethod POST WsService VAGAS

    Local nOpc                  := 3 // inclusao
    Local aRotAuto              := {}
    Local aLogErro              := {}
    Local n                     := 0
    Local oErr                  := Nil
    Local cErr                  := ""
    Local bOld                  := ErrorBlock({|e| oErr := e, Break(e)})
    Local lEnvOk                := .F.

    Local cJson                 := ""
    Local cDescriCargo          := ""
    Local cCodCentroCusto       := ""
    Local cCodFuncao            := ""
    Local cTipVaga              := ""
    Local cMatResponsavel       := ""
    Local cCodTurno             := ""
    Local cMatSolicitante       := ""
    Local cNomeSolicitante      := ""
    Local cObservacoes          := ""
    Local cNomeSubstituido      := ""
    Local cMatriculaSubstituido := ""
    Local cSigilo               := ""
    Local cCaraterVaga          := ""
    Local cGrauEscola           := ""
    Local cUnidade              := ""
    Local _cCompany             := ""
    Local _cBranch              := ""

    Private lMsErroAuto      := .F.
    Private oJson            := JsonObject():New()
    Private oResult          := JsonObject():New()
    Private lAutoErrNoFile   := .T.
    Private lMsHelpAuto      := .T.
    Private Sx8Num           := ""//GetSX8Num("SQS","QS_VAGA")

    _cCompany := SuperGetMv("SP_EMPAPI",, "01")
    _cBranch  := SuperGetMv("SP_FILAPI",, "01")

    cJson := Self:GetContent()
    oJson:FromJson(cJson)

    cDescriCargo          := oJson["cargo_descricao"]
    cCodCentroCusto       := oJson["codigo_centrocusto"]
    cCodFuncao            := oJson["cargo_codigo"]
    cTipVaga              := oJson["tipo_vaga"] // 1 - Interna/Externa ; 2 - Interna ; 3 - Externa
    cMatResponsavel       := oJson["matricula_imediato"] // matricula do imediato solicitante
    cCodTurno             := oJson["codigo_horatrabalho"] // codigo do turno de trabalho
    cMatSolicitante       := oJson["matricula_solicitante"] // matricula do solicitante da vaga
    cNomeSolicitante      := oJson["nome_solicitante"] // nome do solicitante da vaga
    cObservacoes          := oJson["observacoes"] // observacoes da vaga
    cNomeSubstituido      := oJson["nome_substituicao"] // nome do colaborador que sera substituido
    cMatriculaSubstituido := oJson["matricula_substituicao"] // matricula do colaborador que sera substituido
    cSigilo               := oJson["vaga_sigilosa"] // 1 - Sim / 2 - Nao
    cCaraterVaga          := oJson["carater_contratacao"] // 1 - Efetivo / 2 - Temporario
    cGrauEscola           := oJson["grau_escolaridade"]
    cUnidade              := oJson["unidade_negocio"]

    // Validacao minima de contexto para evitar PREPARE com filial vazia/invalida
    If Empty(AllTrim(cValToChar(cUnidade)))
        oResult := JsonObject():New()
        oResult["status"]  := "ERROR"
        oResult["message"] := "Falha na inclusao da vaga."
        oResult["details"] := "Campo obrigatorio nao informado: unidade_negocio."
        ::SetStatus(400)
        ::SetResponse(FWJsonSerialize(oResult))
        ErrorBlock(bOld)
        Return
    EndIf

    BEGIN SEQUENCE
        RpcSetType(3)
        PREPARE ENVIRONMENT EMPRESA _cCompany FILIAL cUnidade MODULO "RSP"
            If TCIsConnected()
                lEnvOk := .T.
                ConOut('[VAGAS] ' + DToC(dDatabase) + ' - ' + Time() + ': Ambiente Protheus aberto e pronto para uso')
                cFilant := cUnidade
            Else
                cErr := "Falha ao conectar no ambiente Protheus."
                ConOut('[VAGAS] ' + DToC(dDatabase) + ' - ' + Time() + ': ' + cErr)
            EndIf
    RECOVER
    END SEQUENCE

    If oErr <> Nil
        cErr := AllTrim(oErr:Description)

        If ("EXCEDEU" $ Upper(cErr)) .And. ("LICEN" $ Upper(cErr))
            ::SetStatus(503)
            ::SetResponse('{"status":"ERROR","message":"Servico indisponivel no momento. Todas as licencas estao em uso."}')
            ErrorBlock(bOld)
            Return
        EndIf
    EndIf

    If !lEnvOk
        If Empty(cErr)
            cErr := "Nao foi possivel abrir ambiente para a filial informada."
        EndIf

        oResult := JsonObject():New()
        oResult["status"]  := "ERROR"
        oResult["message"] := "Falha ao preparar ambiente Protheus."
        oResult["details"] := cErr

        ::SetStatus(503)
        ::SetResponse(FWJsonSerialize(oResult))
        ErrorBlock(bOld)
        Return
    EndIf

    Sx8Num := GetSX8Num("SQS","QS_VAGA")
    ConOut(Repl("-",80))
    ConOut("Inicio: " + Time())
    ConOut(PadC("Rotina Automatica INCLUSAO VAGA - SQS", 80))

    dbSelectArea("SQS")
    dbSetOrder(1)
    While MsSeek(xFilial("SQS") + Sx8Num)
        Sx8Num := ConfirmSx8()
    EndDo

    // CAMPOS OBRIGATORIOS - CADASTRO DE VAGAS
    Aadd(aRotAuto, { "QS_FILIAL", xFilial("SQS","01"), Nil })
    Aadd(aRotAuto, { "QS_VAGA", Sx8Num, Nil })
    Aadd(aRotAuto, { "QS_DESCRIC", cDescriCargo, Nil })
    Aadd(aRotAuto, { "QS_TNOTRAB", cCodTurno, Nil }) // TURNO DE TRABALHO
    Aadd(aRotAuto, { "QS_CC", cCodCentroCusto, Nil })
    Aadd(aRotAuto, { "QS_FUNCAO", cCodFuncao, Nil })
    Aadd(aRotAuto, { "QS_SOLICIT", cNomeSolicitante, Nil })
    Aadd(aRotAuto, { "QS_DTABERT", Date(), Nil }) // Data de Abertura da Vaga
    Aadd(aRotAuto, { "QS_TIPO", cTipVaga, Nil }) // 1 - Interna/Externa ; 2 - Interna ; 3 - Externa
    Aadd(aRotAuto, { "QS_ACESCOM", "1", Nil }) // ACESSO A COMPUTADOR 1 - SIM / 2 - NAO
    Aadd(aRotAuto, { "QS_ACESPRO", "1", Nil }) // ACESSO AO PROTHEUS 1 - SIM / 2 - NAO
    Aadd(aRotAuto, { "QS_TELCORP", "1", Nil }) // TELEFONE CORPORATIVO 1 - SIM / 2 - NAO
    Aadd(aRotAuto, { "QS_IMEDIAT", cMatResponsavel, Nil }) // SOLICITANTE
    Aadd(aRotAuto, { "QS_SIGILO", cSigilo, Nil }) // 1 - Sim / 2 - Nao
    Aadd(aRotAuto, { "QS_STATUS", "1", Nil }) // STATUS DA VAGA 1 - ABERTA
    Aadd(aRotAuto, { "QS_NRVAGA", 1, Nil })
    Aadd(aRotAuto, { "QS_MATSUB", cMatriculaSubstituido, Nil })
    Aadd(aRotAuto, { "QS_DESCSUB", cNomeSubstituido, Nil }) // NOME DO SUBSTITUIDO
    Aadd(aRotAuto, { "QS_CRTCONT", cCaraterVaga, Nil }) // Carater da vaga
    Aadd(aRotAuto, { "QS_GRAUESC", cGrauEscola, Nil }) // Grau de escolaridade da vaga

    ConOut('[VAGAS] Payload SQS -> FILIAL:' + xFilial("SQS") + ;
           ' VAGA:' + Sx8Num + ;
           ' STATUS:1 TURNO:' + AllTrim(cValToChar(cCodTurno)) + ;
           ' CC:' + AllTrim(cValToChar(cCodCentroCusto)) + ;
           ' FUNCAO:' + AllTrim(cValToChar(cCodFuncao)))
    ConOut("[VAGAS] Iniciando MSExecAuto RSP100Inc...")

    // chamada ExecAuto com controle transacional
    BEGIN TRANSACTION
        MSExecAuto({|v,x,y,z| RSP100Inc(v,x,y,z)}, "SQS", 0, nOpc, aRotAuto)

        aLogErro := GetAutoGRLog()
        ConOut("[VAGAS] Finalizou MSExecAuto. lMsErroAuto=" + IIf(lMsErroAuto, ".T.", ".F.") + " / LinhasLog=" + cValToChar(Len(aLogErro)))

        If lMsErroAuto
            DisarmTransaction()
        EndIf
    END TRANSACTION

    If !lMsErroAuto
        ConfirmSx8()
        ConOut("**** Incluido com sucesso! ****")
        oResult := JsonObject():New()
        oResult["status"]  := "OK"
        oResult["message"] := "Vaga incluida com sucesso!"
        oResult["vaga"]    := Sx8Num
        ::SetStatus(200)
        ::SetResponse(FWJsonSerialize(oResult))
    EndIf

    If lMsErroAuto
        ConOut("Erro na Inclusao!")

        For n := 1 To Len(aLogErro)
            ConOut(cValToChar(aLogErro[n]))
        Next
        
        // Isola apenas as linhas invalidas do log para devolver um payload estruturado no REST.
        //aInvalidDetails := VagasParseAutoErrorLog(aLogErro)

        nPos := aScan(aLogErro,{|cLine| "< -- Invalido" $ cLine} )

        oResult := JsonObject():New()
        oResult["status"]  := "ERROR"
        oResult["message"] := "Erro na inclusao da vaga!"
        oResult["error"] := VagasCleanLine(aLogErro[nPos]) // Retorna a linha original do log que causou o erro. Pode ser usada para troubleshooting.
        oResult["ajuda"] := aLogErro[1]

        ::SetStatus(400)
        ::SetResponse(FWJsonSerialize(oResult))
        RollBackSX8()
    EndIf

    ConOut("Fim : " + Time())
    ConOut(Repl("-",80))

    ErrorBlock(bOld)
Return

/*
    Remove espa�os extras da linha de log para um retorno mais limpo.
    - Remove espa�os no in�cio/fim com AllTrim().
    - Substitui m�ltiplos espa�os internos por um �nico espa�o.
*/
Static Function VagasCleanLine(cLine)
    Local cClean := AllTrim(cValToChar(cLine))
    
    // Substitui m�ltiplos espa�os por um �nico (repita para casos extremos)
    While "  " $ cClean
        cClean := StrTran(cClean, "  ", " ")
    EndDo
    
Return cClean
