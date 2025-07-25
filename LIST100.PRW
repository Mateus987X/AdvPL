// ============================================================================
// LIST100.PRW
// Programa para manuten��o de pre�os - Lista 100
// Pre�os estes que s�o a cota��o do um determinado produto na data vigente, com intuito de precificar o custo
// de cada produto internamente, em ordens de produ��o, etc.
// ============================================================================
// Autor: Mateus Pereira Barboza
// Data: 11/07/2025
// Descri��o: Rotinas para cadastro, altera��o e exclus�o de pre�os na tabela SZ3
// ============================================================================

#include "protheus.ch"

/*=============================================================================
    Fun��o: LIST100
    Descri��o: Fun��o principal para manuten��o de pre�os da Lista 100.
    Par�metros: Nenhum
    Retorno: Nil
=============================================================================/*/
User Function LIST100()
    Local cAlias    := "SZ3"                                 // Alias da tabela de pre�os
    Local cTitulo   := "Manutencao de pre�os - Lista 100"    // T�tulo da rotina
    Local cVldExc   := "U_LsExc()"                           // Fun��o de valida��o para exclus�o
    Local cVldAlt   := "U_LsAlt()"                           // Fun��o de valida��o para altera��o

    dbSelectArea(cAlias)                                     // Seleciona a �rea de trabalho SZ3
    dbSetOrder(1)                                            // Define a ordem de �ndice 1
    AxCadastro(cAlias,cTitulo,cVldExc,cVldAlt)               // Chama rotina padr�o de cadastro

Return Nil

//=============================================================================
// ALTERA��O DE REGISTRO
//=============================================================================

/*/=============================================================================
    Fun��o: LsAlt
    Descri��o: Valida��o e controle de altera��o de pre�os.
=============================================================================/*/
User Function LsAlt(cAlias,nReg,nOpc)
    local lRet           := .T.                  // Retorno padr�o
    local nPreco         := M->Z3_PRECO          // Pre�o informado
    local cCodPro        := M->Z3_CODPRO         // C�digo do produto
    local dDataCorrente  := M->Z3_DATA           // Data corrente do registro
    Local MaxData        := Nil                  // Vari�vel para armazenar a maior data encontrada
    Local aArea          := Nil                  // Vari�vel para controle de �rea de trabalho

    // Verifica se est� em modo de inclus�o
    IF INCLUI == .T.
        aArea := GetArea()                       // Salva �rea de trabalho atual

        dbSetOrder(2)                            // Define ordem de �ndice 2
        // Verifica se j� existe um registro para o produto com a data atual
        If dbSeek("01IN  " + cCodpro + DTOS(dDataCorrente))
            MsgInfo("J� existe um pre�o para este produto com a data informada. Por favor, verifique o �ltimo pre�o vigente e altere!")
            RestArea(aArea)
            Return .F.
        EndIf

        // Fecha �rea TRB se estiver aberta
        If SELECT("TRB") > 0
            dbSelectArea("TRB")
            dbCloseArea("TRB")
            RestArea(aArea)
        EndIf
        
        // Monta query para buscar a maior data do produto
        cQuery := " SELECT SZ3.Z3_FILIAL, SZ3.Z3_CODPRO, SZ3.Z3_DESCRI, SZ3.Z3_PRECO, SZ3.Z3_DATA  "
        cQuery += " FROM SZ3010 SZ3  "
        cQuery += " WHERE SZ3.D_E_L_E_T_ = '' "
        cQuery += " AND SZ3.Z3_DATA = "
        cQuery += "(   SELECT MAX(CTE.Z3_DATA) "
        cQuery += "FROM SZ3010 CTE "
        cQuery += "WHERE CTE.Z3_CODPRO = SZ3.Z3_CODPRO  "
        cQuery += "GROUP BY CTE.Z3_CODPRO )"   // QUERY RESPONS�VEL POR RETORNAR A MAIOR DATA DE CADA PRODUTO
        cQuery += "AND SZ3.Z3_CODPRO = '" + cCodPro + "' "

        cQuery := ChangeQuery(cQuery)           // Ajusta a query para o ambiente
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),"TRB",.T.,.T.) // Executa a query e abre �rea TRB

        MaxData := TRB->Z3_DATA                 // Atribui a maior data encontrada

        // Se encontrou data e a data corrente � maior ou igual � �ltima data vigente
        if !empty(MaxData) .and. dDataCorrente >= STOD(MaxData)
            aArea := GetArea()
            dbSelectArea("SZ3")
            dbSetOrder(3)
            // Busca o �ltimo pre�o vigente do produto
            if DbSeek("01IN  " + cCodPro + MaxData + "1") // 1 = status ativo
                RecLock("SZ3", .F.)
                Replace SZ3->Z3_VIGENT With "2"           // Altera vigente para 2 - INATIVO
                MsUnlock("SZ3")
            Endif
            RestArea(aArea)
        Endif

    Endif

    // Valida��es de campos obrigat�rios e regras de neg�cio
    if empty(nPreco) 
        MsgInfo("O campo pre�o n�o pode estar vazio!")
        lRet := .F.
        Return lRet
    elseif nPreco < 0
        MsgInfo("O campo pre�o n�o pode ser menor que zero!")
        Return .F.
    elseif M->Z3_DATA < date() 
        MsgInfo("A data do registro n�o pode ser menor que a data atual!")
        Return .F.
    else 
        MsgInfo("Opera��o efetuada!")
    Endif

Return lRet

//=============================================================================
// EXCLUS�O DE REGISTRO
//=============================================================================

/*/=============================================================================
    Fun��o: LsExc
    Descri��o: Mensagem de confirma��o de exclus�o.
    Par�metros:
        cAlias - Alias da tabela
        nReg   - N�mero do registro
        nOpc   - Op��o de exclus�o
    Retorno: .T. (sempre verdadeiro)
=============================================================================/*/
User Function LsExc(cAlias,nReg,nOpc)
    MsgInfo("Exclus�o conclu�da com sucesso!")
Return .T.


