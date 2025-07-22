// ============================================================================
// LIST100.PRW
// Programa para manutenção de preços - Lista 100
// Preços estes que são a cotação do um determinado produto na data vigente, com intuito de precificar o custo
// de cada produto internamente, em ordens de produção, etc.
// ============================================================================
// Autor: Mateus Pereira Barboza
// Data: 11/07/2025
// Descrição: Rotinas para cadastro, alteração e exclusão de preços na tabela SZ3
// ============================================================================

#include "protheus.ch"

/*=============================================================================
    Função: LIST100
    Descrição: Função principal para manutenção de preços da Lista 100.
    Parâmetros: Nenhum
    Retorno: Nil
=============================================================================/*/
User Function LIST100()
    Local cAlias    := "SZ3"                                 // Alias da tabela de preços
    Local cTitulo   := "Manutencao de preços - Lista 100"    // Título da rotina
    Local cVldExc   := "U_LsExc()"                           // Função de validação para exclusão
    Local cVldAlt   := "U_LsAlt()"                           // Função de validação para alteração

    dbSelectArea(cAlias)                                     // Seleciona a área de trabalho SZ3
    dbSetOrder(1)                                            // Define a ordem de índice 1
    AxCadastro(cAlias,cTitulo,cVldExc,cVldAlt)               // Chama rotina padrão de cadastro

Return Nil

//=============================================================================
// ALTERAÇÃO DE REGISTRO
//=============================================================================

/*/=============================================================================
    Função: LsAlt
    Descrição: Validação e controle de alteração de preços.
=============================================================================/*/
User Function LsAlt(cAlias,nReg,nOpc)
    local lRet           := .T.                  // Retorno padrão
    local nPreco         := M->Z3_PRECO          // Preço informado
    local cCodPro        := M->Z3_CODPRO         // Código do produto
    local dDataCorrente  := M->Z3_DATA           // Data corrente do registro
    Local MaxData        := Nil                  // Variável para armazenar a maior data encontrada
    Local aArea          := Nil                  // Variável para controle de área de trabalho

    // Verifica se está em modo de inclusão
    IF INCLUI == .T.
        aArea := GetArea()                       // Salva área de trabalho atual

        dbSetOrder(2)                            // Define ordem de índice 2
        // Verifica se já existe um registro para o produto com a data atual
        If dbSeek("01IN  " + cCodpro + DTOS(dDataCorrente))
            MsgInfo("Já existe um preço para este produto com a data informada. Por favor, verifique o último preço vigente e altere!")
            RestArea(aArea)
            Return .F.
        EndIf

        // Fecha área TRB se estiver aberta
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
        cQuery += "GROUP BY CTE.Z3_CODPRO )"   // QUERY RESPONSÁVEL POR RETORNAR A MAIOR DATA DE CADA PRODUTO
        cQuery += "AND SZ3.Z3_CODPRO = '" + cCodPro + "' "

        cQuery := ChangeQuery(cQuery)           // Ajusta a query para o ambiente
        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),"TRB",.T.,.T.) // Executa a query e abre área TRB

        MaxData := TRB->Z3_DATA                 // Atribui a maior data encontrada

        // Se encontrou data e a data corrente é maior ou igual à última data vigente
        if !empty(MaxData) .and. dDataCorrente >= STOD(MaxData)
            aArea := GetArea()
            dbSelectArea("SZ3")
            dbSetOrder(3)
            // Busca o último preço vigente do produto
            if DbSeek("01IN  " + cCodPro + MaxData + "1") // 1 = status ativo
                RecLock("SZ3", .F.)
                Replace SZ3->Z3_VIGENT With "2"           // Altera vigente para 2 - INATIVO
                MsUnlock("SZ3")
            Endif
            RestArea(aArea)
        Endif

    Endif

    // Validações de campos obrigatórios e regras de negócio
    if empty(nPreco) 
        MsgInfo("O campo preço não pode estar vazio!")
        lRet := .F.
        Return lRet
    elseif nPreco < 0
        MsgInfo("O campo preço não pode ser menor que zero!")
        Return .F.
    elseif M->Z3_DATA < date() 
        MsgInfo("A data do registro não pode ser menor que a data atual!")
        Return .F.
    else 
        MsgInfo("Operação efetuada!")
    Endif

Return lRet

//=============================================================================
// EXCLUSÃO DE REGISTRO
//=============================================================================

/*/=============================================================================
    Função: LsExc
    Descrição: Mensagem de confirmação de exclusão.
    Parâmetros:
        cAlias - Alias da tabela
        nReg   - Número do registro
        nOpc   - Opção de exclusão
    Retorno: .T. (sempre verdadeiro)
=============================================================================/*/
User Function LsExc(cAlias,nReg,nOpc)
    MsgInfo("Exclusão concluída com sucesso!")
Return .T.


