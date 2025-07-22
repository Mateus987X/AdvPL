// PONTOS DE ENTRADA DA ROTINA DESMONTAGEM PARA CALCULO DE CUSTO DINÂMICOS PARA O SETOR DA CONTABILIDADE E AFINS //
// AUTOR: MATEUS PEREIRA BARBOZA //
// DATA: 22/07/2025 //


#include 'protheus.ch'
#include 'parmtype.ch'

// ****** VALIDA SE APENAS UM SUB-PRODUTO ESTÁ SENDO VALORIZADO OU SE NÃO HÁ NENHUM SUB-PRODUTO VALORIZADO ********
User Function MTA242V()
    Local nXi := 0 // Índice para iteração
    Local cProdutosValorizados := {} // Variável para armazenar produtos valorizados
    Local lRet := .T. // Variável de retorno para controle de fluxo    
        //Valida se o campo D3_VALORIZ está preenchido com apenas um produto ou está vazio
        for nXi := 1 to Len(aCols)
            if aCols[nxi][7] == "2" 
                aAdd(cProdutosValorizados, aCols[nXi][1]) // Adiciona o código do produto valorizado ao array
            EndIf
        Next nXi

        if (Len(cProdutosValorizados) > 1) // Se houver mais de um produto valorizado
            MsgInfo("Apenas um sub-produto pode ser valorizado", "Erro") // Exibe mensagem de erro
            Return .F.
        elseif (Len(cProdutosValorizados) == 0) // Se não houver produtos valorizados
            if MsgYesNo("Nehum sub-produto está sendo valorizado, deseja continuar?")
                lRet := .T. // Continua o processo
            else
                Return .F. // Cancela o processo
            EndIf
        EndIf
        
Return lRet


// ****** FUNÇÃO PARA ATUALIZAR E CALCULAR O CUSTO DO SUB-PRODUTO PRINCIPAL ********
User Function MTA242I()
    Local nOpcao := PARAMIXB[1] // Opção escolhida
    Local nQuantidade := 0 // Quantidade do subproduto
    Local cArmazem := "" // Armazém do subproduto
    Local lValoriz := "" // Valorização do subproduto (1 - Não valoriza, 2 - Valoriza)
    Local nPreco := 0 // Preço do subproduto
    Local aSubProdutos := {} // Array para armazenar subprodutos
    Local cCodSubProd := "" // Código do subproduto
    Local nSubProdCustoTotal := 0 // Custo total do subproduto
    Local nXi := 0 // Índice para iteração
    Local TotalSubProdutos := 0
    Local nQuantidadePrincipal := 0 // Quantidade do subproduto principal
    Local nProdValorizado := 0 // Valor do produto valorizado


    Private cSubProdPrincipal := "" // Código do subproduto principal
    Private cArmazemPrincipal := "" // Armazém do subproduto principal

    nCustoTotal := CustoProdOri() // Chama a função para calcular o custo total do produto de origem

    if nOpcao == 1 // Se a opção for 1 (Inclusão)

    //****** FAZ A SOMA DO CUSTO DOS SUBPRODUTOS ***********
        for nXi := 1 to len(aCols)
            cCodSubprod := aCols[nXi][1] // Código do subproduto
            cArmazem := aCols[nXi][2] // Armazém do subproduto
            nQuantidade := aCols[nXi][4] // Quantidade do subproduto
            nPreco := aCols[nXi][6] // Preço do subproduto
            lValoriz := aCols[nXi][7] // Valorização do subproduto (1 - Não valoriza, 2 - Valoriza)

            if lValoriz == "1" // Se o subproduto não for valorizado
                nSubProdCustoTotal := nQuantidade * nPreco // Cálculo do custo total do subproduto
                TotalSubProdutos += nSubProdCustoTotal // Acumula o custo total dos subprodutos
                aAdd(aSubProdutos, {cCodSubProd, Round(nSubProdCustoTotal,2)}) // Adiciona o subproduto e seu custo total ao array
            elseif lValoriz == "2" // Se o subproduto for valorizado
                cSubProdPrincipal := cCodSubprod // Armazena o código do subproduto principal a ser valorizado
                cArmazemPrincipal := cArmazem // Armazém do subproduto principal
                nQuantidadePrincipal := nQuantidade // Quantidade do subproduto principal

            EndIf
        Next nXi
    
    //****** FIM DA SOMA DO CUSTO DOS SUBPRODUTOS ***********
        nCustoTotal := nCustoTotal - TotalSubProdutos // Subtrai o custo total dos subprodutos do custo total do produto de origem 
        nProdValorizado := Round(nCustoTotal / nQuantidadePrincipal,2) // Calcula o custo do produto valorizado

    
    //****** ATUALIZA O PREÇO DO SUBPRODUTO PRINCIPAL NO ACOLS ***********
        for nXi := 1 to len(aCols)
            if aCols[nXi][1] == cSubProdPrincipal // Verifica se o código do subproduto é o principal
                aCols[nXi][6] := nProdValorizado // Atualiza o preço do subproduto principal com o custo valorizado
            EndIf
        Next nXi

    Endif
Return 

// *******FUNCAO PARA CALCULAR O CUSTO TOTAL DO PRODUTO PAI********
Static Function CustoProdOri()
    Local cCodPro := CPRODUTO // Código do produto origem
    Local cArmazem := CLOCORIG // Armazém de origem
    Local nQuantidade := NQTDORIG // Quantidade a ser desmontada
    Local nCusto := 0 // Custo do produto de origem

    Private nCustoTotal := 0 // Custo total do produto de origem
    

    dbSelectArea("SB2")
    dbSetOrder(1)  // Define a ordem de índice 1

    if dbSeek(xFilial("SB2") + cCodpro + cArmazem)
        nCusto := SB2 -> B2_CM1
        nCustoTotal := Round(nCusto * nQuantidade,2) // Calcula o custo total e arredonda o custo para duas casas decimais
    Else
        MsgInfo("Produto origem não encontrado no armazém especificado.", "Erro")
        Return
    EndIf

Return nCustoTotal


    
