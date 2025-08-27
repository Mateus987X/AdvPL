#INCLUDE "TOTVS.CH"
/*
Descricao
O ponto de entrada POGetProd é executado na requisição de consulta dos produtos após informar os parâmetros de pesquisa.
Com este ponto de entrada, é possível adicionar e remover produtos da pesquisa, além de poder adicionar de forma não obrigatória até duas informações por produto para mostrar no card da pesquisa.

As duas informações customizadas que poderão ser adicionadas a um card na pesquisa terão três atributos cada uma.

O primeiro é "CustomLabel", que é referente a um rótulo ou descrição do valor que será adicionado. 

O segundo é "CustomValue", que é referente ao valor vinculado ao rótulo criado. Ex.: oJson["CustomLabel"] := "Máquina", oJson["CustomValue"] := "Injetora".

O terceiro é "CustomLink", que é referente ao link que será aberto no navegador quando o usuário clicar no campo de valor.

Obs.:

Para mostrar a informação customizada no card de pesquisa, o único atributo de preenchimento obrigatório é o "CustomValue".

Se o atributo "CustomLink" for informado, o atributo "CustomValue" será um link que será aberto no navegador, caso contrário, será apenas um campo texto.
*/ 

User Function POGetProd()
    //Local aAreaSB1  := SB1->(GetArea())
    //Local aAreaSB8  := SB8->(GetArea())
    Local aItemsObj := PARAMIXB[1]
    Local cAliasSB8 := GetNextAlias()
    Local cForm     := PARAMIXB[2]
    Local cLocal    := ""
    Local cQuerySB8 := ""
    Local nLenArr   := Len(aItemsObj)
    Local nSaldo    := 0
    Local nX        := 0
    Local oJson     := Nil
    Local lEmpPrev  := .T. //lQtdPrev  := (GetMV("MV_QTDPREV") == "S")   
                           //Pegando conteúdo do parâmetro
     
    //Adicionando novo card de produto no retorno da pesquisa
    If AllTrim(cForm) == "000007"
        For nX:=1 To nLenArr
            //Adicionando informações customizadas ao card de um produto na pesquisa
            dbSelectArea("SB1")
            SB1->(dbSetOrder(1))
            Conout("Produto: " + AllTrim(aItemsObj[nX]["Code"]) )
            If SB1->(MsSeek(xFilial("SB1") + AllTrim(aItemsObj[nX]["Code"])))
                cLocal  := SB1->B1_LOCPAD
                
                Conout("Produto: " + AllTrim(aItemsObj[nX]["Code"]) )

                cQuerySB8 := "SELECT *"
                cQuerySB8 += " FROM " + RetSqlName("SB8")
                cQuerySB8 += " WHERE B8_FILIAL  = '01IN01' " 
                cQuerySB8 +=   " AND B8_COD     = '" + AllTrim(aItemsObj[nX]["Code"]) + "'"
                cQuerySB8 +=   " AND B8_LOCAL   = '" + cLocal + "'"
                cQuerySB8 +=   " AND B8_SALDO <> 0 "
                cQuerySB8 +=   " AND D_E_L_E_T_ = ' '"
    
                dbUseArea(.T., "TOPCONN", TcGenQry( , , cQuerySB8), cAliasSB8, .T., .T.)
                While (cAliasSB8)->(!Eof())
                    //nSaldo += SaldoSB2(,,,,,cAliasSB2,,,,,)
                    nSaldo := SB8Saldo(Nil, Nil, Nil, Nil, cAliasSB8, lEmpPrev, .T.)
                    Conout("Saldo no armazém padrão (" + CValToChar(nSaldo) + ")" )
                    (cAliasSB8)->(dbSkip())
                End
    
                (cAliasSB8)->(dbCloseArea())
    
                aItemsObj[nX]["CustomLabel1"] := "Saldo no armazém padrão (" + cLocal + ")"
                aItemsObj[nX]["CustomValue1"] := CValToChar(nSaldo)
                aItemsObj[nX]["CustomLink1"]  := ""
    
                nSaldo := 0

            EndIf

        Next nX
    
      Conout("antes do if"  )
        //Adicionando novo card de produto no retorno da pesquisa
        If AllTrim(cForm) == "000007"
          Conout("dentro do if"  )
            oJson := JsonObject():New()
            oJson["Code"]         := "PRODUTO3"
            oJson["Description"]  := "DESCRICAO PRODUTO 3"
            oJson["CustomLabel1"] := ""
            oJson["CustomValue1"] := ""
            oJson["CustomLink1"]  := ""
            oJson["CustomLabel2"] := ""
            oJson["CustomValue2"] := ""
            oJson["CustomLink2"]  := ""
            aAdd(aItemsObj, oJson)
        EndIf
    
        //excluindo card de produto do retorno da pesquisa
        nX := Ascan(aItemsObj,{|x| AllTrim(x["Code"]) == "PRODUTO"})
        If nX > 0
            aDel(aItemsObj, nX)
            aSize(aItemsObj, Len(aItemsObj)-1)
        EndIf
Else
      Conout("formulario nao é 000007: "  )
EndIf 
    FreeObj(oJson)   
 
Return aItemsObj
